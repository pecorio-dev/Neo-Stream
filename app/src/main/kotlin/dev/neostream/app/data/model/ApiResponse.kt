package dev.neostream.app.data.model

import kotlinx.serialization.Serializable

@Serializable
data class PaginatedResponse(
    val total: Int = 0,
    val offset: Int = 0,
    val limit: Int = 0,
    val count: Int = 0,
    val data: List<MediaItem> = emptyList(),
)

@Serializable
data class SearchResponse(
    val query: String = "",
    val total: Int = 0,
    val count: Int = 0,
    val data: List<MediaItem> = emptyList(),
)

@Serializable
data class AutocompleteResponse(
    val query: String = "",
    val count: Int = 0,
    val suggestions: List<MediaItem> = emptyList(),
)

@Serializable
data class StatsResponse(
    val status: String = "",
    val films: Int = 0,
    val series: Int = 0,
    val episodes: Int = 0,
    @kotlinx.serialization.Transient val raw: Map<String, kotlinx.serialization.json.JsonElement> = emptyMap(),
)
