## 1.0.2

* Align iOS simulator architecture exclusions with dependent CocoaPods to
  avoid `EXCLUDED_ARCHS` merge warnings.

## 1.0.1

* Fix HarmonyOS hot restart hanging while waiting for repeated Weibo SDK
  registration to complete.

## 1.0.0

* Initial stable release.
* Support Weibo authentication, client detection, and response streams on
  Android, iOS, and HarmonyOS.
* Support text, image, multi-image, and video sharing on all platforms, plus
  webpage sharing on Android and iOS.
* Use Weibo Android SDK 13.10.8 (`13.10.8-opt1` on Maven Central).
* Bundle the official Weibo HarmonyOS SDK 25.4.0.
* Add the idempotent `dart run weibo_kit:setup` host configuration tool.
* Support cold-start callbacks and callback buffering before the first Dart
  stream listener is attached.
