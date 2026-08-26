import 'dart:io';

import 'package:xml/xml.dart';

/// setup 命令支持的平台。
enum WeiboKitSetupPlatform { android, ios, ohos }

/// 宿主配置选项。
class WeiboKitSetupOptions {
  /// 创建宿主配置选项。
  const WeiboKitSetupOptions({
    required this.projectRoot,
    required this.appKey,
    required this.platforms,
    this.universalLink,
    this.associatedDomain,
    this.iosInfoPlist,
    this.iosEntitlements,
    this.ohosModule,
    this.ohosBuildProfile,
    this.dryRun = false,
    this.checkOnly = false,
  });

  final Directory projectRoot;
  final String appKey;
  final Set<WeiboKitSetupPlatform> platforms;
  final String? universalLink;
  final String? associatedDomain;
  final File? iosInfoPlist;
  final File? iosEntitlements;
  final File? ohosModule;
  final File? ohosBuildProfile;
  final bool dryRun;
  final bool checkOnly;
}

/// 宿主配置结果。
class WeiboKitSetupResult {
  /// 创建宿主配置结果。
  const WeiboKitSetupResult({
    required this.changedFiles,
    required this.messages,
    required this.hasPendingChanges,
  });

  final List<File> changedFiles;
  final List<String> messages;
  final bool hasPendingChanges;
}

/// 幂等配置微博宿主工程。
class WeiboKitConfigurator {
  /// 执行配置。
  Future<WeiboKitSetupResult> configure(WeiboKitSetupOptions options) async {
    _validate(options);
    final bool write = !options.dryRun && !options.checkOnly;
    final List<File> changedFiles = <File>[];
    final List<String> messages = <String>[];

    if (options.platforms.contains(WeiboKitSetupPlatform.android)) {
      messages.add(
        'Android: no host edit required; package visibility and FileProvider '
        'are supplied by the SDK and plugin manifest merger.',
      );
    }

    if (options.platforms.contains(WeiboKitSetupPlatform.ios)) {
      final File infoPlist =
          options.iosInfoPlist ??
          File('${options.projectRoot.path}/ios/Runner/Info.plist');
      if (_configureInfoPlist(infoPlist, options.appKey, write: write)) {
        changedFiles.add(infoPlist);
      }

      final Uri universalLink = Uri.parse(options.universalLink!);
      final String domain =
          options.associatedDomain ?? 'applinks:${universalLink.host}';
      final File entitlements = _resolveEntitlements(options);
      if (_configureEntitlements(entitlements, domain, write: write)) {
        changedFiles.add(entitlements);
      }
      final File project = File(
        '${options.projectRoot.path}/ios/Runner.xcodeproj/project.pbxproj',
      );
      if (_configureXcodeEntitlements(
        project,
        _relativeToIos(options.projectRoot, entitlements),
        write: write,
      )) {
        changedFiles.add(project);
      }
      messages.add(
        'iOS: ensured URL Scheme, query allow-list and Associated Domains.',
      );
    }

    if (options.platforms.contains(WeiboKitSetupPlatform.ohos)) {
      final File module =
          options.ohosModule ??
          File('${options.projectRoot.path}/ohos/entry/src/main/module.json5');
      final File buildProfile =
          options.ohosBuildProfile ??
          File('${options.projectRoot.path}/ohos/build-profile.json5');
      if (_configureOhosModule(module, write: write)) {
        changedFiles.add(module);
      }
      if (_configureOhosBuildProfile(buildProfile, write: write)) {
        changedFiles.add(buildProfile);
      }
      messages.add(
        'HarmonyOS: ensured querySchemes contains "sinaweibo" and enabled normalized OHM URLs.',
      );
    }

    messages.add(
      'Manual: verify package name, bundle identifier, universal link and '
      'release signatures in Weibo Open Platform.',
    );
    return WeiboKitSetupResult(
      changedFiles: changedFiles,
      messages: messages,
      hasPendingChanges: changedFiles.isNotEmpty,
    );
  }

  void _validate(WeiboKitSetupOptions options) {
    if (!File('${options.projectRoot.path}/pubspec.yaml').existsSync()) {
      throw ArgumentError('Not a Flutter project: ${options.projectRoot.path}');
    }
    if (options.appKey.trim().isEmpty) {
      throw ArgumentError('appKey must not be empty.');
    }
    if (options.platforms.isEmpty) {
      throw ArgumentError('At least one platform must be selected.');
    }
    if (options.platforms.contains(WeiboKitSetupPlatform.ios)) {
      final Uri? link = Uri.tryParse(options.universalLink ?? '');
      if (link == null || link.scheme != 'https' || link.host.isEmpty) {
        throw ArgumentError('iOS setup requires an HTTPS --universal-link.');
      }
    }
  }

  bool _configureInfoPlist(File file, String appKey, {required bool write}) {
    if (!file.existsSync()) {
      throw StateError('Info.plist not found: ${file.path}');
    }
    final XmlDocument document = XmlDocument.parse(file.readAsStringSync());
    final XmlElement plist = document.rootElement;
    final bool rootWasEmpty =
        plist.name.local == 'plist' && plist.childElements.isEmpty;
    final XmlElement root = _rootDict(document, createIfEmpty: true);
    bool changed = rootWasEmpty;

    XmlElement? urlTypes = _valueForKey(root, 'CFBundleURLTypes');
    if (urlTypes == null) {
      urlTypes = XmlElement(XmlName('array'));
      _appendKeyValue(root, 'CFBundleURLTypes', urlTypes);
      changed = true;
    }
    _requireArray(urlTypes, 'CFBundleURLTypes');
    XmlElement? weiboEntry;
    for (final XmlElement entry in urlTypes.childElements.where(
      (XmlElement element) => element.name.local == 'dict',
    )) {
      if (_stringValue(entry, 'CFBundleURLName') == 'weibo') {
        weiboEntry = entry;
        break;
      }
    }
    final String callbackScheme = 'wb$appKey';
    if (weiboEntry == null) {
      weiboEntry = XmlElement(XmlName('dict'));
      _appendKeyValue(weiboEntry, 'CFBundleTypeRole', _string('Editor'));
      _appendKeyValue(weiboEntry, 'CFBundleURLName', _string('weibo'));
      final XmlElement schemes = XmlElement(XmlName('array'));
      schemes.children.add(_string(callbackScheme));
      _appendKeyValue(weiboEntry, 'CFBundleURLSchemes', schemes);
      urlTypes.children.add(weiboEntry);
      changed = true;
    } else {
      XmlElement? schemes = _valueForKey(weiboEntry, 'CFBundleURLSchemes');
      if (schemes == null) {
        schemes = XmlElement(XmlName('array'));
        _appendKeyValue(weiboEntry, 'CFBundleURLSchemes', schemes);
        changed = true;
      }
      _requireArray(schemes, 'CFBundleURLSchemes');
      final List<XmlElement> values =
          schemes.childElements
              .where((XmlElement element) => element.name.local == 'string')
              .toList();
      if (values.length != 1 || values.single.innerText != callbackScheme) {
        schemes.children
          ..clear()
          ..add(_string(callbackScheme));
        changed = true;
      }
    }

    XmlElement? queries = _valueForKey(root, 'LSApplicationQueriesSchemes');
    if (queries == null) {
      queries = XmlElement(XmlName('array'));
      _appendKeyValue(root, 'LSApplicationQueriesSchemes', queries);
      changed = true;
    }
    _requireArray(queries, 'LSApplicationQueriesSchemes');
    for (final String scheme in const <String>[
      'sinaweibo',
      'sinaweibohd',
      'weibosdk',
      'weibosdk2.5',
      'weibosdk3.3',
    ]) {
      if (!queries.childElements.any(
        (XmlElement element) =>
            element.name.local == 'string' && element.innerText == scheme,
      )) {
        queries.children.add(_string(scheme));
        changed = true;
      }
    }
    if (changed && write) {
      _writeXml(file, document);
    }
    return changed;
  }

  File _resolveEntitlements(WeiboKitSetupOptions options) {
    if (options.iosEntitlements != null) {
      return options.iosEntitlements!;
    }
    final Directory runner = Directory(
      '${options.projectRoot.path}/ios/Runner',
    );
    final List<File> existing =
        runner
            .listSync()
            .whereType<File>()
            .where((File file) => file.path.endsWith('.entitlements'))
            .toList();
    if (existing.length > 1) {
      throw StateError(
        'Multiple entitlements files found; pass --ios-entitlements.',
      );
    }
    return existing.isEmpty
        ? File('${runner.path}/Runner.entitlements')
        : existing.single;
  }

  bool _configureEntitlements(File file, String domain, {required bool write}) {
    final XmlDocument document =
        file.existsSync()
            ? XmlDocument.parse(file.readAsStringSync())
            : XmlDocument.parse(_emptyPlist);
    final XmlElement plist = document.rootElement;
    final bool rootWasEmpty =
        plist.name.local == 'plist' && plist.childElements.isEmpty;
    final XmlElement root = _rootDict(document, createIfEmpty: true);
    XmlElement? domains = _valueForKey(
      root,
      'com.apple.developer.associated-domains',
    );
    bool changed = rootWasEmpty;
    if (domains == null) {
      domains = XmlElement(XmlName('array'));
      _appendKeyValue(root, 'com.apple.developer.associated-domains', domains);
      changed = true;
    }
    _requireArray(domains, 'com.apple.developer.associated-domains');
    if (!domains.childElements.any(
      (XmlElement element) =>
          element.name.local == 'string' && element.innerText == domain,
    )) {
      domains.children.add(_string(domain));
      changed = true;
    }
    if (changed && write) {
      _writeXml(file, document);
    }
    return changed;
  }

  bool _configureXcodeEntitlements(
    File file,
    String path, {
    required bool write,
  }) {
    if (!file.existsSync()) {
      throw StateError('Xcode project not found: ${file.path}');
    }
    final String source = file.readAsStringSync();
    int changes = 0;
    final String updated = source.replaceAllMapped(
      RegExp(r'buildSettings = \{[\s\S]*?\n[ \t]*\};'),
      (Match match) {
        final String block = match.group(0)!;
        if (!block.contains('INFOPLIST_FILE = Runner/Info.plist;')) {
          return block;
        }
        if (RegExp(r'\bCODE_SIGN_ENTITLEMENTS\s*=').hasMatch(block)) {
          if (!block.contains('CODE_SIGN_ENTITLEMENTS = $path;')) {
            throw StateError('Runner uses a different entitlements file.');
          }
          return block;
        }
        changes++;
        return block.replaceFirstMapped(
          RegExp(r'([ \t]+)INFOPLIST_FILE = Runner/Info\.plist;'),
          (Match setting) =>
              '${setting.group(0)}\n${setting.group(1)}CODE_SIGN_ENTITLEMENTS = $path;',
        );
      },
    );
    if (changes == 0 && !source.contains('CODE_SIGN_ENTITLEMENTS = $path;')) {
      throw StateError(
        'Could not locate Runner build settings in ${file.path}',
      );
    }
    if (changes > 0 && write) {
      file.writeAsStringSync(updated);
    }
    return changes > 0;
  }

  XmlElement? _valueForKey(XmlElement dict, String key) {
    final List<XmlElement> elements = dict.childElements.toList();
    for (int index = 0; index + 1 < elements.length; index++) {
      if (elements[index].name.local == 'key' &&
          elements[index].innerText == key) {
        return elements[index + 1];
      }
    }
    return null;
  }

  XmlElement _rootDict(XmlDocument document, {required bool createIfEmpty}) {
    final XmlElement plist = document.rootElement;
    if (plist.name.local != 'plist') {
      throw const FormatException('plist root dict is missing');
    }
    final List<XmlElement> values = plist.childElements.toList();
    if (values.length == 1 && values.single.name.local == 'dict') {
      return values.single;
    }
    if (values.isEmpty && createIfEmpty) {
      final XmlElement dict = XmlElement(XmlName('dict'));
      plist.children.add(dict);
      return dict;
    }
    throw const FormatException('plist root dict is missing');
  }

  String? _stringValue(XmlElement dict, String key) {
    final XmlElement? value = _valueForKey(dict, key);
    return value?.name.local == 'string' ? value?.innerText : null;
  }

  void _appendKeyValue(XmlElement dict, String key, XmlElement value) {
    dict.children
      ..add(
        XmlElement(XmlName('key'), <XmlAttribute>[], <XmlNode>[XmlText(key)]),
      )
      ..add(value);
  }

  XmlElement _string(String value) => XmlElement(
    XmlName('string'),
    <XmlAttribute>[],
    <XmlNode>[XmlText(value)],
  );

  void _requireArray(XmlElement element, String key) {
    if (element.name.local != 'array') {
      throw FormatException('$key must be a plist <array>.');
    }
  }

  void _writeXml(File file, XmlDocument document) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${document.toXmlString(pretty: true, indent: '\t')}\n',
    );
  }

  String _relativeToIos(Directory root, File file) {
    final String prefix = '${root.path}/ios/';
    if (!file.path.startsWith(prefix)) {
      throw ArgumentError('Entitlements file must be inside ios/.');
    }
    return file.path.substring(prefix.length);
  }

  bool _configureOhosModule(File file, {required bool write}) {
    if (!file.existsSync()) {
      throw StateError('HarmonyOS module.json5 not found: ${file.path}');
    }
    String source = file.readAsStringSync();
    final int moduleKey = _findJson5Key(source, 'module');
    if (moduleKey < 0) {
      throw FormatException('Missing "module" object in ${file.path}');
    }
    final int moduleOpen = source.indexOf('{', moduleKey);
    final int moduleClose = _matchingDelimiter(source, moduleOpen, '{', '}');
    final int schemesKey = _findJson5Key(
      source,
      'querySchemes',
      start: moduleOpen,
      end: moduleClose,
    );
    bool changed = false;
    if (schemesKey < 0) {
      final String indent = _indentAfter(source, moduleOpen);
      source = source.replaceRange(
        moduleOpen + 1,
        moduleOpen + 1,
        '\n$indent"querySchemes": [\n'
        '$indent  "sinaweibo"\n'
        '$indent],',
      );
      changed = true;
    } else {
      final int arrayOpen = source.indexOf('[', schemesKey);
      final int arrayClose = _matchingDelimiter(source, arrayOpen, '[', ']');
      final String arraySource = source.substring(arrayOpen, arrayClose + 1);
      if (!RegExp(r'''["']sinaweibo["']''').hasMatch(arraySource)) {
        final String indent = _lineIndent(source, schemesKey);
        final String content = source.substring(arrayOpen + 1, arrayClose);
        final String addition =
            content.trim().isEmpty
                ? '\n$indent  "sinaweibo"\n$indent'
                : '${content.trimRight()},\n$indent  "sinaweibo"\n$indent';
        source = source.replaceRange(arrayOpen + 1, arrayClose, addition);
        changed = true;
      }
    }
    if (changed && write) {
      file.writeAsStringSync(source);
    }
    return changed;
  }

  bool _configureOhosBuildProfile(File file, {required bool write}) {
    if (!file.existsSync()) {
      throw StateError('HarmonyOS build-profile.json5 not found: ${file.path}');
    }
    String source = file.readAsStringSync();
    final int productsKey = _findJson5Key(source, 'products');
    if (productsKey < 0) {
      throw FormatException('Missing "products" array in ${file.path}');
    }
    final int productsOpen = source.indexOf('[', productsKey);
    final int productsClose = _matchingDelimiter(
      source,
      productsOpen,
      '[',
      ']',
    );
    final int normalizedKey = _findJson5Key(
      source,
      'useNormalizedOHMUrl',
      start: productsOpen,
      end: productsClose,
    );
    if (normalizedKey >= 0) {
      final int colon = source.indexOf(':', normalizedKey);
      final Match? value = RegExp(
        r'\b(?:true|false)\b',
      ).firstMatch(source.substring(colon + 1, productsClose));
      if (value == null) {
        throw FormatException(
          'useNormalizedOHMUrl must be a boolean in ${file.path}',
        );
      }
      if (value.group(0) == 'true') {
        return false;
      }
      final int start = colon + 1 + value.start;
      source = source.replaceRange(
        start,
        start + value.group(0)!.length,
        'true',
      );
    } else {
      final int productOpen = source.indexOf('{', productsOpen);
      final int productClose = _matchingDelimiter(
        source,
        productOpen,
        '{',
        '}',
      );
      final int buildOptionKey = _findJson5Key(
        source,
        'buildOption',
        start: productOpen,
        end: productClose,
      );
      if (buildOptionKey < 0) {
        final String indent = _indentAfter(source, productOpen);
        source = source.replaceRange(
          productOpen + 1,
          productOpen + 1,
          '\n$indent"buildOption": {\n'
          '$indent  "strictMode": {\n'
          '$indent    "useNormalizedOHMUrl": true\n'
          '$indent  }\n'
          '$indent},',
        );
      } else {
        final int buildOptionOpen = source.indexOf('{', buildOptionKey);
        final int buildOptionClose = _matchingDelimiter(
          source,
          buildOptionOpen,
          '{',
          '}',
        );
        final int strictModeKey = _findJson5Key(
          source,
          'strictMode',
          start: buildOptionOpen,
          end: buildOptionClose,
        );
        if (strictModeKey < 0) {
          final String indent = _indentAfter(source, buildOptionOpen);
          source = source.replaceRange(
            buildOptionOpen + 1,
            buildOptionOpen + 1,
            '\n$indent"strictMode": {\n'
            '$indent  "useNormalizedOHMUrl": true\n'
            '$indent},',
          );
        } else {
          final int strictModeOpen = source.indexOf('{', strictModeKey);
          final String indent = _indentAfter(source, strictModeOpen);
          source = source.replaceRange(
            strictModeOpen + 1,
            strictModeOpen + 1,
            '\n$indent"useNormalizedOHMUrl": true,',
          );
        }
      }
    }
    if (write) {
      file.writeAsStringSync(source);
    }
    return true;
  }

  int _findJson5Key(String source, String key, {int start = 0, int? end}) {
    final RegExp expression = RegExp('["\']${RegExp.escape(key)}["\']\\s*:');
    for (final Match match in expression.allMatches(source, start)) {
      if (match.start >= (end ?? source.length)) {
        break;
      }
      if (!_insideJson5CommentOrString(source, match.start)) {
        return match.start;
      }
    }
    return -1;
  }

  int _matchingDelimiter(String source, int open, String left, String right) {
    if (open < 0 || source[open] != left) {
      throw const FormatException('Invalid JSON5 delimiter.');
    }
    int depth = 0;
    for (int index = open; index < source.length; index++) {
      if (_insideJson5CommentOrString(source, index)) {
        continue;
      }
      if (source[index] == left) {
        depth++;
      }
      if (source[index] == right && --depth == 0) {
        return index;
      }
    }
    throw const FormatException('Unclosed JSON5 delimiter.');
  }

  bool _insideJson5CommentOrString(String source, int position) {
    String? quote;
    bool lineComment = false;
    bool blockComment = false;
    for (int index = 0; index < position; index++) {
      final String char = source[index];
      final String next = index + 1 < source.length ? source[index + 1] : '';
      if (lineComment) {
        if (char == '\n') {
          lineComment = false;
        }
      } else if (blockComment) {
        if (char == '*' && next == '/') {
          blockComment = false;
          index++;
        }
      } else if (quote != null) {
        if (char == r'\') {
          index++;
        } else if (char == quote) {
          quote = null;
        }
      } else if (char == '/' && next == '/') {
        lineComment = true;
        index++;
      } else if (char == '/' && next == '*') {
        blockComment = true;
        index++;
      } else if (char == '"' || char == "'") {
        quote = char;
      }
    }
    return lineComment || blockComment || quote != null;
  }

  String _indentAfter(String source, int open) =>
      '${_lineIndent(source, open)}  ';

  String _lineIndent(String source, int position) {
    final int lineStart = source.lastIndexOf('\n', position) + 1;
    return RegExp(
      r'^[ \t]*',
    ).firstMatch(source.substring(lineStart))!.group(0)!;
  }

  static const String _emptyPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>''';
}
