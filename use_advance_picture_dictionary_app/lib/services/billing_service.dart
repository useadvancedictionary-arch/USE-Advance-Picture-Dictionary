import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_auth_service.dart';

/// Manages Google Play In-App Purchases and Pro entitlement state.
class BillingService extends ChangeNotifier {
  static final BillingService instance = BillingService._internal();
  BillingService._internal();

  /// Product ID configured in Google Play Console
  static const String proLifetimeProductId = 'use_dictionary_pro_lifetime';
  static const String _prefKeyProUnlocked = 'sp_is_pro_unlocked';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool _isProUnlocked = false;
  bool _isLoading = true;
  ProductDetails? _proProduct;
  String? _errorMessage;

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  ProductDetails? get proProduct => _proProduct;
  String? get errorMessage => _errorMessage;

  /// Returns true if user has unlocked Pro OR if Admin is authenticated.
  bool get isProUnlocked {
    // If Admin panel is unlocked, grant full Pro access automatically
    if (AdminAuthService.instance.isAdminUnlocked) {
      return true;
    }
    return _isProUnlocked;
  }

  /// Initialize billing service, restore cached state, query products and listen to stream
  Future<void> init() async {
    // 1. Load locally cached entitlement
    try {
      final prefs = await SharedPreferences.getInstance();
      _isProUnlocked = prefs.getBool(_prefKeyProUnlocked) ?? false;
    } catch (e) {
      debugPrint('BillingService: Error reading shared prefs: $e');
    }

    // 2. Set up purchase listener
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('BillingService: Purchase stream error: $error');
      },
    );

    // 3. Check Google Play availability
    try {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        await _queryProductDetails();
      }
    } catch (e) {
      debugPrint('BillingService: isAvailable check failed (normal on desktop): $e');
      _isAvailable = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Query Product Details from Google Play
  Future<void> _queryProductDetails() async {
    try {
      final response = await _iap.queryProductDetails({proLifetimeProductId});
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('BillingService: Products not found in Play Console: ${response.notFoundIDs}');
      }
      if (response.productDetails.isNotEmpty) {
        _proProduct = response.productDetails.firstWhere(
          (p) => p.id == proLifetimeProductId,
          orElse: () => response.productDetails.first,
        );
        debugPrint('BillingService: Found Pro Product: ${_proProduct?.title} (${_proProduct?.price})');
      }
    } catch (e) {
      debugPrint('BillingService: Error querying product details: $e');
    }
  }

  /// Trigger purchase flow for Pro Lifetime
  Future<bool> buyProLifetime() async {
    if (!_isAvailable) {
      _errorMessage = 'Google Play Billing is unavailable on this device.';
      notifyListeners();
      return false;
    }

    if (_proProduct == null) {
      // Re-try query once
      await _queryProductDetails();
      if (_proProduct == null) {
        _errorMessage = 'Pro item not yet registered on Google Play Store.';
        notifyListeners();
        return false;
      }
    }

    final purchaseParam = PurchaseParam(productDetails: _proProduct!);
    try {
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return success;
    } catch (e) {
      _errorMessage = 'Purchase initiation error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Restore previous purchases (for users changing phones or reinstalling)
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('BillingService: restorePurchases error: $e');
    }
  }

  /// Handle incoming purchase status updates from Google Play
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.productID == proLifetimeProductId) {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            final valid = await _verifyPurchase(purchase);
            if (valid) {
              await _grantProEntitlement();
            }
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            break;
          case PurchaseStatus.error:
            _errorMessage = purchase.error?.message ?? 'Purchase failed';
            notifyListeners();
            break;
          case PurchaseStatus.pending:
            // Purchase is waiting for bank/user action
            break;
          case PurchaseStatus.canceled:
            debugPrint('BillingService: User canceled purchase');
            break;
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // Google Play client-side verification; receipt token exists
    return purchase.verificationData.serverVerificationData.isNotEmpty;
  }

  Future<void> _grantProEntitlement() async {
    _isProUnlocked = true;
    _errorMessage = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyProUnlocked, true);
    } catch (e) {
      debugPrint('BillingService: Error saving entitlement: $e');
    }
    notifyListeners();
  }

  /// For testing/development: manually toggle Pro status
  Future<void> debugSetPro(bool unlocked) async {
    _isProUnlocked = unlocked;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyProUnlocked, unlocked);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

