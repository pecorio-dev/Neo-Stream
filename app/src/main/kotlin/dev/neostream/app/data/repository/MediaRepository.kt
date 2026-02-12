package dev.neostream.app.data.repository

import dev.neostream.app.data.api.NeoStreamApi
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.data.model.PaginatedResponse
import dev.neostream.app.data.local.FavoriteEntity

class MediaRepository {

    private val recommendationEngine = RecommendationEngine()

    suspend fun getFilms(limit: Int = 50, offset: Int = 0): Result<PaginatedResponse> =
        NeoStreamApi.getFilms(limit, offset)

    suspend fun getSeries(limit: Int = 50, offset: Int = 0): Result<PaginatedResponse> =
        NeoStreamApi.getSeries(limit, offset)

    suspend fun getDetail(id: String, type: String = "film"): Result<MediaItem> {
        val result = NeoStreamApi.getDetail(id, type)
        val item = result.getOrNull() ?: return result

        if (type == "serie" && item.episodesBySeason.isEmpty()) {
            return Result.success(tryMergeSeriesDuplicates(item))
        }
        return Result.success(item)
    }

    private suspend fun tryMergeSeriesDuplicates(item: MediaItem): MediaItem {
        val searchResult = NeoStreamApi.search(item.title, type = "serie", limit = 20)
            .getOrNull()?.data ?: return item

        val candidates = searchResult.filter {
            it.id != item.id
                && it.title.equals(item.title, ignoreCase = true)
                && (it.seasonsCount > 0 || it.episodesCount > 0)
        }
        if (candidates.isEmpty()) return item

        val best = candidates.maxByOrNull { it.episodesCount }!!
        val detail = NeoStreamApi.getDetail(best.id, "serie").getOrNull() ?: return item
        if (detail.episodesBySeason.isEmpty()) return item

        return item.copy(
            episodesBySeason = detail.episodesBySeason,
            seasonsCount = detail.seasonsCount,
            episodesCount = detail.episodesCount,
            synopsis = item.synopsis.ifBlank { detail.synopsis },
            genres = item.genres.ifEmpty { detail.genres },
            actors = item.actors.ifEmpty { detail.actors },
            directors = item.directors.ifEmpty { detail.directors },
            rating = if (item.rating > 0) item.rating else detail.rating,
            year = item.year.ifBlank { detail.year },
            quality = item.quality.ifBlank { detail.quality },
            version = item.version.ifBlank { detail.version },
            language = item.language.ifBlank { detail.language },
            originalTitle = item.originalTitle.ifBlank { detail.originalTitle },
        )
    }

    suspend fun search(query: String, type: String? = null): Result<List<MediaItem>> =
        NeoStreamApi.search(query, type).map { it.data }

    suspend fun getRecent(type: String? = null, limit: Int = 50): Result<List<MediaItem>> =
        NeoStreamApi.getRecent(type, limit).map { it.data }

    suspend fun getRandom(type: String? = null, genre: String? = null, count: Int = 10): Result<List<MediaItem>> =
        NeoStreamApi.getRandom(type, genre, count).map { it.data }

    suspend fun getTopRated(type: String? = null, minRating: Float = 7f, limit: Int = 50): Result<List<MediaItem>> =
        NeoStreamApi.getTopRated(type, minRating, limit).map { it.data }

    suspend fun getGenres(): Result<List<String>> = NeoStreamApi.getGenres()

    suspend fun getGenreItems(genre: String, type: String? = null, limit: Int = 50): Result<List<MediaItem>> =
        NeoStreamApi.getGenreItems(genre, type, limit)

    suspend fun getRecommendations(source: MediaItem, limit: Int = 20): List<MediaItem> =
        recommendationEngine.getRecommendations(source, limit)

    companion object {
        fun MediaItem.toFavoriteEntity() = FavoriteEntity(
            id = id, title = title, poster = poster, year = year,
            type = type, rating = rating, quality = quality, url = url,
        )

        fun FavoriteEntity.toMediaItem() = MediaItem(
            id = id, title = title, poster = poster, year = year, type = type,
            rating = rating, quality = quality, url = url,
        )
    }
}
