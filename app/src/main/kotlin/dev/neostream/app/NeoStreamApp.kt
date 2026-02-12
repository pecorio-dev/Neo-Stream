package dev.neostream.app

import android.app.Application
import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.network.okhttp.OkHttpNetworkFetcherFactory
import coil3.request.CachePolicy
import coil3.request.crossfade
import dev.neostream.app.util.PlatformDetector
import okhttp3.OkHttpClient
import okhttp3.Interceptor
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.dnsoverhttps.DnsOverHttps
import java.util.concurrent.TimeUnit

class NeoStreamApp : Application(), SingletonImageLoader.Factory {

    override fun onCreate() {
        super.onCreate()
        PlatformDetector.detect(this)
    }

    override fun newImageLoader(context: android.content.Context): ImageLoader {
        val okHttpClient = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            // DNS-over-HTTPS pour bypass FAI
            .dns(okhttp3.dnsoverhttps.DnsOverHttps.Builder()
                .client(OkHttpClient.Builder().build())
                .url("https://1.1.1.1/dns-query".toHttpUrl())
                .bootstrapDnsHosts(
                    listOf(
                        java.net.InetAddress.getByName("1.1.1.1"),
                        java.net.InetAddress.getByName("1.0.0.1"),
                        java.net.InetAddress.getByName("8.8.8.8"),
                        java.net.InetAddress.getByName("8.8.4.4")
                    )
                )
                .build()
            )
            // Intercepteur pour headers universels
            .addInterceptor(Interceptor { chain ->
                val request = chain.request()
                val newRequest = request.newBuilder()
                    .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                    .header("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8")
                    .header("Accept-Language", "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7")
                    .header("Accept-Encoding", "gzip, deflate, br")
                    .header("Connection", "keep-alive")
                    .header("Upgrade-Insecure-Requests", "1")
                    .header("Sec-Fetch-Dest", "image")
                    .header("Sec-Fetch-Mode", "no-cors")
                    .header("Sec-Fetch-Site", "cross-site")
                    .removeHeader("X-Forwarded-For") // Retirer trace de proxy
                    .build()
                
                val host = request.url.host
                // Ajouter referer spécifique par domaine
                val finalRequest = if (host.contains("cpasmieux", ignoreCase = true)) {
                    newRequest.newBuilder()
                        .header("Referer", "https://www.cpasmieux.is/")
                        .header("Origin", "https://www.cpasmieux.is")
                        .build()
                } else {
                    newRequest
                }
                
                chain.proceed(finalRequest)
            })
            // Retry automatique
            .retryOnConnectionFailure(true)
            .build()

        return ImageLoader.Builder(context)
            .components {
                add(OkHttpNetworkFetcherFactory(callFactory = { okHttpClient }))
            }
            .crossfade(300)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .diskCachePolicy(CachePolicy.ENABLED)
            .networkCachePolicy(CachePolicy.ENABLED)
            .build()
    }
}
