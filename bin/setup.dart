import 'dart:io';

import 'package:args/args.dart';
import 'package:weibo_kit/src/setup/weibo_kit_configurator.dart';

Future<void> main(List<String> arguments) async {
  final ArgParser parser =
      ArgParser()
        ..addOption('project', defaultsTo: '.')
        ..addOption('app-key', mandatory: true)
        ..addOption('universal-link')
        ..addOption('associated-domain')
        ..addOption('platforms', defaultsTo: 'android,ios,ohos')
        ..addOption('ios-info-plist')
        ..addOption('ios-entitlements')
        ..addOption('ohos-module')
        ..addOption('ohos-build-profile')
        ..addFlag('dry-run', negatable: false)
        ..addFlag('check', negatable: false)
        ..addFlag('help', abbr: 'h', negatable: false);
  try {
    final ArgResults args = parser.parse(arguments);
    if (args.flag('help')) {
      stdout.writeln(_usage(parser));
      return;
    }
    final Directory root = Directory(args.option('project')!).absolute;
    final WeiboKitSetupOptions options = WeiboKitSetupOptions(
      projectRoot: root,
      appKey: args.option('app-key')!,
      universalLink: args.option('universal-link'),
      associatedDomain: args.option('associated-domain'),
      platforms: _parsePlatforms(args.option('platforms')!),
      iosInfoPlist: _optionalFile(root, args.option('ios-info-plist')),
      iosEntitlements: _optionalFile(root, args.option('ios-entitlements')),
      ohosModule: _optionalFile(root, args.option('ohos-module')),
      ohosBuildProfile: _optionalFile(root, args.option('ohos-build-profile')),
      dryRun: args.flag('dry-run'),
      checkOnly: args.flag('check'),
    );
    final WeiboKitSetupResult result = await WeiboKitConfigurator().configure(
      options,
    );
    final bool preview = options.dryRun || options.checkOnly;
    stdout.writeln(
      result.hasPendingChanges
          ? preview
              ? 'weibo_kit: host configuration changes are required.'
              : 'weibo_kit: host configuration updated.'
          : 'weibo_kit: host configuration is already up to date.',
    );
    for (final File file in result.changedFiles) {
      stdout.writeln('  ${preview ? 'would update' : 'updated'} ${file.path}');
    }
    for (final String message in result.messages) {
      stdout.writeln('  - $message');
    }
    if (options.checkOnly && result.hasPendingChanges) {
      exitCode = 2;
    }
  } on Object catch (error) {
    stderr.writeln('weibo_kit setup failed: $error');
    exitCode = 1;
  }
}

Set<WeiboKitSetupPlatform> _parsePlatforms(String value) {
  final Set<WeiboKitSetupPlatform> result = <WeiboKitSetupPlatform>{};
  for (final String raw in value.split(',')) {
    switch (raw.trim().toLowerCase()) {
      case 'android':
        result.add(WeiboKitSetupPlatform.android);
      case 'ios':
        result.add(WeiboKitSetupPlatform.ios);
      case 'ohos':
        result.add(WeiboKitSetupPlatform.ohos);
      case '':
        break;
      default:
        throw FormatException('Unsupported platform: ${raw.trim()}');
    }
  }
  return result;
}

File? _optionalFile(Directory root, String? value) {
  if (value == null || value.isEmpty) return null;
  return File(value.startsWith('/') ? value : '${root.path}/$value');
}

String _usage(ArgParser parser) => '''Configure a Flutter host for weibo_kit.

Usage:
  dart run weibo_kit:setup --app-key <app-key> \\
    --universal-link https://example.com/weibo/

${parser.usage}''';
