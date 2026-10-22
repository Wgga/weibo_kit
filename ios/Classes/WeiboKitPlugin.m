#import "WeiboKitPlugin.h"
// xcframework 的 module 名是 WeiboSDK，CocoaPods 上的 Weibo_SDK pod 则是 Weibo_SDK
#if __has_include(<WeiboSDK/WeiboSDK.h>)
#import <WeiboSDK/WeiboSDK.h>
#else
#import <Weibo_SDK/WeiboSDK.h>
#endif
#if __has_include(<Flutter/FlutterSceneLifeCycle.h>)
#import <Flutter/FlutterSceneLifeCycle.h>
#define WEIBO_KIT_HAS_SCENE_LIFECYCLE 1
#else
#define WEIBO_KIT_HAS_SCENE_LIFECYCLE 0
#endif

@interface WeiboKitPlugin () <WeiboSDKDelegate
#if WEIBO_KIT_HAS_SCENE_LIFECYCLE
                              , FlutterSceneLifeCycleDelegate
#endif
                              >

@end

@implementation WeiboKitPlugin {
    FlutterMethodChannel *_channel;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
        methodChannelWithName:@"wgga.github.io/weibo_kit"
              binaryMessenger:[registrar messenger]];
    WeiboKitPlugin *instance = [[WeiboKitPlugin alloc] initWithChannel:channel];
    [registrar addApplicationDelegate:instance];
#if WEIBO_KIT_HAS_SCENE_LIFECYCLE
    if (@available(iOS 13.0, *)) {
        [registrar addSceneDelegate:instance];
    }
#endif
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel {
    self = [super init];
    if (self) {
        _channel = channel;
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
    if ([@"registerApp" isEqualToString:call.method]) {
        NSString *appKey = call.arguments[@"appKey"];
        NSString *universalLink = call.arguments[@"universalLink"];
        if (appKey.length == 0 || universalLink.length == 0) {
            result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                                       message:@"appKey and universalLink must not be empty"
                                       details:nil]);
        } else if ([WeiboSDK registerApp:appKey universalLink:universalLink]) {
            result(nil);
        } else {
            result([FlutterError errorWithCode:@"REGISTER_FAILED"
                                       message:@"Weibo rejected the app registration"
                                       details:nil]);
        }
    } else if ([@"isInstalled" isEqualToString:call.method]) {
        result([NSNumber numberWithBool:[WeiboSDK isWeiboAppInstalled]]);
    } else if ([@"isSupportMultipleImage" isEqualToString:call.method]) {
        result([NSNumber numberWithBool:YES]);
    } else if ([@"auth" isEqualToString:call.method]) {
        [self handleAuthCall:call result:result];
    } else if ([@"shareText" isEqualToString:call.method] ||
               [@"shareImage" isEqualToString:call.method] ||
               [@"shareMultiImage" isEqualToString:call.method] ||
               [@"shareVideo" isEqualToString:call.method] ||
               [@"shareWebpage" isEqualToString:call.method]) {
        [self handleShareCall:call result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)handleAuthCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    WBAuthorizeRequest *request = [WBAuthorizeRequest request];
    request.scope = call.arguments[@"scope"];
    request.redirectURI = call.arguments[@"redirectUrl"];
    request.shouldShowWebViewForAuthIfCannotSSO = YES;
    request.shouldOpenWeiboAppInstallPageIfNotInstalled = NO;
    [WeiboSDK sendRequest:request
               completion:^(BOOL success){
                   if (!success) {
                       NSLog(@"weibo_kit: Weibo rejected the authorization request");
                   }
               }];
    result(nil);
}

- (void)handleShareCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    WBMessageObject *message = [WBMessageObject message];
    if ([@"shareText" isEqualToString:call.method]) {
        message.text = call.arguments[@"text"];
    } else if ([@"shareImage" isEqualToString:call.method]) {
        message.text = call.arguments[@"text"];
        WBImageObject *object = [WBImageObject object];
        FlutterStandardTypedData *imageData = call.arguments[@"imageData"];
        if (imageData != nil) {
            object.imageData = imageData.data;
        } else {
            NSString *imageUri = call.arguments[@"imageUri"];
            NSURL *imageUrl = [NSURL URLWithString:imageUri];
            object.imageData = [NSData dataWithContentsOfFile:imageUrl.path];
        }
        message.imageObject = object;
    } else if ([@"shareMultiImage" isEqualToString:call.method]) {
        message.text = call.arguments[@"text"];
        WBImageObject *object = [WBImageObject object];
        NSArray *imageUris = call.arguments[@"imageUris"];
        NSMutableArray<UIImage *> *images = [[NSMutableArray alloc] init];
        for (NSString *imageUri in imageUris) {
            NSURL *imageUrl = [NSURL URLWithString:imageUri];
            [images addObject:[UIImage imageWithContentsOfFile:imageUrl.path]];
        }
        [object addImages:images];
        message.imageObject = object;
    } else if ([@"shareVideo" isEqualToString:call.method]) {
        message.text = call.arguments[@"text"];
        WBNewVideoObject *object = [WBNewVideoObject object];
        NSString *videoUri = call.arguments[@"videoUri"];
        [object addVideo:[NSURL URLWithString:videoUri]];
        message.videoObject = object;
    } else if ([@"shareWebpage" isEqualToString:call.method]) {
        WBWebpageObject *object = [WBWebpageObject object];
        object.objectID = [[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
        object.title = call.arguments[@"title"];
        object.description = call.arguments[@"description"];
        FlutterStandardTypedData *thumbData = call.arguments[@"thumbData"];
        if (thumbData != nil) {
            object.thumbnailData = thumbData.data;
        }
        object.webpageUrl = call.arguments[@"webpageUrl"];
        message.mediaObject = object;
    }
    WBSendMessageToWeiboRequest *request = [WBSendMessageToWeiboRequest request];
    request.message = message;
    [WeiboSDK sendRequest:request
               completion:^(BOOL success){
                   if (!success) {
                       NSLog(@"weibo_kit: Weibo rejected the share request");
                   }
               }];
    result(nil);
}

#pragma mark - AppDelegate

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [WeiboSDK handleOpenURL:url delegate:self];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [WeiboSDK handleOpenURL:url delegate:self];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    return [WeiboSDK handleOpenURL:url delegate:self];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *_Nonnull))restorationHandler {
    return [WeiboSDK handleOpenUniversalLink:userActivity delegate:self];
}

#if WEIBO_KIT_HAS_SCENE_LIFECYCLE
- (BOOL)scene:(UIScene *)scene
    openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts API_AVAILABLE(ios(13.0)) {
    BOOL handled = NO;
    for (UIOpenURLContext *context in URLContexts) {
        handled = [WeiboSDK handleOpenURL:context.URL delegate:self] || handled;
    }
    return handled;
}

- (BOOL)scene:(UIScene *)scene
    continueUserActivity:(NSUserActivity *)userActivity API_AVAILABLE(ios(13.0)) {
    return [WeiboSDK handleOpenUniversalLink:userActivity delegate:self];
}

- (BOOL)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions API_AVAILABLE(ios(13.0)) {
    BOOL handled = NO;
    for (UIOpenURLContext *context in connectionOptions.URLContexts) {
        handled = [WeiboSDK handleOpenURL:context.URL delegate:self] || handled;
    }
    for (NSUserActivity *activity in connectionOptions.userActivities) {
        handled = [WeiboSDK handleOpenUniversalLink:activity delegate:self] || handled;
    }
    return handled;
}
#endif

#pragma mark - WeiboSDKDelegate

- (void)didReceiveWeiboRequest:(WBBaseRequest *)request {
}

- (void)didReceiveWeiboResponse:(WBBaseResponse *)response {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSNumber numberWithInteger:response.statusCode] forKey:@"errorCode"];
    [dictionary setValue:response.userInfo.description forKey:@"errorMessage"];
    if ([response isKindOfClass:[WBAuthorizeResponse class]]) {
        if (response.statusCode == WeiboSDKResponseStatusCodeSuccess) {
            WBAuthorizeResponse *authorizeResponse = (WBAuthorizeResponse *)response;
            NSString *userId = authorizeResponse.userID;
            NSString *accessToken = authorizeResponse.accessToken;
            NSString *refreshToken = authorizeResponse.refreshToken;
            long long expiresTime = authorizeResponse.expirationDate.timeIntervalSince1970 * 1000;
            [dictionary setValue:userId forKey:@"userId"];
            [dictionary setValue:accessToken forKey:@"accessToken"];
            [dictionary setValue:refreshToken forKey:@"refreshToken"];
            [dictionary setValue:[NSNumber numberWithLongLong:expiresTime] forKey:@"expiresTime"];
        }
        [_channel invokeMethod:@"onAuthResp" arguments:dictionary];
    } else if ([response isKindOfClass:[WBSendMessageToWeiboResponse class]]) {
        [_channel invokeMethod:@"onShareMsgResp" arguments:dictionary];
    }
}

@end
