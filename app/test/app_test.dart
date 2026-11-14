import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/main.dart';

void main() {
  testWidgets('shows Kaname', (tester) async {
    await tester.pumpWidget(const KanameApp());

    expect(find.text('Kaname'), findsOneWidget);
  });
}
