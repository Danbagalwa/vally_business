import 'package:flutter_test/flutter_test.dart';

import 'package:vally_business/main.dart';

void main() {
  testWidgets('L’appli démarre avec le thème Vally', (tester) async {
    await tester.pumpWidget(const VallyApp());
    expect(find.text('Vally Business'), findsOneWidget);
  });
}
