import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../data/services/subscription_service.dart';

/// Tier data model for the paywall cards
class _TierInfo {
  final String id;
  final String name;
  final String? price; // null = "Contact Us"
  final String? oldPrice; // shown as strikethrough
  final String staffLimit;
  final String eventsLimit;
  final bool aiExtraction;
  final String aiMessages; // e.g. "30/mo", "Unlimited"
  final String aiContext; // e.g. "15 events", "50 events"
  final bool analytics;
  final bool customBranding; // team logo
  final String bulkCreate; // e.g. "3 events", "30 events"
  final bool isMostPopular;

  const _TierInfo({
    required this.id,
    required this.name,
    this.price,
    this.oldPrice,
    required this.staffLimit,
    required this.eventsLimit,
    required this.aiExtraction,
    required this.aiMessages,
    required this.aiContext,
    required this.analytics,
    required this.customBranding,
    required this.bulkCreate,
    this.isMostPopular = false,
  });
}

const _tiers = [
  _TierInfo(
    id: 'lite',
    name: 'Lite',
    price: '14.99',
    staffLimit: '10 staff',
    eventsLimit: 'Unlimited',
    aiExtraction: true,
    aiMessages: '30 AI chats/mo',
    aiContext: '15 events AI context',
    analytics: false,
    customBranding: false,
    bulkCreate: 'Bulk create up to 3 events',
  ),
  _TierInfo(
    id: 'starter',
    name: 'Starter',
    price: '39.99',
    oldPrice: '49',
    staffLimit: '25 staff',
    eventsLimit: 'Unlimited',
    aiExtraction: true,
    aiMessages: '50 AI chats/mo',
    aiContext: '20 events AI context',
    analytics: false,
    customBranding: true,
    bulkCreate: 'Bulk create up to 5 events',
  ),
  _TierInfo(
    id: 'pro',
    name: 'Pro',
    price: '76.99',
    oldPrice: '99',
    staffLimit: '60 staff',
    eventsLimit: 'Unlimited',
    aiExtraction: true,
    aiMessages: 'Unlimited AI chats',
    aiContext: '50 events AI context',
    analytics: true,
    customBranding: true,
    bulkCreate: 'Bulk create up to 15 events',
    isMostPopular: true,
  ),
  _TierInfo(
    id: 'business',
    name: 'Business',
    price: '209.99',
    oldPrice: '249',
    staffLimit: '150 staff',
    eventsLimit: 'Unlimited',
    aiExtraction: true,
    aiMessages: 'Unlimited AI chats',
    aiContext: '50 events AI context',
    analytics: true,
    customBranding: true,
    bulkCreate: 'Bulk create up to 30 events',
  ),
  _TierInfo(
    id: 'enterprise',
    name: 'Enterprise',
    price: null,
    staffLimit: 'Unlimited',
    eventsLimit: 'Unlimited',
    aiExtraction: true,
    aiMessages: 'Unlimited AI chats',
    aiContext: '50 events AI context',
    analytics: true,
    customBranding: true,
    bulkCreate: 'Bulk create up to 30 events',
  ),
];

/// Subscription Paywall Page for Manager App
/// Shows multi-tier pricing cards and handles purchase flow
class SubscriptionPaywallPage extends StatefulWidget {
  const SubscriptionPaywallPage({super.key});

  @override
  State<SubscriptionPaywallPage> createState() => _SubscriptionPaywallPageState();
}

class _SubscriptionPaywallPageState extends State<SubscriptionPaywallPage> {
  final _subscriptionService = GetIt.instance<SubscriptionService>();
  final _pageController = PageController(viewportFraction: 0.85, initialPage: 2);
  String? _purchasingTier;
  bool _restoring = false;
  int _currentPage = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase(String tierId) async {
    if (tierId == 'enterprise') {
      // TODO: Open contact/email for enterprise inquiries
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact us at hello@nexaapp.com for Enterprise pricing.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _purchasingTier = tierId);

    try {
      final success = await _subscriptionService.purchaseSubscription(tierId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to Nexa ${tierId[0].toUpperCase()}${tierId.substring(1)}! Features unlocked.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase cancelled or failed. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _purchasingTier = null);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _restoring = true);

    try {
      final success = await _subscriptionService.restorePurchases();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription restored successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active subscription found to restore.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    'Scale Your Business',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick the plan that fits your team',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Page indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_tiers.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.grey[700] : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // Tier cards PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _tiers.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final tier = _tiers[index];
                  return _buildTierCard(tier, theme, isDark);
                },
              ),
            ),

            const SizedBox(height: 12),

            // Restore purchases
            TextButton(
              onPressed: _purchasingTier != null || _restoring ? null : _handleRestore,
              child: _restoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Restore Purchase',
                      style: TextStyle(fontSize: 15),
                    ),
            ),

            // Free tier info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  'Free plan: 5 staff, 3 events/month, no AI extraction',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Terms
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Text(
                'Subscription automatically renews unless cancelled at least 24 hours before the current period ends.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(_TierInfo tier, ThemeData theme, bool isDark) {
    final isEnterprise = tier.price == null;
    final isPurchasing = _purchasingTier == tier.id;
    final isDisabled = _purchasingTier != null || _restoring;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Card(
        elevation: tier.isMostPopular ? 8 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: tier.isMostPopular
              ? BorderSide(color: theme.colorScheme.primary, width: 2.5)
              : BorderSide.none,
        ),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Most Popular badge
              if (tier.isMostPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Most Popular',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              if (tier.isMostPopular) const SizedBox(height: 12),

              // Tier name
              Text(
                tier.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              // Price
              if (!isEnterprise) ...[
                if (tier.oldPrice != null)
                  Text(
                    '\$${tier.oldPrice}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.red.withOpacity(0.7),
                      decorationThickness: 2,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      tier.price!,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        height: 1,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Text(
                  '/month',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Custom',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Contact us for pricing',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Staff limit highlight
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      tier.staffLimit,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (!isEnterprise && tier.id != 'free')
                      Text(
                        '+\$2/extra staff/mo',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Feature checklist
              _featureRow('${tier.eventsLimit} events/mo', true, theme, isDark),
              _featureRow('AI extraction', tier.aiExtraction, theme, isDark),
              _featureRow(tier.aiMessages, true, theme, isDark),
              _featureRow(tier.aiContext, true, theme, isDark),
              _featureRow(tier.bulkCreate, true, theme, isDark),
              _featureRow('Analytics & reports', tier.analytics, theme, isDark),
              _featureRow('Your logo for your team', tier.customBranding, theme, isDark),

              const SizedBox(height: 20),

              // CTA button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isDisabled ? null : () => _handlePurchase(tier.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tier.isMostPopular
                        ? theme.colorScheme.primary
                        : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[200]),
                    foregroundColor: tier.isMostPopular
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: tier.isMostPopular ? 4 : 1,
                  ),
                  child: isPurchasing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEnterprise ? 'Contact Us' : 'Get ${tier.name}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(String label, bool included, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle : Icons.cancel_outlined,
            size: 20,
            color: included
                ? theme.colorScheme.primary
                : (isDark ? Colors.grey[700] : Colors.grey[400]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: included
                    ? (isDark ? Colors.grey[200] : Colors.black87)
                    : (isDark ? Colors.grey[600] : Colors.grey[400]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
