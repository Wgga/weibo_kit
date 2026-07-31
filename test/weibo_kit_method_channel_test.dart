import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weibo_kit/weibo_kit_platform_interface.dart';

const MethodChannel _channel = MethodChannel('wgga.github.io/weibo_kit');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelWeiboKit platform;
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
          calls.add(call);
          return switch (call.method) {
            'isInstalled' => true,
            'isSupportMultipleImage' => false,
            _ => null,
          };
        });
    platform = MethodChannelWeiboKit();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('registerApp sends the documented arguments', () async {
    await platform.registerApp(
      appKey: '123456',
      universalLink: 'https://example.com/weibo/',
      scope: <String>[WeiboScope.ALL],
    );

    expect(calls.single.method, 'registerApp');
    expect(calls.single.arguments, <String, Object?>{
      'appKey': '123456',
      'universalLink': 'https://example.com/weibo/',
      'scope': WeiboScope.ALL,
      'redirectUrl': WeiboRegister.DEFAULT_REDIRECTURL,
    });
  });

  test('shareWebpage sends a stable method-channel contract', () async {
    final Uint8List thumbData = Uint8List.fromList(<int>[1, 2, 3]);
    await platform.shareWebpage(
      title: 'title',
      description: 'description',
      thumbData: thumbData,
      webpageUrl: 'https://example.com',
      clientOnly: true,
    );

    expect(calls.single.method, 'shareWebpage');
    expect(calls.single.arguments, <String, Object?>{
      'title': 'title',
      'description': 'description',
      'thumbData': thumbData,
      'webpageUrl': 'https://example.com',
      'clientOnly': true,
    });
  });

  test('shareVideo forwards the optional HarmonyOS cover URI', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'weibo_kit_video_',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final Uri videoUri =
        (File('${temp.path}/video.mp4')..writeAsBytesSync(<int>[1])).uri;
    final Uri coverUri =
        (File('${temp.path}/cover.jpg')..writeAsBytesSync(<int>[1])).uri;
    await platform.shareVideo(
      text: 'video',
      videoUri: videoUri,
      videoCoverUri: coverUri,
      clientOnly: true,
    );

    expect(calls.single.method, 'shareVideo');
    expect(calls.single.arguments, <String, Object?>{
      'text': 'video',
      'videoUri': videoUri.toString(),
      'videoCoverUri': coverUri.toString(),
      'clientOnly': true,
    });
  });

  test('boolean queries preserve native results', () async {
    expect(await platform.isInstalled(), isTrue);
    expect(await platform.isSupportMultipleImage(), isFalse);
  });

  test('native auth callback is decoded into the response stream', () async {
    final Future<BaseResp> response = platform.respStream().first;
    await _sendNativeCallback(
      const MethodCall('onAuthResp', <String, Object?>{
        'errorCode': 0,
        'userId': 'user',
        'accessToken': 'token',
      }),
    );

    final AuthResp auth = await response as AuthResp;
    expect(auth.isSuccessful, isTrue);
    expect(auth.userId, 'user');
    expect(auth.accessToken, 'token');
  });

  test(
    'native callback is buffered until the first listener attaches',
    () async {
      await _sendNativeCallback(
        const MethodCall('onShareMsgResp', <String, Object?>{
          'errorCode': -1,
          'errorMessage': 'cancelled',
        }),
      );

      final ShareMsgResp response =
          await platform.respStream().first as ShareMsgResp;
      expect(response.isCancelled, isTrue);
      expect(response.errorMessage, 'cancelled');
    },
  );
}

Future<void> _sendNativeCallback(MethodCall call) async {
  final Completer<void> completer = Completer<void>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        const StandardMethodCodec().encodeMethodCall(call),
        (ByteData? data) => completer.complete(),
      );
  await completer.future;
}
