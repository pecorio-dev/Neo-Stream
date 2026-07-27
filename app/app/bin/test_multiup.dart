import 'package:http/http.dart' as http;

void main() async {
  final url1 = 'https://1.multiup.us/player/embed_player.php?vid=ll2joQ8WEI5R&autoplay=no';
  final resp1 = await http.get(Uri.parse(url1), headers: {'User-Agent': 'Mozilla/5.0'});
  final m = RegExp(r"window\.location\.replace\s*\(\s*'([^']+)'").firstMatch(resp1.body);
  final redirectUrl = m!.group(1)!;

  print('Redirecting to: $redirectUrl');
  final resp2 = await http.get(Uri.parse(redirectUrl), headers: {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://1.multiup.us/'});
  print('Page 2 status: ${resp2.statusCode}');
  print('Page 2 body:\n${resp2.body}');
}
