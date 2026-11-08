import 'package:flutter/material.dart';
import '../services/billing_service.dart';

/// Bottom sheet dialog prompting the user to upgrade to Pro Lifetime.
class ProPaywallSheet extends StatefulWidget {
  final String? triggeredWord;

  const ProPaywallSheet({super.key, this.triggeredWord});

  static Future<bool?> show(BuildContext context, {String? triggeredWord}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProPaywallSheet(triggeredWord: triggeredWord),
    );
  }

  @override
  State<ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends State<ProPaywallSheet> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final proProduct = BillingService.instance.proProduct;
    final priceString = proProduct?.price ?? '\$4.99';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Crown Icon Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB703), Color(0xFFFB8500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFB8500).withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 16),

          Text(
            widget.triggeredWord != null
                ? 'Unlock "${widget.triggeredWord}" & All 15,000+ Words'
                : 'Unlock USE Advance Picture Dictionary Pro',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get lifetime unrestricted access to the complete visual vocabulary library.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Features List
          _buildFeatureRow(Icons.all_inclusive_rounded, '15,916+ High-Definition Picture Cards', 'Complete access to every vocabulary word, idiom & phrase'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.block_rounded, '100% Ad-Free Experience', 'Zero interruptions, clean and focused learning'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.wifi_off_rounded, 'Full Offline Learning', 'Study anywhere, anytime without an internet connection'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.devices_rounded, 'Lifetime Access & Multi-Device Sync', 'One-time purchase, yours forever across all your Android devices'),

          const SizedBox(height: 28),

          // Purchase CTA Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handlePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0D1B2A),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0D1B2A)),
                    )
                  : Text(
                      'Upgrade to Pro Lifetime ($priceString)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Restore Purchases & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later', style: TextStyle(color: Colors.white54)),
              ),
              TextButton.icon(
                onPressed: () async {
                  await BillingService.instance.restorePurchases();
                  if (mounted && BillingService.instance.isProUnlocked) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.restore_rounded, size: 16, color: Colors.white70),
                label: const Text('Restore Purchases', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF00E5FF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isProcessing = true);
    final success = await BillingService.instance.buyProLifetime();
    if (mounted) {
      setState(() => _isProcessing = false);
      if (BillingService.instance.isProUnlocked) {
        Navigator.pop(context, true);
      } else if (!success && BillingService.instance.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(BillingService.instance.errorMessage!),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }
}
