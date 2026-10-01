import 'package:flutter_test/flutter_test.dart';
import 'package:maishop_plus/main.dart';

void main() {
  testWidgets('MaiShopApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaiShopApp());
    expect(find.byType(MaiShopApp), findsOneWidget);
  });
}
