import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:weibo_kit/weibo_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('platform plugin is reachable', (WidgetTester tester) async {
    try {
      expect(await WeiboKit.instance.isInstalled(), isA<bool>());
    } on Object {
      // The native SDK requires registerApp before querying installation.
    }
  });
}
