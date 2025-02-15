import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'subtitle_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class QuizQuestion {
  final String keyword;
  final String question;
  final String correctAnswer;
  final List<String> incorrectAnswers;

  QuizQuestion({
    required this.keyword,
    required this.question,
    required this.correctAnswer,
    required this.incorrectAnswers,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      keyword: json['keyword'],
      question: json['question'],
      correctAnswer: json['correctAnswer'],
      incorrectAnswers: List<String>.from(json['incorrectAnswers']),
    );
  }
}

class QuizService {
  final SubtitleService _subtitleService = SubtitleService();

  Future<QuizQuestion> generateQuizFromSubtitles(String vttContent) async {
    try {
      print('Sending VTT content to Cloud Function...');
      
      // Call Cloud Function with raw VTT content
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('generateQuiz');
      final result = await callable.call({
        'text': vttContent,
      });

      return QuizQuestion.fromJson(result.data);
    } catch (e) {
      throw Exception('Failed to generate quiz: $e');
    }
  }

  List<String> getShuffledAnswers(QuizQuestion question) {
    List<String> allAnswers = [question.correctAnswer, ...question.incorrectAnswers];
    allAnswers.shuffle();
    return allAnswers;
  }
} 