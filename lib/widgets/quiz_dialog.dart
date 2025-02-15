import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import 'dart:io';

class QuizDialog extends StatefulWidget {
  final QuizQuestion question;

  const QuizDialog({
    Key? key,
    required this.question,
  }) : super(key: key);

  @override
  State<QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<QuizDialog> {
  String? selectedAnswer;
  bool hasSubmitted = false;

  TextStyle get _japaneseTextStyle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: Platform.isIOS ? '.SF UI Text' : 'Noto Sans JP',
    fontFamilyFallback: Platform.isIOS 
      ? ['Hiragino Sans', 'Hiragino Kaku Gothic ProN'] 
      : ['Noto Sans CJK JP', 'DroidSansFallback'],
    height: 1.3,
    letterSpacing: 0.5,
  );

  TextStyle get _answerTextStyle => TextStyle(
    fontSize: 16,
    fontFamily: Platform.isIOS ? '.SF UI Text' : 'Noto Sans JP',
    fontFamilyFallback: Platform.isIOS 
      ? ['Hiragino Sans', 'Hiragino Kaku Gothic ProN'] 
      : ['Noto Sans CJK JP', 'DroidSansFallback'],
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final QuizService quizService = QuizService();
    final List<String> shuffledAnswers = quizService.getShuffledAnswers(widget.question);

    return AlertDialog(
      title: const Text('Video Quiz'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.question.question,
              style: _japaneseTextStyle,
            ),
            const SizedBox(height: 20),
            ...shuffledAnswers.map((answer) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ChoiceChip(
                label: Text(
                  answer,
                  style: _answerTextStyle,
                ),
                selected: selectedAnswer == answer,
                onSelected: hasSubmitted ? null : (selected) {
                  setState(() {
                    selectedAnswer = selected ? answer : null;
                  });
                },
                backgroundColor: hasSubmitted
                    ? (answer == widget.question.correctAnswer
                        ? Colors.green.withOpacity(0.2)
                        : (answer == selectedAnswer
                            ? Colors.red.withOpacity(0.2)
                            : null))
                    : null,
              ),
            )).toList(),
            if (hasSubmitted) ...[
              const SizedBox(height: 16),
              Text(
                selectedAnswer == widget.question.correctAnswer
                    ? 'Correct! 🎉'
                    : 'Incorrect. The correct answer was: ${widget.question.correctAnswer}',
                style: TextStyle(
                  color: selectedAnswer == widget.question.correctAnswer
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontFamily: Platform.isIOS ? '.SF UI Text' : 'Noto Sans JP',
                  fontFamilyFallback: Platform.isIOS 
                    ? ['Hiragino Sans', 'Hiragino Kaku Gothic ProN'] 
                    : ['Noto Sans CJK JP', 'DroidSansFallback'],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: hasSubmitted
              ? () => Navigator.of(context).pop()
              : (selectedAnswer == null
                  ? null
                  : () {
                      setState(() {
                        hasSubmitted = true;
                      });
                    }),
          child: Text(hasSubmitted ? 'Close' : 'Submit'),
        ),
      ],
    );
  }
} 