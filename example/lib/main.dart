import 'dart:async';

import 'package:flutter/material.dart';
import 'package:weibo_kit/weibo_kit.dart';

const String _appKey = 'your-weibo-app-key';
const String _universalLink = 'https://example.com/weibo/';

void main() => runApp(const WeiboKitExample());

class WeiboKitExample extends StatelessWidget {
  const WeiboKitExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weibo Kit',
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final StreamSubscription<BaseResp> _subscription;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _subscription = WeiboKit.instance.respStream().listen(_showResponse);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weibo Kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          FilledButton(
            onPressed: _register,
            child: const Text('Register Weibo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _checkInstalled,
            child: const Text('Check Weibo'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _authenticate,
            child: const Text('Authenticate'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _shareText, child: const Text('Share Text')),
          const SizedBox(height: 24),
          SelectableText(_status),
        ],
      ),
    );
  }

  Future<void> _register() async {
    await _run(
      () => WeiboKit.instance.registerApp(
        appKey: _appKey,
        universalLink: _universalLink,
        scope: const <String>[WeiboScope.ALL],
      ),
    );
  }

  Future<void> _checkInstalled() async {
    try {
      final bool installed = await WeiboKit.instance.isInstalled();
      if (mounted) {
        setState(() => _status = 'Weibo installed: $installed');
      }
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _authenticate() async {
    await _run(
      () => WeiboKit.instance.auth(
        appKey: _appKey,
        scope: const <String>[WeiboScope.ALL],
      ),
    );
  }

  Future<void> _shareText() async {
    await _run(() => WeiboKit.instance.shareText(text: 'Hello Weibo'));
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) {
        setState(() => _status = 'Request sent');
      }
    } on Object catch (error) {
      _showError(error);
    }
  }

  void _showResponse(BaseResp response) {
    if (mounted) {
      setState(
        () =>
            _status =
                '${response.runtimeType}: ${response.errorCode}\n'
                '${response.errorMessage ?? ''}',
      );
    }
  }

  void _showError(Object error) {
    if (mounted) {
      setState(() => _status = 'Request failed: $error');
    }
  }
}
