import 'package:flutter_test/flutter_test.dart';
import 'package:use_advance_picture_dictionary_app/services/smart_auto_tagger.dart';
import 'package:use_advance_picture_dictionary_app/services/picture_database_service.dart';

void main() {
  test('SmartAutoTagger correctly classifies fugitive as Law & Justice', () {
    final cat = SmartAutoTagger.autoClassify(
      word: 'Fugitive',
      meaning: 'A person who is running away, especially from the law or justice.',
      pos: 'Noun, Adjective',
    );
    expect(cat, equals('Law & Justice'));
  });

  test('SmartAutoTagger resolves bundled card for abandon', () {
    final img = SmartAutoTagger.autoResolveImage('abandon');
    expect(img, equals('assets/cards/abandon.jpg'));
  });

  test('Database service singleton is available and starter entries are populated', () {
    final service = PictureDatabaseService.instance;
    expect(service, isNotNull);
    expect(SmartAutoTagger.autoResolveImage('abdicate'), equals('assets/cards/abdicate.jpg'));
  });
}
