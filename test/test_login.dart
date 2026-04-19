import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== Test de login Neo-Stream ===\n');
  
  final url = Uri.parse('https://neo-stream.eu/app/auth/login');
  
  print('URL: $url');
  print('Method: POST');
  print('Headers:');
  
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'Neo-Stream/1.0.0 (windows; Flutter)',
    'X-App-Client': 'neo-stream-flutter',
    'X-App-Version': '1.0.0',
    'X-App-Platform': 'windows',
  };
  
  headers.forEach((key, value) {
    print('  $key: $value');
  });
  
  final body = {
    'username': 'pecorio',
    'password': 'pecorio91',
  };
  
  print('\nBody:');
  print('  ${json.encode(body)}');
  
  print('\nEnvoi de la requête...\n');
  
  try {
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode(body),
    ).timeout(Duration(seconds: 30));
    
    print('Status Code: ${response.statusCode}');
    print('Headers de réponse:');
    response.headers.forEach((key, value) {
      print('  $key: $value');
    });
    print('\nBody de réponse:');
    print(response.body);
    
    if (response.statusCode == 200) {
      print('\n✅ LOGIN RÉUSSI !');
      final data = json.decode(response.body);
      print('User: ${data['user']['username']}');
    } else {
      print('\n❌ LOGIN ÉCHOUÉ');
    }
    
  } catch (e, stackTrace) {
    print('❌ ERREUR: $e');
    print('\nStack trace:');
    print(stackTrace);
  }
  
  print('\n=== Fin du test ===');
}
