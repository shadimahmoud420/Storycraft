package com.storycraft.instagram_story_share;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.io.File;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Shares an image to the Instagram Stories composer. */
public class InstagramStorySharePlugin
        implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private static final String INSTAGRAM_PACKAGE = "com.instagram.android";

    private MethodChannel channel;
    private Activity activity;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "instagram_story_share");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (!"shareBackgroundImage".equals(call.method)) {
            result.notImplemented();
            return;
        }
        if (activity == null) {
            result.success(false);
            return;
        }
        String path = call.argument("imagePath");
        String appId = call.argument("appId");
        try {
            File file = new File(path);
            Uri uri = FileProvider.getUriForFile(
                    activity, activity.getPackageName() + ".instagram_story_share", file);

            Intent intent = new Intent("com.instagram.share.ADD_TO_STORY");
            intent.putExtra("source_application", appId);
            intent.setDataAndType(uri, "image/png");
            intent.setPackage(INSTAGRAM_PACKAGE);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.grantUriPermission(
                    INSTAGRAM_PACKAGE, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);

            if (intent.resolveActivity(activity.getPackageManager()) == null) {
                result.success(false);
                return;
            }
            activity.startActivity(intent);
            result.success(true);
        } catch (ActivityNotFoundException | IllegalArgumentException e) {
            result.success(false);
        }
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }
}
