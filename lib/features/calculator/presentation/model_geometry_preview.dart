import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/http/admin_resource_repository.dart';
import '../../../core/ui/media_file_actions.dart';
import '../../../core/ui/top_notification.dart';
import '../data/calculator_models.dart';
import '../data/roof_geometry_calculation.dart';

const geometryOnlyPreviewWidth = 450;
const geometryOnlyPreviewHeight = 305;

Rect _geometryPreviewSideRect(Size size, double pad) {
  final targetWidth = math.min(122.0, math.max(104.0, size.width * 0.27));
  final left = math.max(pad + 80.0, size.width - pad - targetWidth);
  return Rect.fromLTWH(
    left,
    pad,
    math.max(48.0, size.width - pad - left),
    size.height - pad * 2,
  );
}

String _firstSentence(String value) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return '';
  final match = RegExp(r'^.*?[.!?](?:\s|$)').firstMatch(text);
  return match?.group(0)?.trim() ?? text;
}

class ModelGeometryPreview extends ConsumerStatefulWidget {
  const ModelGeometryPreview({
    super.key,
    required this.modelCode,
    required this.modelLabel,
    required this.mediaRepository,
    this.widthMm,
    this.depthMm,
    this.heightMm,
    this.geometryParams = const [],
    this.modules = const [],
    this.moduleRoles = const [],
    this.calculatedModules = const [],
    this.calculationNumber,
    this.calculationSavedAt,
    this.buyerName,
    this.buyerContactName,
    this.buyerEmail,
    this.buyerPhone,
    this.weights = const {},
    this.deliveryName,
    this.completionWeek,
    this.colorCode,
    this.colorSwatchColor,
    this.isSpecialColor = false,
    this.coveringName,
    this.wallMounted = false,
    this.postCount = 0,
    this.quoteNotes,
    this.warnings = const [],
    this.highlightedModuleIndex,
    this.highlightedGlassFieldIndex,
    this.roofAngleDeg,
    this.rearHeightMm,
    this.frontHeightMm,
  });

  final String? modelCode;
  final String? modelLabel;
  final AdminResourceRepository mediaRepository;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final List<RoofGeometryParam> geometryParams;
  final List<CalculatorSetContentTab> modules;
  final List<String> moduleRoles;
  final List<RoofModuleCalculation> calculatedModules;
  final String? calculationNumber;
  final String? calculationSavedAt;
  final String? buyerName;
  final String? buyerContactName;
  final String? buyerEmail;
  final String? buyerPhone;
  final Map<String, dynamic> weights;
  final String? deliveryName;
  final int? completionWeek;
  final String? colorCode;
  final Color? colorSwatchColor;
  final bool isSpecialColor;
  final String? coveringName;
  final bool wallMounted;
  final int postCount;
  final String? quoteNotes;
  final List<String> warnings;
  final int? highlightedModuleIndex;
  final int? highlightedGlassFieldIndex;
  final int? roofAngleDeg;
  final int? rearHeightMm;
  final int? frontHeightMm;

  @override
  ConsumerState<ModelGeometryPreview> createState() => _ModelGeometryPreviewState();
}

class _ModelGeometryPreviewState extends ConsumerState<ModelGeometryPreview> {
  late Future<ui.Image?> _humanImageFuture;

  @override
  void initState() {
    super.initState();
    _humanImageFuture = _loadHumanImage();
  }

  Future<ui.Image?> _loadHumanImage() async {
    try {
      final mediaFile = await widget.mediaRepository.findMediaFileByOriginalFilename('human.png');
      final fileId = mediaFile?['id']?.toString().trim() ?? '';
      if (fileId.isEmpty) return null;
      final response = await widget.mediaRepository.viewMediaFile(fileId);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(response.bytes, completer.complete);
      return completer.future;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = _modelDisplayLabel;
    final hasSelection = widget.modelCode?.trim().isNotEmpty ?? false;
    final authSession = ref.watch(authSessionProvider);
    final currentUser = _currentUserLabel(authSession);

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schema_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('Geometry preview', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'Open printable geometry preview',
                  onPressed: hasSelection ? () => _showExpandedPreview(context, currentUser) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: const Icon(Icons.print_outlined, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasSelection
                  ? 'Schematic of $label, scaled to the entered dimensions.'
                  : 'Select a model to show a schematic of the roof shape.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (widget.wallMounted) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_outlined, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Wandmontage',
                    style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              width: double.infinity,
              child: _buildGeometryCanvas(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  String get _modelDisplayLabel {
    final label = widget.modelLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    final code = widget.modelCode?.trim();
    return code != null && code.isNotEmpty ? code : 'No model selected';
  }

  Widget _buildGeometryCanvas(
    ColorScheme colorScheme, {
    bool clearHighlight = false,
    double sideInfoBottomReserve = 0.0,
  }) {
    return FutureBuilder<ui.Image?>(
      future: _humanImageFuture,
      builder: (context, snapshot) {
        return CustomPaint(
          painter: _ModelGeometryPreviewPainter(
            modelCode: widget.modelCode,
            modelLabel: widget.modelLabel,
            widthMm: widget.widthMm,
            depthMm: widget.depthMm,
            heightMm: widget.heightMm,
            geometryParams: widget.geometryParams,
            colorCode: widget.colorCode,
            colorSwatchColor: widget.colorSwatchColor,
            isSpecialColor: widget.isSpecialColor,
            coveringName: widget.coveringName,
            humanImage: snapshot.data,
            lineColor: colorScheme.onSurface,
            mutedLineColor: colorScheme.onSurfaceVariant,
            accentColor: colorScheme.primary,
            surfaceColor: colorScheme.surface,
            highlightedModuleIndex: clearHighlight ? null : widget.highlightedModuleIndex,
            highlightedGlassFieldIndex: clearHighlight ? null : widget.highlightedGlassFieldIndex,
            roofAngleDeg: widget.roofAngleDeg,
            rearHeightMm: widget.rearHeightMm,
            frontHeightMm: widget.frontHeightMm,
            calculatedModules: widget.calculatedModules,
            wallMounted: widget.wallMounted,
            postCount: widget.postCount,
            sideInfoBottomReserve: sideInfoBottomReserve,
          ),
        );
      },
    );
  }

  Future<void> _showExpandedPreview(BuildContext context, String currentUser) async {
    final repaintBoundaryKey = GlobalKey();
    final colorScheme = Theme.of(context).colorScheme;
    final exportDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(28),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280, maxHeight: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                  child: Row(
                    children: [
                      Icon(Icons.schema_outlined, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Geometry preview · $_modelDisplayLabel',
                          style: Theme.of(dialogContext).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Download PNG',
                        onPressed: () => _downloadExpandedPreview(
                          repaintBoundaryKey,
                          exportDate,
                        ),
                        icon: const Icon(Icons.download_outlined),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: RepaintBoundary(
                      key: repaintBoundaryKey,
                      child: ColoredBox(
                        color: colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 320,
                                child: _ExpandedPreviewInfo(
                                  modelLabel: _modelDisplayLabel,
                                  modelCode: widget.modelCode,
                                  buyerName: widget.buyerName,
                                  buyerContactName: widget.buyerContactName,
                                  buyerEmail: widget.buyerEmail,
                                  buyerPhone: widget.buyerPhone,
                                  weights: widget.weights,
                                  deliveryName: widget.deliveryName,
                                  completionWeek: widget.completionWeek,
                                  widthMm: widget.widthMm,
                                  depthMm: widget.depthMm,
                                  heightMm: widget.heightMm,
                                  roofAngleDeg: widget.roofAngleDeg,
                                  colorCode: widget.colorCode,
                                  isSpecialColor: widget.isSpecialColor,
                                  coveringName: widget.coveringName,
                                  wallMounted: widget.wallMounted,
                                  calculatedModules: widget.calculatedModules,
                                  postCount: widget.postCount,
                                  currentUser: currentUser,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final sideRect = _geometryPreviewSideRect(
                                            Size(
                                              constraints.maxWidth,
                                              constraints.maxHeight,
                                            ),
                                            12,
                                          );
                                          final dateRightInset = math.max(
                                            12.0,
                                            constraints.maxWidth - sideRect.left + 9.0,
                                          );
                                          final calculationNumber =
                                              widget.calculationNumber?.trim();
                                          final qrSize = math.min(
                                            72.0,
                                            sideRect.width - 16.0,
                                          );
                                          final hasQr = calculationNumber != null &&
                                              calculationNumber.isNotEmpty;
                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              _buildGeometryCanvas(
                                                colorScheme,
                                                clearHighlight: true,
                                                sideInfoBottomReserve:
                                                    hasQr ? qrSize + 16 : 0.0,
                                              ),
                                              Positioned(
                                                left: 12,
                                                right: dateRightInset,
                                                top: 8,
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Kommission: ${_expandedKommissionLabel(widget.calculationNumber)}',
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: Theme.of(
                                                          dialogContext,
                                                        )
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color:
                                                                  Colors.black87,
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Text(
                                                      'Date: ${_displaySavedDate(widget.calculationSavedAt)}',
                                                      maxLines: 1,
                                                      style: Theme.of(
                                                        dialogContext,
                                                      )
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                Colors.black87,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (widget.warnings.isNotEmpty ||
                                                  widget.quoteNotes
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true)
                                                Positioned(
                                                  left: 12,
                                                  right: 12,
                                                  bottom: 8,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      if (widget
                                                          .warnings.isNotEmpty)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 5,
                                                            vertical: 3,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: colorScheme
                                                                .surface
                                                                .withValues(
                                                                  alpha: 0.86,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(4),
                                                          ),
                                                          child: Text(
                                                            widget.warnings
                                                                .map(
                                                                  _firstSentence,
                                                                )
                                                                .where(
                                                                  (message) =>
                                                                      message
                                                                          .isNotEmpty,
                                                                )
                                                                .toSet()
                                                                .join('\n'),
                                                            maxLines: 3,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: Theme.of(
                                                              dialogContext,
                                                            )
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  fontSize: 9,
                                                                  height: 1.15,
                                                                  color:
                                                                      colorScheme
                                                                          .error,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                      if (widget.warnings
                                                              .isNotEmpty &&
                                                          widget.quoteNotes
                                                                  ?.trim()
                                                                  .isNotEmpty ==
                                                              true)
                                                        const SizedBox(height: 4),
                                                      if (widget.quoteNotes
                                                              ?.trim()
                                                              .isNotEmpty ==
                                                          true)
                                                        Text(
                                                          widget.quoteNotes!
                                                              .trim(),
                                                          maxLines: 3,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(
                                                            dialogContext,
                                                          )
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color:
                                                                    Colors.black,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              if (hasQr)
                                                Positioned(
                                                  left: sideRect.left +
                                                      (sideRect.width - qrSize) /
                                                          2,
                                                  bottom: constraints.maxHeight -
                                                      sideRect.bottom +
                                                      8,
                                                  child: QrImageView(
                                                    data: calculationNumber!,
                                                    version: QrVersions.auto,
                                                    size: qrSize,
                                                    padding:
                                                        const EdgeInsets.all(10),
                                                    backgroundColor: Colors.white,
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _ExpandedPreviewModules(
                                      calculatedModules: widget.calculatedModules,
                                      modules: widget.modules,
                                      moduleRoles: widget.moduleRoles,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadExpandedPreview(GlobalKey repaintBoundaryKey, DateTime exportDate) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = repaintBoundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Geometry preview is not ready for export.');
      }

      final image = await renderObject.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('PNG encoding failed.');

      final calculation = widget.calculationNumber?.trim();
      final baseName = calculation == null || calculation.isEmpty ? 'roof_geometry' : calculation;
      downloadMediaBytes(
        byteData.buffer.asUint8List(),
        filename: '${_safeFilename(baseName)}_${_fileDate(exportDate)}.png',
        contentType: 'image/png',
      );
    } catch (error) {
      if (!mounted) return;
      showTopNotification(
        context,
        'Geometry preview download failed: $error',
        type: TopNotificationType.error,
      );
    }
  }
}

class _ExpandedPreviewInfo extends StatelessWidget {
  const _ExpandedPreviewInfo({
    required this.modelLabel,
    required this.modelCode,
    required this.buyerName,
    required this.buyerContactName,
    required this.buyerEmail,
    required this.buyerPhone,
    required this.weights,
    required this.deliveryName,
    required this.completionWeek,
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
    required this.roofAngleDeg,
    required this.colorCode,
    required this.isSpecialColor,
    required this.coveringName,
    required this.wallMounted,
    required this.calculatedModules,
    required this.postCount,
    required this.currentUser,
  });

  final String modelLabel;
  final String? modelCode;
  final String? buyerName;
  final String? buyerContactName;
  final String? buyerEmail;
  final String? buyerPhone;
  final Map<String, dynamic> weights;
  final String? deliveryName;
  final int? completionWeek;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final int? roofAngleDeg;
  final String? colorCode;
  final bool isSpecialColor;
  final String? coveringName;
  final bool wallMounted;
  final List<RoofModuleCalculation> calculatedModules;
  final int postCount;
  final String currentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final modelCodeValue = modelCode?.trim();
    final buyerNameValue = buyerName?.trim();
    final contactDetails = [buyerContactName, buyerEmail, buyerPhone]
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' · ');
    double weight(String key) => (weights[key] as num?)?.toDouble() ?? 0;
    bool complete(String key) => weights[key] is bool ? weights[key] as bool : true;
    String weightText(String valueKey, String completeKey) {
      if (weights.isEmpty) return '—';
      return '${weight(valueKey).toStringAsFixed(1)} kg${complete(completeKey) ? '' : '*'}';
    }

    final nonGlassComplete = complete('set_complete')
        && complete('accessories_complete')
        && complete('options_complete');
    final nonGlassWeight =
        weight('set_kg') + weight('accessories_kg') + weight('options_kg');
    final totalGlassCount = calculatedModules.fold<int>(
      0,
      (sum, module) => sum + module.glassCount,
    );
    final totalBeamCount = calculatedModules.fold<int>(
      0,
      (sum, module) => sum + module.beamCount,
    );
    final glassName = coveringName?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: DefaultTextStyle(
        style: theme.textTheme.bodySmall ?? const TextStyle(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Text('Roof geometry', style: theme.textTheme.titleLarge),
            //const SizedBox(height: 14),
            _PreviewMetadataRow(
              label: 'Besteller / Auftraggeber',
              value: buyerNameValue == null || buyerNameValue.isEmpty ? '—' : buyerNameValue,
            ),
            if (contactDetails.isNotEmpty)
              _PreviewMetadataRow(label: 'Configurator contact', value: contactDetails),
            _PreviewMetadataRow(
              label: 'Roof type',
              value: modelCodeValue == null || modelCodeValue.isEmpty
                  ? modelLabel
                  : '$modelLabel ($modelCodeValue)',
            ),
            if (colorCode?.trim().isNotEmpty == true)
              _PreviewMetadataRow(
                label: isSpecialColor ? 'Color (Sonderfarbe)' : 'Color',
                value: colorCode!.trim(),
              ),
            if (glassName.isNotEmpty || totalGlassCount > 0)
              _PreviewMetadataRow(
                label: 'Covering',
                value: 'Glas: ${glassName.isEmpty ? '—' : glassName} · $totalGlassCount stk.',
              ),
            _PreviewMetadataRow(
              label: 'Set content',
              value: 'Pfosten: $postCount stk.\nTräger: $totalBeamCount stk.',
            ),
            if (wallMounted)
              const _PreviewMetadataRow(label: 'Montage', value: 'Wandmontage'),
            if ((deliveryName ?? '').trim().isNotEmpty || completionWeek != null)
              _PreviewMetadataRow(
                label: 'Delivery',
                value: [
                  if ((deliveryName ?? '').trim().isNotEmpty) deliveryName!.trim(),
                  if (completionWeek != null) 'Fertigst. KW $completionWeek',
                ].join(' · '),
              ),
            _PreviewMetadataRow(
              label: 'Gewicht',
              value: '${weights.isEmpty ? '—' : '${nonGlassWeight.toStringAsFixed(1)} kg${nonGlassComplete ? '' : '*'}'} / '
                  'Glas: ${weightText('glass_kg', 'glass_complete')} / '
                  'Gesamt: ${weightText('total_kg', 'total_complete')}',
            ),
            _PreviewMetadataRow(
              label: 'Overall dimensions',
              value: 'B: ${_dimensionValue(widthMm)} mm × T: ${_dimensionValue(depthMm)} mm × H: ${_dimensionValue(heightMm)} mm',
            ),
            if (roofAngleDeg != null) _PreviewMetadataRow(label: 'Roof angle', value: '$roofAngleDeg°'),
            const Spacer(),
            const Divider(),
            _PreviewMetadataRow(label: 'User', value: currentUser),
          ],
        ),
      ),
    );
  }
}

class _ExpandedPreviewModules extends StatelessWidget {
  const _ExpandedPreviewModules({
    required this.calculatedModules,
    required this.modules,
    required this.moduleRoles,
  });

  final List<RoofModuleCalculation> calculatedModules;
  final List<CalculatorSetContentTab> modules;
  final List<String> moduleRoles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text('Modules', style: theme.textTheme.labelLarge),
          const SizedBox(height: 5),
          if (modules.isEmpty)
            Text('—', style: theme.textTheme.bodyMedium)
          else
            for (var index = 0; index < modules.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${index + 1} · ${_moduleLabel(_effectiveModuleRole(modules[index], index, moduleRoles), index + 1)} · '
                  'T: ${_dimensionValue(modules[index].moduleDepthMm)} mm × '
                  'B: ${_dimensionValue(modules[index].moduleWidthMm)} mm · '
                  'Glas: ${calculatedModules.where((entry) => entry.moduleIndex == index + 1).firstOrNull?.glassCount ?? '—'} · '
                  'Träger: ${calculatedModules.where((entry) => entry.moduleIndex == index + 1).firstOrNull?.beamCount ?? '—'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
        ],
      ),
    );
  }
}

class _PreviewMetadataRow extends StatelessWidget {
  const _PreviewMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _currentUserLabel(AuthSessionState session) {
  final fullName = session.fullName?.trim();
  final email = session.email?.trim();
  if (fullName != null && fullName.isNotEmpty) {
    if (email != null && email.isNotEmpty) return '$fullName · $email';
    return fullName;
  }
  if (email != null && email.isNotEmpty) return email;
  return '—';
}


String _effectiveModuleRole(
  CalculatorSetContentTab module,
  int index,
  List<String> moduleRoles,
) {
  final storedRole = module.moduleRole.trim();
  final normalized = storedRole.toLowerCase();
  final isGenericRole = storedRole.isEmpty || RegExp(r'^module[_\s-]*\d+$').hasMatch(normalized);
  if (isGenericRole && index < moduleRoles.length) {
    final configuredRole = moduleRoles[index].trim();
    if (configuredRole.isNotEmpty) return configuredRole;
  }
  return storedRole;
}

String _moduleLabel(String role, int index) {
  final value = role.trim();
  if (value.isEmpty) return 'Module $index';
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _dimensionValue(int? value) => value == null ? '—' : '$value';

String _expandedKommissionLabel(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? 'New calculation' : normalized;
}

String _displayDate(DateTime value) {
  final local = value.toLocal();
  String two(int item) => item.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String _displaySavedDate(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return '—';
  final parsed = DateTime.tryParse(normalized);
  return parsed == null ? normalized : _displayDate(parsed);
}

String _fileDate(DateTime value) {
  String two(int item) => item.toString().padLeft(2, '0');
  return '${value.year}${two(value.month)}${two(value.day)}_${two(value.hour)}${two(value.minute)}';
}

String _safeFilename(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return normalized.isEmpty ? 'roof_geometry' : normalized;
}

List<RoofGeometryParam> geometryPreviewParamsFromDraft(CalculatorDraft draft) {
  final params = <RoofGeometryParam>[
    RoofGeometryParam('B', draft.widthMm),
    RoofGeometryParam('BR', draft.widthMm),
    RoofGeometryParam('BW', draft.widthMm),
    RoofGeometryParam('TK', draft.depthMm),
    RoofGeometryParam('T', draft.depthMm),
    RoofGeometryParam('D', draft.depthMm),
    RoofGeometryParam('H', draft.heightMm),
  ];

  for (var i = 0; i < draft.setContents.length; i++) {
    final tab = draft.setContents[i];
    final index = i + 1;
    params.add(RoofGeometryParam('BR$index', tab.blockWidthMm));
    params.add(RoofGeometryParam('BW$index', tab.blockWidthMm));
    params.add(RoofGeometryParam('TK$index', tab.blockDepthMm));
  }

  return params;
}

class RoofGeometryParam {
  const RoofGeometryParam(this.code, this.valueMm);

  final String code;
  final int? valueMm;
}

enum _RoofShape {
  rectangle,
  lFront,
  lBack,
  uBack,
  tBack,
  angleFront,
  angleBack,
}

class _RoofProfile {
  const _RoofProfile({
    required this.shape,
    required this.smallPartOnLeft,
    this.mirrorView = false,
  });

  final _RoofShape shape;
  final bool smallPartOnLeft;
  final bool mirrorView;
}

class _RoofLayout {
  const _RoofLayout({
    required this.front,
    required this.back,
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
    required this.dimensions,
    required this.postPoints,
    required this.rafterX,
    this.moduleAreas = const [],
    this.widthDimensionsOnFront = false,
  });

  final List<Offset> front;
  final List<Offset> back;
  final double widthMm;
  final double depthMm;
  final double heightMm;
  final List<_RoofDimensionLine> dimensions;
  final List<Offset> postPoints;
  final List<double> rafterX;
  final List<_RoofModuleArea> moduleAreas;
  final bool widthDimensionsOnFront;
}

class _RoofModuleArea {
  const _RoofModuleArea({required this.index, required this.corners});

  final int index;
  final List<Offset> corners;
}

class _RoofDimensionLine {
  const _RoofDimensionLine({
    required this.code,
    required this.start,
    required this.end,
    this.offset = Offset.zero,
    this.hAlign = 0.5,
  });

  final String code;
  final Offset start;
  final Offset end;
  final Offset offset;
  final double hAlign;
}

class _PostCornerGroups {
  const _PostCornerGroups({
    this.external = const [],
    this.internal = const [],
  });

  final List<Offset> external;
  final List<Offset> internal;
}

class _GeometryParamBag {
  _GeometryParamBag(List<RoofGeometryParam> params)
      : _values = {
          for (final param in params)
            if (param.valueMm != null && param.valueMm! > 0) _normalizeCode(param.code): param.valueMm!.toDouble(),
        };

  final Map<String, double> _values;

  double value(List<String> codes, double fallback) {
    for (final code in codes) {
      final value = _values[_normalizeCode(code)];
      if (value != null && value > 0) return value;
    }
    return fallback;
  }

  int? intValue(String code) {
    final value = _values[_normalizeCode(code)];
    return value?.round();
  }

  static String _normalizeCode(String code) => code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

Future<Uint8List> renderGeometryOnlyPreviewPng({
  required String? modelCode,
  required String? modelLabel,
  required int? widthMm,
  required int? depthMm,
  required int? heightMm,
  required List<RoofGeometryParam> geometryParams,
  required String? coveringName,
  required List<RoofModuleCalculation> calculatedModules,
  required bool wallMounted,
  required int postCount,
  required int? roofAngleDeg,
  required int? rearHeightMm,
  required int? frontHeightMm,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(
    geometryOnlyPreviewWidth.toDouble(),
    geometryOnlyPreviewHeight.toDouble(),
  );

  final painter = _ModelGeometryPreviewPainter(
    modelCode: modelCode,
    modelLabel: modelLabel,
    widthMm: widthMm,
    depthMm: depthMm,
    heightMm: heightMm,
    geometryParams: geometryParams,
    colorCode: null,
    colorSwatchColor: null,
    isSpecialColor: false,
    coveringName: coveringName,
    humanImage: null,
    lineColor: Colors.black,
    mutedLineColor: const Color(0xFF6F7478),
    accentColor: Colors.black,
    surfaceColor: Colors.white,
    highlightedModuleIndex: null,
    highlightedGlassFieldIndex: null,
    roofAngleDeg: roofAngleDeg,
    rearHeightMm: rearHeightMm,
    frontHeightMm: frontHeightMm,
    calculatedModules: calculatedModules,
    wallMounted: wallMounted,
    postCount: postCount,
    sideInfoBottomReserve: 0,
    geometryOnly: true,
  );
  painter.paint(canvas, size);

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    geometryOnlyPreviewWidth,
    geometryOnlyPreviewHeight,
  );
  picture.dispose();
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Geometry-only PNG encoding failed.');
    }
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  } finally {
    image.dispose();
  }
}

class _ModelGeometryPreviewPainter extends CustomPainter {
  const _ModelGeometryPreviewPainter({
    required this.modelCode,
    required this.modelLabel,
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
    required this.geometryParams,
    required this.colorCode,
    required this.colorSwatchColor,
    required this.isSpecialColor,
    required this.coveringName,
    required this.humanImage,
    required this.lineColor,
    required this.mutedLineColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.highlightedModuleIndex,
    required this.highlightedGlassFieldIndex,
    required this.roofAngleDeg,
    required this.rearHeightMm,
    required this.frontHeightMm,
    required this.calculatedModules,
    required this.wallMounted,
    required this.postCount,
    required this.sideInfoBottomReserve,
    this.geometryOnly = false,
  });

  final String? modelCode;
  final String? modelLabel;
  final int? widthMm;
  final int? depthMm;
  final int? heightMm;
  final List<RoofGeometryParam> geometryParams;
  final String? colorCode;
  final Color? colorSwatchColor;
  final bool isSpecialColor;
  final String? coveringName;
  final ui.Image? humanImage;
  final Color lineColor;
  final Color mutedLineColor;
  final Color accentColor;
  final Color surfaceColor;
  final int? highlightedModuleIndex;
  final int? highlightedGlassFieldIndex;
  final int? roofAngleDeg;
  final int? rearHeightMm;
  final int? frontHeightMm;
  final List<RoofModuleCalculation> calculatedModules;
  final bool wallMounted;
  final int postCount;
  final double sideInfoBottomReserve;
  final bool geometryOnly;

  static const double _ddx = 0.52;
  static const double _ddy = 0.73;
  static const double _depthProjectionScale = 0.88;
  static const double _planRotationDeg = 8;
  static const double _defaultWidthMm = 5000;
  static const double _defaultDepthMm = 3000;
  static const double _defaultHeightMm = 2500;
  static const double _humanMm = 1800;
  static const double _depthDimensionOffsetScale = 1 / 3;
  static const double _sideInfoMaxGap = 14;
  static const double _sideInfoFontSize = 10.5;

  @override
  void paint(Canvas canvas, Size size) {
    final profile = _shapeFromText('${modelCode ?? ''} ${modelLabel ?? ''}');
    final params = _GeometryParamBag(geometryParams);
    final layout = _layoutFor(profile, params);

    final backgroundPaint = Paint()
      ..color = Color.lerp(surfaceColor, Colors.white, 0.72) ?? surfaceColor
      ..style = PaintingStyle.fill;
    if (geometryOnly) {
      canvas.drawRect(Offset.zero & size, backgroundPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
        backgroundPaint,
      );
    }

    const pad = 12.0;
    const labelBottom = 22.0;
    const sideGap = 10.0;
    const humanGapMm = 500.0;
    final sideRect = geometryOnly
        ? Rect.fromLTWH(size.width, pad, 0, size.height - pad * 2)
        : _previewSideRect(size, pad);
    if (!geometryOnly) {
      _drawPreviewSideBackground(canvas, sideRect);
    }

    final projDx = (profile.shape == _RoofShape.lFront ? (profile.mirrorView ? -0.42 : 0.58) : _ddx)
        * _depthProjectionScale;
    final projDy = (profile.shape == _RoofShape.lFront ? 0.70 : _ddy) * _depthProjectionScale;
    final rotationRad = _planRotationDeg * math.pi / 180;
    final rotationCos = math.cos(rotationRad);
    final rotationSin = math.sin(rotationRad);

    Offset projectPlan(double xMm, double yMm) {
      final viewX = profile.mirrorView ? layout.widthMm - xMm : xMm;
      final rotatedX = viewX * rotationCos + yMm * rotationSin;
      final rotatedY = -viewX * rotationSin + yMm * rotationCos;
      return Offset(
        rotatedX + rotatedY * projDx,
        -rotatedY * projDy,
      );
    }

    final projectedRoofPoints = [
      ...layout.front,
      ...layout.back,
    ].map((point) => projectPlan(point.dx, point.dy)).toList(growable: false);
    final minProjectedX = projectedRoofPoints.map((point) => point.dx).reduce(_min);
    final maxProjectedX = projectedRoofPoints.map((point) => point.dx).reduce(_max);
    final minProjectedY = projectedRoofPoints.map((point) => point.dy).reduce(_min);
    final maxProjectedY = projectedRoofPoints.map((point) => point.dy).reduce(_max);
    final humanX = profile.mirrorView ? layout.widthMm : 0.0;
    final humanY = _yAt(layout.front, humanX);
    final humanPlan = projectPlan(humanX, humanY);
    final humanDisplayHeightMm = _humanDisplayHeightMm(
      layout,
      Offset(humanX, humanY),
    );
    final leftReserveMm = geometryOnly
        ? 0.0
        : humanGapMm + humanDisplayHeightMm * 0.55;
    final top = geometryOnly
        ? minProjectedY
        : _min(
            minProjectedY,
            humanPlan.dy + layout.heightMm - humanDisplayHeightMm,
          );
    final bottom = maxProjectedY + layout.heightMm;
    final contentW = leftReserveMm + maxProjectedX - minProjectedX;
    final contentH = bottom - top;
    // Keep a real visual guard between the full roof drawing (including
    // dimension arrows/text and beam strokes) and the separated right inset.
    // The model bounds are in millimetres, but some labels/offsets are drawn
    // directly in pixels, so reserve the margin in the available canvas area.
    final mainRightGuard = geometryOnly ? 64.0 : 42.0;
    final availW = geometryOnly
        ? _max(40, size.width - pad * 2 - mainRightGuard)
        : _max(40, sideRect.left - pad - sideGap - mainRightGuard);
    final availH = size.height - pad - labelBottom;
    final k = _min(availW / contentW, availH / contentH);
    final ox = pad + (availW - contentW * k) / 2 + leftReserveMm * k - minProjectedX * k;
    final oy = pad - top * k + (availH - contentH * k) / 2;

    Offset s(double xMm, double yMm, double zMm) {
      final projected = projectPlan(xMm, yMm);
      return Offset(
        ox + projected.dx * k,
        oy + (projected.dy + layout.heightMm - zMm) * k,
      );
    }

    final guidePaint = Paint()
      ..color = mutedLineColor.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final dimensionPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final roofFillPaint = Paint()
      ..color = _roofCoveringFillColor()
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.055)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(
      geometryOnly
          ? Offset.zero & size
          : Rect.fromLTWH(
              0,
              0,
              sideRect.left - sideGap * 0.5,
              size.height,
            ),
    );

    _drawGroundShadow(canvas, s, layout, shadowPaint);
    _drawWallGuides(canvas, s, layout, guidePaint);

    // Painter order creates the same visual overlap as a simple 3D scene:
    // rear supports/edge, complete roof plane, then front supports/gutter.
    _drawPostsForEdge(canvas, s, layout, layout.back, k);
    _drawRoofEdge(canvas, s, layout.back, layout.heightMm, k);

    _drawRoofFill(canvas, s, layout, roofFillPaint);
    _drawHighlightedModule(canvas, s, layout);
    _drawGlassDepthSplits(canvas, s, layout);
    _drawRafters(canvas, s, layout, k);
    _drawRoofSideEdges(canvas, s, layout, k);

    _drawPostsForEdge(canvas, s, layout, layout.front, k);
    _drawRoofEdge(canvas, s, layout.front, layout.heightMm, k, isGutter: true);
    _drawDimensions(canvas, s, params, layout, profile, dimensionPaint);

    if (!geometryOnly) {
      _drawHuman(
        canvas,
        s(humanX, humanY, 0),
        humanDisplayHeightMm * k,
        humanGapMm * k,
      );
    }
    canvas.restore();

    if (!geometryOnly) {
      _drawPlanInset(canvas, sideRect, layout, profile, params);
    }
  }

  _RoofProfile _shapeFromText(String value) {
    final v = _normalize(value);
    final isLeft = v.contains('links') ||
        v.contains('lrtl') ||
        v.contains('lwtl') ||
        v.contains('srl') ||
        v.contains('swl');
    if (v.contains('schrag') ||
        v.contains('srl') ||
        v.contains('srr') ||
        v.contains('swl') ||
        v.contains('swr')) {
      final shape = v.contains('rinne') ||
              v.contains('srl') ||
              v.contains('srr')
          ? _RoofShape.angleFront
          : _RoofShape.angleBack;
      return _RoofProfile(shape: shape, smallPartOnLeft: isLeft);
    }
    if (v.contains('u geteilt') ||
        v.contains('u wandprofil') ||
        v.contains('uwtm')) {
      return const _RoofProfile(shape: _RoofShape.uBack, smallPartOnLeft: false);
    }
    if (v.contains('t geteilt') ||
        v.contains('t wandprofil') ||
        v.contains('twtm')) {
      return const _RoofProfile(shape: _RoofShape.tBack, smallPartOnLeft: false);
    }
    if (v.contains('l geteilt') ||
        v.contains('lrtr') ||
        v.contains('lrtl') ||
        v.contains('lwtr') ||
        v.contains('lwtl')) {
      final shape = v.contains('rinne') ||
              v.contains('lrtr') ||
              v.contains('lrtl')
          ? _RoofShape.lFront
          : _RoofShape.lBack;
      return _RoofProfile(shape: shape, smallPartOnLeft: isLeft);
    }
    return const _RoofProfile(shape: _RoofShape.rectangle, smallPartOnLeft: false);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll('–', ' ')
      .replaceAll('—', ' ')
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .replaceAll('/', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  _RoofLayout _layoutFor(_RoofProfile profile, _GeometryParamBag params) {
    final mainWidth = params.value(const ['B', 'BR', 'BW'], (widthMm ?? _defaultWidthMm).toDouble());
    final mainDepth = profile.shape == _RoofShape.rectangle
        ? params.value(const ['T', 'D', 'TK'], (depthMm ?? _defaultDepthMm).toDouble())
        : params.value(const ['TK', 'T', 'D'], (depthMm ?? _defaultDepthMm).toDouble());
    final h = params.value(const ['H'], (heightMm ?? _defaultHeightMm).toDouble());

    switch (profile.shape) {
      case _RoofShape.lFront:
        return _lLayout(
          profile: profile,
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          splitAtFront: true,
          widthPrefix: 'BR',
        );
      case _RoofShape.lBack:
        return _lLayout(
          profile: profile,
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          splitAtFront: false,
          widthPrefix: 'BW',
        );
      case _RoofShape.angleFront:
        return _angleLayout(
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          splitAtFront: true,
          leftShort: profile.smallPartOnLeft,
        );
      case _RoofShape.angleBack:
        return _angleLayout(
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          splitAtFront: false,
          leftShort: profile.smallPartOnLeft,
        );
      case _RoofShape.tBack:
        return _threePartBackLayout(
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          centerIsDeep: true,
        );
      case _RoofShape.uBack:
        return _threePartBackLayout(
          params: params,
          width: mainWidth,
          depth: mainDepth,
          height: h,
          centerIsDeep: false,
        );
      case _RoofShape.rectangle:
        return _rectangleLayout(params, mainWidth, mainDepth, h);
    }
  }

  _RoofLayout _rectangleLayout(_GeometryParamBag params, double width, double depth, double height) {
    final front = [Offset.zero, Offset(width, 0)];
    final back = [Offset(0, depth), Offset(width, depth)];
    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: depth,
      heightMm: height,
      postPoints: _uniquePoints([front.first, front.last]),
      moduleAreas: [
        _RoofModuleArea(index: 1, corners: [front.first, front.last, back.last, back.first]),
      ],
      rafterX: _rafterPositions(width, const []),
      widthDimensionsOnFront: false,
      dimensions: [
        _RoofDimensionLine(code: 'B', start: front.first, end: front.last, offset: const Offset(0, 16)),
        _RoofDimensionLine(code: 'T', start: front.last, end: back.last, offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
  }

  _RoofLayout _lLayout({
    required _RoofProfile profile,
    required _GeometryParamBag params,
    required double width,
    required double depth,
    required double height,
    required bool splitAtFront,
    required String widthPrefix,
  }) {
    final smallW = params.value([widthPrefix == 'BR' ? 'BR2' : 'BW2'], width * 0.42).clamp(width * 0.18, width * 0.82).toDouble();
    final bigW = params.value([widthPrefix == 'BR' ? 'BR1' : 'BW1'], width - smallW).clamp(width * 0.18, width * 0.82).toDouble();
    final total = smallW + bigW;
    final leftW = profile.smallPartOnLeft ? smallW : bigW;
    final leftDepth = profile.smallPartOnLeft
        ? params.value(const ['TK2'], depth * 0.62)
        : params.value(const ['TK1'], depth);
    final rightDepth = profile.smallPartOnLeft
        ? params.value(const ['TK1'], depth)
        : params.value(const ['TK2'], depth * 0.62);
    final d = _max(depth, _max(leftDepth, rightDepth));
    final splitX = leftW / total * width;
    final leftFrontY = splitAtFront ? d - leftDepth : 0.0;
    final rightFrontY = splitAtFront ? d - rightDepth : 0.0;
    final leftBackY = splitAtFront ? d : leftDepth;
    final rightBackY = splitAtFront ? d : rightDepth;

    final front = splitAtFront
        ? [Offset(0, leftFrontY), Offset(splitX, leftFrontY), Offset(splitX, rightFrontY), Offset(width, rightFrontY)]
        : [Offset.zero, Offset(width, 0)];
    final back = splitAtFront
        ? [Offset(0, d), Offset(width, d)]
        : [Offset(0, leftBackY), Offset(splitX, leftBackY), Offset(splitX, rightBackY), Offset(width, rightBackY)];

    final leftWidthCode = profile.smallPartOnLeft ? '${widthPrefix}2' : '${widthPrefix}1';
    final rightWidthCode = profile.smallPartOnLeft ? '${widthPrefix}1' : '${widthPrefix}2';
    final leftDepthCode = profile.smallPartOnLeft ? 'TK2' : 'TK1';
    final rightDepthCode = profile.smallPartOnLeft ? 'TK1' : 'TK2';
    final leftY = splitAtFront ? d : leftBackY;
    final rightY = splitAtFront ? d : rightBackY;
    final leftWidthY = splitAtFront ? leftFrontY : leftBackY;
    final rightWidthY = splitAtFront ? rightFrontY : rightBackY;
    final leftWidthStart = Offset(0, leftWidthY);
    final leftWidthEnd = Offset(splitX, leftWidthY);
    final rightWidthStart = Offset(splitX, rightWidthY);
    final rightWidthEnd = Offset(width, rightWidthY);

    final postPoints = _uniquePoints([front.first, ...front, front.last]);
    final blockedRafterX = [
      for (final point in postPoints)
        if (point.dx > 1 && point.dx < width - 1) point.dx,
    ];

    final leftModuleIndex = profile.smallPartOnLeft ? 2 : 1;
    final rightModuleIndex = profile.smallPartOnLeft ? 1 : 2;
    final leftModuleCorners = splitAtFront
        ? [leftWidthStart, leftWidthEnd, Offset(splitX, leftY), Offset(0, leftY)]
        : [Offset(0, 0), Offset(splitX, 0), leftWidthEnd, leftWidthStart];
    final rightModuleCorners = splitAtFront
        ? [rightWidthStart, rightWidthEnd, Offset(width, rightY), Offset(splitX, rightY)]
        : [Offset(splitX, 0), Offset(width, 0), rightWidthEnd, rightWidthStart];

    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: d,
      heightMm: height,
      postPoints: postPoints,
      moduleAreas: [
        _RoofModuleArea(
          index: leftModuleIndex,
          corners: leftModuleCorners,
        ),
        _RoofModuleArea(
          index: rightModuleIndex,
          corners: rightModuleCorners,
        ),
      ],
      rafterX: _rafterPositions(width, [splitX], blocked: blockedRafterX),
      widthDimensionsOnFront: splitAtFront,
      dimensions: [
        _RoofDimensionLine(code: leftWidthCode, start: leftWidthStart, end: leftWidthEnd, offset: const Offset(0, 15)),
        _RoofDimensionLine(code: rightWidthCode, start: rightWidthStart, end: rightWidthEnd, offset: const Offset(0, 15)),
        _RoofDimensionLine(code: leftDepthCode, start: Offset(0, splitAtFront ? leftFrontY : 0), end: Offset(0, leftY), offset: const Offset(-18, 0), hAlign: 1),
        _RoofDimensionLine(code: rightDepthCode, start: Offset(width, splitAtFront ? rightFrontY : 0), end: Offset(width, rightY), offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
  }

  _RoofLayout _angleLayout({
    required _GeometryParamBag params,
    required double width,
    required double depth,
    required double height,
    required bool splitAtFront,
    required bool leftShort,
  }) {
    final shortDepth = params.value(const ['TK2'], depth * 0.64).clamp(depth * 0.30, depth).toDouble();
    final longDepth = params.value(const ['TK1', 'TK'], depth).clamp(shortDepth, depth * 1.20).toDouble();
    final leftDepth = leftShort ? shortDepth : longDepth;
    final rightDepth = leftShort ? longDepth : shortDepth;
    final d = _max(depth, _max(leftDepth, rightDepth));
    final front = splitAtFront
        ? [Offset(0, d - leftDepth), Offset(width, d - rightDepth)]
        : [Offset.zero, Offset(width, 0)];
    final back = splitAtFront
        ? [Offset(0, d), Offset(width, d)]
        : [Offset(0, leftDepth), Offset(width, rightDepth)];

    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: d,
      heightMm: height,
      postPoints: _uniquePoints([front.first, front.last]),
      moduleAreas: [
        _RoofModuleArea(index: 1, corners: [front.first, front.last, back.last, back.first]),
      ],
      rafterX: _rafterPositions(width, const []),
      widthDimensionsOnFront: false,
      dimensions: [
        _RoofDimensionLine(code: 'B', start: Offset(0, 0), end: Offset(width, 0), offset: const Offset(0, 16)),
        _RoofDimensionLine(code: leftShort ? 'TK2' : 'TK1', start: front.first, end: back.first, offset: const Offset(-18, 0), hAlign: 1),
        _RoofDimensionLine(code: leftShort ? 'TK1' : 'TK2', start: front.last, end: back.last, offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
  }

  _RoofLayout _threePartBackLayout({
    required _GeometryParamBag params,
    required double width,
    required double depth,
    required double height,
    required bool centerIsDeep,
  }) {
    final leftWidthCode = centerIsDeep ? 'BW2' : 'BW1';
    final centerWidthCode = centerIsDeep ? 'BW1' : 'BW3';
    final rightWidthCode = centerIsDeep ? 'BW3' : 'BW2';
    final leftW = params.value([leftWidthCode], width * 0.34).clamp(width * 0.18, width * 0.55).toDouble();
    final rightW = params.value([rightWidthCode], width * 0.30).clamp(width * 0.18, width * 0.55).toDouble();
    final centerW = params.value([centerWidthCode], width - leftW - rightW).clamp(width * 0.16, width * 0.48).toDouble();
    final total = leftW + centerW + rightW;
    final x1 = leftW / total * width;
    final x2 = (leftW + centerW) / total * width;
    final deep = params.value(const ['TK1', 'TK'], depth);
    final sideLeft = params.value(const ['TK2'], depth * 0.66);
    final sideRight = params.value(const ['TK3'], depth * 0.66);
    final leftDepth = centerIsDeep ? sideLeft : deep;
    final centerDepth = centerIsDeep ? deep : params.value(const ['TK3'], depth * 0.54);
    final rightDepth = centerIsDeep ? sideRight : params.value(const ['TK2'], depth);
    final d = _max(depth, _max(leftDepth, _max(centerDepth, rightDepth)));
    final front = [Offset.zero, Offset(width, 0)];
    final back = [
      Offset(0, leftDepth),
      Offset(x1, leftDepth),
      Offset(x1, centerDepth),
      Offset(x2, centerDepth),
      Offset(x2, rightDepth),
      Offset(width, rightDepth),
    ];

    final centerDepthCode = centerIsDeep ? 'TK1' : 'TK3';
    final leftDepthCode = centerIsDeep ? 'TK2' : 'TK1';
    final rightDepthCode = centerIsDeep ? 'TK3' : 'TK2';

    return _RoofLayout(
      front: front,
      back: back,
      widthMm: width,
      depthMm: d,
      heightMm: height,
      postPoints: _uniquePoints([front.first, front.last]),
      moduleAreas: [
        _RoofModuleArea(
          index: centerIsDeep ? 2 : 1,
          corners: [Offset(0, 0), Offset(x1, 0), Offset(x1, leftDepth), Offset(0, leftDepth)],
        ),
        _RoofModuleArea(
          index: centerIsDeep ? 1 : 3,
          corners: [Offset(x1, 0), Offset(x2, 0), Offset(x2, centerDepth), Offset(x1, centerDepth)],
        ),
        _RoofModuleArea(
          index: centerIsDeep ? 3 : 2,
          corners: [Offset(x2, 0), Offset(width, 0), Offset(width, rightDepth), Offset(x2, rightDepth)],
        ),
      ],
      rafterX: _rafterPositions(width, [x1, x2]),
      widthDimensionsOnFront: false,
      dimensions: [
        _RoofDimensionLine(code: leftWidthCode, start: Offset(0, leftDepth), end: Offset(x1, leftDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: centerWidthCode, start: Offset(x1, centerDepth), end: Offset(x2, centerDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: rightWidthCode, start: Offset(x2, rightDepth), end: Offset(width, rightDepth), offset: const Offset(0, 15)),
        _RoofDimensionLine(code: leftDepthCode, start: Offset(0, 0), end: Offset(0, leftDepth), offset: const Offset(-18, 0), hAlign: 1),
        _RoofDimensionLine(code: centerDepthCode, start: Offset((x1 + x2) / 2, 0), end: Offset((x1 + x2) / 2, centerDepth), offset: const Offset(12, 0), hAlign: 0),
        _RoofDimensionLine(code: rightDepthCode, start: Offset(width, 0), end: Offset(width, rightDepth), offset: const Offset(18, 0), hAlign: 0),
        _RoofDimensionLine(code: 'H', start: front.first, end: front.first, offset: const Offset(-18, 0), hAlign: 1),
      ],
    );
  }

  Color _roofCoveringFillColor() {
    final value = coveringName?.trim().toLowerCase() ?? '';
    if (value.contains('matt')) {
      return const Color(0xFFD9DDE1).withValues(alpha: 0.78);
    }
    if (value.contains('klar')) {
      return const Color(0xFFCFEAF7).withValues(alpha: 0.74);
    }
    return Colors.white.withValues(alpha: 0.26);
  }

  void _drawGroundShadow(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    Paint paint,
  ) {
    final outline = <Offset>[
      ...layout.front,
      for (var i = layout.back.length - 1; i >= 0; i--) layout.back[i],
    ];
    if (outline.isEmpty) return;
    const shadowShift = Offset(64, 10);
    final path = Path();
    final first = s(outline.first.dx, outline.first.dy, 0) + shadowShift;
    path.moveTo(first.dx, first.dy);
    for (final point in outline.skip(1)) {
      final p = s(point.dx, point.dy, 0) + shadowShift;
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawRoofFill(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    Paint paint,
  ) {
    final outline = <Offset>[
      for (final p in layout.back) s(p.dx, p.dy, layout.heightMm),
      for (var i = layout.front.length - 1; i >= 0; i--) s(layout.front[i].dx, layout.front[i].dy, layout.heightMm),
    ];
    final roof = Path()..moveTo(outline.first.dx, outline.first.dy);
    for (final point in outline.skip(1)) {
      roof.lineTo(point.dx, point.dy);
    }
    roof.close();
    canvas.drawPath(roof, paint);
  }


  void _drawHighlightedModule(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
  ) {
    final index = highlightedModuleIndex;
    if (index == null || index <= 0) return;
    _RoofModuleArea? area;
    for (final candidate in layout.moduleAreas) {
      if (candidate.index == index) {
        area = candidate;
        break;
      }
    }
    if (area == null || area.corners.length < 3) return;

    var corners = area.corners;
    final fieldIndex = highlightedGlassFieldIndex;
    final calculation = _calculatedModuleFor(index);
    final fieldCount = calculation?.glassDepthFieldCount ?? 1;
    if (fieldIndex != null &&
        fieldCount > 1 &&
        fieldIndex >= 1 &&
        fieldIndex <= fieldCount &&
        area.corners.length == 4) {
      corners = _glassFieldCorners(area.corners, fieldIndex, fieldCount);
    }

    final path = Path();
    final first = s(corners.first.dx, corners.first.dy, layout.heightMm);
    path.moveTo(first.dx, first.dy);
    for (final point in corners.skip(1)) {
      final projected = s(point.dx, point.dy, layout.heightMm);
      path.lineTo(projected.dx, projected.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF61FFDF).withValues(alpha: 0.30)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8BAFF).withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawGlassDepthSplits(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
  ) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (final area in layout.moduleAreas) {
      if (area.corners.length != 4) continue;
      final fieldCount = _calculatedModuleFor(area.index)?.glassDepthFieldCount ?? 1;
      if (fieldCount <= 1) continue;
      for (var splitIndex = 1; splitIndex < fieldCount; splitIndex++) {
        final t = splitIndex / fieldCount;
        final left = Offset.lerp(area.corners[0], area.corners[3], t)!;
        final right = Offset.lerp(area.corners[1], area.corners[2], t)!;
        canvas.drawLine(
          s(left.dx, left.dy, layout.heightMm),
          s(right.dx, right.dy, layout.heightMm),
          paint,
        );
      }
    }
  }

  RoofModuleCalculation? _calculatedModuleFor(int moduleIndex) => calculatedModules
      .where((entry) => entry.moduleIndex == moduleIndex)
      .cast<RoofModuleCalculation?>()
      .firstOrNull;

  List<Offset> _glassFieldCorners(
    List<Offset> corners,
    int fieldIndex,
    int fieldCount,
  ) {
    final start = (fieldIndex - 1) / fieldCount;
    final end = fieldIndex / fieldCount;
    return [
      Offset.lerp(corners[0], corners[3], start)!,
      Offset.lerp(corners[1], corners[2], start)!,
      Offset.lerp(corners[1], corners[2], end)!,
      Offset.lerp(corners[0], corners[3], end)!,
    ];
  }

  void _drawRoofEdge(
    Canvas canvas,
    Offset Function(double, double, double) s,
    List<Offset> edge,
    double heightMm,
    double k, {
    bool isGutter = false,
  }) {
    for (var i = 0; i < edge.length - 1; i++) {
      _drawBeam(
        canvas,
        s(edge[i].dx, edge[i].dy, heightMm),
        s(edge[i + 1].dx, edge[i + 1].dy, heightMm),
        k,
        isGutter: isGutter,
      );
    }
  }

  void _drawRoofSideEdges(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    double k,
  ) {
    _drawBeam(
      canvas,
      s(layout.front.first.dx, layout.front.first.dy, layout.heightMm),
      s(layout.back.first.dx, layout.back.first.dy, layout.heightMm),
      k,
    );
    _drawBeam(
      canvas,
      s(layout.front.last.dx, layout.front.last.dy, layout.heightMm),
      s(layout.back.last.dx, layout.back.last.dy, layout.heightMm),
      k,
    );
  }

  void _drawWallGuides(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    Paint paint,
  ) {
    final points = _wallGuidePoints(layout);
    final ground = <Offset>[];
    for (final point in points) {
      final top = s(point.dx, point.dy, layout.heightMm);
      final bottom = s(point.dx, point.dy, 0);
      canvas.drawLine(top, bottom, paint);
      ground.add(bottom);
    }
    for (var i = 0; i < ground.length - 1; i++) {
      canvas.drawLine(ground[i], ground[i + 1], paint);
    }
  }

  void _drawRafters(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    double k,
  ) {
    for (final x in _effectiveRafterX(layout)) {
      final y1 = _yAt(layout.front, x);
      final y2 = _usesSharedModuleBeams
          ? _sharedModuleBackY(layout, x)
          : _yAt(layout.back, x);
      if ((y2 - y1).abs() < 40) continue;
      _drawBeam(canvas, s(x, y1, layout.heightMm), s(x, y2, layout.heightMm), k, isRafter: true);
    }
  }

  void _drawPostsForEdge(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _RoofLayout layout,
    List<Offset> edge,
    double k,
  ) {
    for (final point in _recommendedPostPoints(layout).where((point) => _pointOnEdge(point, edge))) {
      _drawRecommendedPost(
        canvas,
        s(point.dx, point.dy, layout.heightMm),
        s(point.dx, point.dy, 0),
      );
    }
    for (final point in _effectivePostPoints(layout).where((point) => _pointOnEdge(point, edge))) {
      _drawPost(canvas, s(point.dx, point.dy, layout.heightMm), s(point.dx, point.dy, 0), k);
    }
  }

  bool _pointOnEdge(Offset point, List<Offset> edge) {
    for (var i = 0; i < edge.length - 1; i++) {
      if (_distanceToSegment(point, edge[i], edge[i + 1]) < 1) return true;
    }
    return edge.length == 1 && (point - edge.first).distance < 1;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared <= 1e-9) return (point - start).distance;
    final t = (((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) / lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
    return (point - Offset(start.dx + dx * t, start.dy + dy * t)).distance;
  }

  void _drawBeam(Canvas canvas, Offset a, Offset b, double _, {bool isGutter = false, bool isRafter = false}) {
    final width = isRafter ? 2.0 : 4.0;
    final shadowAlpha = isRafter ? 0.16 : (isGutter ? 0.22 : 0.20);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: shadowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 1.0
      ..strokeCap = StrokeCap.square;
    final body = Paint()
      ..color = const Color(0xFFBFC1C2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.square;
    final light = Paint()
      ..color = const Color(0xFFF3F4F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRafter ? 0.7 : 1.0
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(a + const Offset(1.2, 1.4), b + const Offset(1.2, 1.4), shadow);
    canvas.drawLine(a, b, body);
    canvas.drawLine(a - const Offset(0.4, 0.6), b - const Offset(0.4, 0.6), light);
  }

  void _drawPost(Canvas canvas, Offset top, Offset bottom, double _) {
    const width = 4.0;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 1.0
      ..strokeCap = StrokeCap.square;
    final body = Paint()
      ..color = const Color(0xFFB6B8B9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.square;
    final light = Paint()
      ..color = const Color(0xFFE8E9E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(top + const Offset(1.1, 1.2), bottom + const Offset(1.1, 1.2), shadow);
    canvas.drawLine(top, bottom, body);
    canvas.drawLine(top - const Offset(0.4, 0), bottom - const Offset(0.4, 0), light);
  }

  void _drawRecommendedPost(Canvas canvas, Offset top, Offset bottom) {
    final halo = Paint()
      ..color = const Color(0xFF4F9FA4).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;
    final body = Paint()
      ..color = const Color(0xFF4F9FA4).withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(canvas, top, bottom, halo, dashLength: 7, gapLength: 5);
    _drawDashedLine(canvas, top, bottom, body, dashLength: 7, gapLength: 5);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;
    final direction = delta / distance;
    var position = 0.0;
    while (position < distance) {
      final dashEnd = _min(position + dashLength, distance);
      canvas.drawLine(start + direction * position, start + direction * dashEnd, paint);
      position += dashLength + gapLength;
    }
  }

  Rect _previewSideRect(Size size, double pad) =>
      _geometryPreviewSideRect(size, pad);

  void _drawPreviewSideBackground(Canvas canvas, Rect rect) {
    if (rect.width <= 0 || rect.height <= 0) return;
    final background = Paint()
      ..color = surfaceColor.withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      background,
    );
    final divider = Paint()
      ..color = lineColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(rect.left - 5, rect.top), Offset(rect.left - 5, rect.bottom), divider);
  }

  void _drawDimensions(
    Canvas canvas,
    Offset Function(double, double, double) s,
    _GeometryParamBag params,
    _RoofLayout layout,
    _RoofProfile profile,
    Paint paint,
  ) {
    final roofGroundPoints = <Offset>[
      ...layout.front.map((point) => s(point.dx, point.dy, 0)),
      ...layout.back.map((point) => s(point.dx, point.dy, 0)),
    ];
    final roofGroundCenter = Offset(
      roofGroundPoints.map((point) => point.dx).reduce((sum, value) => sum + value) /
          roofGroundPoints.length,
      roofGroundPoints.map((point) => point.dy).reduce((sum, value) => sum + value) /
          roofGroundPoints.length,
    );
    _RoofDimensionLine? leftmostDepthDimension;
    var leftmostDepthX = double.infinity;
    for (final dim in layout.dimensions) {
      if (dim.code == 'H' || _isWidthDimensionCode(dim.code)) continue;
      final midpoint = _lerp(
        s(dim.start.dx, dim.start.dy, 0),
        s(dim.end.dx, dim.end.dy, 0),
        0.5,
      );
      if (midpoint.dx < roofGroundCenter.dx && midpoint.dx < leftmostDepthX) {
        leftmostDepthDimension = dim;
        leftmostDepthX = midpoint.dx;
      }
    }

    for (final dim in layout.dimensions) {
      if (dim.code == 'H') continue;
      if (_isWidthDimensionCode(dim.code)) {
        final normalized = _GeometryParamBag._normalizeCode(dim.code);
        late final Offset start;
        late final Offset end;
        if (layout.widthDimensionsOnFront) {
          final startRaw = s(dim.start.dx, dim.start.dy, 0);
          final endRaw = s(dim.end.dx, dim.end.dy, 0);
          const shift = Offset(0, 10);
          start = startRaw + shift;
          end = endRaw + shift;
        } else {
          final isRectangleWidth = normalized == 'B' && profile.shape == _RoofShape.rectangle;
          final isSchraegWidth = normalized == 'B' &&
              (profile.shape == _RoofShape.angleFront || profile.shape == _RoofShape.angleBack);
          final useDimensionY = normalized.startsWith('BW') &&
              (dim.start.dy.abs() > 1e-6 || dim.end.dy.abs() > 1e-6);
          final dimYStart = useDimensionY
              ? dim.start.dy
              : isRectangleWidth
                  ? _yAt(layout.front, dim.start.dx)
                  : isSchraegWidth
                      ? (profile.shape == _RoofShape.angleFront ? layout.depthMm : 0.0)
                      : layout.depthMm;
          final dimYEnd = useDimensionY
              ? dim.end.dy
              : isRectangleWidth
                  ? _yAt(layout.front, dim.end.dx)
                  : isSchraegWidth
                      ? (profile.shape == _RoofShape.angleFront ? layout.depthMm : 0.0)
                      : layout.depthMm;
          final startRaw = s(dim.start.dx, dimYStart, 0);
          final endRaw = s(dim.end.dx, dimYEnd, 0);
          final oppositeMid = isSchraegWidth
              ? _lerp(
                  s(dim.start.dx, profile.shape == _RoofShape.angleFront ? _yAt(layout.front, dim.start.dx) : _yAt(layout.back, dim.start.dx), 0),
                  s(dim.end.dx, profile.shape == _RoofShape.angleFront ? _yAt(layout.front, dim.end.dx) : _yAt(layout.back, dim.end.dx), 0),
                  0.5,
                )
              : _lerp(
                  s(dim.start.dx, _yAt(layout.front, dim.start.dx), 0),
                  s(dim.end.dx, _yAt(layout.front, dim.end.dx), 0),
                  0.5,
                );
          final dimMid = _lerp(startRaw, endRaw, 0.5);
          final outward = dimMid - oppositeMid;
          final outwardUnit = outward.distance > 0 ? outward / outward.distance : const Offset(0, 1);
          final shift = outwardUnit * 8;
          start = startRaw + shift;
          end = endRaw + shift;
        }
        if ((end - start).distance < 18) continue;
        _dimLine(canvas, start, end, paint);
        _drawText(canvas, _paramText(params, dim.code, null), _lerp(start, end, 0.5) + const Offset(0, 10), lineColor, 10.5, isBold: true, hAlign: 0.5);
      } else {
        final startRaw = s(dim.start.dx, dim.start.dy, 0);
        final endRaw = s(dim.end.dx, dim.end.dy, 0);
        var offset = dim.offset * _depthDimensionOffsetScale;
        var textAlign = dim.hAlign;
        if (identical(dim, leftmostDepthDimension)) {
          final direction = endRaw - startRaw;
          if (direction.distance > 0) {
            var inward = Offset(-direction.dy, direction.dx) / direction.distance;
            final midpoint = _lerp(startRaw, endRaw, 0.5);
            final towardCenter = roofGroundCenter - midpoint;
            if (inward.dx * towardCenter.dx + inward.dy * towardCenter.dy < 0) {
              inward = inward * -1;
            }
            offset = inward *
                (dim.offset.distance > 0 ? dim.offset.distance : 18) *
                _depthDimensionOffsetScale;
            textAlign = inward.dx >= 0 ? 0 : 1;
          }
        }
        final start = startRaw + offset;
        final end = endRaw + offset;
        if ((end - start).distance < 18) continue;
        _dimLine(canvas, start, end, paint);
        _drawText(canvas, _paramText(params, dim.code, null), _lerp(start, end, 0.5) + offset * 0.10, lineColor, 10.5, isBold: true, hAlign: textAlign);
      }
    }
  }

  void _drawPlanInset(Canvas canvas, Rect sideRect, _RoofLayout layout, _RoofProfile profile, _GeometryParamBag params) {
    final insetWidth = _min(86, _max(48, sideRect.width - 18));
    final code = colorCode?.trim();
    final hasColor = code != null && code.isNotEmpty;
    final depth = depthMm;
    final angle = roofAngleDeg;
    final rearHeight = rearHeightMm;
    final frontHeight = frontHeightMm;
    final hasSlope = depth != null &&
        depth > 0 &&
        angle != null &&
        angle >= 0 &&
        rearHeight != null &&
        rearHeight > 0 &&
        frontHeight != null &&
        frontHeight > 0 &&
        frontHeight <= rearHeight;

    const heightBlockHeight = 28.0;
    const countsBlockHeight = 28.0;
    final colorBlockHeight = hasColor ? 30.0 + (isSpecialColor ? 24.0 : 0.0) : 0.0;
    final infoHeight = _min(
      240.0,
      _max(0.0, sideRect.height - sideInfoBottomReserve),
    );
    if (infoHeight <= 0) return;

    var insetHeight = _min(58, _max(34, infoHeight * 0.24));
    var slopeBlockHeight = hasSlope ? 52.0 : 0.0;
    final blockCount = 3 + (hasColor ? 1 : 0) + (hasSlope ? 1 : 0);
    final gapCount = blockCount - 1;
    const minimumGap = 3.0;
    final fixedBlockHeight =
        heightBlockHeight + colorBlockHeight + countsBlockHeight;
    final availableFlexibleHeight = _max(
      0.0,
      infoHeight - fixedBlockHeight - gapCount * minimumGap,
    );
    final flexibleHeight = insetHeight + slopeBlockHeight;
    if (flexibleHeight > availableFlexibleHeight) {
      final insetRoom = _max(0.0, insetHeight - 34);
      final slopeRoom = _max(
        0.0,
        slopeBlockHeight - (hasSlope ? 32.0 : 0.0),
      );
      final room = insetRoom + slopeRoom;
      if (room > 0) {
        final reduction = _min(
          1.0,
          (flexibleHeight - availableFlexibleHeight) / room,
        );
        insetHeight -= insetRoom * reduction;
        slopeBlockHeight -= slopeRoom * reduction;
      }
    }
    final totalBlockHeight =
        fixedBlockHeight + insetHeight + slopeBlockHeight;
    final blockGap = gapCount > 0
        ? _min(
            _sideInfoMaxGap,
            _max(0.0, (infoHeight - totalBlockHeight) / gapCount),
          )
        : 0.0;

    final rect = Rect.fromLTWH(
      sideRect.left + (sideRect.width - insetWidth) / 2,
      sideRect.top,
      insetWidth,
      insetHeight,
    );
    final planPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;
    final beamPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.square;
    final scale = _min(rect.width / layout.widthMm, rect.height / layout.depthMm) * 0.82;
    final usedW = layout.widthMm * scale;
    final usedH = layout.depthMm * scale;
    final left = rect.left + (rect.width - usedW) / 2;
    final top = rect.top + (rect.height - usedH) / 2;

    Offset p(Offset point) {
      final x = profile.mirrorView ? layout.widthMm - point.dx : point.dx;
      final y = layout.depthMm - point.dy;
      return Offset(left + x * scale, top + y * scale);
    }

    final outline = <Offset>[
      ...layout.front,
      for (var i = layout.back.length - 1; i >= 0; i--) layout.back[i],
    ];
    if (outline.isNotEmpty) {
      final path = Path()..moveTo(p(outline.first).dx, p(outline.first).dy);
      for (final point in outline.skip(1)) {
        final pp = p(point);
        path.lineTo(pp.dx, pp.dy);
      }
      path.close();
      canvas.drawPath(path, planPaint);
    }
    for (final x in _effectiveRafterX(layout)) {
      final a = p(Offset(x, _yAt(layout.front, x)));
      final b = p(Offset(x, _yAt(layout.back, x)));
      canvas.drawLine(a, b, beamPaint);
    }

    var blockTop = rect.bottom + blockGap;
    final ukwHeight = params.intValue('H') ?? heightMm;
    _drawText(
      canvas,
      'Höhe UKW:',
      Offset(rect.center.dx, blockTop + 7),
      lineColor,
      _sideInfoFontSize,
      isBold: true,
      hAlign: 0.5,
    );
    _drawText(
      canvas,
      '${_dimensionValue(ukwHeight)} mm',
      Offset(rect.center.dx, blockTop + 21),
      lineColor,
      _sideInfoFontSize,
      isBold: true,
      hAlign: 0.5,
    );
    blockTop += heightBlockHeight + blockGap;

    if (hasColor) {
      blockTop = _drawColorInset(canvas, rect, blockTop) + blockGap;
    }
    if (hasSlope) {
      _drawSlopeInset(
        canvas,
        Rect.fromLTWH(
          sideRect.left,
          blockTop,
          sideRect.width,
          slopeBlockHeight,
        ),
      );
      blockTop += slopeBlockHeight + blockGap;
    }
    _drawSetContentInset(
      canvas,
      Rect.fromLTWH(
        sideRect.left,
        blockTop,
        sideRect.width,
        countsBlockHeight,
      ),
    );
  }

  double _drawColorInset(Canvas canvas, Rect planRect, double top) {
    final code = colorCode?.trim();
    if (code == null || code.isEmpty) return top;

    const tileHeight = 30.0;
    final tileWidth = planRect.width + 12;
    final tileRect = Rect.fromLTWH(
      planRect.center.dx - tileWidth / 2,
      top,
      tileWidth,
      tileHeight,
    );
    final background = colorSwatchColor ?? const Color(0xFFE1E3E4);
    final foreground = background.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;
    final rrect = RRect.fromRectAndRadius(tileRect, const Radius.circular(7));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = background
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = lineColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    _drawText(
      canvas,
      code,
      tileRect.center,
      foreground,
      _sideInfoFontSize,
      isBold: true,
      hAlign: 0.5,
    );
    if (!isSpecialColor) return tileRect.bottom;

    const warningHeight = 18.0;
    final warningCenter = Offset(tileRect.center.dx, tileRect.bottom + 6 + warningHeight / 2);
    final iconCenter = Offset(warningCenter.dx - 37, warningCenter.dy);
    final triangle = Path()
      ..moveTo(iconCenter.dx, iconCenter.dy - 6)
      ..lineTo(iconCenter.dx - 6, iconCenter.dy + 5)
      ..lineTo(iconCenter.dx + 6, iconCenter.dy + 5)
      ..close();
    final warningPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(triangle, warningPaint);
    canvas.drawLine(
      Offset(iconCenter.dx, iconCenter.dy - 2.5),
      Offset(iconCenter.dx, iconCenter.dy + 1.5),
      warningPaint,
    );
    canvas.drawCircle(
      Offset(iconCenter.dx, iconCenter.dy + 3.8),
      0.8,
      warningPaint..style = PaintingStyle.fill,
    );
    _drawText(
      canvas,
      'Sonderfarbe',
      Offset(warningCenter.dx - 28, warningCenter.dy),
      Colors.red,
      10.5,
      isBold: true,
      hAlign: 0,
    );
    return tileRect.bottom + 6 + warningHeight;
  }

  void _drawSlopeInset(Canvas canvas, Rect blockRect) {
    final depth = depthMm;
    final angle = roofAngleDeg;
    final rearHeight = rearHeightMm;
    final frontHeight = frontHeightMm;
    if (depth == null ||
        depth <= 0 ||
        angle == null ||
        angle < 0 ||
        rearHeight == null ||
        rearHeight <= 0 ||
        frontHeight == null ||
        frontHeight <= 0 ||
        frontHeight > rearHeight) {
      return;
    }

    final heightDifference = rearHeight - frontHeight;
    final availableWidth = _max(36, blockRect.width - 24);
    if (blockRect.height < 28) return;

    final maxRiseHeight = _min(54, _max(3, blockRect.height - 24));
    final geometryScale = _min(
      availableWidth / depth,
      heightDifference > 0 ? maxRiseHeight / heightDifference : availableWidth / depth,
    );
    final baseLength = depth * geometryScale;
    final rise = heightDifference * geometryScale;
    final bottom = blockRect.bottom - 13;
    final left = blockRect.center.dx - baseLength / 2;
    final leftBottom = Offset(left, bottom);
    final rightBottom = Offset(left + baseLength, bottom);
    final rightTop = Offset(rightBottom.dx, bottom - rise);

    final linePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    if (rise > 0.5) {
      final triangle = Path()
        ..moveTo(leftBottom.dx, leftBottom.dy)
        ..lineTo(rightBottom.dx, rightBottom.dy)
        ..lineTo(rightTop.dx, rightTop.dy)
        ..close();
      canvas.drawPath(triangle, fillPaint);
      canvas.drawPath(triangle, linePaint);
    } else {
      canvas.drawLine(leftBottom, rightBottom, linePaint);
    }

    const markerSize = 6.0;
    final markerTop = Offset(rightBottom.dx, rightBottom.dy - markerSize);
    final markerInner = Offset(rightBottom.dx - markerSize, rightBottom.dy - markerSize);
    final markerLeft = Offset(rightBottom.dx - markerSize, rightBottom.dy);
    canvas.drawLine(markerTop, markerInner, linePaint);
    canvas.drawLine(markerInner, markerLeft, linePaint);

    _drawText(
      canvas,
      '$angle°',
      leftBottom + const Offset(7, -9),
      accentColor,
      9.5,
      isBold: true,
      hAlign: 0,
    );
    _drawText(
      canvas,
      'T: $depth mm',
      Offset((leftBottom.dx + rightBottom.dx) / 2, bottom + 9),
      lineColor,
      8.5,
      isBold: true,
      hAlign: 0.5,
    );
    _drawText(
      canvas,
      'ΔH: $heightDifference mm',
      Offset(rightBottom.dx - 2, rightTop.dy - 8),
      lineColor,
      8.0,
      isBold: true,
      hAlign: 1,
    );
  }

  void _drawSetContentInset(Canvas canvas, Rect blockRect) {
    final totalBeamCount = calculatedModules.fold<int>(
      0,
      (sum, module) => sum + module.beamCount,
    );
    _drawText(
      canvas,
      'Pfosten: $postCount stk.',
      Offset(blockRect.center.dx, blockRect.top + 7),
      lineColor,
      _sideInfoFontSize,
      isBold: true,
      hAlign: 0.5,
    );
    _drawText(
      canvas,
      'Träger: $totalBeamCount stk.',
      Offset(blockRect.center.dx, blockRect.top + 21),
      lineColor,
      _sideInfoFontSize,
      isBold: true,
      hAlign: 0.5,
    );
  }

  String _paramText(_GeometryParamBag params, String code, int? fallback) {
    final value = params.intValue(code) ?? fallback;
    return value == null || value <= 0 ? code : '$code $value';
  }

  bool _isWidthDimensionCode(String code) {
    final normalized = _GeometryParamBag._normalizeCode(code);
    return normalized == 'B' || normalized.startsWith('BR') || normalized.startsWith('BW');
  }

  void _dimLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final direction = end - start;
    final length = direction.distance;
    if (length <= 0) return;
    final unit = direction / length;
    final normal = Offset(-unit.dy, unit.dx);
    const arrow = 6.0;
    canvas.drawLine(start - unit * arrow + normal * 3.5, start + unit * arrow - normal * 3.5, paint);
    canvas.drawLine(end - unit * arrow + normal * 3.5, end + unit * arrow - normal * 3.5, paint);
  }

  void _drawHuman(Canvas canvas, Offset frontLeftGround, double heightPx, double gapPx) {
    final feetY = frontLeftGround.dy;
    final image = humanImage;
    if (image != null) {
      final aspect = image.width / image.height;
      final widthPx = heightPx * aspect;
      final rect = Rect.fromLTWH(
        frontLeftGround.dx - gapPx - widthPx,
        feetY - heightPx,
        widthPx,
        heightPx,
      );
      paintImage(
        canvas: canvas,
        rect: rect,
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
      return;
    }

    final silhouette = Paint()
      ..color = Colors.black.withValues(alpha: 0.86)
      ..style = PaintingStyle.fill;
    final centerX = frontLeftGround.dx - gapPx - heightPx * 0.18;
    final headR = heightPx * 0.075;
    final headCenter = Offset(centerX, feetY - heightPx + headR * 1.15);
    canvas.drawCircle(headCenter, headR, silhouette);
    final body = Path()
      ..moveTo(centerX - heightPx * 0.10, feetY - heightPx * 0.80)
      ..lineTo(centerX + heightPx * 0.10, feetY - heightPx * 0.80)
      ..lineTo(centerX + heightPx * 0.15, feetY - heightPx * 0.44)
      ..lineTo(centerX + heightPx * 0.07, feetY)
      ..lineTo(centerX - heightPx * 0.02, feetY)
      ..lineTo(centerX - heightPx * 0.03, feetY - heightPx * 0.38)
      ..lineTo(centerX - heightPx * 0.12, feetY)
      ..lineTo(centerX - heightPx * 0.21, feetY)
      ..lineTo(centerX - heightPx * 0.13, feetY - heightPx * 0.44)
      ..close();
    canvas.drawPath(body, silhouette);
  }

  double _humanDisplayHeightMm(
    _RoofLayout layout,
    Offset humanPoint,
  ) {
    final posts = _effectivePostPoints(layout);
    if (posts.isEmpty) return _humanMm;

    var nearest = posts.first;
    var nearestDistance = (nearest - humanPoint).distance;
    for (final post in posts.skip(1)) {
      final distance = (post - humanPoint).distance;
      if (distance < nearestDistance) {
        nearest = post;
        nearestDistance = distance;
      }
    }

    final configuredPostHeight = _pointOnEdge(nearest, layout.front)
        ? frontHeightMm
        : rearHeightMm;
    if (configuredPostHeight == null || configuredPostHeight < _humanMm) {
      return _humanMm;
    }
    return _humanMm * layout.heightMm / configuredPostHeight;
  }


  bool get _usesSharedModuleBeams => const {
        'LWTR',
        'LWTL',
        'UWTM',
        'TWTM',
      }.contains(modelCode?.trim().toUpperCase());

  int _visualBeamCount(RoofModuleCalculation calculation) => math.max(
        2,
        calculation.beamCount + calculation.glassCountOffset + 1,
      ).toInt();

  double _sharedModuleBackY(_RoofLayout layout, double x) {
    final candidates = <double>[];
    for (final area in layout.moduleAreas) {
      if (area.corners.length != 4) continue;
      final xs = area.corners.map((point) => point.dx).toList(growable: false);
      final minX = xs.reduce((a, b) => math.min(a, b).toDouble());
      final maxX = xs.reduce((a, b) => math.max(a, b).toDouble());
      if (x < minX - 1 || x > maxX + 1) continue;
      final left = area.corners[3];
      final right = area.corners[2];
      if ((right.dx - left.dx).abs() < 1e-6) {
        candidates.add(math.max(left.dy, right.dy).toDouble());
      } else {
        final t = ((x - left.dx) / (right.dx - left.dx)).clamp(0.0, 1.0).toDouble();
        candidates.add(left.dy + (right.dy - left.dy) * t);
      }
    }
    if (candidates.isEmpty) return _yAt(layout.back, x);
    return candidates.reduce((a, b) => math.max(a, b).toDouble());
  }

  List<double> _effectiveRafterX(_RoofLayout layout) {
    if (calculatedModules.isEmpty || layout.moduleAreas.isEmpty) return layout.rafterX;
    final values = <double>[];
    for (final area in layout.moduleAreas) {
      final calculation = calculatedModules
          .where((entry) => entry.moduleIndex == area.index)
          .cast<RoofModuleCalculation?>()
          .firstOrNull;
      if (calculation == null || calculation.beamCount < 2 || area.corners.isEmpty) continue;
      final xs = area.corners.map((point) => point.dx).toList(growable: false);
      final minX = xs.reduce((a, b) => math.min(a, b).toDouble());
      final maxX = xs.reduce((a, b) => math.max(a, b).toDouble());
      final span = maxX - minX;
      if (span <= 0 || calculation.widthMm <= 0) continue;

      if (_usesSharedModuleBeams) {
        // The module keeps its calculated physical beam quantity, while the
        // visual count also includes boundary beams shared with neighbours.
        // Exact boundary coordinates merge the common profile into one line.
        final visualCount = _visualBeamCount(calculation);
        for (var i = 0; i < visualCount; i++) {
          values.add(minX + span * i / (visualCount - 1));
        }
        continue;
      }

      // Split-gutter L models intentionally keep two adjacent profiles at the
      // module joint, therefore their profile centres remain independently inset.
      final beamWidthMm = (
        calculation.widthMm -
        (calculation.beamCount - 1) * calculation.beamStepMm
      ) / calculation.beamCount;
      final edgeInsetFraction = (beamWidthMm / 2 / calculation.widthMm).clamp(0.0, 0.49);
      final usableFraction = 1 - edgeInsetFraction * 2;
      for (var i = 0; i < calculation.beamCount; i++) {
        final fraction = edgeInsetFraction + usableFraction * i / (calculation.beamCount - 1);
        values.add(minX + span * fraction);
      }
    }
    if (values.isEmpty) return layout.rafterX;
    values.sort();
    final unique = <double>[];
    for (final value in values) {
      if (!_usesSharedModuleBeams || unique.isEmpty || (unique.last - value).abs() >= 1) {
        unique.add(value);
      }
    }
    return unique;
  }

  List<double> _rafterPositions(double width, List<double> fixed, {List<double> blocked = const []}) {
    final count = (width / 620).round().clamp(4, 11).toInt();
    final values = <double>{};
    for (var i = 1; i < count; i++) {
      values.add(width * i / count);
    }
    for (final value in fixed) {
      if (value > 0 && value < width) values.add(value);
    }
    final out = values
        .where((value) => !blocked.any((blockedValue) => (blockedValue - value).abs() < 80))
        .toList()
      ..sort();
    return out;
  }

  List<Offset> _wallGuidePoints(_RoofLayout layout) {
    final points = <Offset>[
      for (final point in layout.back)
        if (!_hasPostAt(layout, point)) point,
      for (final point in layout.front)
        if (!_hasPostAt(layout, point)) point,
    ];
    return _uniquePoints(points);
  }

  bool _hasPostAt(_RoofLayout layout, Offset point) {
    return _effectivePostPoints(layout).any((post) => (post - point).distance < 1) ||
        _canonicalPostPoints(layout).any((post) => (post - point).distance < 1);
  }

  List<Offset> _effectivePostPoints(_RoofLayout layout) {
    final canonical = _canonicalPostPoints(layout);
    if (postCount <= 0) return canonical;

    final points = <Offset>[];
    void append(List<Offset> candidates) {
      for (final point in candidates) {
        if (points.length >= postCount) return;
        if (!points.any((entry) => (entry - point).distance < 1)) points.add(point);
      }
    }

    final front = _edgePostCorners(layout.front, isFront: true);
    append(front.external);
    append(front.internal);

    if (!wallMounted) {
      final back = _edgePostCorners(layout.back, isFront: false);
      append(back.external);
      append(back.internal);
    }

    if (points.length < postCount) {
      append(_segmentJointPostPoints(layout, layout.front, points));
    }
    if (!wallMounted && points.length < postCount) {
      append(_segmentJointPostPoints(layout, layout.back, points));
    }

    if (points.length < postCount) {
      final widestFrontGap = _widestGapBeamPoint(layout, layout.front, points);
      if (widestFrontGap != null) append([widestFrontGap]);
    }
    if (!wallMounted && points.length < postCount) {
      final widestBackGap = _widestGapBeamPoint(layout, layout.back, points);
      if (widestBackGap != null) append([widestBackGap]);
    }

    if (points.length < postCount) {
      append(_supplementalEdgePoints(layout, layout.front, points));
    }
    if (!wallMounted && points.length < postCount) {
      append(_supplementalEdgePoints(layout, layout.back, points));
    }

    return points;
  }

  List<Offset> _recommendedPostPoints(_RoofLayout layout) {
    final actual = _effectivePostPoints(layout);
    return _canonicalPostPoints(layout)
        .where((point) => !actual.any((post) => (post - point).distance < 1))
        .toList();
  }

  List<Offset> _canonicalPostPoints(_RoofLayout layout) {
    final points = <Offset>[];
    final front = _edgePostCorners(layout.front, isFront: true);
    points.addAll(front.external);
    points.addAll(front.internal);
    if (!wallMounted) {
      final back = _edgePostCorners(layout.back, isFront: false);
      points.addAll(back.external);
      points.addAll(back.internal);
    }
    return _uniquePoints(points);
  }

  _PostCornerGroups _edgePostCorners(List<Offset> edge, {required bool isFront}) {
    if (edge.isEmpty) return const _PostCornerGroups();
    if (edge.length == 1) return _PostCornerGroups(external: [edge.first]);

    final external = <Offset>[edge.first, edge.last];
    final internal = <Offset>[];
    for (var index = 1; index < edge.length - 1; index++) {
      final before = edge[index] - edge[index - 1];
      final after = edge[index + 1] - edge[index];
      final cross = before.dx * after.dy - before.dy * after.dx;
      if (cross.abs() < 1e-6) continue;
      final isExternalCorner = isFront ? cross > 0 : cross < 0;
      (isExternalCorner ? external : internal).add(edge[index]);
    }
    return _PostCornerGroups(
      external: _uniquePoints(external),
      internal: _uniquePoints(internal),
    );
  }

  List<Offset> _segmentJointPostPoints(
    _RoofLayout layout,
    List<Offset> edge,
    List<Offset> occupied,
  ) {
    final boundaryX = <double>[];
    for (final area in layout.moduleAreas) {
      if (area.corners.isEmpty) continue;
      final xs = area.corners.map((point) => point.dx).toList(growable: false);
      final minX = xs.reduce((a, b) => math.min(a, b).toDouble());
      final maxX = xs.reduce((a, b) => math.max(a, b).toDouble());
      if (minX > 1 && minX < layout.widthMm - 1) boundaryX.add(minX);
      if (maxX > 1 && maxX < layout.widthMm - 1) boundaryX.add(maxX);
    }

    final jointPoints = <Offset>[];
    for (final x in boundaryX) {
      final snapped = _snapToNearestBeamPoint(
        layout,
        edge,
        Offset(x, _yAt(edge, x)),
      );
      if (snapped != null) jointPoints.add(snapped);
    }
    final remaining = _uniquePoints(jointPoints)
        .where((point) => !occupied.any((entry) => (entry - point).distance < 1))
        .toList();
    final ordered = <Offset>[];
    final spacingPoints = <Offset>[
      ...occupied.where((point) => _pointOnEdge(point, edge)),
    ];

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final scoreA = _minimumEdgeDistance(edge, a, spacingPoints);
        final scoreB = _minimumEdgeDistance(edge, b, spacingPoints);
        final bySpacing = scoreB.compareTo(scoreA);
        if (bySpacing != 0) return bySpacing;
        return _edgePosition(edge, a).compareTo(_edgePosition(edge, b));
      });
      final next = remaining.removeAt(0);
      ordered.add(next);
      spacingPoints.add(next);
    }
    return ordered;
  }

  Offset? _widestGapBeamPoint(
    _RoofLayout layout,
    List<Offset> edge,
    List<Offset> occupied,
  ) {
    final pointsOnEdge = occupied.where((point) => _pointOnEdge(point, edge)).toList();
    if (pointsOnEdge.isEmpty) return null;
    final candidates = _beamIntersectionsOnEdge(layout, edge)
        .where((point) => !occupied.any((entry) => (entry - point).distance < 1))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final scoreA = _minimumEdgeDistance(edge, a, pointsOnEdge);
      final scoreB = _minimumEdgeDistance(edge, b, pointsOnEdge);
      final bySpacing = scoreB.compareTo(scoreA);
      if (bySpacing != 0) return bySpacing;
      return _edgePosition(edge, a).compareTo(_edgePosition(edge, b));
    });
    return candidates.first;
  }

  List<Offset> _supplementalEdgePoints(
    _RoofLayout layout,
    List<Offset> edge,
    List<Offset> occupied,
  ) {
    if (edge.length < 2) return const [];
    final points = <Offset>[];
    final unavailable = <Offset>[...occupied];
    for (var denominator = 2; denominator <= 64; denominator *= 2) {
      for (var numerator = 1; numerator < denominator; numerator += 2) {
        final target = _pointAlongEdge(edge, numerator / denominator);
        final snapped = _snapToNearestBeamPoint(
          layout,
          edge,
          target,
          excluded: [...unavailable, ...points],
        );
        if (snapped != null) points.add(snapped);
      }
    }
    return _uniquePoints(points);
  }

  Offset? _snapToNearestBeamPoint(
    _RoofLayout layout,
    List<Offset> edge,
    Offset target, {
    List<Offset> excluded = const [],
  }) {
    final candidates = _beamIntersectionsOnEdge(layout, edge)
        .where((point) => !excluded.any((entry) => (entry - point).distance < 1))
        .toList();
    if (candidates.isEmpty) return null;
    final targetPosition = _edgePosition(edge, target);
    candidates.sort((a, b) {
      final distanceA = (_edgePosition(edge, a) - targetPosition).abs();
      final distanceB = (_edgePosition(edge, b) - targetPosition).abs();
      return distanceA.compareTo(distanceB);
    });
    return candidates.first;
  }

  List<Offset> _beamIntersectionsOnEdge(_RoofLayout layout, List<Offset> edge) {
    if (edge.length < 2) return const [];
    final points = <Offset>[];
    for (final x in _effectiveRafterX(layout)) {
      final point = Offset(x, _yAt(edge, x));
      if (_pointOnEdge(point, edge)) points.add(point);
    }
    return _uniquePoints(points);
  }

  double _minimumEdgeDistance(List<Offset> edge, Offset point, List<Offset> others) {
    if (others.isEmpty) return double.infinity;
    final position = _edgePosition(edge, point);
    return others
        .map((entry) => (_edgePosition(edge, entry) - position).abs())
        .reduce((a, b) => math.min(a, b).toDouble());
  }

  double _edgePosition(List<Offset> edge, Offset point) {
    var consumed = 0.0;
    var bestPosition = 0.0;
    var bestDistance = double.infinity;
    for (var index = 0; index < edge.length - 1; index++) {
      final start = edge[index];
      final end = edge[index + 1];
      final delta = end - start;
      final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
      final segmentLength = delta.distance;
      final t = lengthSquared <= 1e-9
          ? 0.0
          : (((point.dx - start.dx) * delta.dx + (point.dy - start.dy) * delta.dy) / lengthSquared)
              .clamp(0.0, 1.0)
              .toDouble();
      final projected = start + delta * t;
      final distance = (point - projected).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestPosition = consumed + segmentLength * t;
      }
      consumed += segmentLength;
    }
    return bestPosition;
  }

  Offset _pointAlongEdge(List<Offset> edge, double fraction) {
    final segmentLengths = <double>[];
    var totalLength = 0.0;
    for (var index = 0; index < edge.length - 1; index++) {
      final length = (edge[index + 1] - edge[index]).distance;
      segmentLengths.add(length);
      totalLength += length;
    }
    if (totalLength <= 0) return edge.first;

    final target = totalLength * fraction.clamp(0.0, 1.0).toDouble();
    var consumed = 0.0;
    for (var index = 0; index < segmentLengths.length; index++) {
      final segmentLength = segmentLengths[index];
      if (target <= consumed + segmentLength || index == segmentLengths.length - 1) {
        final t = segmentLength <= 0
            ? 0.0
            : ((target - consumed) / segmentLength).clamp(0.0, 1.0).toDouble();
        return _lerp(edge[index], edge[index + 1], t);
      }
      consumed += segmentLength;
    }
    return edge.last;
  }

  List<Offset> _uniquePoints(List<Offset> points) {
    final out = <Offset>[];
    for (final point in points) {
      if (!out.any((entry) => (entry - point).distance < 1)) out.add(point);
    }
    return out;
  }

  double _yAt(List<Offset> edge, double x) {
    for (var i = 0; i < edge.length - 1; i++) {
      final a = edge[i];
      final b = edge[i + 1];
      if ((a.dx - b.dx).abs() < 1e-6) continue;
      if (x >= _min(a.dx, b.dx) - 1e-6 && x <= _max(a.dx, b.dx) + 1e-6) {
        final t = (x - a.dx) / (b.dx - a.dx);
        return a.dy + t * (b.dy - a.dy);
      }
    }
    return x > edge.first.dx ? edge.last.dy : edge.first.dy;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset at,
    Color color,
    double fontSize, {
    bool isBold = false,
    double hAlign = 0.5,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 86);
    painter.paint(canvas, at - Offset(painter.width * hAlign, painter.height / 2));
  }

  bool _sameGeometryParams(List<RoofGeometryParam> a, List<RoofGeometryParam> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].code != b[i].code || a[i].valueMm != b[i].valueMm) return false;
    }
    return true;
  }

  Offset _lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;
  double _min(double a, double b) => a < b ? a : b;
  double _max(double a, double b) => a > b ? a : b;

  @override
  bool shouldRepaint(covariant _ModelGeometryPreviewPainter oldDelegate) {
    return oldDelegate.modelCode != modelCode ||
        oldDelegate.modelLabel != modelLabel ||
        oldDelegate.widthMm != widthMm ||
        oldDelegate.depthMm != depthMm ||
        oldDelegate.heightMm != heightMm ||
        !_sameGeometryParams(oldDelegate.geometryParams, geometryParams) ||
        oldDelegate.colorCode != colorCode ||
        oldDelegate.colorSwatchColor != colorSwatchColor ||
        oldDelegate.isSpecialColor != isSpecialColor ||
        oldDelegate.coveringName != coveringName ||
        oldDelegate.humanImage != humanImage ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.mutedLineColor != mutedLineColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.highlightedModuleIndex != highlightedModuleIndex ||
        oldDelegate.highlightedGlassFieldIndex != highlightedGlassFieldIndex ||
        oldDelegate.roofAngleDeg != roofAngleDeg ||
        oldDelegate.rearHeightMm != rearHeightMm ||
        oldDelegate.frontHeightMm != frontHeightMm ||
        oldDelegate.calculatedModules != calculatedModules ||
        oldDelegate.wallMounted != wallMounted ||
        oldDelegate.postCount != postCount ||
        oldDelegate.sideInfoBottomReserve != sideInfoBottomReserve ||
        oldDelegate.geometryOnly != geometryOnly;
  }
}
