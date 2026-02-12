package dev.neostream.app.data.repository

import dev.neostream.app.data.api.NeoStreamApi
import dev.neostream.app.data.model.MediaItem
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

class RecommendationEngine {

    suspend fun getRecommendations(source: MediaItem, limit: Int = 20): List<MediaItem> = coroutineScope {
        val sourceId = source.id

        val genreItems = async {
            source.genres.firstOrNull()?.let { genre ->
                NeoStreamApi.getGenreItems(genre, type = source.type, limit = 50)
                    .getOrDefault(emptyList())
            } ?: emptyList()
        }

        val topRated = async {
            NeoStreamApi.getTopRated(type = source.type, limit = 50)
                .map { it.data }
                .getOrDefault(emptyList())
        }

        val random = async {
            NeoStreamApi.getRandom(type = source.type, count = 30)
                .map { it.data }
                .getOrDefault(emptyList())
        }

        val sameYear = async {
            NeoStreamApi.getRecent(type = source.type, limit = 50)
                .map { it.data }
                .getOrDefault(emptyList())
        }

        val allCandidates = mutableMapOf<String, ScoredItem>()

        fun addCandidates(items: List<MediaItem>, sourceWeight: Float) {
            for (item in items) {
                if (item.id == sourceId || item.id.isBlank()) continue
                val existing = allCandidates[item.id]
                val score = calculateSimilarity(source, item) * sourceWeight
                if (existing == null || existing.score < score) {
                    allCandidates[item.id] = ScoredItem(item, score)
                }
            }
        }

        addCandidates(genreItems.await(), 1.5f)
        addCandidates(topRated.await(), 1.0f)
        addCandidates(sameYear.await(), 1.2f)
        addCandidates(random.await(), 0.5f)

        allCandidates.values
            .sortedByDescending { it.score }
            .take(limit)
            .map { it.item }
    }

    private fun calculateSimilarity(source: MediaItem, candidate: MediaItem): Float {
        var score = 0f

        val genreOverlap = source.genres.intersect(candidate.genres.toSet()).size
        score += genreOverlap * 3f

        val sourceYear = source.year.toIntOrNull() ?: 0
        val candidateYear = candidate.year.toIntOrNull() ?: 0
        if (sourceYear > 0 && candidateYear > 0) {
            val yearDiff = kotlin.math.abs(sourceYear - candidateYear)
            score += when {
                yearDiff == 0 -> 2f
                yearDiff <= 2 -> 1.5f
                yearDiff <= 5 -> 1f
                else -> 0f
            }
        }

        if (candidate.rating >= 7f) score += 1.5f
        else if (candidate.rating >= 5f) score += 0.5f

        val directorOverlap = source.directors.intersect(candidate.directors.toSet()).size
        score += directorOverlap * 4f

        val actorOverlap = source.actors.intersect(candidate.actors.toSet()).size
        score += actorOverlap * 2f

        if (source.synopsis.isNotBlank() && candidate.synopsis.isNotBlank()) {
            val sourceWords = source.synopsis.lowercase().split(" ").filter { it.length > 3 }.toSet()
            val candidateWords = candidate.synopsis.lowercase().split(" ").filter { it.length > 3 }.toSet()
            val wordOverlap = sourceWords.intersect(candidateWords).size
            score += (wordOverlap.toFloat() / maxOf(sourceWords.size, 1)).coerceAtMost(3f)
        }

        return score
    }

    private data class ScoredItem(val item: MediaItem, val score: Float)
}
