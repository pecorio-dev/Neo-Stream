import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/neo.dart';
import '../services/ai_search_service.dart';
import '../screens/detail_screen.dart';
import '../screens/anime_detail_screen.dart';

class AISearchScreen extends StatefulWidget {
  AISearchScreen({super.key});

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
      backgroundColor: Neo.bgBase(context),
      appBar: AppBar(
        title: Text('Recherche IA'),
        backgroundColor: Neo.bgSurface(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Neo.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Décris ce que tu cherches... (ex: anime action récent en VF)',
                      hintStyle: TextStyle(color: Neo.textTertiary(context)),
                      filled: true,
                      fillColor: Neo.bgSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
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
              padding: EdgeInsets.all(16),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NeoTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NeoTheme.warningOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: NeoTheme.warningOrange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Serveur IA non détecté. Lancez start_llm.bat puis start_server.bat.',
                        style: TextStyle(color: Neo.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_result?.parsed != null) _buildParsedInfo(),
          if (_isSearching)
            Expanded(child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: TextStyle(color: NeoTheme.errorRed))))
          else if (_result != null)
            Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildParsedInfo() {
    final parsed = _result!.parsed;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Neo.bgSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 18),
              SizedBox(width: 8),
              Text('Analyse IA', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
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
              padding: EdgeInsets.only(top: 8),
              child: Text('Mots-clés: ${parsed.keywords.join(', ')}',
                  style: TextStyle(color: Neo.textSecondary(context), fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: TextStyle(color: Neo.textSecondary(context), fontSize: 12)),
    );
  }

  Widget _buildResults() {
    final results = _result!.results;
    if (results.isEmpty) {
      return Center(child: Text('Aucun résultat trouvé', style: TextStyle(color: Neo.textSecondary(context))));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return Card(
          color: Neo.bgSurface(context),
          margin: EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: item.posterUrl != null && item.posterUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item.posterUrl!, width: 50, height: 75, fit: BoxFit.cover,
                        errorBuilder: (_1, _2, _3) => Container(width: 50, height: 75, color: Neo.bgElevated(context), child: Icon(Icons.movie, color: Neo.textDisabled(context)))))
                : Container(width: 50, height: 75, decoration: BoxDecoration(color: Neo.bgElevated(context), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.movie, color: Neo.textDisabled(context))),
            title: Text(item.displayTitle, style: TextStyle(color: Neo.textPrimary(context), fontWeight: FontWeight.w600)),
            subtitle: Text('${item.typeLabel}${item.year != null ? " · ${item.year}" : ""}${item.rating != null ? " · ${item.rating!.toStringAsFixed(1)}★" : ""}',
                style: TextStyle(color: Neo.textSecondary(context), fontSize: 12)),
            trailing: item.score != null
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${(item.score! * 100).toInt()}%', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)))
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