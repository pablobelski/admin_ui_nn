import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class JobUpdate {
  const JobUpdate(this.quoteIds, {this.reset = false});
  final Set<String> quoteIds;
  final bool reset;
  bool affects(String quoteId) => reset || quoteIds.contains(quoteId);
}

// Shared by the header, open quote panels and completion waiters in this session.
class JobUpdates {
  JobUpdates(this._api);
  final ApiClient _api;
  final _events = StreamController<JobUpdate>.broadcast();
  final _quotes = <String, int>{};
  final _revisions = <String, int>{};
  final _random = Random();
  http.Client? _transport;
  Completer<void>? _abort;
  Timer? _reconnect;
  Timer? _fallback;
  int _generation = 0;
  int _failures = 0;
  int _revision = 0;
  int _waiters = 0;
  bool _fallbackLoading = false;
  bool _blocked = false;
  bool _disposed = false;
  bool connected = false;
  bool stale = true;
  List<Map<String, dynamic>> jobs = const [];

  Stream<JobUpdate> get changes => _events.stream;
  bool get disposed => _disposed;
  int revision(String quoteId) => _revisions[quoteId] ?? 0;

  void start() => _restart();

  void Function() watchQuote(String quoteId, {bool waiting = false}) {
    if (_disposed || quoteId.isEmpty) return () {};
    final first = !_quotes.containsKey(quoteId);
    if (first && _quotes.length >= 20) throw StateError('Too many quotes are being monitored.');
    _quotes.update(quoteId, (count) => count + 1, ifAbsent: () => 1);
    if (waiting) _waiters++;
    if (first) _restart();
    if (!connected && waiting) { _fallback?.cancel(); _fallback = null; _scheduleFallback(); }
    var released = false;
    return () {
      if (released || _disposed) return;
      released = true;
      if (waiting) _waiters--;
      final remaining = (_quotes[quoteId] ?? 1) - 1;
      if (remaining > 0) { _quotes[quoteId] = remaining; return; }
      _quotes.remove(quoteId);
      _revisions.remove(quoteId);
      _restart();
    };
  }

  void _publish(JobUpdate update) {
    if (_disposed) return;
    _revision++;
    for (final id in _quotes.keys) {
      if (update.affects(id)) _revisions[id] = _revision;
    }
    _events.add(update);
  }

  void _restart() {
    if (_disposed || _blocked) return;
    _generation++;
    _closeTransport();
    connected = false;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(milliseconds: 150), () => unawaited(_connect()));
    _scheduleFallback();
  }

  Future<void> _connect() async {
    if (_disposed || _blocked) return;
    final generation = ++_generation;
    final client = http.Client();
    _closeTransport();
    _transport = client;
    final abort = Completer<void>();
    _abort = abort;
    try {
      final ids = _quotes.keys.toList()..sort();
      final request = http.AbortableRequest('GET', Uri.parse(_api.url(
        '/api/internal/calculator/job-events',
        ids.isEmpty ? null : {'quote_ids': ids.join(',')},
      )), abortTrigger: abort.future)..headers.addAll(_api.authHeaders(extra: {'Accept': 'text/event-stream'}));
      final response = await client.send(request).timeout(const Duration(seconds: 10));
      if (_disposed || generation != _generation) return;
      if (response.statusCode == 401 || response.statusCode == 403) {
        _blocked = true; // A new authenticated session creates a new service.
        throw StateError('Task stream authorization expired.');
      }
      if (response.statusCode != 200 ||
          !(response.headers['content-type'] ?? '').startsWith('text/event-stream')) {
        throw StateError('Task stream is unavailable.');
      }
      var event = '';
      var data = '';
      // http 1.6.0 in the existing lockfile streams BrowserClient responses via fetch.
      await for (final line in response.stream.timeout(const Duration(seconds: 45))
          .transform(utf8.decoder).transform(const LineSplitter())) {
        if (_disposed || generation != _generation) return;
        if (line.isEmpty) {
          if (event == 'jobs' && data.isNotEmpty) {
            _accept(Map<String, dynamic>.from(jsonDecode(data) as Map));
          }
          event = ''; data = '';
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data += '${line.substring(5).trimLeft()}\n';
          if (data.length > 1024 * 1024) throw StateError('Task stream frame is too large.');
        }
      }
    } catch (_) {
      // The shared fallback covers all subscribers while the stream reconnects.
    } finally {
      if (!abort.isCompleted) abort.complete();
      client.close();
      if (!_disposed && generation == _generation) {
        _transport = null;
        connected = false;
        stale = true;
        _publish(const JobUpdate({}));
        if (!_blocked) {
          _failures = min(_failures + 1, 5);
          final delay = min(30, 1 << _failures);
          _reconnect = Timer(Duration(milliseconds: delay * 1000 + _random.nextInt(1000)),
              () => unawaited(_connect()));
          _scheduleFallback();
        } else {
          _fallback?.cancel(); _fallback = null;
        }
      }
    }
  }

  void _closeTransport() {
    final abort = _abort;
    if (abort != null && !abort.isCompleted) abort.complete();
    _abort = null;
    _transport?.close();
    _transport = null;
  }

  List<Map<String, dynamic>> _rows(Object? value) => (value as List? ?? const [])
      .whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();

  void _accept(Map<String, dynamic> data) {
    jobs = _rows(data['jobs']);
    connected = true;
    stale = false;
    _failures = 0;
    _fallback?.cancel(); _fallback = null;
    final ids = <String>{
      for (final id in data['quote_ids'] as List? ?? const []) '$id',
      for (final id in data['denied_quote_ids'] as List? ?? const []) '$id',
    };
    _publish(JobUpdate(ids, reset: data['reset'] == true));
  }

  void _scheduleFallback() {
    if (_disposed || _blocked || connected || _fallback != null) return;
    final seconds = jobs.isNotEmpty || _waiters > 0 ? 5 : 30;
    _fallback = Timer(Duration(milliseconds: seconds * 1000 + _random.nextInt(1000)), () {
      _fallback = null;
      unawaited(_poll());
    });
  }

  Future<void> _poll() async {
    if (_disposed || _blocked || connected || _fallbackLoading) return;
    _fallbackLoading = true;
    try {
      final data = await _api.getJson('/api/internal/calculator/active-jobs')
          .timeout(const Duration(seconds: 10));
      if (_disposed || connected) return;
      jobs = _rows(data['jobs']);
      stale = false;
      _publish(const JobUpdate({}, reset: true));
    } catch (_) {
      if (!_disposed && !connected) { stale = true; _publish(const JobUpdate({})); }
    } finally {
      _fallbackLoading = false;
      _scheduleFallback();
    }
  }

  Future<bool> waitForChange(String quoteId, int previous, Duration timeout,
      {bool Function()? shouldContinue}) async {
    if (_disposed || (shouldContinue != null && !shouldContinue())) return false;
    if (revision(quoteId) != previous) return true;
    final done = Completer<bool>();
    void finish(bool changed) { if (!done.isCompleted) done.complete(changed); }
    final subscription = changes.listen((update) {
      if (update.affects(quoteId)) finish(true);
    }, onDone: () => finish(false));
    final deadline = Timer(timeout, () => finish(false));
    final cancellation = shouldContinue == null ? null : Timer.periodic(
      const Duration(seconds: 1), (_) { if (!shouldContinue()) finish(false); });
    try { return await done.future; }
    finally { deadline.cancel(); cancellation?.cancel(); await subscription.cancel(); }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _reconnect?.cancel(); _fallback?.cancel(); _closeTransport();
    unawaited(_events.close());
  }
}
