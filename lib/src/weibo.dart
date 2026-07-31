import 'package:weibo_kit/weibo_kit.dart';

/// 旧版应用入口。
@Deprecated('Use WeiboKit instead.')
class Weibo {
  const Weibo._();

  static WeiboKitPlatform get instance => WeiboKit.instance;
}
