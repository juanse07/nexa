/// Statistics data models for Manager App

class StatisticsPeriod {
  final String type;
  final DateTime start;
  final DateTime end;
  final String label;

  StatisticsPeriod({
    required this.type,
    required this.start,
    required this.end,
    required this.label,
  });

  factory StatisticsPeriod.fromJson(Map<String, dynamic> json) {
    return StatisticsPeriod(
      type: json['type'] ?? 'month',
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
      label: json['label'] ?? '',
    );
  }
}

class ManagerStatisticsSummary {
  final int totalEvents;
  final int completedEvents;
  final int cancelledEvents;
  final double totalStaffHours;
  final double totalPayroll;
  final double averageEventSize;
  final int fulfillmentRate;

  ManagerStatisticsSummary({
    required this.totalEvents,
    required this.completedEvents,
    required this.cancelledEvents,
    required this.totalStaffHours,
    required this.totalPayroll,
    required this.averageEventSize,
    required this.fulfillmentRate,
  });

  factory ManagerStatisticsSummary.fromJson(Map<String, dynamic> json) {
    return ManagerStatisticsSummary(
      totalEvents: json['totalEvents'] ?? 0,
      completedEvents: json['completedEvents'] ?? 0,
      cancelledEvents: json['cancelledEvents'] ?? 0,
      totalStaffHours: (json['totalStaffHours'] ?? 0).toDouble(),
      totalPayroll: (json['totalPayroll'] ?? 0).toDouble(),
      averageEventSize: (json['averageEventSize'] ?? 0).toDouble(),
      fulfillmentRate: json['fulfillmentRate'] ?? 0,
    );
  }

  static ManagerStatisticsSummary get empty => ManagerStatisticsSummary(
    totalEvents: 0,
    completedEvents: 0,
    cancelledEvents: 0,
    totalStaffHours: 0,
    totalPayroll: 0,
    averageEventSize: 0,
    fulfillmentRate: 0,
  );
}

class ComplianceSummary {
  final int pendingFlags;
  final int resolvedThisPeriod;
  final Map<String, int> flagsByType;

  ComplianceSummary({
    required this.pendingFlags,
    required this.resolvedThisPeriod,
    required this.flagsByType,
  });

  factory ComplianceSummary.fromJson(Map<String, dynamic> json) {
    final flagsByType = <String, int>{};
    if (json['flagsByType'] != null) {
      (json['flagsByType'] as Map<String, dynamic>).forEach((key, value) {
        flagsByType[key] = value as int;
      });
    }
    return ComplianceSummary(
      pendingFlags: json['pendingFlags'] ?? 0,
      resolvedThisPeriod: json['resolvedThisPeriod'] ?? 0,
      flagsByType: flagsByType,
    );
  }

  static ComplianceSummary get empty => ComplianceSummary(
    pendingFlags: 0,
    resolvedThisPeriod: 0,
    flagsByType: {},
  );
}

class ManagerStatistics {
  final StatisticsPeriod period;
  final ManagerStatisticsSummary summary;
  final ComplianceSummary compliance;

  ManagerStatistics({
    required this.period,
    required this.summary,
    required this.compliance,
  });

  factory ManagerStatistics.fromJson(Map<String, dynamic> json) {
    return ManagerStatistics(
      period: StatisticsPeriod.fromJson(json['period']),
      summary: ManagerStatisticsSummary.fromJson(json['summary']),
      compliance: ComplianceSummary.fromJson(json['compliance']),
    );
  }

  static ManagerStatistics get empty => ManagerStatistics(
    period: StatisticsPeriod(
      type: 'month',
      start: DateTime.now(),
      end: DateTime.now(),
      label: '',
    ),
    summary: ManagerStatisticsSummary.empty,
    compliance: ComplianceSummary.empty,
  );
}

class PayrollEntry {
  final String userKey;
  final String name;
  final String email;
  final String picture;
  final int shifts;
  final double hours;
  final double earnings;
  final double averageRate;
  final List<String> roles;

  PayrollEntry({
    required this.userKey,
    required this.name,
    required this.email,
    required this.picture,
    required this.shifts,
    required this.hours,
    required this.earnings,
    required this.averageRate,
    required this.roles,
  });

  factory PayrollEntry.fromJson(Map<String, dynamic> json) {
    return PayrollEntry(
      userKey: json['userKey'] ?? '',
      name: json['name'] ?? 'Unknown',
      email: json['email'] ?? '',
      picture: json['picture'] ?? '',
      shifts: json['shifts'] ?? 0,
      hours: (json['hours'] ?? 0).toDouble(),
      earnings: (json['earnings'] ?? 0).toDouble(),
      averageRate: (json['averageRate'] ?? 0).toDouble(),
      roles: List<String>.from(json['roles'] ?? []),
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
      staffCount: json['staffCount'] ?? 0,
      totalHours: (json['totalHours'] ?? 0).toDouble(),
      totalPayroll: (json['totalPayroll'] ?? 0).toDouble(),
      averagePerStaff: (json['averagePerStaff'] ?? 0).toDouble(),
    );
  }

  static PayrollSummary get empty => PayrollSummary(
    staffCount: 0,
    totalHours: 0,
    totalPayroll: 0,
    averagePerStaff: 0,
  );
}

class PayrollReport {
  final StatisticsPeriod period;
  final PayrollSummary summary;
  final List<PayrollEntry> entries;

  PayrollReport({
    required this.period,
    required this.summary,
    required this.entries,
  });

  factory PayrollReport.fromJson(Map<String, dynamic> json) {
    return PayrollReport(
      period: StatisticsPeriod.fromJson(json['period']),
      summary: PayrollSummary.fromJson(json['summary']),
      entries: (json['entries'] as List<dynamic>?)
          ?.map((e) => PayrollEntry.fromJson(e))
          .toList() ?? [],
    );
  }

  static PayrollReport get empty => PayrollReport(
    period: StatisticsPeriod(
      type: 'month',
      start: DateTime.now(),
      end: DateTime.now(),
      label: '',
    ),
    summary: PayrollSummary.empty,
    entries: [],
  );
}

class TopPerformer {
  final String userKey;
  final String name;
  final String picture;
  final int shiftsCompleted;
  final double hoursWorked;
  final double earnings;
  final int punctualityScore;

  TopPerformer({
    required this.userKey,
    required this.name,
    required this.picture,
    required this.shiftsCompleted,
    required this.hoursWorked,
    required this.earnings,
    required this.punctualityScore,
  });

  factory TopPerformer.fromJson(Map<String, dynamic> json) {
    return TopPerformer(
      userKey: json['userKey'] ?? '',
      name: json['name'] ?? 'Unknown',
      picture: json['picture'] ?? '',
      shiftsCompleted: json['shiftsCompleted'] ?? 0,
      hoursWorked: (json['hoursWorked'] ?? 0).toDouble(),
      earnings: (json['earnings'] ?? 0).toDouble(),
      punctualityScore: json['punctualityScore'] ?? 100,
    );
  }
}

class TopPerformersReport {
  final StatisticsPeriod period;
  final List<TopPerformer> topPerformers;

  TopPerformersReport({
    required this.period,
    required this.topPerformers,
  });

  factory TopPerformersReport.fromJson(Map<String, dynamic> json) {
    return TopPerformersReport(
      period: StatisticsPeriod.fromJson(json['period']),
      topPerformers: (json['topPerformers'] as List<dynamic>?)
          ?.map((e) => TopPerformer.fromJson(e))
          .toList() ?? [],
    );
  }

  static TopPerformersReport get empty => TopPerformersReport(
    period: StatisticsPeriod(
      type: 'month',
      start: DateTime.now(),
      end: DateTime.now(),
      label: '',
    ),
    topPerformers: [],
  );
}

/// Export data model for PDF generation
class ExportData {
  final String title;
  final StatisticsPeriod period;
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic> summary;

  ExportData({
    required this.title,
    required this.period,
    required this.records,
    required this.summary,
  });

  factory ExportData.fromJson(Map<String, dynamic> json) {
    return ExportData(
      title: json['title'] ?? 'Report',
      period: StatisticsPeriod.fromJson(json['period']),
      records: List<Map<String, dynamic>>.from(json['records'] ?? []),
      summary: Map<String, dynamic>.from(json['summary'] ?? {}),
    );
  }
}
