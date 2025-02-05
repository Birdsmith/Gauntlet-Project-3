import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../onboarding/language_selection_screen.dart';
import '../onboarding/proficiency_screen.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final UserService _userService = UserService();
  String? _nativeLanguage;
  List<String> _targetLanguages = [];
  Map<String, String> _proficiencyLevels = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile != null && mounted) {
        setState(() {
          _nativeLanguage = userProfile.nativeLanguage;
          _targetLanguages = userProfile.targetLanguages;
          _proficiencyLevels = userProfile.proficiencyLevels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile == null) throw Exception('User profile not found');

      await _userService.createOrUpdateUserProfile(
        email: userProfile.email,
        displayName: userProfile.displayName,
        targetLanguages: _targetLanguages,
        proficiencyLevels: _proficiencyLevels,
        nativeLanguage: _nativeLanguage ?? userProfile.nativeLanguage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Settings'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Target Languages'),
            subtitle: Text(
              _targetLanguages.isEmpty
                  ? 'No languages selected'
                  : _targetLanguages.join(', ').toUpperCase(),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push<List<String>>(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Select Languages')),
                    body: LanguageSelectionScreen(
                      onLanguagesSelected: (languages) {
                        Navigator.pop(context, languages);
                      },
                      selectedLanguages: _targetLanguages,
                      userNativeLanguage: _nativeLanguage,
                    ),
                  ),
                ),
              );

              if (result != null && mounted) {
                setState(() {
                  _targetLanguages = result;
                  // Remove proficiency levels for removed languages
                  _proficiencyLevels = Map.fromEntries(
                    _proficiencyLevels.entries.where(
                      (entry) => result.contains(entry.key),
                    ),
                  );
                });
              }
            },
          ),
          if (_targetLanguages.isNotEmpty) ...[
            const Divider(),
            ListTile(
              title: const Text('Proficiency Levels'),
              subtitle: Text(
                _proficiencyLevels.entries
                    .map((e) => '${e.key.toUpperCase()}: ${e.value}')
                    .join(', '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.push<Map<String, String>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('Set Proficiency Levels')),
                      body: ProficiencyScreen(
                        onLevelsSelected: (levels) {
                          Navigator.pop(context, levels);
                        },
                        selectedLevels: _proficiencyLevels,
                        targetLanguages: _targetLanguages,
                      ),
                    ),
                  ),
                );

                if (result != null && mounted) {
                  setState(() {
                    _proficiencyLevels = result;
                  });
                }
              },
            ),
          ],
        ],
      ),
    );
  }
} 