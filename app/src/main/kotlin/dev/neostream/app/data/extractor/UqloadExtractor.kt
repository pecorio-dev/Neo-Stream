package dev.neostream.app.data.extractor

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Headers.Companion.toHeaders
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

data class ExtractedStreamInfo(
    val url: String,
    val headers: Map<String, String>,
    val fileSize: Long = 0L
)

object UqloadExtractor {
    private const val TAG = "UqloadExtractor"
    
    private val client = OkHttpClient.Builder()
        .followRedirects(true)
        .followSslRedirects(true)
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    fun isUqloadLink(url: String): Boolean = 
        url.contains("uqload", ignoreCase = true)

    suspend fun extract(url: String): Result<ExtractedStreamInfo> = withContext(Dispatchers.IO) {
        runCatching {
            Log.d(TAG, "Starting extraction for: $url")
            
            // Normaliser l'URL vers uqload.to (uqload.cx est bloqué)
            val normalizedUrl = normalizeToUqloadCx(url)
            Log.d(TAG, "Normalized URL: $normalizedUrl")
            
            // Extraire le domaine utilisé
            val domain = Regex("https?://([^/]+)").find(normalizedUrl)?.groupValues?.get(1) ?: "uqload.to"
            
            // Headers pour la requête initiale
            val headers = mapOf(
                "User-Agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                "Accept" to "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language" to "en-US,en;q=0.5",
                "Referer" to "https://$domain/"
            )
            
            val request = Request.Builder()
                .url(normalizedUrl)
                .headers(headers.toHeaders())
                .build()
            
            Log.d(TAG, "Sending HTTP request to: $normalizedUrl")
            val response = try {
                client.newCall(request).execute()
            } catch (e: Exception) {
                Log.e(TAG, "HTTP request failed", e)
                throw Exception("Failed to connect to Uqload: ${e.message}")
            }
            
            Log.d(TAG, "HTTP response code: ${response.code}")
            
            if (!response.isSuccessful) {
                Log.e(TAG, "HTTP error: ${response.code} - ${response.message}")
                throw Exception("HTTP error: ${response.code} - ${response.message}")
            }
            
            val html = response.body?.string() ?: throw Exception("Empty response")
            Log.d(TAG, "Received HTML response (${html.length} bytes)")
            
            // Extraire les cookies
            val cookies = response.headers("Set-Cookie")
                .joinToString("; ") { it.substringBefore(";") }
            
            Log.d(TAG, "Page loaded, extracting video URL...")
            
            // Chercher l'URL de la vidéo
            val videoUrl = extractVideoUrl(html) 
                ?: throw Exception("No video URL found in page")
            
            Log.d(TAG, "Found video URL: $videoUrl")
            
            // Headers pour la vidéo
            val videoHeaders = mutableMapOf(
                "User-Agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                "Accept" to "*/*",
                "Accept-Language" to "en-US,en;q=0.5",
                "Referer" to normalizedUrl,
                "Origin" to "https://$domain"
            )
            
            if (cookies.isNotEmpty()) {
                videoHeaders["Cookie"] = cookies
            }
            
            // Obtenir la taille du fichier
            val fileSize = getFileSize(videoUrl, videoHeaders)
            Log.d(TAG, "File size: $fileSize bytes")
            
            ExtractedStreamInfo(
                url = videoUrl,
                headers = videoHeaders,
                fileSize = fileSize
            )
        }
    }
    
    private fun normalizeToUqloadCx(url: String): String {
        // Utiliser uqload.bz qui fonctionne dans ton réseau
        
        // Extraire l'ID depuis n'importe quel domaine
        val idRegex = Regex("uqload\\.(?:cx|to|com|org|io|net|ws|bz)/(?:embed-)?([a-zA-Z0-9]+)", RegexOption.IGNORE_CASE)
        val match = idRegex.find(url)
        
        return if (match != null) {
            val id = match.groupValues[1].removeSuffix(".html")
            // Utiliser uqload.bz (domaine fonctionnel)
            "https://uqload.bz/embed-$id.html"
        } else {
            // Si pas de match, garder l'URL originale
            url
        }
    }
    
    private fun extractVideoUrl(html: String): String? {
        Log.d(TAG, "Extracting video URL from HTML (length: ${html.length})")
        
        // Pattern principal: sources: ["URL"]
        val sourcesPattern = Regex("""sources:\s*\["([^"]+)"\]""")
        sourcesPattern.find(html)?.let {
            val url = it.groupValues[1]
            Log.d(TAG, "Found sources pattern: $url")
            // Si l'URL est relative, la rendre absolue
            return if (url.startsWith("//")) {
                "https:$url"
            } else if (url.startsWith("/")) {
                "https://uqload.cx$url"
            } else {
                url
            }
        }
        
        // Pattern alternatif: file: "URL"
        val filePattern = Regex("""file:\s*"([^"]+\.mp4[^"]*)"""")
        filePattern.find(html)?.let {
            val url = it.groupValues[1]
            Log.d(TAG, "Found file pattern: $url")
            return if (url.startsWith("//")) {
                "https:$url"
            } else if (url.startsWith("/")) {
                "https://uqload.cx$url"
            } else {
                url
            }
        }
        
        // Pattern direct MP4
        val mp4Pattern = Regex("""https?://[^"'\s]+\.mp4[^"'\s]*""")
        mp4Pattern.find(html)?.let {
            Log.d(TAG, "Found mp4 pattern: ${it.value}")
            return it.value
        }
        
        // Pattern pour URL relative sans quotes
        val relativePattern = Regex("""sources:\s*\[([^"'][^\]]+)\]""")
        relativePattern.find(html)?.let {
            val url = it.groupValues[1].trim()
            Log.d(TAG, "Found relative pattern: $url")
            return if (url.startsWith("//")) {
                "https:$url"
            } else if (url.startsWith("/")) {
                "https://uqload.cx$url"
            } else {
                url
            }
        }
        
        Log.w(TAG, "No video URL pattern matched in HTML")
        Log.d(TAG, "HTML preview: ${html.take(500)}")
        return null
    }
    
    private fun getFileSize(url: String, headers: Map<String, String>): Long {
        return try {
            val request = Request.Builder()
                .url(url)
                .head()
                .headers(headers.toHeaders())
                .build()
            
            val response = client.newCall(request).execute()
            response.use {
                it.header("Content-Length")?.toLongOrNull() ?: 0L
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get file size", e)
            0L
        }
    }
}
