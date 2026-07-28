package eu.neostream.neo_stream

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import eu.neostream.neo_stream.player.SurfacePlayerViewFactory
import eu.neostream.neo_stream.player.NativeVideoActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "eu.neostream.neo_stream/update"
    private val TV_CHANNEL = "eu.neostream.neo_stream/tv_detector"
    private val PLAYER_CHANNEL = "eu.neostream.neo_stream/player"
    private val PLAYER_REQUEST_CODE = 1001
    private var pendingPlayerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "surface_player_view",
                SurfacePlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null || filePath.isBlank()) {
                        result.error("INVALID_PATH", "File path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installApk(filePath)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PLAYER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val url = call.argument<String>("url")
                    @Suppress("UNCHECKED_CAST")
                    val rawUrls = call.argument<List<*>>("urls")
                    val urls = ArrayList<String>()
                    if (rawUrls != null) {
                        for (item in rawUrls) {
                            val u = item?.toString()?.trim().orEmpty()
                            if (u.startsWith("http://") || u.startsWith("https://")) {
                                if (!urls.contains(u)) urls.add(u)
                            }
                        }
                    }
                    if (url != null) {
                        val u = url.trim()
                        if ((u.startsWith("http://") || u.startsWith("https://")) && !urls.contains(u)) {
                            // url single en tête si pas déjà dans la liste
                            if (urls.isEmpty()) urls.add(u) else {
                                // déjà fourni via urls — ignore doublon
                            }
                        }
                        if (urls.isEmpty() && u.isNotEmpty()) urls.add(u)
                    }
                    if (urls.isEmpty()) {
                        result.error("NO_URL", "URL is required", null)
                        return@setMethodCallHandler
                    }
                    // Un seul play natif à la fois (évite double activity Freebox)
                    if (pendingPlayerResult != null) {
                        result.error("BUSY", "Player already open", null)
                        return@setMethodCallHandler
                    }
                    val position = (call.argument<Number>("position") ?: 0).toInt()
                    val isLive = call.argument<Boolean>("isLive") ?: false
                    @Suppress("UNCHECKED_CAST")
                    val rawHeaders = (call.argument<Map<*, *>>("headers") ?: emptyMap<Any, Any>())
                        .entries
                        .mapNotNull { (k, v) ->
                            val key = k?.toString() ?: return@mapNotNull null
                            val value = v?.toString() ?: return@mapNotNull null
                            key to value
                        }
                        .toMap()
                    @Suppress("UNCHECKED_CAST")
                    val rawHeadersList = call.argument<List<Map<*, *>>>("headersList")
                    val headersBundles = ArrayList<Bundle>()
                    if (rawHeadersList != null) {
                        for (entry in rawHeadersList) {
                            val bundle = Bundle()
                            for ((k, v) in entry) {
                                val key = k?.toString() ?: continue
                                val value = v?.toString() ?: continue
                                bundle.putString(key, value)
                            }
                            headersBundles.add(bundle)
                        }
                    }
                    pendingPlayerResult = result
                    val intent = Intent(this@MainActivity, NativeVideoActivity::class.java).apply {
                        putExtra(NativeVideoActivity.EXTRA_URL, urls.first())
                        putStringArrayListExtra(NativeVideoActivity.EXTRA_URLS, urls)
                        putExtra(NativeVideoActivity.EXTRA_POSITION, position)
                        putExtra(NativeVideoActivity.EXTRA_IS_LIVE, isLive)
                        val bundle = Bundle()
                        rawHeaders.forEach { (k, v) -> bundle.putString(k, v) }
                        putExtra(NativeVideoActivity.EXTRA_HEADERS, bundle)
                        if (headersBundles.isNotEmpty()) {
                            putParcelableArrayListExtra(
                                NativeVideoActivity.EXTRA_HEADERS_LIST,
                                headersBundles,
                            )
                        }
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, PLAYER_REQUEST_CODE)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TV_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTv" -> {
                    val uiMode = resources.configuration.uiMode
                    val isTv = uiMode and android.content.res.Configuration.UI_MODE_TYPE_MASK ==
                            android.content.res.Configuration.UI_MODE_TYPE_TELEVISION
                    result.success(isTv)
                }
                "getBuildProps" -> {
                    val props = mapOf(
                        "brand" to Build.BRAND,
                        "model" to Build.MODEL,
                        "device" to Build.DEVICE,
                        "manufacturer" to Build.MANUFACTURER,
                    )
                    result.success(props)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        pendingPlayerResult?.let {
            it.success(mapOf(
                "position" to 0,
                "completed" to false,
                "error" to "Activity destroyed",
                "hadError" to true,
                "ok" to false
            ))
            pendingPlayerResult = null
        }
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PLAYER_REQUEST_CODE) {
            val result = pendingPlayerResult
            pendingPlayerResult = null
            if (result != null) {
                val position = data?.getIntExtra(NativeVideoActivity.EXTRA_POSITION, 0) ?: 0
                val completed = data?.getBooleanExtra(NativeVideoActivity.EXTRA_COMPLETED, false) ?: false
                val error = data?.getStringExtra(NativeVideoActivity.EXTRA_ERROR)
                val hadError = data?.getBooleanExtra(NativeVideoActivity.EXTRA_HAD_ERROR, false)
                    ?: (resultCode != android.app.Activity.RESULT_OK)
                result.success(
                    mapOf(
                        "position" to position,
                        "completed" to completed,
                        "error" to error,
                        "hadError" to hadError,
                        "ok" to (resultCode == android.app.Activity.RESULT_OK && !hadError),
                    )
                )
            }
        }
    }

    private fun installApk(filePath: String) {
        val file = File(filePath)
        if (!file.exists()) {
            throw IllegalArgumentException("File not found: $filePath")
        }

        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            FileProvider.getUriForFile(
                this,
                "${packageName}.file_provider",
                file,
            )
        } else {
            Uri.fromFile(file)
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
