import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weibo_kit/src/setup/weibo_kit_configurator.dart';
import 'package:xml/xml.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('weibo_kit_setup_');
    File('${root.path}/pubspec.yaml')
      ..createSync(recursive: true)
      ..writeAsStringSync('name: host\n');
    File('${root.path}/ios/Runner/Info.plist')
      ..createSync(recursive: true)
      ..writeAsStringSync(_plist);
    File('${root.path}/ios/Runner.xcodeproj/project.pbxproj')
      ..createSync(recursive: true)
      ..writeAsStringSync(_project);
    File('${root.path}/ohos/entry/src/main/module.json5')
      ..createSync(recursive: true)
      ..writeAsStringSync(_module);
    File('${root.path}/ohos/build-profile.json5')
      ..createSync(recursive: true)
      ..writeAsStringSync(_buildProfile);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('configures iOS idempotently', () async {
    final WeiboKitConfigurator configurator = WeiboKitConfigurator();
    final WeiboKitSetupOptions options = WeiboKitSetupOptions(
      projectRoot: root,
      appKey: '123456',
      universalLink: 'https://example.com/weibo/',
      platforms: const <WeiboKitSetupPlatform>{WeiboKitSetupPlatform.ios},
    );

    final WeiboKitSetupResult first = await configurator.configure(options);
    expect(first.hasPendingChanges, isTrue);
    expect(first.changedFiles, hasLength(3));

    final WeiboKitSetupResult second = await configurator.configure(options);
    expect(second.hasPendingChanges, isFalse);

    final String info =
        File('${root.path}/ios/Runner/Info.plist').readAsStringSync();
    expect('wb123456'.allMatches(info), hasLength(1));
    expect('weibosdk3.3'.allMatches(info), hasLength(1));
    expect(() => XmlDocument.parse(info), returnsNormally);

    final String entitlements =
        File('${root.path}/ios/Runner/Runner.entitlements').readAsStringSync();
    expect('applinks:example.com'.allMatches(entitlements), hasLength(1));
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'.allMatches(
        File(
          '${root.path}/ios/Runner.xcodeproj/project.pbxproj',
        ).readAsStringSync(),
      ),
      hasLength(2),
    );
  });

  test('dry-run reports without modifying files', () async {
    final File plist = File('${root.path}/ios/Runner/Info.plist');
    final String before = plist.readAsStringSync();
    final WeiboKitSetupResult result = await WeiboKitConfigurator().configure(
      WeiboKitSetupOptions(
        projectRoot: root,
        appKey: '123456',
        universalLink: 'https://example.com/weibo/',
        platforms: const <WeiboKitSetupPlatform>{WeiboKitSetupPlatform.ios},
        dryRun: true,
      ),
    );

    expect(result.hasPendingChanges, isTrue);
    expect(result.changedFiles, hasLength(3));
    expect(plist.readAsStringSync(), before);
    expect(
      File('${root.path}/ios/Runner/Runner.entitlements').existsSync(),
      isFalse,
    );
  });

  test('replaces a previous Weibo callback scheme', () async {
    final WeiboKitConfigurator configurator = WeiboKitConfigurator();
    final Set<WeiboKitSetupPlatform> platforms = <WeiboKitSetupPlatform>{
      WeiboKitSetupPlatform.ios,
    };
    await configurator.configure(
      WeiboKitSetupOptions(
        projectRoot: root,
        appKey: 'old',
        universalLink: 'https://example.com/weibo/',
        platforms: platforms,
      ),
    );
    await configurator.configure(
      WeiboKitSetupOptions(
        projectRoot: root,
        appKey: 'new',
        universalLink: 'https://example.com/weibo/',
        platforms: platforms,
      ),
    );

    final String info =
        File('${root.path}/ios/Runner/Info.plist').readAsStringSync();
    expect(info, contains('wbnew'));
    expect(info, isNot(contains('wbold')));
  });

  test('initializes empty plist roots', () async {
    final File info = File('${root.path}/ios/Runner/Info.plist')
      ..writeAsStringSync(_emptyPlist);
    final File entitlements = File(
      '${root.path}/ios/Runner/Runner.entitlements',
    )..writeAsStringSync(_emptyPlist);
    final WeiboKitSetupOptions options = WeiboKitSetupOptions(
      projectRoot: root,
      appKey: '123456',
      universalLink: 'https://example.com/weibo/',
      platforms: const <WeiboKitSetupPlatform>{WeiboKitSetupPlatform.ios},
    );

    final WeiboKitConfigurator configurator = WeiboKitConfigurator();
    final WeiboKitSetupResult first = await configurator.configure(options);
    expect(first.hasPendingChanges, isTrue);
    expect(first.changedFiles, hasLength(3));
    expect(info.readAsStringSync(), contains('wb123456'));
    expect(entitlements.readAsStringSync(), contains('<dict>'));
    expect(entitlements.readAsStringSync(), contains('applinks:example.com'));

    final WeiboKitSetupResult second = await configurator.configure(options);
    expect(second.hasPendingChanges, isFalse);
  });

  test('rejects a non-dictionary plist root', () async {
    File('${root.path}/ios/Runner/Runner.entitlements')
      ..createSync(recursive: true)
      ..writeAsStringSync(_arrayPlist);

    await expectLater(
      WeiboKitConfigurator().configure(
        WeiboKitSetupOptions(
          projectRoot: root,
          appKey: '123456',
          universalLink: 'https://example.com/weibo/',
          platforms: const <WeiboKitSetupPlatform>{WeiboKitSetupPlatform.ios},
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          'plist root dict is missing',
        ),
      ),
    );
  });

  test('configures HarmonyOS idempotently', () async {
    final WeiboKitConfigurator configurator = WeiboKitConfigurator();
    final WeiboKitSetupOptions options = WeiboKitSetupOptions(
      projectRoot: root,
      appKey: '123456',
      platforms: const <WeiboKitSetupPlatform>{WeiboKitSetupPlatform.ohos},
    );

    final WeiboKitSetupResult first = await configurator.configure(options);
    expect(first.hasPendingChanges, isTrue);
    expect(first.changedFiles, hasLength(2));

    final WeiboKitSetupResult second = await configurator.configure(options);
    expect(second.hasPendingChanges, isFalse);

    final String module =
        File(
          '${root.path}/ohos/entry/src/main/module.json5',
        ).readAsStringSync();
    expect('"sinaweibo"'.allMatches(module), hasLength(1));
    expect(module, contains('"custom"'));
    expect(
      File('${root.path}/ohos/build-profile.json5').readAsStringSync(),
      contains('"useNormalizedOHMUrl": true'),
    );
  });

  test('HarmonyOS dry-run does not modify host files', () async {
    final File module = File('${root.path}/ohos/entry/src/main/module.json5');
    final String before = module.readAsStringSync();
    final WeiboKitSetupResult result = await WeiboKitConfigurator().configure(
      WeiboKitSetupOptions(
        projectRoot: root,
        appKey: '123456',
        platforms: const <WeiboKitSetupPlatform>{WeiboKitSetupPlatform.ohos},
        dryRun: true,
      ),
    );

    expect(result.hasPendingChanges, isTrue);
    expect(module.readAsStringSync(), before);
  });
}

const String _plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleName</key><string>Host</string></dict></plist>
''';

const String _emptyPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"></plist>
''';

const String _arrayPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><array/></plist>
''';

const String _project = '''buildSettings = {
  INFOPLIST_FILE = Runner/Info.plist;
};
buildSettings = {
  INFOPLIST_FILE = Runner/Info.plist;
};
''';

const String _module = '''
{
  // Preserve host-owned settings.
  "module": {
    "name": "entry",
    "querySchemes": ["custom"],
  },
}
''';

const String _buildProfile = '''
{
  "app": {
    "products": [
      {
        "name": "default",
        "buildOption": {},
      }
    ]
  }
}
''';
