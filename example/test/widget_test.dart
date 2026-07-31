import 'package:flutter_test/flutter_test.dart';
import 'package:weibo_kit_example/main.dart';

void main() {
  testWidgets('renders the authentication and sharing actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeiboKitExample());

    expect(find.text('Authenticate'), findsOneWidget);
    expect(find.text('Share Text'), findsOneWidget);
  });
}
