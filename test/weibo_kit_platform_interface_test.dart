import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:weibo_kit/weibo_kit.dart';

class _FakeWeiboKitPlatform extends WeiboKitPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<bool> isInstalled() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WeiboKit exposes the configured platform implementation', () async {
    final WeiboKitPlatform original = WeiboKitPlatform.instance;
    final _FakeWeiboKitPlatform fake = _FakeWeiboKitPlatform();
    addTearDown(() => WeiboKitPlatform.instance = original);

    WeiboKitPlatform.instance = fake;

    expect(WeiboKit.instance, same(fake));
    expect(await WeiboKit.instance.isInstalled(), isTrue);
  });
}
