import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://strm7.uqload.is/hls2/04/04476/d3dvpy0o12uc_n/master.m3u8?t=w_UvwriHh-KXuGrtIpYj6QAiFJxzoPaURP6XOnT9p9M&s=1785139839&e=43200&v=1007372&i=0.0&sp=0';
  final headers = {
    'Referer': 'https://uqload.is/',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  };

  print('Fetching m3u8 master...');
  final resp = await http.get(Uri.parse(url), headers: headers);
  print('Status code: ${resp.statusCode}');
  print('Body: ${resp.body}');
}
