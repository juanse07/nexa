/// Linode (Akamai Cloud) self-hosted database cost calculator.
///
/// Provides cost estimation for running MongoDB, MySQL, or PostgreSQL
/// on Linode compute instances with associated infrastructure costs.
///
/// Pricing data sourced from:
/// - https://www.linode.com/pricing/
/// - https://techdocs.akamai.com/cloud-computing/docs/compute-instance-plan-types
///
/// Last updated: February 2026
library;

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// The type of Linode compute plan.
enum LinodePlanType { shared, dedicated, highMemory }

/// High-availability topology.
enum HaTopology {
  /// Single node – no redundancy.
  singleNode,

  /// Primary + 1 replica.
  primaryReplica,

  /// Primary + 2 replicas (recommended for production).
  primaryTwoReplicas,
}

/// A Linode compute plan with its specs and pricing.
class LinodePlan {
  final String id;
  final String label;
  final LinodePlanType type;
  final int ramMB;
  final int vcpus;
  final int storageMB;
  final int transferTB;
  final double monthlyPrice;
  final double hourlyPrice;

  const LinodePlan({
    required this.id,
    required this.label,
    required this.type,
    required this.ramMB,
    required this.vcpus,
    required this.storageMB,
    required this.transferTB,
    required this.monthlyPrice,
    required this.hourlyPrice,
  });

  int get ramGB => ramMB ~/ 1024;
  int get storageGB => storageMB ~/ 1024;

  @override
  String toString() =>
      '$label – ${ramGB}GB RAM, $vcpus vCPU, ${storageGB}GB disk → '
      '\$${monthlyPrice.toStringAsFixed(0)}/mo';
}

/// Extra block storage volume.
class BlockStorageVolume {
  final int sizeGB;

  /// Linode charges \$0.10/GB/month for block storage.
  static const double pricePerGBMonth = 0.10;

  const BlockStorageVolume({required this.sizeGB});

  double get monthlyCost => sizeGB * pricePerGBMonth;
}

/// Summary of a full cost estimate.
class LinodeCostEstimate {
  final LinodePlan plan;
  final HaTopology topology;
  final int nodeCount;
  final double computeMonthlyCost;
  final double backupsMonthlyCost;
  final double blockStorageMonthlyCost;
  final double nodeBalancerMonthlyCost;
  final double transferOverageMonthlyCost;

  const LinodeCostEstimate({
    required this.plan,
    required this.topology,
    required this.nodeCount,
    required this.computeMonthlyCost,
    required this.backupsMonthlyCost,
    required this.blockStorageMonthlyCost,
    required this.nodeBalancerMonthlyCost,
    required this.transferOverageMonthlyCost,
  });

  double get totalMonthlyCost =>
      computeMonthlyCost +
      backupsMonthlyCost +
      blockStorageMonthlyCost +
      nodeBalancerMonthlyCost +
      transferOverageMonthlyCost;

  double get totalYearlyCost => totalMonthlyCost * 12;

  @override
  String toString() {
    final lines = <String>[
      '=== Linode Self-Hosted DB Cost Estimate ===',
      '',
      'Plan:            ${plan.label} (${plan.type.name})',
      'Topology:        ${topology.name} ($nodeCount node${nodeCount > 1 ? 's' : ''})',
      '',
      '--- Monthly Breakdown ---',
      'Compute:         \$${computeMonthlyCost.toStringAsFixed(2)}',
      'Backups:         \$${backupsMonthlyCost.toStringAsFixed(2)}',
      'Block Storage:   \$${blockStorageMonthlyCost.toStringAsFixed(2)}',
      'NodeBalancer:    \$${nodeBalancerMonthlyCost.toStringAsFixed(2)}',
      'Transfer ovg:    \$${transferOverageMonthlyCost.toStringAsFixed(2)}',
      '                 ──────────',
      'TOTAL / month:   \$${totalMonthlyCost.toStringAsFixed(2)}',
      'TOTAL / year:    \$${totalYearlyCost.toStringAsFixed(2)}',
    ];
    return lines.join('\n');
  }
}

// ---------------------------------------------------------------------------
// Plan catalog (post-2024 pricing, after 20% increase)
// ---------------------------------------------------------------------------

/// All available Linode compute plans relevant for database hosting.
class LinodePlanCatalog {
  LinodePlanCatalog._();

  // -- Shared CPU Plans ----------------------------------------------------

  static const shared1GB = LinodePlan(
    id: 'g6-nanode-1',
    label: 'Nanode 1GB',
    type: LinodePlanType.shared,
    ramMB: 1024,
    vcpus: 1,
    storageMB: 25 * 1024,
    transferTB: 1,
    monthlyPrice: 5,
    hourlyPrice: 0.0075,
  );

  static const shared2GB = LinodePlan(
    id: 'g6-standard-1',
    label: 'Linode 2GB',
    type: LinodePlanType.shared,
    ramMB: 2 * 1024,
    vcpus: 1,
    storageMB: 50 * 1024,
    transferTB: 2,
    monthlyPrice: 12,
    hourlyPrice: 0.018,
  );

  static const shared4GB = LinodePlan(
    id: 'g6-standard-2',
    label: 'Linode 4GB',
    type: LinodePlanType.shared,
    ramMB: 4 * 1024,
    vcpus: 2,
    storageMB: 80 * 1024,
    transferTB: 4,
    monthlyPrice: 24,
    hourlyPrice: 0.036,
  );

  static const shared8GB = LinodePlan(
    id: 'g6-standard-4',
    label: 'Linode 8GB',
    type: LinodePlanType.shared,
    ramMB: 8 * 1024,
    vcpus: 4,
    storageMB: 160 * 1024,
    transferTB: 5,
    monthlyPrice: 48,
    hourlyPrice: 0.072,
  );

  static const shared16GB = LinodePlan(
    id: 'g6-standard-6',
    label: 'Linode 16GB',
    type: LinodePlanType.shared,
    ramMB: 16 * 1024,
    vcpus: 6,
    storageMB: 320 * 1024,
    transferTB: 8,
    monthlyPrice: 96,
    hourlyPrice: 0.144,
  );

  static const shared32GB = LinodePlan(
    id: 'g6-standard-8',
    label: 'Linode 32GB',
    type: LinodePlanType.shared,
    ramMB: 32 * 1024,
    vcpus: 8,
    storageMB: 640 * 1024,
    transferTB: 16,
    monthlyPrice: 192,
    hourlyPrice: 0.288,
  );

  static const shared64GB = LinodePlan(
    id: 'g6-standard-16',
    label: 'Linode 64GB',
    type: LinodePlanType.shared,
    ramMB: 64 * 1024,
    vcpus: 16,
    storageMB: 1280 * 1024,
    transferTB: 20,
    monthlyPrice: 384,
    hourlyPrice: 0.576,
  );

  static const shared96GB = LinodePlan(
    id: 'g6-standard-20',
    label: 'Linode 96GB',
    type: LinodePlanType.shared,
    ramMB: 96 * 1024,
    vcpus: 20,
    storageMB: 1920 * 1024,
    transferTB: 20,
    monthlyPrice: 576,
    hourlyPrice: 0.864,
  );

  static const shared128GB = LinodePlan(
    id: 'g6-standard-24',
    label: 'Linode 128GB',
    type: LinodePlanType.shared,
    ramMB: 128 * 1024,
    vcpus: 24,
    storageMB: 2560 * 1024,
    transferTB: 20,
    monthlyPrice: 768,
    hourlyPrice: 1.152,
  );

  static const shared192GB = LinodePlan(
    id: 'g6-standard-32',
    label: 'Linode 192GB',
    type: LinodePlanType.shared,
    ramMB: 192 * 1024,
    vcpus: 32,
    storageMB: 3840 * 1024,
    transferTB: 20,
    monthlyPrice: 1152,
    hourlyPrice: 1.728,
  );

  // -- Dedicated CPU Plans (G7 — Zen 3) ------------------------------------

  static const dedicated4GB = LinodePlan(
    id: 'g7-dedicated-2',
    label: 'Dedicated 4GB',
    type: LinodePlanType.dedicated,
    ramMB: 4 * 1024,
    vcpus: 2,
    storageMB: 80 * 1024,
    transferTB: 4,
    monthlyPrice: 43,
    hourlyPrice: 0.065,
  );

  static const dedicated8GB = LinodePlan(
    id: 'g7-dedicated-4',
    label: 'Dedicated 8GB',
    type: LinodePlanType.dedicated,
    ramMB: 8 * 1024,
    vcpus: 4,
    storageMB: 160 * 1024,
    transferTB: 5,
    monthlyPrice: 86,
    hourlyPrice: 0.129,
  );

  static const dedicated16GB = LinodePlan(
    id: 'g7-dedicated-8',
    label: 'Dedicated 16GB',
    type: LinodePlanType.dedicated,
    ramMB: 16 * 1024,
    vcpus: 8,
    storageMB: 320 * 1024,
    transferTB: 6,
    monthlyPrice: 173,
    hourlyPrice: 0.259,
  );

  static const dedicated32GB = LinodePlan(
    id: 'g7-dedicated-16',
    label: 'Dedicated 32GB',
    type: LinodePlanType.dedicated,
    ramMB: 32 * 1024,
    vcpus: 16,
    storageMB: 640 * 1024,
    transferTB: 7,
    monthlyPrice: 346,
    hourlyPrice: 0.518,
  );

  static const dedicated64GB = LinodePlan(
    id: 'g7-dedicated-32',
    label: 'Dedicated 64GB',
    type: LinodePlanType.dedicated,
    ramMB: 64 * 1024,
    vcpus: 32,
    storageMB: 1280 * 1024,
    transferTB: 8,
    monthlyPrice: 691,
    hourlyPrice: 1.035,
  );

  // -- High Memory Plans ---------------------------------------------------

  static const highMem24GB = LinodePlan(
    id: 'g6-highmem-1',
    label: 'High Memory 24GB',
    type: LinodePlanType.highMemory,
    ramMB: 24 * 1024,
    vcpus: 2,
    storageMB: 20 * 1024,
    transferTB: 5,
    monthlyPrice: 60,
    hourlyPrice: 0.09,
  );

  static const highMem48GB = LinodePlan(
    id: 'g6-highmem-2',
    label: 'High Memory 48GB',
    type: LinodePlanType.highMemory,
    ramMB: 48 * 1024,
    vcpus: 2,
    storageMB: 40 * 1024,
    transferTB: 6,
    monthlyPrice: 120,
    hourlyPrice: 0.18,
  );

  static const highMem90GB = LinodePlan(
    id: 'g6-highmem-4',
    label: 'High Memory 90GB',
    type: LinodePlanType.highMemory,
    ramMB: 90 * 1024,
    vcpus: 4,
    storageMB: 90 * 1024,
    transferTB: 7,
    monthlyPrice: 240,
    hourlyPrice: 0.36,
  );

  static const highMem150GB = LinodePlan(
    id: 'g6-highmem-8',
    label: 'High Memory 150GB',
    type: LinodePlanType.highMemory,
    ramMB: 150 * 1024,
    vcpus: 8,
    storageMB: 200 * 1024,
    transferTB: 8,
    monthlyPrice: 480,
    hourlyPrice: 0.72,
  );

  static const highMem300GB = LinodePlan(
    id: 'g6-highmem-16',
    label: 'High Memory 300GB',
    type: LinodePlanType.highMemory,
    ramMB: 300 * 1024,
    vcpus: 16,
    storageMB: 340 * 1024,
    transferTB: 9,
    monthlyPrice: 960,
    hourlyPrice: 1.44,
  );

  // -- Collections ---------------------------------------------------------

  static const List<LinodePlan> sharedPlans = [
    shared1GB,
    shared2GB,
    shared4GB,
    shared8GB,
    shared16GB,
    shared32GB,
    shared64GB,
    shared96GB,
    shared128GB,
    shared192GB,
  ];

  static const List<LinodePlan> dedicatedPlans = [
    dedicated4GB,
    dedicated8GB,
    dedicated16GB,
    dedicated32GB,
    dedicated64GB,
  ];

  static const List<LinodePlan> highMemoryPlans = [
    highMem24GB,
    highMem48GB,
    highMem90GB,
    highMem150GB,
    highMem300GB,
  ];

  static List<LinodePlan> get allPlans => [
        ...sharedPlans,
        ...dedicatedPlans,
        ...highMemoryPlans,
      ];

  /// Returns plans that have at least [minRamGB] of RAM.
  static List<LinodePlan> plansWithMinRam(int minRamGB) =>
      allPlans.where((p) => p.ramGB >= minRamGB).toList()
        ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));

  /// Returns plans of a specific [type].
  static List<LinodePlan> plansByType(LinodePlanType type) =>
      allPlans.where((p) => p.type == type).toList();
}

// ---------------------------------------------------------------------------
// Cost calculator
// ---------------------------------------------------------------------------

/// Calculates the total monthly cost of self-hosting a database on Linode.
class LinodeDbCostCalculator {
  LinodeDbCostCalculator._();

  /// Backup pricing as a fraction of the plan's monthly price.
  /// Linode charges roughly 25% of the plan cost for backups.
  static const double _backupPriceRatio = 0.25;

  /// NodeBalancer monthly cost.
  static const double nodeBalancerMonthly = 10.0;

  /// Network transfer overage per GB.
  static const double transferOveragePerGB = 0.005;

  /// Estimates the full monthly cost for self-hosting a database.
  ///
  /// Parameters:
  /// - [plan] — the Linode compute plan to use for each node.
  /// - [topology] — single node, primary+replica, or primary+2 replicas.
  /// - [enableBackups] — whether to enable the Linode Backup service.
  /// - [extraStorageGB] — additional block storage in GB (0 = none).
  /// - [enableNodeBalancer] — adds a NodeBalancer for DB connection routing.
  /// - [estimatedTransferOverageGB] — estimated monthly transfer overage.
  static LinodeCostEstimate estimate({
    required LinodePlan plan,
    HaTopology topology = HaTopology.singleNode,
    bool enableBackups = true,
    int extraStorageGB = 0,
    bool enableNodeBalancer = false,
    int estimatedTransferOverageGB = 0,
  }) {
    final nodeCount = switch (topology) {
      HaTopology.singleNode => 1,
      HaTopology.primaryReplica => 2,
      HaTopology.primaryTwoReplicas => 3,
    };

    final computeCost = plan.monthlyPrice * nodeCount;
    final backupsCost =
        enableBackups ? (plan.monthlyPrice * _backupPriceRatio * nodeCount) : 0.0;
    final storageCost =
        extraStorageGB > 0 ? BlockStorageVolume(sizeGB: extraStorageGB).monthlyCost : 0.0;
    final nodeBalancerCost = enableNodeBalancer ? nodeBalancerMonthly : 0.0;
    final transferCost =
        estimatedTransferOverageGB > 0
            ? estimatedTransferOverageGB * transferOveragePerGB
            : 0.0;

    return LinodeCostEstimate(
      plan: plan,
      topology: topology,
      nodeCount: nodeCount,
      computeMonthlyCost: computeCost,
      backupsMonthlyCost: backupsCost,
      blockStorageMonthlyCost: storageCost,
      nodeBalancerMonthlyCost: nodeBalancerCost,
      transferOverageMonthlyCost: transferCost,
    );
  }

  /// Quick comparison: returns estimates for every plan that has at least
  /// [minRamGB] of RAM, using the given options.
  static List<LinodeCostEstimate> compareAllPlans({
    int minRamGB = 2,
    HaTopology topology = HaTopology.singleNode,
    bool enableBackups = true,
    int extraStorageGB = 0,
    bool enableNodeBalancer = false,
    int estimatedTransferOverageGB = 0,
  }) {
    final plans = LinodePlanCatalog.plansWithMinRam(minRamGB);
    return plans
        .map(
          (p) => estimate(
            plan: p,
            topology: topology,
            enableBackups: enableBackups,
            extraStorageGB: extraStorageGB,
            enableNodeBalancer: enableNodeBalancer,
            estimatedTransferOverageGB: estimatedTransferOverageGB,
          ),
        )
        .toList();
  }

  /// Suggests the cheapest plan that meets minimum requirements.
  static LinodeCostEstimate? recommendCheapest({
    required int minRamGB,
    required int minStorageGB,
    HaTopology topology = HaTopology.singleNode,
    bool enableBackups = true,
    bool enableNodeBalancer = false,
    LinodePlanType? preferredType,
  }) {
    var candidates = LinodePlanCatalog.allPlans
        .where((p) => p.ramGB >= minRamGB && p.storageGB >= minStorageGB);

    if (preferredType != null) {
      final filtered = candidates.where((p) => p.type == preferredType);
      if (filtered.isNotEmpty) candidates = filtered;
    }

    final sorted = candidates.toList()
      ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));

    if (sorted.isEmpty) return null;

    return estimate(
      plan: sorted.first,
      topology: topology,
      enableBackups: enableBackups,
      enableNodeBalancer: enableNodeBalancer,
    );
  }
}
