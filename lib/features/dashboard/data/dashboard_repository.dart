import '../../../core/http/api_client.dart';

class DashboardRepository {
  const DashboardRepository(this._client);

  final ApiClient _client;

  Future<DashboardData> fetch({required int days}) async {
    final response = await _client.getJson(
      '/api/admin/dashboard',
      query: {'days': '$days'},
    );
    return DashboardData.fromJson(response);
  }
}

class DashboardData {
  const DashboardData({
    required this.days,
    required this.periodFrom,
    required this.periodTo,
    required this.summary,
    required this.activity,
    required this.statuses,
    required this.topCustomers,
    required this.recentQuotes,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final period = _map(json['period']);
    return DashboardData(
      days: _integer(period['days'], 30),
      periodFrom: _dateTime(period['from']),
      periodTo: _dateTime(period['to']),
      summary: DashboardSummary.fromJson(_map(json['summary'])),
      activity: _maps(
        json['activity'],
      ).map(DashboardActivityPoint.fromJson).toList(),
      statuses: _maps(json['statuses']).map(DashboardStatus.fromJson).toList(),
      topCustomers: _maps(
        json['top_customers'],
      ).map(DashboardCustomer.fromJson).toList(),
      recentQuotes: _maps(
        json['recent_quotes'],
      ).map(DashboardQuote.fromJson).toList(),
    );
  }

  final int days;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final DashboardSummary summary;
  final List<DashboardActivityPoint> activity;
  final List<DashboardStatus> statuses;
  final List<DashboardCustomer> topCustomers;
  final List<DashboardQuote> recentQuotes;
}

class DashboardSummary {
  const DashboardSummary({
    required this.quoteCount,
    required this.quoteValueNet,
    required this.quoteValueGross,
    required this.averageQuoteNet,
    required this.activeCustomerCount,
    required this.missingBuyerCount,
    required this.quotesWithDocument,
    required this.documentCoverageRate,
    required this.previousQuoteCount,
    required this.previousQuoteValueNet,
    required this.previousAverageQuoteNet,
    required this.previousActiveCustomerCount,
    required this.calculationCount,
    required this.validCalculationCount,
    required this.validCalculationRate,
    required this.attentionCalculationCount,
    required this.warningRunCount,
    required this.priceGapRunCount,
    required this.generatedDocumentCount,
    required this.failedIntegrationJobCount,
    required this.openIntegrationJobCount,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      quoteCount: _integer(json['quote_count']),
      quoteValueNet: _decimal(json['quote_value_net']),
      quoteValueGross: _decimal(json['quote_value_gross']),
      averageQuoteNet: _decimal(json['average_quote_net']),
      activeCustomerCount: _integer(json['active_customer_count']),
      missingBuyerCount: _integer(json['missing_buyer_count']),
      quotesWithDocument: _integer(json['quotes_with_document']),
      documentCoverageRate: _decimal(json['document_coverage_rate']),
      previousQuoteCount: _integer(json['previous_quote_count']),
      previousQuoteValueNet: _decimal(json['previous_quote_value_net']),
      previousAverageQuoteNet: _decimal(json['previous_average_quote_net']),
      previousActiveCustomerCount: _integer(
        json['previous_active_customer_count'],
      ),
      calculationCount: _integer(json['calculation_count']),
      validCalculationCount: _integer(json['valid_calculation_count']),
      validCalculationRate: _decimal(json['valid_calculation_rate']),
      attentionCalculationCount: _integer(json['attention_calculation_count']),
      warningRunCount: _integer(json['warning_run_count']),
      priceGapRunCount: _integer(json['price_gap_run_count']),
      generatedDocumentCount: _integer(json['generated_document_count']),
      failedIntegrationJobCount: _integer(json['failed_integration_job_count']),
      openIntegrationJobCount: _integer(json['open_integration_job_count']),
    );
  }

  final int quoteCount;
  final double quoteValueNet;
  final double quoteValueGross;
  final double averageQuoteNet;
  final int activeCustomerCount;
  final int missingBuyerCount;
  final int quotesWithDocument;
  final double documentCoverageRate;
  final int previousQuoteCount;
  final double previousQuoteValueNet;
  final double previousAverageQuoteNet;
  final int previousActiveCustomerCount;
  final int calculationCount;
  final int validCalculationCount;
  final double validCalculationRate;
  final int attentionCalculationCount;
  final int warningRunCount;
  final int priceGapRunCount;
  final int generatedDocumentCount;
  final int failedIntegrationJobCount;
  final int openIntegrationJobCount;
}

class DashboardActivityPoint {
  const DashboardActivityPoint({
    required this.bucket,
    required this.quoteCount,
    required this.netAmount,
  });

  factory DashboardActivityPoint.fromJson(Map<String, dynamic> json) {
    return DashboardActivityPoint(
      bucket: _dateTime(json['bucket']),
      quoteCount: _integer(json['quote_count']),
      netAmount: _decimal(json['net_amount']),
    );
  }

  final DateTime? bucket;
  final int quoteCount;
  final double netAmount;
}

class DashboardStatus {
  const DashboardStatus({
    required this.code,
    required this.quoteCount,
    required this.netAmount,
  });

  factory DashboardStatus.fromJson(Map<String, dynamic> json) {
    return DashboardStatus(
      code: json['status_code']?.toString() ?? '',
      quoteCount: _integer(json['quote_count']),
      netAmount: _decimal(json['net_amount']),
    );
  }

  final String code;
  final int quoteCount;
  final double netAmount;
}

class DashboardCustomer {
  const DashboardCustomer({
    required this.organizationId,
    required this.organizationName,
    required this.quoteCount,
    required this.netAmount,
  });

  factory DashboardCustomer.fromJson(Map<String, dynamic> json) {
    return DashboardCustomer(
      organizationId: json['organization_id']?.toString() ?? '',
      organizationName:
          json['organization_name']?.toString() ?? 'Unknown customer',
      quoteCount: _integer(json['quote_count']),
      netAmount: _decimal(json['net_amount']),
    );
  }

  final String organizationId;
  final String organizationName;
  final int quoteCount;
  final double netAmount;
}

class DashboardQuote {
  const DashboardQuote({
    required this.id,
    required this.quoteNo,
    required this.externalName,
    required this.statusCode,
    required this.buyerName,
    required this.netAmount,
    required this.createdAt,
  });

  factory DashboardQuote.fromJson(Map<String, dynamic> json) {
    return DashboardQuote(
      id: json['id']?.toString() ?? '',
      quoteNo: json['quote_no']?.toString() ?? '',
      externalName: json['quote_no_external']?.toString() ?? '',
      statusCode: json['status_code']?.toString() ?? '',
      buyerName: json['buyer_name']?.toString() ?? '',
      netAmount: _decimal(json['net_amount']),
      createdAt: _dateTime(json['created_at']),
    );
  }

  final String id;
  final String quoteNo;
  final String externalName;
  final String statusCode;
  final String buyerName;
  final double netAmount;
  final DateTime? createdAt;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value.map(_map).toList();
}

int _integer(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _decimal(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTime(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
