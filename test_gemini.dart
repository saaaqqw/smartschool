import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  const apiKey = 'AIzaSyAUWFA2GPlaPGw6kzjX80xptLwOwzBeqlM';
  final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
  
  try {
    print('Testing gemini-1.5-flash...');
    final response = await model.generateContent([Content.text('Hello')]);
    print('Success: ${response.text}');
  } catch (e) {
    print('Error with gemini-1.5-flash: $e');
  }

  // Unfortunately, the current SDK doesn't have a direct listModels() yet in the public interface 
  // that is easily callable without more boilerplate.
  // But we can try common names.
}
