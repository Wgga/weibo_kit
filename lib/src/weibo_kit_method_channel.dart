import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:weibo_kit/src/model/resp.dart';
import 'package:weibo_kit/src/weibo_constant.dart';
import 'package:weibo_kit/src/weibo_kit_platform_interface.dart';

/// An implementation of [WeiboKitPlatform] that uses method channels.
class MethodChannelWeiboKit extends WeiboKitPlatform {
  /// Creates a MethodChannel based Weibo implementation.
  MethodChannelWeiboKit() {
    _respStreamController = StreamController<BaseResp>.broadcast(
      onListen: _flushPendingResps,
    );
    methodChannel.setMethodCallHandler(_handleMethod);
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'wgga.github.io/weibo_kit',
  );

  late final StreamController<BaseResp> _respStreamController;
  final List<BaseResp> _pendingResps = <BaseResp>[];
  bool _respStreamStarted = false;

  void _addResp(BaseResp value) {
    if (_respStreamController.hasListener) {
      _respStreamController.add(value);
    } else if (!_respStreamStarted) {
      _pendingResps.add(value);
    }
  }

  void _flushPendingResps() {
    _respStreamStarted = true;
    for (final BaseResp value in _pendingResps) {
      _respStreamController.add(value);
    }
    _pendingResps.clear();
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    final Map<String, dynamic> data =
        (call.arguments as Map<dynamic, dynamic>).cast<String, dynamic>();
    switch (call.method) {
      case 'onAuthResp':
        _addResp(AuthResp.fromJson(data));
      case 'onShareMsgResp':
        _addResp(ShareMsgResp.fromJson(data));
    }
  }

  @override
  Future<void> registerApp({
    required String appKey,
    required String? universalLink,
    required List<String> scope,
    String redirectUrl = WeiboRegister.DEFAULT_REDIRECTURL,
  }) {
    assert(!Platform.isIOS || (universalLink?.isNotEmpty ?? false));
    return methodChannel.invokeMethod<void>('registerApp', <String, dynamic>{
      'appKey': appKey,
      'universalLink': universalLink,
      'scope': scope.join(','),
      'redirectUrl': redirectUrl,
    });
  }

  @override
  Stream<BaseResp> respStream() {
    return _respStreamController.stream;
  }

  @override
  Future<bool> isInstalled() async {
    return await methodChannel.invokeMethod<bool>('isInstalled') ?? false;
  }

  @override
  Future<bool> isSupportMultipleImage() async {
    return await methodChannel.invokeMethod<bool>('isSupportMultipleImage') ??
        false;
  }

  @override
  Future<void> auth({
    required String appKey,
    required List<String> scope,
    String redirectUrl = WeiboRegister.DEFAULT_REDIRECTURL,
  }) {
    return methodChannel.invokeMethod<void>('auth', <String, dynamic>{
      'appKey': appKey,
      'scope': scope.join(','),
      'redirectUrl': redirectUrl,
    });
  }

  @override
  Future<void> shareText({required String text, bool clientOnly = false}) {
    return methodChannel.invokeMethod<void>('shareText', <String, dynamic>{
      'text': text,
      'clientOnly': clientOnly,
    });
  }

  @override
  Future<void> shareImage({
    String? text,
    Uint8List? imageData,
    Uri? imageUri,
    bool clientOnly = false,
  }) {
    assert(text == null || text.length <= 1024);
    assert(
      (imageData != null && imageData.lengthInBytes <= 2 * 1024 * 1024) ||
          (imageUri != null &&
              imageUri.isScheme('file') &&
              imageUri.toFilePath().length <= 512 &&
              File.fromUri(imageUri).lengthSync() <= 10 * 1024 * 1024),
    );
    return methodChannel.invokeMethod<void>('shareImage', <String, dynamic>{
      if (text != null && text.isNotEmpty) 'text': text,
      if (imageData != null) 'imageData': imageData,
      if (imageUri != null) 'imageUri': imageUri.toString(),
      'clientOnly': clientOnly,
    });
  }

  @override
  Future<void> shareMultiImage({
    String? text,
    required List<Uri> imageUris,
    bool clientOnly = false,
  }) {
    assert(text == null || text.length <= 1024);
    assert(
      imageUris.isNotEmpty &&
          imageUris.every((Uri element) => element.isScheme('file')) &&
          imageUris
                  .map((Uri element) => File.fromUri(element).lengthSync())
                  .reduce((int value, int element) => value + element) <=
              30 * 1024 * 1024,
    );
    return methodChannel
        .invokeMethod<void>('shareMultiImage', <String, dynamic>{
          if (text != null && text.isNotEmpty) 'text': text,
          'imageUris':
              imageUris.map((Uri element) => element.toString()).toList(),
          'clientOnly': clientOnly,
        });
  }

  @override
  Future<void> shareVideo({
    String? text,
    required Uri videoUri,
    Uri? videoCoverUri,
    bool clientOnly = false,
  }) {
    assert(text == null || text.length <= 1024);
    assert(
      videoUri.isScheme('file') &&
          File.fromUri(videoUri).lengthSync() <= 50 * 1024 * 1024,
    );
    return methodChannel.invokeMethod<void>('shareVideo', <String, dynamic>{
      if (text != null && text.isNotEmpty) 'text': text,
      'videoUri': videoUri.toString(),
      if (videoCoverUri != null) 'videoCoverUri': videoCoverUri.toString(),
      'clientOnly': clientOnly,
    });
  }

  @override
  Future<void> shareWebpage({
    required String title,
    required String description,
    required Uint8List thumbData,
    required String webpageUrl,
    bool clientOnly = false,
  }) {
    assert(title.length <= 512);
    assert(description.isNotEmpty && description.length <= 1024);
    assert(thumbData.lengthInBytes <= 32 * 1024);
    assert(webpageUrl.length <= 255);
    return methodChannel.invokeMethod<void>('shareWebpage', <String, dynamic>{
      'title': title,
      'description': description,
      'thumbData': thumbData,
      'webpageUrl': webpageUrl,
      'clientOnly': clientOnly,
    });
  }
}
