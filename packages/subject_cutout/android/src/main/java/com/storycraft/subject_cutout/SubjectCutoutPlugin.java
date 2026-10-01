package com.storycraft.subject_cutout;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.PointF;
import android.graphics.Rect;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.google.mlkit.common.MlKitException;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.face.Face;
import com.google.mlkit.vision.face.FaceContour;
import com.google.mlkit.vision.face.FaceDetection;
import com.google.mlkit.vision.face.FaceDetector;
import com.google.mlkit.vision.face.FaceDetectorOptions;
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation;
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenter;
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Background removal and face contours with ML Kit, fully on device. */
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
    boolean faces = "detectFaces".equals(call.method);
    if (!faces && !"removeBackground".equals(call.method)) {
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
    if (faces) {
      detectFaces(bitmap, result);
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

  /**
   * Face contours for the beauty tools, in bitmap pixels. Each face is a map
   * of region name to a flat [x0, y0, x1, y1, ...] list. ML Kit gives
   * contours for the most prominent face only; others are skipped.
   */
  private void detectFaces(Bitmap bitmap, MethodChannel.Result result) {
    FaceDetector detector = FaceDetection.getClient(new FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
        .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL)
        .setMinFaceSize(0.08f)
        .build());
    detector.process(InputImage.fromBitmap(bitmap, 0))
        .addOnSuccessListener(executor, found -> {
          List<Map<String, List<Double>>> out = new ArrayList<>();
          for (Face face : found) {
            if (face.getContour(FaceContour.FACE) == null) continue;
            Map<String, List<Double>> map = new HashMap<>();
            Rect box = face.getBoundingBox();
            List<Double> bounds = new ArrayList<>();
            bounds.add((double) box.left);
            bounds.add((double) box.top);
            bounds.add((double) box.width());
            bounds.add((double) box.height());
            map.put("bounds", bounds);
            put(map, "contour", face, FaceContour.FACE);
            put(map, "leftEye", face, FaceContour.LEFT_EYE);
            put(map, "rightEye", face, FaceContour.RIGHT_EYE);
            put(map, "leftBrow", face, FaceContour.LEFT_EYEBROW_TOP,
                FaceContour.LEFT_EYEBROW_BOTTOM);
            put(map, "rightBrow", face, FaceContour.RIGHT_EYEBROW_TOP,
                FaceContour.RIGHT_EYEBROW_BOTTOM);
            put(map, "outerLips", face, FaceContour.UPPER_LIP_TOP,
                FaceContour.LOWER_LIP_BOTTOM);
            put(map, "innerLips", face, FaceContour.UPPER_LIP_BOTTOM,
                FaceContour.LOWER_LIP_TOP);
            put(map, "nose", face, FaceContour.NOSE_BOTTOM);
            put(map, "noseCrest", face, FaceContour.NOSE_BRIDGE);
            out.add(map);
          }
          main.post(() -> result.success(out));
        })
        .addOnFailureListener(e -> {
          boolean preparing = e instanceof MlKitException
              && ((MlKitException) e).getErrorCode() == MlKitException.UNAVAILABLE;
          result.error(preparing ? "preparing" : "failed", e.getMessage(), null);
        })
        .addOnCompleteListener(t -> detector.close());
  }

  private static void put(Map<String, List<Double>> map, String name, Face face,
      int... types) {
    List<Double> flat = new ArrayList<>();
    for (int type : types) {
      FaceContour contour = face.getContour(type);
      if (contour == null) continue;
      for (PointF p : contour.getPoints()) {
        flat.add((double) p.x);
        flat.add((double) p.y);
      }
    }
    if (!flat.isEmpty()) map.put(name, flat);
  }
}
