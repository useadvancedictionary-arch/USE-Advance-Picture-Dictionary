import 'package:flutter_test/flutter_test.dart';
import 'package:use_advance_picture_dictionary_app/main.dart';

void main() {
  testWidgets('App starts test', (WidgetTester tester) async {
    await tester.pumpWidget(const UseAdvancePictureDictionaryApp());
    expect(find.text('USE Advance Picture Dictionary'), findsWidgets);
  });
}