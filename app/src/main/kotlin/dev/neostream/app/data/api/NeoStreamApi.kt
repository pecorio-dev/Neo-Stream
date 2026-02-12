package dev.neostream.app.data.api

import dev.neostream.app.BuildConfig
import dev.neostream.app.data.model.AutocompleteResponse
import dev.neostream.app.data.model.MediaItem
import dev.neostream.app.data.model.PaginatedResponse
import dev.neostream.app.data.model.SearchResponse
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

object NeoStreamApi {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }

    private val client = HttpClient(OkHttp) {
        install(ContentNegotiation) { json(this@NeoStreamApi.json) }
        install(Logging) { level = LogLevel.BODY }
        defaultRequest { url(BuildConfig.API_BASE_URL) }
    }

    suspend fun getFilms(limit: Int = 50, offset: Int = 0): Result<PaginatedResponse> = runCatching {
        client.get("/films") {
            parameter("limit", limit)
            parameter("offset", offset)
        }.body()
    }

    suspend fun getSeries(limit: Int = 50, offset: Int = 0): Result<PaginatedResponse> = runCatching {
        client.get("/series") {
            parameter("limit", limit)
            parameter("offset", offset)
        }.body()
    }

    suspend fun getDetail(id: String, type: String = "film"): Result<MediaItem> = runCatching {
        client.get("/item/$id") {
            parameter("type", type)
        }.body()
    }

    suspend fun search(query: String, type: String? = null, limit: Int = 30): Result<SearchResponse> = runCatching {
        client.get("/search") {
            parameter("q", query)
            type?.let { parameter("type", it) }
            parameter("limit", limit)
        }.body()
    }

    suspend fun autocomplete(query: String, limit: Int = 10): Result<AutocompleteResponse> = runCatching {
        client.get("/autocomplete") {
            parameter("q", query)
            parameter("limit", limit)
        }.body()
    }

    suspend fun getRecent(type: String? = null, limit: Int = 50): Result<PaginatedResponse> = runCatching {
        client.get("/recent") {
            type?.let { parameter("type", it) }
            parameter("limit", limit)
        }.body()
    }

    suspend fun getRandom(type: String? = null, genre: String? = null, count: Int = 10): Result<PaginatedResponse> = runCatching {
        client.get("/random") {
            type?.let { parameter("type", it) }
            genre?.let { parameter("genre", it) }
            parameter("count", count)
        }.body()
    }

    suspend fun getTopRated(type: String? = null, minRating: Float = 7f, limit: Int = 50): Result<PaginatedResponse> = runCatching {
        client.get("/top-rated") {
            type?.let { parameter("type", it) }
            parameter("min_rating", minRating)
            parameter("limit", limit)
        }.body()
    }

    suspend fun getGenres(): Result<List<String>> = runCatching {
        client.get("/genres").body()
    }

    suspend fun getGenreItems(genre: String, type: String? = null, limit: Int = 50): Result<List<MediaItem>> = runCatching {
        client.get("/genres/${genre.lowercase()}") {
            type?.let { parameter("type", it) }
            parameter("limit", limit)
        }.body<PaginatedResponse>().data
    }
}
