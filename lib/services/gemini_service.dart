import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static String? apiKey = dotenv.env['GEMINI_API_KEY'];
  static const String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  
  static Future<String> generatePatternBreakdown(List<Map<String, dynamic>> wrongWords) async {
    if (apiKey == null) {
      return 'API key not configured. Please set GEMINI_API_KEY in your .env file.';
    }
    
    if (wrongWords.isEmpty) {
      return 'Not enough data to generate a pattern breakdown. Encourage your child to practice more.';
    }
    
    try {
      // Format the wrong words data for the prompt
      final formattedData = wrongWords.map((word) {
        return '- Word: ${word['word']}, Practice Type: ${word['practiceType']}';
      }).join('\n');
      
      // Create the prompt for Gemini API
      final prompt = '''
      You are an expert speech therapist analyzing a child's speech patterns based on their incorrect words.
      Here is a list of words the child has had trouble with:
      
      $formattedData
      
      Based on this data, provide a brief analysis (3-4 sentences) of potential speech patterns or issues the child might be struggling with.
      Focus on phonetic patterns, letter reversals, or other common speech development challenges.
      Write your response as if you're explaining this to the child's parent, using clear, non-technical language.
      ''';
      
      // Prepare the request body
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 200,
        }
      };
      
      // Make the API call
      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final candidates = data['candidates'] as List;
        if (candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List;
          if (parts.isNotEmpty) {
            return parts[0]['text'] as String;
          }
        }
        return 'Failed to generate pattern breakdown.';
      } else {
        print('API error: ${response.statusCode}: ${response.body}');
        return 'Error generating pattern breakdown. Please try again later.';
      }
    } catch (e) {
      print('Error calling Gemini API: $e');
      return 'The child appears to be struggling with certain speech patterns. Please consult with a speech therapist for a professional assessment.';
    }
  }
} 