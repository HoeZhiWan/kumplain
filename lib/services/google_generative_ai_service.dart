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
      model: 'gemini-2.0-flash',
      generationConfig: GenerationConfig(
        temperature: 0,
        responseMimeType: 'application/json',
        responseSchema: Schema.object(properties: {
          'tag': Schema.string(description: "Tag for the image"),
          'description': Schema.string(description: "Description of the complaint"),
          'title': Schema.string(description: "Title of the complaint"),
        })
      ),
    );
  }

  Future<Map<String, String>> analyzeImage(XFile image, List<String> tags) async {
    try{
      final prompt =
        'The following image is a complaint.'
        'Provide a short description and title of the complaint.'
        'Determine a tag that are best applied to the image.'
        'If the image is not a complaint, provide an empty description and title, and the tag selected should be "Spam" instead.'
        'The tags available are: ${tags.join(', ')}';
      final bytes = await image.readAsBytes();
      
      final content = Content.multi([
        DataPart("image/*", bytes),
        TextPart(prompt),
      ]);

      final responses = await _model.generateContent([content]);

      if (responses.text == null) {
        throw Exception('No response from model');
      }

      print(responses.text!);

      if(jsonDecode(responses.text!) case {'tag' : String tag , 'description' : String description, 'title' : String title}) {
        return {'tag': tag, 'description': description, 'title': title};
      } else {
        throw Exception('Invalid response format');
      }
    }
    catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }
}