import 'package:flutter/material.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final Function(List<String>) onLanguagesSelected;
  final List<String> selectedLanguages;
  final String? userNativeLanguage;

  const LanguageSelectionScreen({
    super.key,
    required this.onLanguagesSelected,
    required this.selectedLanguages,
    this.userNativeLanguage,
  });

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  // Language names in different languages
  final Map<String, Map<String, String>> _languageNames = {
    'en': {
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'ru': 'Russian',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'bn': 'Bengali',
      'tr': 'Turkish',
      'vi': 'Vietnamese',
      'nl': 'Dutch',
      'pl': 'Polish',
      'th': 'Thai',
      'id': 'Indonesian',
    },
    'es': {
      'es': 'Español',
      'fr': 'Francés',
      'de': 'Alemán',
      'it': 'Italiano',
      'pt': 'Portugués',
      'ja': 'Japonés',
      'ko': 'Coreano',
      'zh': 'Chino',
      'ru': 'Ruso',
      'ar': 'Árabe',
      'hi': 'Hindi',
      'bn': 'Bengalí',
      'tr': 'Turco',
      'vi': 'Vietnamita',
      'nl': 'Holandés',
      'pl': 'Polaco',
      'th': 'Tailandés',
      'id': 'Indonesio',
    },
    'fr': {
      'es': 'Espagnol',
      'fr': 'Français',
      'de': 'Allemand',
      'it': 'Italien',
      'pt': 'Portugais',
      'ja': 'Japonais',
      'ko': 'Coréen',
      'zh': 'Chinois',
      'ru': 'Russe',
      'ar': 'Arabe',
      'hi': 'Hindi',
      'bn': 'Bengali',
      'tr': 'Turc',
      'vi': 'Vietnamien',
      'nl': 'Néerlandais',
      'pl': 'Polonais',
      'th': 'Thaïlandais',
      'id': 'Indonésien',
    },
    'de': {
      'es': 'Spanisch',
      'fr': 'Französisch',
      'de': 'Deutsch',
      'it': 'Italienisch',
      'pt': 'Portugiesisch',
      'ja': 'Japanisch',
      'ko': 'Koreanisch',
      'zh': 'Chinesisch',
      'ru': 'Russisch',
      'ar': 'Arabisch',
      'hi': 'Hindi',
      'bn': 'Bengalisch',
      'tr': 'Türkisch',
      'vi': 'Vietnamesisch',
      'nl': 'Niederländisch',
      'pl': 'Polnisch',
      'th': 'Thailändisch',
      'id': 'Indonesisch',
    },
    'it': {
      'es': 'Spagnolo',
      'fr': 'Francese',
      'de': 'Tedesco',
      'it': 'Italiano',
      'pt': 'Portoghese',
      'ja': 'Giapponese',
      'ko': 'Coreano',
      'zh': 'Cinese',
      'ru': 'Russo',
      'ar': 'Arabo',
      'hi': 'Hindi',
      'bn': 'Bengalese',
      'tr': 'Turco',
      'vi': 'Vietnamita',
      'nl': 'Olandese',
      'pl': 'Polacco',
      'th': 'Tailandese',
      'id': 'Indonesiano',
    },
    'pt': {
      'es': 'Espanhol',
      'fr': 'Francês',
      'de': 'Alemão',
      'it': 'Italiano',
      'pt': 'Português',
      'ja': 'Japonês',
      'ko': 'Coreano',
      'zh': 'Chinês',
      'ru': 'Russo',
      'ar': 'Árabe',
      'hi': 'Hindi',
      'bn': 'Bengali',
      'tr': 'Turco',
      'vi': 'Vietnamita',
      'nl': 'Holandês',
      'pl': 'Polonês',
      'th': 'Tailandês',
      'id': 'Indonésio',
    },
    'ja': {
      'es': 'スペイン語',
      'fr': 'フランス語',
      'de': 'ドイツ語',
      'it': 'イタリア語',
      'pt': 'ポルトガル語',
      'ja': '日本語',
      'ko': '韓国語',
      'zh': '中国語',
      'ru': 'ロシア語',
      'ar': 'アラビア語',
      'hi': 'ヒンディー語',
      'bn': 'ベンガル語',
      'tr': 'トルコ語',
      'vi': 'ベトナム語',
      'nl': 'オランダ語',
      'pl': 'ポーランド語',
      'th': 'タイ語',
      'id': 'インドネシア語',
    },
    // Add more languages as needed
  };

  final List<Map<String, String>> _languages = [
    {'code': 'es', 'flag': '🇪🇸'},
    {'code': 'fr', 'flag': '🇫🇷'},
    {'code': 'de', 'flag': '🇩🇪'},
    {'code': 'it', 'flag': '🇮🇹'},
    {'code': 'pt', 'flag': '🇵🇹'},
    {'code': 'ja', 'flag': '🇯🇵'},
    {'code': 'ko', 'flag': '🇰🇷'},
    {'code': 'zh', 'flag': '🇨🇳'},
    {'code': 'ru', 'flag': '🇷🇺'},
    {'code': 'ar', 'flag': '🇸🇦'},
    {'code': 'hi', 'flag': '🇮🇳'},
    {'code': 'bn', 'flag': '🇧🇩'},
    {'code': 'tr', 'flag': '🇹🇷'},
    {'code': 'vi', 'flag': '🇻🇳'},
    {'code': 'nl', 'flag': '🇳🇱'},
    {'code': 'pl', 'flag': '🇵🇱'},
    {'code': 'th', 'flag': '🇹🇭'},
    {'code': 'id', 'flag': '🇮🇩'},
  ];

  String _getLanguageName(String languageCode) {
    final nativeLanguage = widget.userNativeLanguage ?? 'en';
    return _languageNames[nativeLanguage]?[languageCode] ?? 
           _languageNames['en']?[languageCode] ?? 
           languageCode.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(
            'What languages do you want to learn?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select one or more languages to focus on',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          if (widget.selectedLanguages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: widget.selectedLanguages.map((code) {
                return Chip(
                  label: Text(_getLanguageName(code)),
                  onDeleted: () {
                    final updatedLanguages = List<String>.from(widget.selectedLanguages)
                      ..remove(code);
                    widget.onLanguagesSelected(updatedLanguages);
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final language = _languages[index];
                final isSelected = widget.selectedLanguages.contains(language['code']);

                return InkWell(
                  onTap: () {
                    final updatedLanguages = List<String>.from(widget.selectedLanguages);
                    if (isSelected) {
                      updatedLanguages.remove(language['code']);
                    } else {
                      updatedLanguages.add(language['code']!);
                    }
                    widget.onLanguagesSelected(updatedLanguages);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? Theme.of(context).primaryColor.withAlpha(26)
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              language['flag']!,
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getLanguageName(language['code']!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.check_circle,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 