import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// ストア課金（RevenueCat 経由で Google Play / App Store）。
///
/// レシートの検証と月額の期限管理は RevenueCat のサーバ側が持つ。
/// アプリはその結果（entitlement が有効かどうか）を受け取るだけにしている。
class BillingService {
  /// RevenueCat ダッシュボードで作る entitlement の識別子。
  /// この entitlement が有効ならプレミアム機能を開放する。
  static const entitlementId = 'spin_counter_pro';

  /// ストアに登録する商品ID。RevenueCat 側でこの2つを [entitlementId] に紐づける。
  static const lifetimeId = 'lifetime';
  static const monthlyId = 'monthly';

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

  /// Test Store のキー。購入はすべて擬似で、ストアにも請求にも届かない。
  /// リリースビルドでこれを使うと課金が素通りしてしまうので、
  /// --dart-define を渡していないデバッグビルドに限って使う。
  static const testStoreApiKey = 'test_cZShVhfNKqyvZlkFwXTtMahjjuS';

  /// 課金が使える状態か。キー未設定や初期化失敗のときは false。
  bool available = false;

  /// 表示できるプラン。取得できなかった商品は含まれない。
  final Map<String, Package> packages = {};

  /// ダッシュボードで current に設定した offering。ペイウォールの表示に渡す。
  Offering? offering;

  /// 直近に受け取った購入者情報。契約状態の表示に使う。
  CustomerInfo? customerInfo;

  /// entitlement の状態が変わったとき。'lifetime' | 'monthly' | 'none' を渡す。
  void Function(String premiumType)? onEntitlementChanged;

  /// 購入手続き中かどうか。ボタンの二度押し防止に使う。
  void Function(bool pending)? onPending;

  /// ユーザーに見せるエラー。購入のキャンセルでは呼ばない。
  void Function(String message)? onError;

  static String get _apiKey {
    final key = defaultTargetPlatform == TargetPlatform.iOS
        ? iosApiKey
        : androidApiKey;
    if (key.isNotEmpty) return key;
    // 本番キーを渡さずにビルドしたとき、開発中だけ Test Store で動かす。
    return kDebugMode ? testStoreApiKey : '';
  }

  /// 擬似課金（Test Store）で動いているか。開発用の表示に使う。
  bool get isTestStore => _apiKey.startsWith('test_');

  Future<void> init() async {
    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
      // キーを渡さずにリリースビルドした場合。課金UIは「準備中」のまま出す。
      return;
    }
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(apiKey));

      // 再インストールや機種変更のあとも、ログイン中のストアアカウントから
      // 自動で購入状態が復元される。
      Purchases.addCustomerInfoUpdateListener(_applyCustomerInfo);
      _applyCustomerInfo(await Purchases.getCustomerInfo());

      await _loadOfferings();
      available = true;
    } on PlatformException catch (e) {
      onError?.call('ストアに接続できませんでした: ${e.message ?? ''}');
    }
  }

  Future<void> _loadOfferings() async {
    final offerings = await Purchases.getOfferings();
    offering = offerings.current;
    packages
      ..clear()
      ..addEntries(
        (offering?.availablePackages ?? const <Package>[]).map(
          (package) => MapEntry(package.storeProduct.identifier, package),
        ),
      );
  }

  /// ストアから取得した価格表示。取れていなければ null。
  /// 金額をアプリ側にハードコードすると、実際の販売価格や通貨とずれる。
  String? priceOf(String productId) =>
      packages[productId]?.storeProduct.priceString;

  /// RevenueCat ダッシュボードで作ったペイウォールを出す。
  ///
  /// entitlement を既に持っている人には出さない（[PaywallResult.notPresented]）。
  /// 表示できなかったときは null を返すので、呼び出し側でアプリ内の
  /// シートにフォールバックする。
  Future<PaywallResult?> presentPaywall() async {
    if (!available) return null;
    onPending?.call(true);
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(
        entitlementId,
        offering: offering,
        displayCloseButton: true,
      );
      if (result == PaywallResult.purchased ||
          result == PaywallResult.restored) {
        // リスナーにも届くが、閉じた直後の表示を確実に合わせる。
        _applyCustomerInfo(await Purchases.getCustomerInfo());
      }
      return result;
    } on PlatformException catch (e) {
      debugPrint('presentPaywall failed: ${e.message}');
      return null;
    } on MissingPluginException {
      // ペイウォールに対応していないプラットフォーム（テストや web）。
      return null;
    } finally {
      onPending?.call(false);
    }
  }

  /// 解約・返金・購入の復元をまとめた RevenueCat の Customer Center を出す。
  /// 表示できなければ false を返す。
  Future<bool> presentCustomerCenter() async {
    if (!available) return false;
    try {
      await RevenueCatUI.presentCustomerCenter(
        onRestoreCompleted: _applyCustomerInfo,
        onRestoreFailed: (error) =>
            onError?.call('購入の復元に失敗しました: ${error.message}'),
        onManagementOptionSelected: (optionId, url) =>
            debugPrint('customer center: $optionId ${url ?? ''}'),
      );
      // 解約や返金のあとは entitlement が変わっている可能性がある。
      await refresh();
      return true;
    } on PlatformException catch (e) {
      onError?.call('契約の管理画面を開けませんでした: ${e.message ?? ''}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

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

  /// 契約状態を取り直す。キャッシュを捨てるので、解約直後などに使う。
  Future<void> refresh() async {
    if (!available) return;
    try {
      await Purchases.invalidateCustomerInfoCache();
      _applyCustomerInfo(await Purchases.getCustomerInfo());
      await _loadOfferings();
    } on PlatformException catch (e) {
      debugPrint('refresh failed: ${e.message}');
    }
  }

  /// 月額プランの次回更新日。買い切りや未課金なら null。
  DateTime? get renewsAt {
    final expiration =
        customerInfo?.entitlements.active[entitlementId]?.expirationDate;
    return expiration == null ? null : DateTime.tryParse(expiration)?.toLocal();
  }

  /// 解約済みで期限切れ待ちなら false。買い切りは常に true 扱いにしない。
  bool get willRenew =>
      customerInfo?.entitlements.active[entitlementId]?.willRenew ?? false;

  /// entitlement の有無から、アプリが持つ課金種別に読み替える。
  void _applyCustomerInfo(CustomerInfo info) {
    customerInfo = info;
    final entitlement = info.entitlements.active[entitlementId];
    if (entitlement == null) {
      onEntitlementChanged?.call('none');
      return;
    }
    // Android の定期購入は 'monthly:base-plan' の形で返ることがある。
    onEntitlementChanged?.call(
      entitlement.productIdentifier.startsWith(monthlyId)
          ? 'monthly'
          : 'lifetime',
    );
  }
}
