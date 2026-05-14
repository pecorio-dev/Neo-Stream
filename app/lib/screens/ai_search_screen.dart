import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/ai_search_service.dart';
import '../screens/detail_screen.dart';
import '../screens/anime_detail_screen.dart';

class AISearchScreen extends StatefulWidget {
  const AISearchScreen({super.key});

  @override
  State<AISearchScreen> createState() => _AISearchScreenState();
}

class _AISearchScreenState extends State<AISearchScreen> {
  final _searchController = TextEditingController();
  final _ai = AISearchService();

  bool _isSearching = false;
  AIActivityResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    await _ai.checkAvailability();
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _result = null;
      _error = null;
    });

    final result = await _ai.analyzeQuery(query);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _result = result;
        if (result.error != null) {
          _error = result.error;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeoTheme.bgBase,
      appBar: AppBar(
        title: const Text('Recherche IA'),
        backgroundColor: NeoTheme.bgSurface,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: NeoTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Décris ce que tu cherches... (ex: anime action récent en VF)',
                      hintStyle: const TextStyle(color: NeoTheme.textTertiary),
                      filled: true,
                      fillColor: NeoTheme.bgSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: NeoTheme.primaryRed),
                        onPressed: _isSearching ? null : _search,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
              ],
            ),
          ),
          if (!_ai.isAvailable)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NeoTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NeoTheme.warningOrange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: NeoTheme.warningOrange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Serveur IA non détecté. Lancez start_llm.bat puis start_server.bat.',
                        style: TextStyle(color: NeoTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_result?.parsed != null) _buildParsedInfo(),
          if (_isSearching)
            const Expanded(child: Center(child: CircularProgressIndicator(color: NeoTheme.primaryRed)))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: NeoTheme.errorRed))))
          else if (_result != null)
            Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildParsedInfo() {
    final parsed = _result!.parsed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeoTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeoTheme.primaryRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: NeoTheme.primaryRed, size: 18),
              const SizedBox(width: 8),
              Text('Analyse IA', style: TextStyle(color: NeoTheme.primaryRed, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _infoChip('Type', parsed.contentTypeLabel),
              if (parsed.genres.isNotEmpty) _infoChip('Genres', parsed.genres.join(', ')),
              if (parsed.yearRange.min > 0 || parsed.yearRange.max < 9999)
                _infoChip('Année', '${parsed.yearRange.min}-${parsed.yearRange.max == 9999 ? "∞" : parsed.yearRange.max}'),
              if (parsed.language != 'any') _infoChip('Langue', parsed.language),
              if (parsed.quality != 'any') _infoChip('Qualité', parsed.quality),
              if (parsed.exclusions.isNotEmpty) _infoChip('Exclure', parsed.exclusions.join(', ')),
            ],
          ),
          if (parsed.keywords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Mots-clés: ${parsed.keywords.join(', ')}',
                  style: const TextStyle(color: NeoTheme.textSecondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NeoTheme.primaryRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: const TextStyle(color: NeoTheme.textSecondary, fontSize: 12)),
    );
  }

  Widget _buildResults() {
    final results = _result!.results;
    if (results.isEmpty) {
      return const Center(child: Text('Aucun résultat trouvé', style: TextStyle(color: NeoTheme.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return Card(
          color: NeoTheme.bgSurface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: item.posterUrl != null && item.posterUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item.posterUrl!, width: 50, height: 75, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 50, height: 75, color: NeoTheme.bgElevated, child: const Icon(Icons.movie, color: NeoTheme.textDisabled))))
                : Container(width: 50, height: 75, decoration: BoxDecoration(color: NeoTheme.bgElevated, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.movie, color: NeoTheme.textDisabled)),
            title: Text(item.displayTitle, style: const TextStyle(color: NeoTheme.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text('${item.typeLabel}${item.year != null ? " · ${item.year}" : ""}${item.rating != null ? " · ${item.rating!.toStringAsFixed(1)}★" : ""}',
                style: const TextStyle(color: NeoTheme.textSecondary, fontSize: 12)),
            trailing: item.score != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: NeoTheme.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${(item.score! * 100).toInt()}%', style: const TextStyle(color: NeoTheme.primaryRed, fontSize: 12, fontWeight: FontWeight.bold)))
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => item.type == 'anime'
                      ? AnimeDetailScreen(animeId: item.id)
                      : DetailScreen(contentId: item.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}