import 'package:nexa/core/di/injection.dart';
import 'package:nexa/core/network/api_client.dart';

/// Service for payroll export, config, and mapping operations.
class PayrollExportService {
  PayrollExportService() : _apiClient = getIt<ApiClient>();
  final ApiClient _apiClient;

  // ─── Payroll Config ──────────────────────────────────────────────

  /// Fetch org-wide payroll configuration.
  Future<PayrollConfig> getPayrollConfig() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/payroll/config',
    );

    if (response.statusCode != null && response.statusCode! >= 300) {
      throw Exception('Failed to load payroll config (${response.statusCode})');
    }

    final data = response.data as Map<String, dynamic>;
    return PayrollConfig.fromJson(data['config'] as Map<String, dynamic>? ?? {});
  }

  /// Save org-wide payroll configuration.
  Future<PayrollConfig> savePayrollConfig(PayrollConfig config) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '/payroll/config',
      data: config.toJson(),
    );

    if (response.statusCode != null && response.statusCode! >= 300) {
      throw Exception('Failed to save payroll config (${response.statusCode})');
    }

    final data = response.data as Map<String, dynamic>;
    return PayrollConfig.fromJson(data['config'] as Map<String, dynamic>? ?? {});
  }

  // ─── Bulk Mapping ────────────────────────────────────────────────

  /// Bulk-save payroll mappings for staff roster.
  Future<BulkMappingResult> bulkSaveMappings(List<StaffPayrollMapping> mappings) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/payroll/bulk-mapping',
      data: {
        'mappings': mappings.map((m) => m.toJson()).toList(),
      },
    );

    if (response.statusCode != null && response.statusCode! >= 300) {
      throw Exception('Failed to save mappings (${response.statusCode})');
    }

    final data = response.data as Map<String, dynamic>;
    return BulkMappingResult(
      upserted: data['upserted'] as int? ?? 0,
      modified: data['modified'] as int? ?? 0,
      total: data['total'] as int? ?? 0,
    );
  }

  // ─── Staff Roster (for mapping screen) ───────────────────────────

  /// Fetch staff roster with payroll fields.
  Future<List<StaffRosterItem>> fetchStaffRoster() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/staff',
      queryParameters: {'limit': '200'},
    );

    if (response.statusCode != null && response.statusCode! >= 300) {
      throw Exception('Failed to load staff roster');
    }

    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => StaffRosterItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Preview / Summary ────────────────────────────────────────────

  /// Fetch payroll preview (summary + entries with mapping status).
  Future<PayrollPreview> fetchPreview({
    required String startDate,
    required String endDate,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/exports/payroll-preview',
      queryParameters: {'startDate': startDate, 'endDate': endDate},
    );

    if (response.statusCode != null && response.statusCode! >= 300) {
      throw Exception('Failed to load payroll preview (${response.statusCode})');
    }

    return PayrollPreview.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── CSV Export ───────────────────────────────────────────────────

  /// Export payroll as CSV (returns download URL + metadata).
  Future<PayrollExportResult> exportCsv({
    required String startDate,
    required String endDate,
    required PayrollFormat format,
    String? companyCode,
    String? checkDate,
  }) async {
    final path = switch (format) {
      PayrollFormat.adp => '/exports/payroll-adp',
      PayrollFormat.paychex => '/exports/payroll-paychex',
      PayrollFormat.generic => '/exports/payroll-csv',
    };

    final params = <String, dynamic>{
      'startDate': startDate,
      'endDate': endDate,
    };
    if (companyCode != null) params['companyCode'] = companyCode;
    if (checkDate != null) params['checkDate'] = checkDate;

    final response = await _apiClient.get<Map<String, dynamic>>(
      path,
      queryParameters: params,
    );

    if (response.statusCode != null && response.statusCode! >= 300) {
      throw Exception('Export failed (${response.statusCode})');
    }

    final data = response.data as Map<String, dynamic>;
    return PayrollExportResult(
      url: data['url'] as String,
      filename: data['filename'] as String? ?? 'payroll.csv',
      unmappedStaff: List<String>.from((data['unmappedStaff'] as List<dynamic>?) ?? <dynamic>[]),
      mappedCount: data['mappedCount'] as int? ?? 0,
    );
  }

  // ─── Single-Event CSV Export ─────────────────────────────────────

  /// Export a single event's staff data as CSV (returns download URL + counts).
  Future<EventCsvExportResult> exportEventCsv(String eventId) async {
    final response = await _apiClient.get<dynamic>(
      '/exports/event-csv',
      queryParameters: {'eventId': eventId},
    );

    if (response.statusCode != null && response.statusCode! >= 300) {
      throw Exception('Export failed (${response.statusCode})');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected response from server');
    }
    return EventCsvExportResult(
      url: data['url'] as String,
      filename: data['filename'] as String? ?? 'event.csv',
      staffCount: data['staffCount'] as int? ?? 0,
      approvedCount: data['approvedCount'] as int? ?? 0,
      pendingCount: data['pendingCount'] as int? ?? 0,
    );
  }

  // ─── Legacy (kept for backward compat, deprecated) ────────────────

  Future<List<EmployeeMapping>> getMappings({String? provider}) async {
    final params = <String, dynamic>{};
    if (provider != null) params['provider'] = provider;

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/payroll/employee-mappings',
      queryParameters: params,
    );

    if (response.statusCode != null && response.statusCode! >= 300) {
      throw Exception('Failed to load mappings');
    }

    final data = response.data as Map<String, dynamic>;
    final list = data['mappings'] as List<dynamic>;
    return list.map((m) => EmployeeMapping.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<void> deleteMapping(String id) async {
    // No-op — legacy endpoint removed
  }

  Future<EmployeeMapping> saveMapping(EmployeeMapping mapping) async {
    // Redirect to bulk endpoint
    await bulkSaveMappings([
      StaffPayrollMapping(
        userKey: mapping.userKey,
        externalEmployeeId: mapping.externalEmployeeId,
        workerType: mapping.workerType,
      ),
    ]);
    return mapping;
  }
}

// ─── Data Models ──────────────────────────────────────────────────────

enum PayrollFormat { adp, paychex, generic }

class PayrollConfig {
  final String provider;
  final String companyCode;
  final String defaultDepartment;
  final String defaultEarningsCode;
  final double overtimeThreshold;
  final double overtimeMultiplier;

  PayrollConfig({
    this.provider = 'none',
    this.companyCode = '',
    this.defaultDepartment = '',
    this.defaultEarningsCode = 'REG',
    double? overtimeThreshold,
    double? overtimeMultiplier,
  })  : overtimeThreshold = overtimeThreshold ?? 40,
        overtimeMultiplier = overtimeMultiplier ?? 1.5;

  factory PayrollConfig.fromJson(Map<String, dynamic> json) {
    return PayrollConfig(
      provider: json['provider'] as String? ?? 'none',
      companyCode: json['companyCode'] as String? ?? '',
      defaultDepartment: json['defaultDepartment'] as String? ?? '',
      defaultEarningsCode: json['defaultEarningsCode'] as String? ?? 'REG',
      overtimeThreshold: _toDouble(json['overtimeThreshold'], 40),
      overtimeMultiplier: _toDouble(json['overtimeMultiplier'], 1.5),
    );
  }

  /// Safe num→double with fallback (guards against runtime null from undeployed backend)
  static double _toDouble(dynamic v, double fallback) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'companyCode': companyCode,
    'defaultDepartment': defaultDepartment,
    'defaultEarningsCode': defaultEarningsCode,
    'overtimeThreshold': overtimeThreshold,
    'overtimeMultiplier': overtimeMultiplier,
  };

  PayrollConfig copyWith({
    String? provider,
    String? companyCode,
    String? defaultDepartment,
    String? defaultEarningsCode,
    double? overtimeThreshold,
    double? overtimeMultiplier,
  }) {
    return PayrollConfig(
      provider: provider ?? this.provider,
      companyCode: companyCode ?? this.companyCode,
      defaultDepartment: defaultDepartment ?? this.defaultDepartment,
      defaultEarningsCode: defaultEarningsCode ?? this.defaultEarningsCode,
      overtimeThreshold: overtimeThreshold ?? this.overtimeThreshold,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
    );
  }

  bool get isConfigured => provider != 'none' && provider.isNotEmpty;

  String get providerLabel => switch (provider) {
    'adp' => 'ADP',
    'paychex' => 'Paychex',
    'gusto' => 'Gusto',
    _ => 'None',
  };

  String get employeeIdLabel => switch (provider) {
    'adp' => 'ADP File Number',
    'paychex' => 'Paychex Employee ID',
    'gusto' => 'Gusto Employee ID',
    _ => 'Employee ID',
  };
}

class StaffRosterItem {
  final String userKey;
  final String name;
  final String? email;
  final String? picture;
  final List<String> roles;
  final int shiftCount;
  final String externalEmployeeId;
  final String workerType;
  final String department;
  final bool isMapped;

  StaffRosterItem({
    required this.userKey,
    required this.name,
    this.email,
    this.picture,
    this.roles = const [],
    this.shiftCount = 0,
    this.externalEmployeeId = '',
    this.workerType = 'w2',
    this.department = '',
    this.isMapped = false,
  });

  factory StaffRosterItem.fromJson(Map<String, dynamic> json) {
    return StaffRosterItem(
      userKey: json['userKey'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String?,
      picture: json['picture'] as String?,
      roles: List<String>.from((json['roles'] as List<dynamic>?) ?? []),
      shiftCount: json['shiftCount'] as int? ?? 0,
      externalEmployeeId: json['externalEmployeeId'] as String? ?? '',
      workerType: json['workerType'] as String? ?? 'w2',
      department: json['department'] as String? ?? '',
      isMapped: json['isMapped'] as bool? ?? false,
    );
  }
}

class StaffPayrollMapping {
  final String userKey;
  final String externalEmployeeId;
  final String workerType;
  final String? department;
  final String? earningsCode;

  StaffPayrollMapping({
    required this.userKey,
    required this.externalEmployeeId,
    this.workerType = 'w2',
    this.department,
    this.earningsCode,
  });

  Map<String, dynamic> toJson() => {
    'userKey': userKey,
    'externalEmployeeId': externalEmployeeId,
    'workerType': workerType,
    if (department != null) 'department': department,
    if (earningsCode != null) 'earningsCode': earningsCode,
  };
}

class BulkMappingResult {
  final int upserted;
  final int modified;
  final int total;

  BulkMappingResult({
    required this.upserted,
    required this.modified,
    required this.total,
  });
}

class OvertimeStats {
  final int staffWithOT;
  final double totalOTHours;
  final double totalOTEarnings;

  OvertimeStats({
    required this.staffWithOT,
    required this.totalOTHours,
    required this.totalOTEarnings,
  });

  factory OvertimeStats.fromJson(Map<String, dynamic> json) {
    return OvertimeStats(
      staffWithOT: (json['staffWithOT'] as num?)?.toInt() ?? 0,
      totalOTHours: PayrollConfig._toDouble(json['totalOTHours'], 0),
      totalOTEarnings: PayrollConfig._toDouble(json['totalOTEarnings'], 0),
    );
  }

  bool get hasOvertime => staffWithOT > 0;
}

class UnapprovedShiftWarning {
  final String userKey;
  final String name;
  final String eventName;
  final String eventDate;

  UnapprovedShiftWarning({
    required this.userKey,
    required this.name,
    required this.eventName,
    required this.eventDate,
  });

  factory UnapprovedShiftWarning.fromJson(Map<String, dynamic> json) {
    return UnapprovedShiftWarning(
      userKey: json['userKey'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      eventName: json['eventName'] as String? ?? '',
      eventDate: json['eventDate'] as String? ?? '',
    );
  }
}

class PayrollPreview {
  final Map<String, String> period;
  final PayrollSummary summary;
  final List<PayrollEntry> entries;
  final MappingStats mappingStats;
  final OvertimeStats? overtimeStats;
  final List<UnapprovedShiftWarning> unapprovedStaffShifts;

  PayrollPreview({
    required this.period,
    required this.summary,
    required this.entries,
    required this.mappingStats,
    this.overtimeStats,
    this.unapprovedStaffShifts = const [],
  });

  factory PayrollPreview.fromJson(Map<String, dynamic> json) {
    final periodMap = json['period'] as Map<String, dynamic>;
    final summaryMap = json['summary'] as Map<String, dynamic>;
    final entriesList = json['entries'] as List<dynamic>;
    final statsMap = json['mappingStats'] as Map<String, dynamic>;
    final otMap = json['overtimeStats'] as Map<String, dynamic>?;
    final warningsMap = json['warnings'] as Map<String, dynamic>?;
    final unapprovedList = (warningsMap?['unapprovedStaffShifts'] as List<dynamic>?) ?? [];

    return PayrollPreview(
      period: {
        'start': periodMap['start'] as String,
        'end': periodMap['end'] as String,
      },
      summary: PayrollSummary.fromJson(summaryMap),
      entries: entriesList
          .map((e) => PayrollEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      mappingStats: MappingStats.fromJson(statsMap),
      overtimeStats: otMap != null ? OvertimeStats.fromJson(otMap) : null,
      unapprovedStaffShifts: unapprovedList
          .map((e) => UnapprovedShiftWarning.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PayrollSummary {
  final int staffCount;
  final double totalHours;
  final double totalPayroll;
  final double averagePerStaff;

  PayrollSummary({
    required this.staffCount,
    required this.totalHours,
    required this.totalPayroll,
    required this.averagePerStaff,
  });

  factory PayrollSummary.fromJson(Map<String, dynamic> json) {
    return PayrollSummary(
      staffCount: (json['staffCount'] as num?)?.toInt() ?? 0,
      totalHours: PayrollConfig._toDouble(json['totalHours'], 0),
      totalPayroll: PayrollConfig._toDouble(json['totalPayroll'], 0),
      averagePerStaff: PayrollConfig._toDouble(json['averagePerStaff'], 0),
    );
  }
}

class PayrollEntry {
  final String userKey;
  final String name;
  final String email;
  final String phone;
  final String appId;
  final String picture;
  final int shifts;
  final double hours;
  final double earnings;
  final double averageRate;
  final List<String> roles;
  final bool isMapped;
  final double otHours;

  PayrollEntry({
    required this.userKey,
    required this.name,
    required this.email,
    this.phone = '',
    this.appId = '',
    required this.picture,
    required this.shifts,
    required this.hours,
    required this.earnings,
    required this.averageRate,
    required this.roles,
    required this.isMapped,
    this.otHours = 0,
  });

  bool get hasOvertime => otHours > 0;

  factory PayrollEntry.fromJson(Map<String, dynamic> json) {
    return PayrollEntry(
      userKey: json['userKey'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      picture: json['picture'] as String? ?? '',
      shifts: (json['shifts'] as num?)?.toInt() ?? 0,
      hours: PayrollConfig._toDouble(json['hours'], 0),
      earnings: PayrollConfig._toDouble(json['earnings'], 0),
      averageRate: PayrollConfig._toDouble(json['averageRate'], 0),
      roles: List<String>.from((json['roles'] as List<dynamic>?) ?? <dynamic>[]),
      isMapped: json['isMapped'] as bool? ?? false,
      otHours: PayrollConfig._toDouble(json['otHours'], 0),
    );
  }
}

class MappingStats {
  final int totalStaff;
  final int mapped;
  final int unmapped;

  MappingStats({
    required this.totalStaff,
    required this.mapped,
    required this.unmapped,
  });

  factory MappingStats.fromJson(Map<String, dynamic> json) {
    return MappingStats(
      totalStaff: json['totalStaff'] as int? ?? 0,
      mapped: json['mapped'] as int? ?? 0,
      unmapped: json['unmapped'] as int? ?? 0,
    );
  }
}

class EmployeeMapping {
  final String? id;
  final String userKey;
  final String staffName;
  final String provider;
  final String externalEmployeeId;
  final String workerType;
  final String? department;
  final String? earningsCode;

  EmployeeMapping({
    this.id,
    required this.userKey,
    required this.staffName,
    required this.provider,
    required this.externalEmployeeId,
    this.workerType = 'w2',
    this.department,
    this.earningsCode,
  });

  factory EmployeeMapping.fromJson(Map<String, dynamic> json) {
    return EmployeeMapping(
      id: json['_id'] as String?,
      userKey: json['userKey'] as String? ?? '',
      staffName: json['staffName'] as String? ?? '',
      provider: json['provider'] as String? ?? 'adp',
      externalEmployeeId: json['externalEmployeeId'] as String? ?? '',
      workerType: json['workerType'] as String? ?? 'w2',
      department: json['department'] as String?,
      earningsCode: json['earningsCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userKey': userKey,
      'staffName': staffName,
      'provider': provider,
      'externalEmployeeId': externalEmployeeId,
      'workerType': workerType,
      if (department != null) 'department': department,
      if (earningsCode != null) 'earningsCode': earningsCode,
    };
  }

  EmployeeMapping copyWith({
    String? id,
    String? userKey,
    String? staffName,
    String? provider,
    String? externalEmployeeId,
    String? workerType,
    String? department,
    String? earningsCode,
  }) {
    return EmployeeMapping(
      id: id ?? this.id,
      userKey: userKey ?? this.userKey,
      staffName: staffName ?? this.staffName,
      provider: provider ?? this.provider,
      externalEmployeeId: externalEmployeeId ?? this.externalEmployeeId,
      workerType: workerType ?? this.workerType,
      department: department ?? this.department,
      earningsCode: earningsCode ?? this.earningsCode,
    );
  }
}

class PayrollExportResult {
  final String url;
  final String filename;
  final List<String> unmappedStaff;
  final int mappedCount;

  PayrollExportResult({
    required this.url,
    required this.filename,
    required this.unmappedStaff,
    required this.mappedCount,
  });
}

class EventCsvExportResult {
  final String url;
  final String filename;
  final int staffCount;
  final int approvedCount;
  final int pendingCount;

  EventCsvExportResult({
    required this.url,
    required this.filename,
    required this.staffCount,
    required this.approvedCount,
    required this.pendingCount,
  });
}
