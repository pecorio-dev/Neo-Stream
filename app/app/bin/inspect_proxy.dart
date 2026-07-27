import 'package:http/http.dart' as http;

void main() async {
  final urls = [
    'https://1.multiup.us/player/embed_player.php?vid=ll2joQ8WEI5R&autoplay=no',
    'https://kokoflix.lol/tokyo_go.php?id=BG0JxVOEZeh69opz1WPSa',
    'https://kokoflix.lol/grandline_go.php?id=OaWVEJf51YLzijMdrkoNg',
    'https://kakaflix.lol/doood/newPlayer.php?id=2e7b3f24-3a0a-49a2-8d01-50bb0a42855f',
  ];

  for (final url in urls) {
    print('\n==================================================');
    print('Testing URL: $url');
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'Referer': 'https://kakaflix.lol/',
        },
      );
      print('Status: ${resp.statusCode}');
      print('Length: ${resp.body.length}');
      final body = resp.body;
      print('Body snippet:\n${body.substring(0, body.length > 800 ? 800 : body.length)}');
    } catch (e) {
      print('Error: $e');
    }
  }
}
