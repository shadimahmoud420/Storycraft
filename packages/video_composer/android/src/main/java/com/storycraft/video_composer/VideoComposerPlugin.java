package com.storycraft.video_composer;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.media3.common.Effect;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.effect.BitmapOverlay;
import androidx.media3.effect.OverlayEffect;
import androidx.media3.effect.Presentation;
import androidx.media3.effect.TextureOverlay;
import androidx.media3.transformer.Composition;
import androidx.media3.transformer.EditedMediaItem;
import androidx.media3.transformer.EditedMediaItemSequence;
import androidx.media3.transformer.Effects;
import androidx.media3.transformer.ExportException;
import androidx.media3.transformer.ExportResult;
import androidx.media3.transformer.Transformer;

import com.google.common.collect.ImmutableList;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Video + music + animated overlay composition with Media3 Transformer. */
@OptIn(markerClass = UnstableApi.class)
public class VideoComposerPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
  private MethodChannel channel;
  private Context context;
  private Transformer transformer;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    context = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), "video_composer");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    if (transformer != null) transformer.cancel();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    try {
      switch (call.method) {
        case "probe":
          result.success(probe(call.argument("video")));
          break;
        case "compose":
          compose(call, result);
          break;
        default:
          result.notImplemented();
      }
    } catch (Exception e) {
      result.error("failed", e.getMessage(), null);
    }
  }

  /** Display size (rotation applied) and duration of a media file. */
  private static Map<String, Object> probe(String path) throws Exception {
    MediaMetadataRetriever r = new MediaMetadataRetriever();
    try {
      r.setDataSource(path);
      int w = parse(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH));
      int h = parse(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT));
      int rotation =
          parse(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION));
      int duration = parse(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
      Map<String, Object> out = new HashMap<>();
      boolean turned = rotation % 180 != 0;
      out.put("width", turned ? h : w);
      out.put("height", turned ? w : h);
      out.put("durationMs", duration);
      return out;
    } finally {
      r.release();
    }
  }

  private static int parse(String s) {
    try {
      return s == null ? 0 : Integer.parseInt(s);
    } catch (NumberFormatException e) {
      return 0;
    }
  }

  private void compose(MethodCall call, MethodChannel.Result result) throws Exception {
    String videoPath = call.argument("video");
    int durationMs = call.<Number>argument("durationMs").intValue();
    String audioPath = call.argument("audio");
    Number audioStart = call.argument("audioStartMs");
    int audioStartMs = audioStart == null ? 0 : audioStart.intValue();
    String overlayDir = call.argument("overlayDir");
    int fps = call.<Number>argument("overlayFps").intValue();
    int[] frames = call.argument("overlayFrames");
    int width = call.<Number>argument("width").intValue();
    int height = call.<Number>argument("height").intValue();
    String output = call.argument("output");

    // Video: its own sound removed, scaled to the output, overlay on top.
    List<Effect> videoEffects = new ArrayList<>();
    videoEffects.add(
        Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_STRETCH_TO_FIT));
    videoEffects.add(new OverlayEffect(ImmutableList.<TextureOverlay>of(
        new FrameOverlay(overlayDir, fps, frames, width, height))));
    MediaItem videoItem = new MediaItem.Builder()
        .setUri(Uri.fromFile(new File(videoPath)))
        .setClippingConfiguration(new MediaItem.ClippingConfiguration.Builder()
            .setEndPositionMs(durationMs)
            .build())
        .build();
    EditedMediaItem video = new EditedMediaItem.Builder(videoItem)
        .setRemoveAudio(true)
        .setEffects(new Effects(ImmutableList.of(), videoEffects))
        .build();

    List<EditedMediaItemSequence> sequences = new ArrayList<>();
    sequences.add(new EditedMediaItemSequence(ImmutableList.of(video)));

    if (audioPath != null) {
      long audioLength = (long) probeDuration(audioPath);
      long end = Math.min(audioLength > 0 ? audioLength : Long.MAX_VALUE,
          (long) audioStartMs + durationMs);
      if (end > audioStartMs) {
        MediaItem audioItem = new MediaItem.Builder()
            .setUri(Uri.fromFile(new File(audioPath)))
            .setClippingConfiguration(new MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(audioStartMs)
                .setEndPositionMs(end)
                .build())
            .build();
        EditedMediaItem music =
            new EditedMediaItem.Builder(audioItem).setRemoveVideo(true).build();
        sequences.add(new EditedMediaItemSequence(ImmutableList.of(music)));
      }
    }

    Composition composition = new Composition.Builder(sequences).build();
    new File(output).delete();
    transformer = new Transformer.Builder(context)
        .setVideoMimeType(MimeTypes.VIDEO_H264)
        .setAudioMimeType(MimeTypes.AUDIO_AAC)
        .addListener(new Transformer.Listener() {
          @Override
          public void onCompleted(@NonNull Composition c, @NonNull ExportResult r) {
            transformer = null;
            result.success(null);
          }

          @Override
          public void onError(@NonNull Composition c, @NonNull ExportResult r,
              @NonNull ExportException e) {
            transformer = null;
            result.error("failed", e.getMessage(), null);
          }
        })
        .build();
    transformer.start(composition, output);
  }

  private static int probeDuration(String path) {
    MediaMetadataRetriever r = new MediaMetadataRetriever();
    try {
      r.setDataSource(path);
      return parse(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
    } catch (Exception e) {
      return 0;
    } finally {
      try {
        r.release();
      } catch (Exception ignored) {
      }
    }
  }

  /** Draws the pre-rendered overlay PNG for each video frame's time. */
  private static final class FrameOverlay extends BitmapOverlay {
    private final String dir;
    private final int fps;
    private final int[] frames;
    private final int width;
    private final int height;
    private long baseUs = -1;
    private int lastIndex = Integer.MIN_VALUE;
    private Bitmap last;
    private Bitmap empty;

    FrameOverlay(String dir, int fps, int[] frames, int width, int height) {
      this.dir = dir;
      this.fps = Math.max(1, fps);
      this.frames = frames == null ? new int[0] : frames;
      this.width = width;
      this.height = height;
    }

    @Override
    public Bitmap getBitmap(long presentationTimeUs) {
      if (baseUs < 0) baseUs = presentationTimeUs;
      long ms = Math.max(0, presentationTimeUs - baseUs) / 1000;
      int index = -1;
      if (frames.length > 0) {
        int frame = (int) Math.min(frames.length - 1, ms * fps / 1000);
        index = frames[frame];
      }
      if (index == lastIndex && last != null) return last;
      lastIndex = index;
      Bitmap bitmap = null;
      if (index >= 0) {
        bitmap = BitmapFactory.decodeFile(dir + "/f" + index + ".png");
        if (bitmap != null
            && (bitmap.getWidth() != width || bitmap.getHeight() != height)) {
          bitmap = Bitmap.createScaledBitmap(bitmap, width, height, true);
        }
      }
      if (bitmap == null) {
        if (empty == null) {
          empty = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        }
        bitmap = empty;
      }
      last = bitmap;
      return bitmap;
    }
  }
}
