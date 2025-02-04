import 'package:flutter/material.dart';

class ProficiencyScreen extends StatefulWidget {
  final Function(String) onLevelSelected;
  final String? selectedLevel;

  const ProficiencyScreen({
    super.key,
    required this.onLevelSelected,
    this.selectedLevel,
  });

  @override
  State<ProficiencyScreen> createState() => _ProficiencyScreenState();
}

class _ProficiencyScreenState extends State<ProficiencyScreen> {
  final List<Map<String, String>> _levels = [
    {
      'code': 'A1',
      'name': 'Beginner',
      'description': 'Basic phrases and expressions for everyday situations',
    },
    {
      'code': 'A2',
      'name': 'Elementary',
      'description': 'Simple conversations and routine tasks',
    },
    {
      'code': 'B1',
      'name': 'Intermediate',
      'description': 'Clear communication on familiar topics',
    },
    {
      'code': 'B2',
      'name': 'Upper Intermediate',
      'description': 'Complex discussions and abstract topics',
    },
    {
      'code': 'C1',
      'name': 'Advanced',
      'description': 'Fluent expression and understanding of nuances',
    },
    {
      'code': 'C2',
      'name': 'Mastery',
      'description': 'Near-native level understanding and expression',
    },
  ];

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
            'Select your current level in the language',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: _levels.length,
              itemBuilder: (context, index) {
                final level = _levels[index];
                final isSelected = level['code'] == widget.selectedLevel;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => widget.onLevelSelected(level['code']!),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  level['code']!,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                level['name']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            level['description']!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
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