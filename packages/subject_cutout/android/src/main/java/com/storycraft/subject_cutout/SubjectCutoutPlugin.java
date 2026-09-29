package com.storycraft.subject_cutout;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.google.mlkit.common.MlKitException;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation;
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenter;
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions;

import java.io.ByteArrayOutputStream;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Background removal with ML Kit subject segmentation, fully on device. */
public class SubjectCutoutPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
  private MethodChannel channel;
  private final ExecutorService executor = Executors.newSingleThreadExecutor();
  private final Handler main = new Handler(Looper.getMainLooper());

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), "subject_cutout");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if (!"removeBackground".equals(call.method)) {
      result.notImplemented();
      return;
    }
    Map<?, ?> args = (Map<?, ?>) call.arguments;
    byte[] data = args == null ? null : (byte[]) args.get("image");
    if (data == null) {
      result.error("failed", "No image", null);
      return;
    }
    Bitmap bitmap = BitmapFactory.decodeByteArray(data, 0, data.length);
    if (bitmap == null) {
      result.error("failed", "Cannot decode", null);
      return;
    }

    SubjectSegmenter segmenter = SubjectSegmentation.getClient(
        new SubjectSegmenterOptions.Builder().enableForegroundBitmap().build());
    segmenter.process(InputImage.fromBitmap(bitmap, 0))
        .addOnSuccessListener(executor, seg -> {
          Bitmap fg = seg.getForegroundBitmap();
          if (fg == null) {
            main.post(() -> result.error("no_subject", null, null));
            return;
          }
          ByteArrayOutputStream out = new ByteArrayOutputStream();
          fg.compress(Bitmap.CompressFormat.PNG, 100, out);
          byte[] png = out.toByteArray();
          main.post(() -> result.success(png));
        })
        .addOnFailureListener(e -> {
          boolean preparing = e instanceof MlKitException
              && ((MlKitException) e).getErrorCode() == MlKitException.UNAVAILABLE;
          result.error(preparing ? "preparing" : "failed", e.getMessage(), null);
        })
        .addOnCompleteListener(t -> segmenter.close());
  }
}
