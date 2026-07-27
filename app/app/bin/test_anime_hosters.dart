import '../lib/services/video_extractor.dart';

class TestAnimeItem {
  final String title;
  final String player;
  final String url;
  TestAnimeItem(this.title, this.player, this.url);
}

void main() async {
  final testUrls = [
    TestAnimeItem('Nana', 'sibnet', 'https://video.sibnet.ru/shell.php?videoid=4876753'),
    TestAnimeItem('Nana', 'vidmoly', 'https://vidmoly.to/embed-ijh3rj9jlz8s.html'),
    TestAnimeItem('Nana', 'movearnpre', 'https://movearnpre.com/embed/zdrlcrckv5ne'),
    TestAnimeItem('Nana', 'sendvid', 'https://sendvid.com/embed/od7q02lx'),
    TestAnimeItem('Nana', 'sibnet', 'https://video.sibnet.ru/shell.php?videoid=4876754'),
    TestAnimeItem('Nana', 'vidmoly', 'https://vidmoly.to/embed-bevy0s7e3jrt.html'),
    TestAnimeItem('Nana', 'movearnpre', 'https://movearnpre.com/embed/l7vyntp0xduh'),
    TestAnimeItem('Nana', 'sendvid', 'https://sendvid.com/embed/9nvbyxiv'),
    TestAnimeItem('Nana', 'sibnet', 'https://video.sibnet.ru/shell.php?videoid=4876755'),
    TestAnimeItem('Nana', 'vidmoly', 'https://vidmoly.to/embed-nib6799z2n4c.html'),
    TestAnimeItem('Nana', 'movearnpre', 'https://movearnpre.com/embed/8tipuy497ii5'),
    TestAnimeItem('Nana', 'sendvid', 'https://sendvid.com/embed/w4shn5f7'),
    TestAnimeItem('Nana', 'sibnet', 'https://video.sibnet.ru/shell.php?videoid=4876757'),
    TestAnimeItem('Nana', 'vidmoly', 'https://vidmoly.to/embed-nj8tggs1eksg.html'),
    TestAnimeItem('Nana', 'movearnpre', 'https://movearnpre.com/embed/dv7irtpdaguf'),
    TestAnimeItem('Nana', 'sendvid', 'https://sendvid.com/embed/n93w810x'),
    TestAnimeItem('Nana', 'sibnet', 'https://video.sibnet.ru/shell.php?videoid=4876763'),
    TestAnimeItem('Nana', 'vidmoly', 'https://vidmoly.to/embed-3rtvn95izglu.html'),
    TestAnimeItem('Nana', 'movearnpre', 'https://movearnpre.com/embed/dxwy4xh0dlk1'),
    TestAnimeItem('Nana', 'sendvid', 'https://sendvid.com/embed/e4unjt9b'),
    TestAnimeItem('Nana', 'sibnet', 'https://video.sibnet.ru/shell.php?videoid=4876764'),
    TestAnimeItem('Nana', 'vidmoly', 'https://vidmoly.to/embed-5k4lwhrcjngl.html'),
    TestAnimeItem('Nana', 'movearnpre', 'https://movearnpre.com/embed/rbhxhk88wriv'),
    TestAnimeItem('Nana', 'sendvid', 'https://sendvid.com/embed/5njufzz5'),
    TestAnimeItem('Nana', 'sibnet', 'https://video.sibnet.ru/shell.php?videoid=4876766'),
    TestAnimeItem('Nana', 'vidmoly', 'https://vidmoly.to/embed-x6rym6d2cby4.html'),
    TestAnimeItem('Nana', 'movearnpre', 'https://movearnpre.com/embed/oci1w3dq94qj'),
    TestAnimeItem('Nana', 'sendvid', 'https://sendvid.com/embed/9h5sxybz'),
    TestAnimeItem('Nana', 'sibnet', 'https://video.sibnet.ru/shell.php?videoid=4876770'),
    TestAnimeItem('Nana', 'vidmoly', 'https://vidmoly.to/embed-835xen5n3vhe.html'),
  ];

  print('=== TESTING FLUTTER NATIVE EXTRACTOR ON ANIME DB LINKS ===');
  int success = 0;
  int fail = 0;

  for (final item in testUrls) {
    print('\n--------------------------------------------------');
    print('Anime: ' + item.title + ' | Player: ' + item.player + ' | URL: ' + item.url);
    final res = await VideoExtractor.extract(item.url);
    if (res['success'] == true && res['video_url'] != null) {
      success++;
      print('SUCCESS! Video URL: ' + res['video_url'].toString());
      print('Type: ' + res['type'].toString() + ' | Server: ' + res['server'].toString());
      if (res['qualities'] != null && (res['qualities'] as List).isNotEmpty) {
        print('Qualities: ' + res['qualities'].toString());
      }
    } else {
      fail++;
      print('FAILED: ' + res['error'].toString());
    }
  }

  print('\n==================================================');
  print('SUMMARY: Success: ' + success.toString() + ' / ' + testUrls.length.toString());
}
