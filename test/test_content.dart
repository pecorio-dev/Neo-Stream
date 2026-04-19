import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== Test de chargement du contenu ===\n');
  
  // D'abord, login pour obtenir les credentials
  print('1. Login...');
  final loginUrl = Uri.parse('https://neo-stream.eu/app/auth/login');
  final loginResponse = await http.post(
    loginUrl,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-App-Client': 'neo-stream-flutter',
      'X-App-Version': '1.0.0',
      'X-App-Platform': 'windows',
    },
    body: json.encode({
      'username': 'pecorio',
      'password': 'pecorio91',
    }),
  ).timeout(Duration(seconds: 30));
  
  if (loginResponse.statusCode != 200) {
    print('❌ Login échoué: ${loginResponse.statusCode}');
    return;
  }
  
  final loginData = json.decode(loginResponse.body);
  final integrityToken = loginData['security']['integrity_token'];
  print('✅ Login réussi, token obtenu\n');
  
  // Test 2: Charger le home
  print('2. Test endpoint /content/home...');
  final homeUrl = Uri.parse('https://neo-stream.eu/app/content/home');
  
  final credentials = base64Encode(utf8.encode('pecorio:pecorio91'));
  
  try {
    final homeResponse = await http.get(
      homeUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Basic $credentials',
        'X-App-Client': 'neo-stream-flutter',
        'X-App-Version': '1.0.0',
        'X-App-Platform': 'windows',
        'X-App-Integrity': integrityToken,
      },
    ).timeout(Duration(seconds: 30));
    
    print('Status: ${homeResponse.statusCode}');
    
    if (homeResponse.statusCode == 200) {
      final data = json.decode(homeResponse.body);
      print('✅ Contenu chargé !');
      print('Sections: ${data.keys.toList()}');
    } else {
      print('❌ Erreur ${homeResponse.statusCode}');
      print('Body: ${homeResponse.body}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
  
  // Test 3: Charger la liste
  print('\n3. Test endpoint /content/list...');
  final listUrl = Uri.parse('https://neo-stream.eu/app/content/list?page=1&per_page=10');
  
  try {
    final listResponse = await http.get(
      listUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Basic $credentials',
        'X-App-Client': 'neo-stream-flutter',
        'X-App-Version': '1.0.0',
        'X-App-Platform': 'windows',
        'X-App-Integrity': integrityToken,
      },
    ).timeout(Duration(seconds: 30));
    
    print('Status: ${listResponse.statusCode}');
    
    if (listResponse.statusCode == 200) {
      final data = json.decode(listResponse.body);
      print('✅ Liste chargée !');
      print('Items: ${data['items']?.length ?? 0}');
    } else {
      print('❌ Erreur ${listResponse.statusCode}');
      print('Body: ${listResponse.body.substring(0, 500)}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
  
  print('\n=== Fin des tests ===');
}
