import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class GoogleGenerativeAIService {
  late final GenerativeModel _model;

  GoogleGenerativeAIService() {
    final apiKey = dotenv.get('GEMINI_API_KEY');
    if (apiKey.isEmpty) {
      throw Exception('API key not found in .env file');
    }
    _model = GenerativeModel(
      apiKey: apiKey,
      model: 'gemini-1.5-flash',
      generationConfig: GenerationConfig(
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: Schema.object(properties: {
          'tag': Schema.string(description: "Tag for the image"),
          'description': Schema.string(description: "Description of the image"),
        })
      ),
    );
  }

  Future<Map<String, String>> analyzeImage(XFile image, List<String> tags) async {
    try{
      final prompt =
        'The following image is a complaint.'
        'Provide a short description of what happened in the image.'
        'Determine a tag that are best applied to the image.'
        'If the image is not a complaint, the tag selected should be "Spam" instead.'
        'The tags available are: ${tags.join(', ')}';
        'Provide your response as a JSON object with the following format: {"tag": "", "description": ""}'
        'Do not return your result as Markdown.';
      final bytes = await image.readAsBytes();
      final content = Content.multi([
        TextPart(prompt),
        DataPart("image/*", bytes),
      ]);

      final responses = await _model.generateContent([content]);

      if (responses.text == null) {
        throw Exception('No response from model');
      }

      if(jsonDecode(responses.text!) case {'tag' : String tag , 'description' : String description}){
        return {'tag': tag, 'description': description};
      } else {
        throw Exception('Invalid response format');
      }
    }
    catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }
}