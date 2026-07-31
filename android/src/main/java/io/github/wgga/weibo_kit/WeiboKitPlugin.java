package io.github.wgga.weibo_kit;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.FileProvider;

import com.sina.weibo.sdk.api.ImageObject;
import com.sina.weibo.sdk.api.MultiImageObject;
import com.sina.weibo.sdk.api.TextObject;
import com.sina.weibo.sdk.api.VideoSourceObject;
import com.sina.weibo.sdk.api.WebpageObject;
import com.sina.weibo.sdk.api.WeiboMultiMessage;
import com.sina.weibo.sdk.auth.AuthInfo;
import com.sina.weibo.sdk.auth.Oauth2AccessToken;
import com.sina.weibo.sdk.auth.WbAuthListener;
import com.sina.weibo.sdk.common.UiError;
import com.sina.weibo.sdk.openapi.IWBAPI;
import com.sina.weibo.sdk.openapi.WBAPIFactory;
import com.sina.weibo.sdk.share.WbShareCallback;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/**
 * WeiboKitPlugin
 */
public class WeiboKitPlugin implements FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener, MethodCallHandler {
    private static class WeiboErrorCode {
        public static final int SUCCESS = 0;//成功
        public static final int USERCANCEL = -1;//用户取消发送
        public static final int SENT_FAIL = -2;//发送失败
        public static final int AUTH_DENY = -3;//授权失败
        public static final int USERCANCEL_INSTALL = -4;//用户取消安装微博客户端
        public static final int PAY_FAIL = -5;//支付失败
        public static final int SHARE_IN_SDK_FAILED = -8;//分享失败 详情见response UserInfo
        public static final int UNSUPPORT = -99;//不支持的请求
        public static final int UNKNOWN = -100;
    }

    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;
    private Context applicationContext;
    private ActivityPluginBinding activityPluginBinding;

    private IWBAPI iwbapi;

    // --- FlutterPlugin

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "wgga.github.io/weibo_kit");
        channel.setMethodCallHandler(this);
        applicationContext = binding.getApplicationContext();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
        }
        channel = null;
        iwbapi = null;
        applicationContext = null;
    }

    // --- ActivityAware

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityPluginBinding = binding;
        activityPluginBinding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        if (activityPluginBinding != null) {
            activityPluginBinding.removeActivityResultListener(this);
        }
        activityPluginBinding = null;
    }

    // --- ActivityResultListener

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        final Activity activity = getActivity();
        if (activity == null || iwbapi == null) {
            return false;
        }
        switch (requestCode) {
            case 32973:
                iwbapi.authorizeCallback(activity, requestCode, resultCode, data);
                return true;
            case 10001:
                iwbapi.doResultIntent(data, new WbShareCallback() {
                        @Override
                        public void onComplete() {
                            final Map<String, Object> map = new HashMap<>();
                            map.put("errorCode", WeiboErrorCode.SUCCESS);
                            if (channel != null) {
                                channel.invokeMethod("onShareMsgResp", map);
                            }
                        }

                        @Override
                        public void onError(UiError uiError) {
                            final Map<String, Object> map = new HashMap<>();
                            map.put("errorCode", WeiboErrorCode.SHARE_IN_SDK_FAILED);
                            if (channel != null) {
                                channel.invokeMethod("onShareMsgResp", map);
                            }
                        }

                        @Override
                        public void onCancel() {
                            final Map<String, Object> map = new HashMap<>();
                            map.put("errorCode", WeiboErrorCode.USERCANCEL);
                            if (channel != null) {
                                channel.invokeMethod("onShareMsgResp", map);
                            }
                        }
                    });
                return true;
        }
        return false;
    }

    // --- MethodCallHandler

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if ("registerApp".equals(call.method)) {
            final String appKey = call.argument("appKey");
            final String scope = call.argument("scope");
            final String redirectUrl = call.argument("redirectUrl");
            final Activity activity = getActivity();
            if (activity == null || applicationContext == null) {
                result.error("NO_ACTIVITY", "weibo_kit requires a foreground Activity", null);
                return;
            }
            iwbapi = WBAPIFactory.createWBAPI(activity);
            iwbapi.registerApp(applicationContext, new AuthInfo(applicationContext, appKey, redirectUrl, scope));
            result.success(null);
        } else if ("isInstalled".equals(call.method)) {
            if (iwbapi != null) {
                result.success(iwbapi.isWBAppInstalled());
            } else {
                result.error("FAILED", "请先调用registerApp", null);
            }
        } else if ("isSupportMultipleImage".equals(call.method)) {
            if (iwbapi != null) {
                result.success(iwbapi.isWBAppSupportMultipleImage());
            } else {
                result.error("FAILED", "请先调用registerApp", null);
            }
        } else if ("auth".equals(call.method)) {
            if (iwbapi != null) {
                handleAuthCall(call, result);
            } else {
                result.error("FAILED", "请先调用registerApp", null);
            }
        } else if (Arrays.asList("shareText", "shareImage", "shareMultiImage", "shareVideo", "shareWebpage").contains(call.method)) {
            if (iwbapi != null) {
                handleShareCall(call, result);
            } else {
                result.error("FAILED", "请先调用registerApp", null);
            }
        } else {
            result.notImplemented();
        }
    }

    private void handleAuthCall(@NonNull MethodCall call, @NonNull Result result) {
        final Activity activity = getActivity();
        if (activity == null) {
            result.error("NO_ACTIVITY", "weibo_kit requires a foreground Activity", null);
            return;
        }
        iwbapi.authorize(activity, new WbAuthListener() {
            @Override
            public void onComplete(Oauth2AccessToken token) {
                final Map<String, Object> map = new HashMap<>();
                if (token.isSessionValid()) {
                    map.put("errorCode", WeiboErrorCode.SUCCESS);
                    map.put("userId", token.getUid());
                    map.put("accessToken", token.getAccessToken());
                    map.put("refreshToken", token.getRefreshToken());
                    map.put("expiresTime", token.getExpiresTime());
                } else {
                    map.put("errorCode", WeiboErrorCode.UNKNOWN);
                }
                if (channel != null) {
                    channel.invokeMethod("onAuthResp", map);
                }
            }

            @Override
            public void onError(UiError uiError) {
                final Map<String, Object> map = new HashMap<>();
                map.put("errorCode", WeiboErrorCode.UNKNOWN);
                if (channel != null) {
                    channel.invokeMethod("onAuthResp", map);
                }
            }

            @Override
            public void onCancel() {
                final Map<String, Object> map = new HashMap<>();
                map.put("errorCode", WeiboErrorCode.USERCANCEL);
                if (channel != null) {
                    channel.invokeMethod("onAuthResp", map);
                }
            }
        });
        result.success(null);
    }

    private void handleShareCall(@NonNull MethodCall call, @NonNull Result result) {
        final Activity activity = getActivity();
        if (activity == null || applicationContext == null) {
            result.error("NO_ACTIVITY", "weibo_kit requires a foreground Activity", null);
            return;
        }
        final WeiboMultiMessage message = new WeiboMultiMessage();
        if ("shareText".equals(call.method)) {
            final TextObject object = new TextObject();
            object.text = call.argument("text");// 1024
            message.textObject = object;
        } else if ("shareImage".equals(call.method)) {
            if (call.hasArgument("text")) {
                final TextObject object = new TextObject();
                object.text = call.argument("text");// 1024
                message.textObject = object;
            }
            final ImageObject object = new ImageObject();
            if (call.hasArgument("imageData")) {
                object.imageData = call.argument("imageData");// 2 * 1024 * 1024
            } else if (call.hasArgument("imageUri")) {
                final String imageUri = call.argument("imageUri");
                object.imagePath = Uri.parse(imageUri).getPath();// 512 - 10 * 1024 * 1024
            }
            message.imageObject = object;
        } else if ("shareMultiImage".equals(call.method)) {
            if (call.hasArgument("text")) {
                final TextObject object = new TextObject();
                object.text = call.argument("text");// 1024
                message.textObject = object;
            }
            final MultiImageObject object = new MultiImageObject();
            final List<String> imageUris = call.argument("imageUris");
            final ArrayList<Uri> images = new ArrayList<>();
            for (String imageUri : imageUris) {
                final Uri shareFileUri = toShareUri(imageUri);
                applicationContext.grantUriPermission("com.sina.weibo", shareFileUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
                images.add(shareFileUri);
            }
            object.imageList = images;
            message.multiImageObject = object;
        } else if ("shareVideo".equals(call.method)) {
            if (call.hasArgument("text")) {
                final TextObject object = new TextObject();
                object.text = call.argument("text");// 1024
                message.textObject = object;
            }
            final VideoSourceObject object = new VideoSourceObject();
            final String videoUri = call.argument("videoUri");
            final Uri shareFileUri = toShareUri(videoUri);
            applicationContext.grantUriPermission("com.sina.weibo", shareFileUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            object.videoPath = shareFileUri;
            message.videoSourceObject = object;
        } else if ("shareWebpage".equals(call.method)) {
            final WebpageObject object = new WebpageObject();
            object.identify = UUID.randomUUID().toString();
            object.title = call.argument("title");// 512
            object.description = call.argument("description");// 1024
            object.thumbData = call.argument("thumbData");// 32 * 1024
            object.defaultText = call.argument("description");
            object.actionUrl = call.argument("webpageUrl");// 512

            message.mediaObject = object;
        }

        final Boolean clientOnlyValue = call.argument("clientOnly");
        final boolean clientOnly = Boolean.TRUE.equals(clientOnlyValue);

        iwbapi.shareMessage(activity, message, clientOnly);
        result.success(null);
    }

    @Nullable
    private Activity getActivity() {
        return activityPluginBinding == null ? null : activityPluginBinding.getActivity();
    }

    @NonNull
    private Uri toShareUri(@NonNull String fileUri) {
        final Uri uri = Uri.parse(fileUri);
        return FileProvider.getUriForFile(
                applicationContext,
                applicationContext.getPackageName() + ".wbsdk.fileprovider",
                new File(uri.getPath()));
    }
}
