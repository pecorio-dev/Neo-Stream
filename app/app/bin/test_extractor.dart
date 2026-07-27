import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../lib/services/video_extractor.dart';

void main() async {
  final testUrls = [
    'https://uqload.is/embed-d3dvpy0o12uc.html',
    'https://vidzy.org/embed-abc123xyz.html',
    'https://1.multiup.us/download/12345',
    'https://kakaflix.lol/watch/12345',
    'https://voe.sx/e/xyz123',
    'https://do7go.com/e/abc123xyz',
    'https://filemoon.sx/e/file123',
  ];

  print('=== TESTING FLUTTER VIDEO EXTRACTOR ===');
  for (final url in testUrls) {
    print('\nTesting URL: $url');
    final res = await VideoExtractor.extract(url);
    print('Result: $res');
  }
}
