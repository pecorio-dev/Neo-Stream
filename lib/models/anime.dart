import 'dart:convert';
import 'package:flutter/foundation.dart';

class Anime {
  final int id;
  final String animeId;
  final String url;
  final String title;
  final String? titleAlt;
  final String? synopsis;
  final List<String> genres;
  final String? posterUrl;
  final Map<int, AnimeSeason> seasons;
  final int totalSeasons;
  final int totalEpisodes;
  final String contentType;
  final bool isAnime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Anime({
    required this.id,
    required this.animeId,
    required this.url,
    required this.title,
    this.titleAlt,
    this.synopsis,
    required this.genres,
    this.posterUrl,
    required this.seasons,
    required this.totalSeasons,
    required this.totalEpisodes,
    this.contentType = 'anime',
    this.isAnime = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasPoster => posterUrl != null && posterUrl!.isNotEmpty;

  factory Anime.fromJson(Map<String, dynamic> json) {
    // Parser les saisons
    final seasonsData = json['seasons'];
    final seasons = <int, AnimeSeason>{};
    
    if (seasonsData != null && seasonsData is! List) {
      // Si c'est un Map (objet JSON avec clés numériques)
      if (seasonsData is Map) {
        try {
          seasonsData.forEach((key, value) {
            if (value == null) return; // Skip null values
            
            final seasonNum = int.tryParse(key.toString());
            if (seasonNum != null) {
              try {
                // Convertir value en Map<String, dynamic>
                Map<String, dynamic> seasonMap;
                if (value is Map<String, dynamic>) {
                  seasonMap = value;
                } else if (value is Map) {
                  // Convertir Map générique en Map<String, dynamic>
                  seasonMap = Map<String, dynamic>.from(value);
                } else {
                  return; // Skip si ce n'est pas un Map
                }
                
                seasons[seasonNum] = AnimeSeason.fromJson(seasonMap);
              } catch (e) {
                debugPrint('[Anime] Erreur parsing saison $seasonNum: $e');
              }
            }
          });
        } catch (e) {
          debugPrint('[Anime] Erreur parsing seasons: $e');
        }
      }
    }
    // Si c'est un tableau vide ou null, on laisse seasons vide

    // Parser les genres (peut être une string JSON, une liste, ou une string avec virgules)
    List<String> genresList = [];
    final genresData = json['genres'];
    
    if (genresData is List) {
      // Si c'est une liste, traiter chaque élément
      for (var item in genresData) {
        if (item is String) {
          // Si l'élément contient des virgules, le split
          if (item.contains(',')) {
            genresList.addAll(
              item.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty)
            );
          } else {
            final trimmed = item.trim();
            if (trimmed.isNotEmpty) {
              genresList.add(trimmed);
            }
          }
        }
      }
    } else if (genresData is String && genresData.isNotEmpty) {
      // Si c'est une string directe
      if (genresData.contains(',')) {
        genresList = genresData.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList();
      } else {
        try {
          // Essayer de parser comme JSON
          final decoded = jsonDecode(genresData);
          if (decoded is List) {
            for (var item in decoded) {
              if (item is String && item.contains(',')) {
                genresList.addAll(
                  item.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty)
                );
              } else {
                final trimmed = item.toString().trim();
                if (trimmed.isNotEmpty) {
                  genresList.add(trimmed);
                }
              }
            }
          }
        } catch (_) {
          final trimmed = genresData.trim();
          if (trimmed.isNotEmpty) {
            genresList = [trimmed];
          }
        }
      }
    }

    return Anime(
      id: json['id'] as int? ?? 0,
      animeId: json['anime_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? 'Sans titre',
      titleAlt: json['title_alt'] as String?,
      synopsis: json['synopsis'] as String?,
      genres: genresList,
      posterUrl: json['poster_url'] as String? ?? json['image_url'] as String?,
      seasons: seasons,
      totalSeasons: json['total_seasons'] as int? ?? seasons.length,
      totalEpisodes: json['total_episodes'] as int? ?? 0,
      contentType: json['content_type'] as String? ?? 'anime',
      isAnime: json['is_anime'] as bool? ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class AnimeSeason {
  final String name;
  final String path;
  final List<AnimeEpisode> episodes;
  final int episodeCount;

  AnimeSeason({
    required this.name,
    required this.path,
    required this.episodes,
    required this.episodeCount,
  });

  factory AnimeSeason.fromJson(Map<String, dynamic> json) {
    final episodesData = json['episodes'];
    final episodes = <AnimeEpisode>[];
    
    try {
      if (episodesData != null && episodesData is Map) {
        // Les épisodes sont dans un objet avec des clés episode_1, episode_2, etc.
        episodesData.forEach((key, value) {
          if (value == null) return; // Skip null values
          
          try {
            // Extraire le numéro d'épisode depuis la clé (episode_1 -> 1)
            final episodeNumMatch = RegExp(r'episode_(\d+)').firstMatch(key.toString());
            if (episodeNumMatch != null) {
              final episodeNum = int.tryParse(episodeNumMatch.group(1)!);
              if (episodeNum != null) {
                final players = <Map<String, String>>[];
                
                if (value is List) {
                  // Chaque épisode a un tableau de players
                  for (var playerData in value) {
                    if (playerData == null) continue;
                    
                    try {
                      Map<String, dynamic> playerMap;
                      if (playerData is Map<String, dynamic>) {
                        playerMap = playerData;
                      } else if (playerData is Map) {
                        playerMap = Map<String, dynamic>.from(playerData);
                      } else {
                        continue;
                      }
                      
                      final player = playerMap['player']?.toString() ?? '';
                      final url = playerMap['url']?.toString() ?? '';
                      if (player.isNotEmpty && url.isNotEmpty) {
                        players.add({'player': player, 'url': url});
                      }
                    } catch (e) {
                      debugPrint('[AnimeSeason] Erreur parsing player: $e');
                    }
                  }
                }
                
                if (players.isNotEmpty) {
                  episodes.add(AnimeEpisode(
                    title: '', // Pas de titre dans les données
                    url: players.first['url']!, // URL du premier player
                    episodeNumber: episodeNum,
                    players: players,
                  ));
                }
              }
            }
          } catch (e) {
            debugPrint('[AnimeSeason] Erreur parsing épisode $key: $e');
          }
        });
        
        // Trier les épisodes par numéro
        episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      } else if (episodesData is List) {
        // Format alternatif: liste d'épisodes
        for (var item in episodesData) {
          if (item == null) continue;
          
          try {
            Map<String, dynamic> itemMap;
            if (item is Map<String, dynamic>) {
              itemMap = item;
            } else if (item is Map) {
              itemMap = Map<String, dynamic>.from(item);
            } else {
              continue;
            }
            episodes.add(AnimeEpisode.fromJson(itemMap));
          } catch (e) {
            debugPrint('[AnimeSeason] Erreur parsing épisode liste: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[AnimeSeason] Erreur parsing episodes: $e');
    }

    return AnimeSeason(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      episodes: episodes,
      episodeCount: json['episode_count'] as int? ?? episodes.length,
    );
  }
}

class AnimeEpisode {
  final String title;
  final String url;
  final int episodeNumber;
  final List<Map<String, String>> players;

  AnimeEpisode({
    required this.title,
    required this.url,
    required this.episodeNumber,
    List<Map<String, String>>? players,
  }) : players = players ?? [];

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) {
    final playersData = json['players'];
    final players = <Map<String, String>>[];
    
    if (playersData is List) {
      for (var playerData in playersData) {
        if (playerData is Map) {
          players.add({
            'player': playerData['player']?.toString() ?? '',
            'url': playerData['url']?.toString() ?? '',
          });
        }
      }
    }
    
    return AnimeEpisode(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      episodeNumber: json['episode'] as int? ?? 0,
      players: players,
    );
  }
}
