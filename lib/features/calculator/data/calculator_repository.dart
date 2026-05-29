import '../../../core/http/api_client.dart';
import 'calculator_models.dart';

class CalculatorRepository {
  const CalculatorRepository(this._client);

  final ApiClient _client;

  Future<CalculatorContext> fetchContext() async {
    final response = await _client.getJson('/api/internal/calculator/context');
    return CalculatorContext.fromJson(response);
  }

  Future<CalculatorResult> calculate(CalculatorDraft draft) async {
    final response = await _client.postJson(
      '/api/internal/calculator/calculate',
      body: draft.toCalculationJson(),
    );
    return CalculatorResult.fromJson(response);
  }

  Future<LoadedQuote> loadQuoteForWorkspace(String quoteId) async {
    final response = await _client.postJson(
      '/api/internal/calculator/load-quote',
      body: {
        'quote_id': quoteId,
      },
    );
    return LoadedQuote.fromJson(response);
  }

  Future<SavedQuote> saveQuote(
    CalculatorDraft draft, {
    SaveQuoteMode mode = SaveQuoteMode.asNew,
    String? baseQuoteId,
  }) async {
    final response = await _client.postJson(
      '/api/internal/calculator/save-quote',
      body: {
        'input': draft.toCalculationJson(),
        'mode': mode.apiValue,
        if (baseQuoteId != null && baseQuoteId.isNotEmpty) 'base_quote_id': baseQuoteId,
      },
    );

    final quote = response['quote'];
    if (quote is Map) {
      return SavedQuote.fromJson(Map<String, dynamic>.from(quote));
    }

    return SavedQuote.fromJson(response);
  }
}
