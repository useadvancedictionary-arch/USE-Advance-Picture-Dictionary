import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/interlink_service.dart';

class AboutInfoAccordionScreen extends StatefulWidget {
  const AboutInfoAccordionScreen({super.key});

  @override
  State<AboutInfoAccordionScreen> createState() => _AboutInfoAccordionScreenState();
}

class _AboutInfoAccordionScreenState extends State<AboutInfoAccordionScreen> {
  // Expansion controllers to control which accordions are open by default
  bool _aboutExpanded = true;
  bool _helpExpanded = false;
  bool _privacyExpanded = false;
  bool _termsExpanded = false;

  Future<void> _sendEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'useadvancedictionary@gmail.com',
      query: 'subject=Feedback%20for%20USE%20Advance%20Picture%20Dictionary',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyEmail();
      }
    } catch (_) {
      _copyEmail();
    }
  }

  void _copyEmail() {
    Clipboard.setData(const ClipboardData(text: 'useadvancedictionary@gmail.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email copied: useadvancedictionary@gmail.com')),
    );
  }

  void _shareApp() {
    const text =
        'Explore USE Advance Picture Dictionary — complete visual and multilingual English, Sindhi & Urdu dictionary designed for learners, TOEFL, IELTS, CSS candidates, and professionals with 15,900+ HD visual cards.';
    Clipboard.setData(const ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App information copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About & Information'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share App',
            onPressed: _shareApp,
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Contact Support',
            onPressed: _sendEmail,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header Hero Card matching Logo Theme
                _buildHeaderHero(theme),
                const SizedBox(height: 20),

                // 2. Accordion 1: USE Advance Picture Dictionary
                _buildAccordionCard(
                  theme: theme,
                  title: 'USE Advance Picture Dictionary',
                  subtitle: 'Vision, 15,900+ HD visual cards, and trilingual dictionary features',
                  icon: Icons.photo_library_outlined,
                  iconColor: const Color(0xFF0072FF),
                  initiallyExpanded: _aboutExpanded,
                  onExpansionChanged: (val) => setState(() => _aboutExpanded = val),
                  children: [
                    _buildAboutContent(theme),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Accordion 2: Help & How to Use
                _buildAccordionCard(
                  theme: theme,
                  title: 'Help & How to Use the Picture Dictionary',
                  subtitle: 'Search tips, flashcards, quizzes, and grid picture import',
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF00A86B),
                  initiallyExpanded: _helpExpanded,
                  onExpansionChanged: (val) => setState(() => _helpExpanded = val),
                  children: [
                    _buildHelpContent(theme),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. Accordion 3: Privacy Policy
                _buildAccordionCard(
                  theme: theme,
                  title: 'Privacy Policy',
                  subtitle: 'Data safety, offline cards, permissions, and security',
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF7B2CBF),
                  initiallyExpanded: _privacyExpanded,
                  onExpansionChanged: (val) => setState(() => _privacyExpanded = val),
                  children: [
                    _buildPrivacyContent(theme),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Accordion 4: Usage, Copyright & Disclaimer
                _buildAccordionCard(
                  theme: theme,
                  title: 'Usage, Copyright & Disclaimer',
                  subtitle: 'Intellectual property, permitted use, and developer credits',
                  icon: Icons.gavel_rounded,
                  iconColor: const Color(0xFFE65100),
                  initiallyExpanded: _termsExpanded,
                  onExpansionChanged: (val) => setState(() => _termsExpanded = val),
                  children: [
                    _buildUsageCopyrightContent(theme),
                  ],
                ),
                const SizedBox(height: 24),

                // 6. Footer Signature
                _buildFooterSignature(theme),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderHero(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF041530), // Deep Midnight Navy
            Color(0xFF09316C), // Royal Sapphire Blue (from logo body)
            Color(0xFF0058C8), // Vivid Logo Blue
            Color(0xFF008BE3), // Bright Cerulean Blue
            Color(0xFF00C6FF), // Electric Cyan (from logo banner highlight)
          ],
          stops: [0.0, 0.28, 0.58, 0.82, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0058C8).withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // App Logo with radiant cyan-blue ring matching logo border
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF0066FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C6FF).withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(44),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 82,
                  height: 82,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 82,
                    height: 82,
                    color: const Color(0xFF09316C),
                    child: const Icon(Icons.auto_stories, color: Colors.white, size: 42),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'USE Advance Picture Dictionary',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle Badge matching logo's cyan ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.55)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined, size: 14, color: Color(0xFF00E5FF)),
                SizedBox(width: 6),
                Text(
                  'Visual Flashcards • English • Sindhi • Urdu • 15,900+ Words',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Descriptive Matter
          const Text(
            'A premier visual dictionary combining high-definition educational picture flashcards with comprehensive English meanings, Sindhi & Urdu translations, synonyms, antonyms, and practical usage examples.\nDesigned for learners, TOEFL, IELTS, CSS candidates, teachers, and language enthusiasts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 18),

          // Quick Action buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF09316C),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _shareApp,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.email_outlined, size: 16),
                label: const Text('Contact Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _sendEmail,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF041530),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Companion App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => InterlinkService.instance.openInAdvanceDictionary(context, 'dictionary'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool initiallyExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  // --- Content for Section 1: About USE Advance Picture Dictionary ---
  Widget _buildAboutContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 14),
        const Text(
          'Welcome to USE Advance Picture Dictionary',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'USE Advance Picture Dictionary is an educational visual dictionary designed to revolutionize how students, professionals, and language enthusiasts master vocabulary.\n\n'
          'By uniting high-definition educational picture flashcards with clear English definitions, authentic Sindhi and Urdu translations, comprehensive synonyms, antonyms, and usage examples, the app turns abstract words into memorable visual experiences.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        const SizedBox(height: 16),
        const Text(
          'What USE Advance Picture Dictionary Offers:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildBulletPoint('15,900+ Visual Vocabulary Entries: Every headword paired with an intuitive picture flashcard.'),
        _buildBulletPoint('Visual Memory Anchor: Enhances rapid comprehension and long-term retention for tests & exams.'),
        _buildBulletPoint('Trilingual Knowledge: Clear English definitions with Sindhi and Urdu translations.'),
        _buildBulletPoint('Parts of Speech Categorization: Nouns, Verbs, Adjectives, Adverbs, Idioms, and Phrases clearly tagged.'),
        _buildBulletPoint('Rich Lexical Range: Synonyms (similar words) and Antonyms (opposites) with tap-to-search chips.'),
        _buildBulletPoint('Authentic Context: Real-world example sentences showing practical usage in communication.'),
        _buildBulletPoint('Interactive Visual Quizzes: Timed picture-matching quizzes with instant score tracking.'),
        _buildBulletPoint('Multi-Card Grid Splitter: Import composite images (like 10-card sheets) and auto-crop pictures per word with zero duplicates.'),
        _buildBulletPoint('100% Offline Database: Complete dictionary stored on your device for lightning-fast offline lookups.'),
        _buildBulletPoint('Direct Companion App Interlinking: One-tap access to USE Advance Dictionary for advanced grammar and MCQs.'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0072FF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0072FF).withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.contact_support_outlined, size: 20, color: Color(0xFF0072FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('For feedback, corrections, or picture suggestions:', style: TextStyle(fontSize: 12)),
                    GestureDetector(
                      onTap: _sendEmail,
                      child: const Text(
                        'useadvancedictionary@gmail.com',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0072FF), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Content for Section 2: Help & How to Use ---
  Widget _buildHelpContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 14),
        const Text(
          'Frequently Asked Questions & User Guide',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        _buildFaqItem(
          'How do I search for words in the Picture Dictionary?',
          'Type a word in English, Sindhi, or Urdu into the search bar at the top of the Home screen. The dictionary filters results instantly and displays corresponding picture cards.',
        ),
        _buildFaqItem(
          'How do I view pictures in high definition and zoom in?',
          'Tap any card from the grid to open its Word Detail Screen. Tap the picture card or the "Tap to Zoom" button to launch the full-screen interactive viewer with pinch-to-zoom and pan support.',
        ),
        _buildFaqItem(
          'How do synonyms and antonyms work?',
          'On any word detail page, scroll to the Synonyms and Antonyms sections. Tapping any chip immediately searches and opens that related vocabulary word.',
        ),
        _buildFaqItem(
          'How do I use the Visual Vocabulary Quiz?',
          'Tap the Quiz icon in the top AppBar. The quiz presents an educational picture and asks you to pick the matching word or meaning from multiple choices.',
        ),
        _buildFaqItem(
          'How does the Grid Picture Splitter work?',
          'Tap the Grid icon in the AppBar. Pick a composite image containing multiple cards (such as a 5×2 grid of 10 vocabulary cards). Choose your crop preset ("Center Illustration Only" to automatically trim headers and footers, or "Full Card"), enter or verify the words, and tap "Apply". The app crops each picture separately and assigns it to the word with zero duplicates.',
        ),
        _buildFaqItem(
          'Does the Picture Dictionary work offline?',
          'Yes! The entire dictionary database of over 15,900+ words, definitions, translations, and bundled flashcards is stored locally in SQLite and works completely offline without needing the internet.',
        ),
        _buildFaqItem(
          'How do I listen to the correct pronunciation of words?',
          'Tap the Speaker icon on any word detail page to hear clear, natural English text-to-speech pronunciation.',
        ),
        _buildFaqItem(
          'How does the Companion App interlink work?',
          'Tap "Open in USE Advance Dictionary" on any word card to jump directly to that word in the companion trilingual dictionary app for deeper grammatical analysis and MCQs.',
        ),
        _buildFaqItem(
          'How do I report an error or suggest a missing word/picture?',
          'Email us at useadvancedictionary@gmail.com with the word details. We review suggestions and typically respond within 24 to 48 hours.',
        ),
      ],
    );
  }

  // --- Content for Section 3: Privacy Policy ---
  Widget _buildPrivacyContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Last Updated: 2026', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'USE Advance Picture Dictionary is developed by Badruddin Siddiqui. We are committed to protecting your privacy and providing a safe, clean educational environment.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('Information We Collect'),
        _buildSubParagraph(
          '• Local Pictures & Cards: Any picture cards you import using the Grid Picture Splitter are stored strictly on your local device. They are never uploaded to any remote server.',
        ),
        _buildSubParagraph(
          '• Diagnostic & Performance Data: To improve performance and stability across devices, the App may collect anonymous diagnostic information such as device model, OS version, basic analytics, and crash logs through standard platform tools.',
        ),
        _buildSubParagraph(
          '• No Personal Data Collected: We do NOT collect your name, email, phone number, contacts, private photos, camera stream, microphone audio, precise location, or device credentials. The App requires no registration or user sign-in.',
        ),
        const SizedBox(height: 10),

        _buildSectionHeader('Third-Party Services'),
        _buildSubParagraph(
          'The App may utilize standard platform services including Google Play Services, Firebase Analytics, and Firebase Crashlytics to monitor stability. These services process limited anonymous technical data under their respective privacy policies. We do not sell or trade your data to any third party.',
        ),
        const SizedBox(height: 10),

        _buildSectionHeader('Children’s Privacy & Data Security'),
        _buildSubParagraph(
          'USE Advance Picture Dictionary is an educational resource suitable for learners of all ages. We do not knowingly collect personal data from children under 13. We implement industry-standard safeguards to secure app operations.',
        ),
        const SizedBox(height: 10),

        _buildSectionHeader('Contact Us'),
        _buildSubParagraph(
          'If you have questions regarding this Privacy Policy, please contact: useadvancedictionary@gmail.com',
        ),
      ],
    );
  }

  // --- Content for Section 4: Usage, Copyright & Disclaimer ---
  Widget _buildUsageCopyrightContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 14),

        _buildSectionHeader('Permitted Usage'),
        _buildSubParagraph(
          'Search any vocabulary word to explore picture cards, definitions, examples, synonyms, antonyms, and grammatical categories. You may use this App freely for individual vocabulary building, classroom teaching, academic research, and competitive exam preparation (such as TOEFL, IELTS, and CSS). You may not commercialize, rent, or redistribute the dictionary database without written permission.',
        ),
        const SizedBox(height: 12),

        _buildSectionHeader('Copyright & Intellectual Property Notice'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE65100).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '© 2026 USE Advance Picture Dictionary. All Rights Reserved.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                'All educational visual layouts, compiled picture flashcards, vocabulary definitions, example sentences, synonyms, antonyms, UI components, and software structure inside USE Advance Picture Dictionary are protected by copyright and intellectual property laws.\n\n'
                'No part of this App or database may be mass-copied, modified, redistributed, or reverse engineered without explicit written authorization.',
                style: TextStyle(fontSize: 12.5, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('Disclaimer & Limitation of Liability'),
        _buildSubParagraph(
          'USE Advance Picture Dictionary provides vocabulary definitions, visual flashcards, translations, and examples solely for educational and reference purposes. While diligent effort is made to maintain utmost accuracy, content is provided "as is" without warranty of completeness. The developer is not liable for inadvertent typographical errors, translation nuances, or device compatibility variations.',
        ),
        const SizedBox(height: 14),

        _buildSectionHeader('Developer & Designer Credits'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.brush_rounded, size: 20, color: Color(0xFF0072FF)),
              SizedBox(width: 10),
              Text(
                'Prepared and designed by Badruddin Siddiqui',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helper Widgets ---
  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF00A86B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Q: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0072FF), fontSize: 13.5)),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
      ),
    );
  }

  Widget _buildSubParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, height: 1.45),
      ),
    );
  }

  Widget _buildFooterSignature(ThemeData theme) {
    return Column(
      children: [
        Text(
          'USE Advance Picture Dictionary • Version 1.0.0',
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Prepared and designed by Badruddin Siddiqui',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
