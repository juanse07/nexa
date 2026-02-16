/// Quick CLI script to generate a Linode self-hosted DB cost report.
///
/// Run with:
///   dart run bin/linode_cost_report.dart
library;

import 'package:nexa/core/utils/linode_db_cost_calculator.dart';

void main() {
  _printHeader('LINODE SELF-HOSTED DATABASE COST REPORT');
  _printHeader('For: Nexa (MongoDB)');
  print('');

  // ── Scenario 1: Dev / Staging (cheapest viable) ──────────────────────
  _printHeader('SCENARIO 1 — Dev / Staging (Single Node, Shared CPU)');
  final dev = LinodeDbCostCalculator.estimate(
    plan: LinodePlanCatalog.shared2GB,
    topology: HaTopology.singleNode,
    enableBackups: true,
    extraStorageGB: 0,
  );
  print(dev);
  print('');

  // ── Scenario 2: Small Production (Dedicated, Primary + Replica) ──────
  _printHeader('SCENARIO 2 — Small Production (Dedicated 4GB, Primary+Replica)');
  final smallProd = LinodeDbCostCalculator.estimate(
    plan: LinodePlanCatalog.dedicated4GB,
    topology: HaTopology.primaryReplica,
    enableBackups: true,
    extraStorageGB: 50,
    enableNodeBalancer: true,
  );
  print(smallProd);
  print('');

  // ── Scenario 3: Production HA (Dedicated, 3-node replica set) ────────
  _printHeader('SCENARIO 3 — Production HA (Dedicated 8GB, 3-Node Replica Set)');
  final prodHa = LinodeDbCostCalculator.estimate(
    plan: LinodePlanCatalog.dedicated8GB,
    topology: HaTopology.primaryTwoReplicas,
    enableBackups: true,
    extraStorageGB: 100,
    enableNodeBalancer: true,
  );
  print(prodHa);
  print('');

  // ── Scenario 4: High Memory for large dataset ────────────────────────
  _printHeader('SCENARIO 4 — Large Dataset (High Memory 24GB, Single Node)');
  final highMem = LinodeDbCostCalculator.estimate(
    plan: LinodePlanCatalog.highMem24GB,
    topology: HaTopology.singleNode,
    enableBackups: true,
    extraStorageGB: 200,
  );
  print(highMem);
  print('');

  // ── Comparison Table ─────────────────────────────────────────────────
  _printHeader('COMPARISON: All Shared & Dedicated Plans (Single Node + Backups)');
  final all = LinodeDbCostCalculator.compareAllPlans(
    minRamGB: 2,
    topology: HaTopology.singleNode,
    enableBackups: true,
  );
  _printComparisonTable(all);
  print('');

  // ── Recommendation ───────────────────────────────────────────────────
  _printHeader('RECOMMENDATION — Cheapest plan with ≥4GB RAM, ≥80GB disk');
  final rec = LinodeDbCostCalculator.recommendCheapest(
    minRamGB: 4,
    minStorageGB: 80,
    topology: HaTopology.primaryReplica,
    enableBackups: true,
    enableNodeBalancer: true,
  );
  if (rec != null) {
    print(rec);
  } else {
    print('No plan found matching those requirements.');
  }

  print('');
  _printHeader('NOTES');
  print('• Prices are post-2024 pricing (20% increase applied to most plans).');
  print('• Block storage: \$0.10/GB/month.');
  print('• Transfer overage: \$0.005/GB (inbound is free).');
  print('• NodeBalancer: \$10/mo flat.');
  print('• Backups: ~25% of compute cost.');
  print('• For production MongoDB: Dedicated CPU + HA replica set recommended.');
  print('• Compare with MongoDB Atlas M10 (\$57/mo) / M20 (\$175/mo) / M30 (\$540/mo).');
  print('');
  print('Source: https://www.linode.com/pricing/');
}

void _printHeader(String title) {
  final bar = '─' * 60;
  print(bar);
  print(' $title');
  print(bar);
}

void _printComparisonTable(List<LinodeCostEstimate> estimates) {
  print('');
  print(
    '${'Plan'.padRight(24)}'
    '${'Type'.padRight(12)}'
    '${'RAM'.padRight(8)}'
    '${'vCPU'.padRight(7)}'
    '${'Disk'.padRight(9)}'
    '${'Mo. Cost'.padRight(10)}',
  );
  print('${'─' * 24}${'─' * 12}${'─' * 8}${'─' * 7}${'─' * 9}${'─' * 10}');
  for (final e in estimates) {
    print(
      '${e.plan.label.padRight(24)}'
      '${e.plan.type.name.padRight(12)}'
      '${'${e.plan.ramGB}GB'.padRight(8)}'
      '${e.plan.vcpus.toString().padRight(7)}'
      '${'${e.plan.storageGB}GB'.padRight(9)}'
      '\$${e.totalMonthlyCost.toStringAsFixed(2).padRight(10)}',
    );
  }
}
