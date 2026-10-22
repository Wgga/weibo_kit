Pod::Spec.new do |s|
  s.name             = 'weibo_kit'
  s.version          = '1.0.3'
  s.summary          = 'Flutter plugin for Weibo authentication and sharing.'
  s.description      = s.summary
  s.homepage         = 'https://github.com/Wgga/weibo_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Wgga'
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # 内置官方 master 分支的 WeiboSDK.xcframework（2026-08-21 提交 907f308）：
  # 同时提供 ios-arm64 与 ios-arm64_x86_64-simulator 切片，可在 Apple Silicon 模拟器上运行。
  # 不再依赖 CocoaPods 上的 Weibo_SDK 3.3.5（其 libWeiboSDK.a 只有真机 arm64 切片）。
  s.vendored_frameworks = 'WeiboSDK.xcframework'
  s.resources           = ['WeiboSDK.bundle', 'PrivacyInfo.xcprivacy']

  s.frameworks = 'Photos', 'ImageIO', 'SystemConfiguration', 'CoreText', 'QuartzCore',
                 'Security', 'UIKit', 'Foundation', 'CoreGraphics', 'CoreTelephony', 'WebKit'
  s.libraries  = 'sqlite3', 'z'

  s.static_framework = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC -all_load',
  }
end
