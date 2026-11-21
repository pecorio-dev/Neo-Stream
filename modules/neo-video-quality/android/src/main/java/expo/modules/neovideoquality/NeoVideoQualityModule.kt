package expo.modules.neovideoquality

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import expo.modules.kotlin.functions.Queues
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import expo.modules.video.player.VideoPlayer

@OptIn(UnstableApi::class)
class NeoVideoQualityModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("NeoVideoQuality")

    AsyncFunction("getQuality") { ref: VideoPlayer ->
      val player = ref.player
      val variants = videoVariants(player)
      val parameters = player.takeUnless { it.isReleased }?.trackSelectionParameters
      val selected = variants.firstOrNull { variant ->
        parameters?.overrides?.get(variant.group.mediaTrackGroup)?.trackIndices == listOf(variant.index)
      }?.height
      mapOf("heights" to variants.map { it.height }.distinct().sortedDescending(), "selectedHeight" to selected)
    }.runOnQueue(Queues.MAIN)

    AsyncFunction("selectHeight") { ref: VideoPlayer, height: Int? ->
      val player = ref.player
      if (player.isReleased) return@AsyncFunction false
      val parameters = player.trackSelectionParameters
      val builder = parameters.buildUpon()
      if (height == null) {
        builder.clearOverridesOfType(C.TRACK_TYPE_VIDEO)
      } else {
        val variants = videoVariants(player)
        if (variants.all { it.height == height }) return@AsyncFunction false
        val variant = variants.filter { it.height == height }.maxWithOrNull(
          compareBy<Variant>({ it.group.isSelected }, { it.bitrate })
        ) ?: return@AsyncFunction false
        builder.setOverrideForType(TrackSelectionOverride(variant.group.mediaTrackGroup, variant.index))
      }
      val updated = builder.build()
      player.trackSelectionParameters = updated
      player.trackSelectionParameters == updated
    }.runOnQueue(Queues.MAIN)
  }

  private data class Variant(val group: Tracks.Group, val index: Int, val height: Int, val bitrate: Int)

  private fun videoVariants(player: ExoPlayer): List<Variant> {
    if (player.isReleased || player.trackSelectionParameters.disabledTrackTypes.contains(C.TRACK_TYPE_VIDEO)) return emptyList()
    return buildList {
      for (group in player.currentTracks.groups) {
        if (group.type != C.TRACK_TYPE_VIDEO) continue
        for (index in 0 until group.length) {
          if (!group.isTrackSupported(index)) continue
          val format = group.getTrackFormat(index)
          if (format.height > 0) add(Variant(group, index, format.height, maxOf(format.peakBitrate, format.averageBitrate)))
        }
      }
    }
  }
}
