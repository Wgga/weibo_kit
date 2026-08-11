# weibo_kit

[![Pub Package](https://img.shields.io/pub/v/weibo_kit.svg)](https://pub.dev/packages/weibo_kit)
[![License](https://img.shields.io/github/license/Wgga/weibo_kit)](https://github.com/Wgga/weibo_kit/blob/main/LICENSE)

微博 OpenSDK 的 Flutter 插件，支持 Android、iOS 和 HarmonyOS。

## 功能

| 功能 | Android | iOS | HarmonyOS |
| --- | :---: | :---: | :---: |
| 授权登录 | 支持 | 支持 | 支持 |
| 文字分享 | 支持 | 支持 | 支持 |
| 单图/多图分享 | 支持 | 支持 | 支持 |
| 视频分享 | 支持 | 支持 | 支持，需封面 URI |
| 网页分享 | 支持 | 支持 | 不支持 |
| 检测微博客户端 | 支持 | 支持 | 支持 |

微博官方 HarmonyOS SDK 当前不提供网页分享。在 HarmonyOS 调用 `shareWebpage`
会抛出 `PlatformException(code: 'unsupported')`；图片分享必须传 `imageUri`，视频
分享必须传 `videoCoverUri`。

## 环境要求

- Dart `>=3.7.0 <4.0.0`
- Flutter `>=3.29.0`
- Android API 24 或更高、Java 17
- iOS 13.0 或更高
- HarmonyOS API 12 或更高

当前原生依赖：

| 平台 | SDK |
| --- | --- |
| Android | `io.github.sinaweibosdk:core:13.10.8-opt1` |
| iOS | `Weibo_SDK ~> 3.3.5` |
| HarmonyOS | 官方 `core.har 25.4.0` |

微博 Android SDK 的上游版本是 13.10.8，其 Maven Central 制品版本名为
`13.10.8-opt1`。

## 安装

```yaml
dependencies:
  weibo_kit: ^1.0.2
```

## 宿主配置

插件提供与 `alipay_kit`、`wechat_kit` 一致的幂等 setup 命令：

```shell
dart run weibo_kit:setup \
  --app-key <your-app-key> \
  --universal-link https://example.com/weibo/
```

默认处理 Android、iOS 和 HarmonyOS。工具会：

- 检查 Android 配置由插件 Manifest 和微博 SDK 自动合并；
- 为 iOS 配置 `wb<appKey>` URL Scheme、查询白名单和 Associated Domains；
- 为 HarmonyOS 配置 `sinaweibo` 查询 Scheme；
- 为 HarmonyOS 官方 Bytecode HAR 启用 `useNormalizedOHMUrl`。

可通过 `--platforms android,ios,ohos` 选择平台，通过 `--dry-run` 预览，或通过
`--check` 在 CI 中检查。非标准目录可使用 `--ios-info-plist`、
`--ios-entitlements`、`--ohos-module` 和 `--ohos-build-profile` 指定。

执行后仍需在微博开放平台核对 Android 包名/签名、iOS Bundle ID/Universal Link，
以及 HarmonyOS `bundleName` 和签名。微博开放平台创建应用时需选择 Android 应用，
再登记 HarmonyOS 包名及签名。

## 使用

```dart
import 'package:weibo_kit/weibo_kit.dart';

await WeiboKit.instance.registerApp(
  appKey: 'your-app-key',
  universalLink: 'https://example.com/weibo/',
  scope: const <String>[WeiboScope.ALL],
);

WeiboKit.instance.respStream().listen((BaseResp response) {
  // Handle AuthResp or ShareMsgResp.
});

await WeiboKit.instance.auth(
  appKey: 'your-app-key',
  scope: const <String>[WeiboScope.ALL],
);

await WeiboKit.instance.shareText(text: 'Hello Weibo');
```

HarmonyOS 视频分享需要同时提供视频和封面文件 URI：

```dart
await WeiboKit.instance.shareVideo(
  videoUri: Uri.file('/path/to/video.mp4'),
  videoCoverUri: Uri.file('/path/to/cover.jpg'),
);
```

完整调用方式见 [example/lib/main.dart](example/lib/main.dart)。

## HarmonyOS SDK

官方 HarmonyOS SDK 以 Bytecode HAR 发布，未发布到 OHPM。插件内置
`ohos/libs/core.har`，宿主无需另行下载。`@ohos/flutter_ohos` 由 OpenHarmony
Flutter SDK 在构建时注入，不需要复制或提交 `flutter.har`。

SDK 来源、版本、许可证和校验值见 [ohos/libs/README.md](ohos/libs/README.md)。

## 示例工程

`example/` 是插件的真实宿主工程，用于验证 Android Manifest/Gradle、iOS
CocoaPods/Scene 生命周期，以及 HarmonyOS HAR/EntryAbility 和微博回调。

运行示例前，将 [example/lib/main.dart](example/lib/main.dart) 中的 App Key、
Universal Link 和分享文件替换为已在微博开放平台登记的测试配置。

## 测试

```shell
flutter analyze
flutter test

cd example/android
./gradlew :weibo_kit:testDebugUnitTest

cd ../
flutter build hap --debug
```

HarmonyOS HAP 打包前需在 DevEco Studio 中为 `example/ohos` 配置调试签名。

## 官方资料

- [微博 SDK](https://open.weibo.com/wiki/SDK)
- [微博 Android SDK](https://github.com/sinaweibosdk/weibo_android_sdk)
- [微博 iOS SDK](https://github.com/sinaweibosdk/weibo_ios_sdk)
- [微博开放平台](https://open.weibo.com/)

## License

插件源码使用 MIT License。内置微博 HarmonyOS SDK 的许可证信息见
[ohos/libs/README.md](ohos/libs/README.md)。
