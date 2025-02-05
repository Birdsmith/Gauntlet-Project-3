import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import 'welcome_screen.dart';
import 'language_selection_screen.dart';
import 'proficiency_screen.dart';
import 'native_language_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  final PageController _pageController = PageController();
  final _userService = UserService();
  final _auth = FirebaseAuth.instance;
  int _currentPage = 0;
  String? _nativeLanguage;
  List<String> _targetLanguages = [];
  Map<String, String> _proficiencyLevels = {};
  bool _isSaving = false;

  void _updateNativeLanguage(String code) {
    setState(() {
      _nativeLanguage = code;
    });
  }

  void _updateTargetLanguages(List<String> codes) {
    setState(() {
      _targetLanguages = codes;
    });
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0: // Welcome screen
        return true;
      case 1: // Native language
        return _nativeLanguage != null;
      case 2: // Target languages
        return _targetLanguages.isNotEmpty;
      case 3: // Proficiency
        return _proficiencyLevels.length == _targetLanguages.length;
      default:
        return false;
    }
  }

  Future<void> _completeOnboarding() async {
    if (_nativeLanguage == null ||
        _targetLanguages.isEmpty ||
        _proficiencyLevels.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user found');

      await _userService.createOrUpdateUserProfile(
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        targetLanguages: _targetLanguages,
        proficiencyLevels: _proficiencyLevels,
        nativeLanguage: _nativeLanguage!,
      );
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: ${e.toString()}')),
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

  void _nextPage() {
    if (!_canProceed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please make a selection to continue')),
      );
      return;
    }

    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              const WelcomeScreen(),
              NativeLanguageScreen(
                onLanguageSelected: _updateNativeLanguage,
                selectedLanguage: _nativeLanguage,
              ),
              LanguageSelectionScreen(
                onLanguagesSelected: _updateTargetLanguages,
                selectedLanguages: _targetLanguages,
                userNativeLanguage: _nativeLanguage,
              ),
              ProficiencyScreen(
                onLevelsSelected: (levels) => setState(() => _proficiencyLevels = levels),
                selectedLevels: _proficiencyLevels,
                targetLanguages: _targetLanguages,
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _isSaving ? null : _previousPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  Row(
                    children: List.generate(
                      4,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _nextPage,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentPage == 3 ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 