import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// ストア課金（RevenueCat 経由で Google Play / App Store）。
///
/// レシートの検証と月額の期限管理は RevenueCat のサーバ側が持つ。
/// アプリはその結果（entitlement が有効かどうか）を受け取るだけにしている。
class BillingService {
  /// RevenueCat ダッシュボードで作る entitlement の識別子。
  static const entitlementId = 'premium';

  /// ストアに登録する商品ID。RevenueCat 側でこの2つを [entitlementId] に紐づける。
  static const onetimeId = 'premium_onetime';
  static const monthlyId = 'premium_monthly';

  /// 公開SDKキー。クライアントに埋め込む前提の公開鍵なので、
  /// リポジトリに置いて問題ない（Secret key は絶対に置かないこと）。
  /// ダッシュボードの Project settings → API keys から取得する。
  static const androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: '',
  );
  static const iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: '',
  );

  /// 課金が使える状態か。キー未設定や初期化失敗のときは false。
  bool available = false;

  /// 表示できるプラン。取得できなかった商品は含まれない。
  final Map<String, Package> packages = {};

  /// entitlement の状態が変わったとき。'onetime' | 'monthly' | 'none' を渡す。
  void Function(String premiumType)? onEntitlementChanged;

  /// 購入手続き中かどうか。ボタンの二度押し防止に使う。
  void Function(bool pending)? onPending;

  /// ユーザーに見せるエラー。購入のキャンセルでは呼ばない。
  void Function(String message)? onError;

  static String get _apiKey =>
      defaultTargetPlatform == TargetPlatform.iOS ? iosApiKey : androidApiKey;

  Future<void> init() async {
    if (_apiKey.isEmpty) {
      // キーを渡さずにビルドした場合。課金UIは「準備中」のまま出す。
      return;
    }
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(_apiKey));

      // 再インストールや機種変更のあとも、ログイン中のストアアカウントから
      // 自動で購入状態が復元される。
      Purchases.addCustomerInfoUpdateListener(_applyCustomerInfo);
      _applyCustomerInfo(await Purchases.getCustomerInfo());

      final offerings = await Purchases.getOfferings();
      for (final package in offerings.current?.availablePackages ?? const []) {
        packages[package.storeProduct.identifier] = package;
      }
      available = true;
    } on PlatformException catch (e) {
      onError?.call('ストアに接続できませんでした: ${e.message ?? ''}');
    }
  }

  /// ストアから取得した価格表示。取れていなければ null。
  /// 金額をアプリ側にハードコードすると、実際の販売価格や通貨とずれる。
  String? priceOf(String productId) =>
      packages[productId]?.storeProduct.priceString;

  Future<void> buy(String productId) async {
    final package = packages[productId];
    if (package == null) {
      onError?.call('この商品は現在購入できません。');
      return;
    }
    onPending?.call(true);
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _applyCustomerInfo(result.customerInfo);
    } on PlatformException catch (e) {
      // ユーザーが自分でやめた場合はエラー扱いにしない。
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        onError?.call('購入できませんでした: ${e.message ?? ''}');
      }
    } finally {
      onPending?.call(false);
    }
  }

  Future<void> restore() async {
    if (!available) {
      onError?.call('ストアに接続できていません。');
      return;
    }
    onPending?.call(true);
    try {
      _applyCustomerInfo(await Purchases.restorePurchases());
    } on PlatformException catch (e) {
      onError?.call('購入の復元に失敗しました: ${e.message ?? ''}');
    } finally {
      onPending?.call(false);
    }
  }

  /// entitlement の有無から、アプリが持つ課金種別に読み替える。
  void _applyCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.active[entitlementId];
    if (entitlement == null) {
      onEntitlementChanged?.call('none');
      return;
    }
    onEntitlementChanged?.call(
      entitlement.productIdentifier.startsWith(monthlyId)
          ? 'monthly'
          : 'onetime',
    );
  }
}
