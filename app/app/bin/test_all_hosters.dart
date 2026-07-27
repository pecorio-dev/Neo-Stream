import '../lib/services/video_extractor.dart';

class TestItem {
  final String player;
  final String url;
  TestItem(this.player, this.url);
}

void main() async {
  final testUrls = [
    TestItem('unknown', 'https://vidzy.cc/embed-q0b3csk2afzn.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-byjq5clt4b80.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-idg99smuqujd.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-lmsjky3xjdtl.html'),
    TestItem('unknown', 'https://do7go.com/e/ddaylfknq435'),
    TestItem('unknown', 'https://uqload.net/embed-oau17v6bwbyj.html'),
    TestItem('unknown', 'https://1.multiup.us/player/embed_player.php?vid=ll2joQ8WEI5R&autoplay=no'),
    TestItem('unknown', 'https://vidzy.cc/embed-lpaohp58dgut.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-xld6e4wqlckk.html'),
    TestItem('unknown', 'https://vidzy.live/embed-5a3l97qrjvhh.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-s2xqfddvnh5w.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-2562a7ix86ky.html'),
    TestItem('unknown', 'https://uqload.is/embed-8ig87dugvx95.html'),
    TestItem('unknown', 'https://dood.li/e/s6oitybs7ys0'),
    TestItem('unknown', 'https://vidaraa.cc/e/5jae5QSMrQtXC'),
    TestItem('unknown', 'https://vidzy.cc/embed-ynfzelunw1mo.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-qrdd1019yf40.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-f8uuxjvhokvc.html'),
    TestItem('unknown', 'https://vidzy.cc/embed-ne3r1wl2owxx.html'),
    TestItem('unknown', 'https://uqload.is/embed-1o7gae243ix9.html'),
    TestItem('unknown', 'https://kokoflix.lol/tokyo_go.php?id=BG0JxVOEZeh69opz1WPSa'),
    TestItem('unknown', 'https://kokoflix.lol/grandline_go.php?id=OaWVEJf51YLzijMdrkoNg'),
    TestItem('unknown', 'https://vidzy.live/embed-6k9txwi8hi76.html'),
    TestItem('unknown', 'https://uqload.is/embed-enoxwi3432mu.html'),
    TestItem('unknown', 'https://kakaflix.lol/doood/newPlayer.php?id=2e7b3f24-3a0a-49a2-8d01-50bb0a42855f'),
  ];

  print('=== TESTING FLUTTER NATIVE EXTRACTOR ON REAL DB LINKS ===');
  int success = 0;
  int fail = 0;

  for (final item in testUrls) {
    print('\n--------------------------------------------------');
    print('Player: ' + item.player + ' | URL: ' + item.url);
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
