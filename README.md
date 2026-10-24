# USE Advance Picture Dictionary 📚🖼️

An advanced interactive visual dictionary and vocabulary learning system featuring **15,916 curated vocabulary entries**, didactic flashcards, parts of speech, definitions, example sentences, interactive synonyms and antonyms, pronunciation audio (TTS), and companion app interlinking.

## ✨ Key Features
- **15,916 Vocabulary Words:** Complete comprehensive vocabulary dataset with full parts of speech, English meanings, examples, and Sindhi/Urdu translations.
- **High-Definition Visual Cards:** Pre-bundled reference cards cropped from HD flashcard sheets with didactic visual mappings.
- **Interactive Synonyms & Antonyms:** Tap any synonym or antonym chip to jump directly into that word's full visual definition.
- **Offline SQLite Engine:** Fast local search with exact & prefix ranking for instant results across all 15,916 words.
- **Text-to-Speech (TTS):** Integrated pronunciation audio for every entry.
- **Cross-Platform Support:** Windows desktop executable, Android, Web, and iOS.
- **Companion App Interlinking:** Seamless protocol (`useadvancepicdict://`) integration with the USE Advance Dictionary companion application.

## 📁 Repository Structure
- `use_advance_picture_dictionary_app/` — Flutter application source code (UI, widgets, models, services)
- `Brandings/` — Official branding sheets, logos, and high-resolution icon assets
- `firebase_export/` — Firebase Firestore dataset exports including bilingual translations
- `USE Advance Pictue Dictionary.xlsx` — Primary master dataset (15,916 rows)

## 🚀 Running the App Locally
```bash
cd use_advance_picture_dictionary_app
flutter pub get
flutter run -d windows
```

## 📦 Building Windows Release Executable
```bash
cd use_advance_picture_dictionary_app
flutter build windows --release
```
The compiled standalone executable is generated in:
`use_advance_picture_dictionary_app/build/windows/x64/runner/Release/use_advance_picture_dictionary_app.exe`

## 👨‍💻 Author
**Badruddin Siddiqui**
