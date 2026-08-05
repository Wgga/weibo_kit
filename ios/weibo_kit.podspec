Pod::Spec.new do |s|
  s.name             = 'weibo_kit'
  s.version          = '1.0.1'
  s.summary          = 'Flutter plugin for Weibo authentication and sharing.'
  s.description      = s.summary
  s.homepage         = 'https://github.com/Wgga/weibo_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Wgga'
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Weibo_SDK', '~> 3.3.5'
  s.platform = :ios, '13.0'

  s.static_framework = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64 i386',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC -all_load',
  }
  # Weibo_SDK 3.3.5 packages its arm64 slice for devices only.
  s.user_target_xcconfig = {
    'ARCHS[sdk=iphonesimulator*]' => 'x86_64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64 i386',
  }
end
