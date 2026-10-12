import 'package:flutter_test/flutter_test.dart';
import 'package:sahayak_mobile/main.dart';

void main() {
  testWidgets('SahayakApp renders Phase 2 User Sign In screen when unauthenticated',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SahayakApp(restoreSessionOnInit: false));

    expect(find.textContaining('SAHAYAK'), findsWidgets);
    expect(find.text('Sign In to Stick User Module'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });
}
