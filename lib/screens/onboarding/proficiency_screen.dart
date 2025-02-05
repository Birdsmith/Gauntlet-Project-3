import 'package:flutter/material.dart';

class ProficiencyScreen extends StatelessWidget {
  final Function(Map<String, String>) onLevelsSelected;
  final Map<String, String> selectedLevels;
  final List<String> targetLanguages;

  const ProficiencyScreen({
    super.key,
    required this.onLevelsSelected,
    required this.selectedLevels,
    required this.targetLanguages,
  });

  final List<String> _levels = const ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  String _getLanguageName(String code) {
    final languageNames = {
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
    };
    return languageNames[code] ?? code.toUpperCase();
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
            'What\'s your proficiency level?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your level for each language',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: targetLanguages.length,
              separatorBuilder: (context, index) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final language = targetLanguages[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getLanguageName(language),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _levels.map((level) {
                        final isSelected = selectedLevels[language] == level;
                        return ChoiceChip(
                          label: Text(level),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              final newLevels = Map<String, String>.from(selectedLevels);
                              newLevels[language] = level;
                              onLevelsSelected(newLevels);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 