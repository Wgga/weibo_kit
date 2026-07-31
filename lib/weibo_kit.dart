import 'src/weibo_kit_platform_interface.dart';

export 'src/model/resp.dart';
export 'src/weibo.dart';
export 'src/weibo_constant.dart';
export 'src/weibo_kit_platform_interface.dart';

/// 微博 SDK 的应用层入口。
abstract final class WeiboKit {
  /// 当前平台实现。
  static WeiboKitPlatform get instance => WeiboKitPlatform.instance;
}
