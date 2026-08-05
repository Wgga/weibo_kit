import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import common from '@ohos.app.ability.common';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import bundleManager from '@ohos.bundle.bundleManager';
import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  NewWantListener,
} from '@ohos/flutter_ohos';
import {
  AuthInfo,
  IWBAPI,
  MultiImageObject,
  Oauth2AccessToken,
  SdkListener,
  TextObject,
  UiError,
  VideoSourceObject,
  WBAPI,
  WbASListener,
  WeiboMultiMessage,
} from 'core';

const CHANNEL_NAME: string = 'wgga.github.io/weibo_kit';
const WEIBO_LINK: string = 'sinaweibo://';
const SUCCESS: number = 0;
const USER_CANCEL: number = -1;
const SHARE_FAILED: number = -8;
const UNKNOWN: number = -100;

/** HarmonyOS implementation backed by the official Weibo OpenSDK. */
export default class WeiboKitPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware,
  NewWantListener {
  private channel: MethodChannel | null = null;
  private abilityBinding: AbilityPluginBinding | null = null;
  private ability: UIAbility | null = null;
  private wbApi: IWBAPI | null = null;
  private registered: boolean = false;
  private initialWantHandled: boolean = false;

  getUniqueClassName(): string {
    return 'WeiboKitPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding;
    this.ability = binding.getAbility();
    binding.addOnNewWantListener(this);
  }

  onDetachedFromAbility(): void {
    this.abilityBinding?.removeOnNewWantListener(this);
    this.abilityBinding = null;
    this.ability = null;
    this.initialWantHandled = false;
  }

  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    if (this.registered) {
      this.requireWBApi().doWBAsResult(want, this.requireAbilityContext());
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'registerApp':
          this.registerApp(call, result);
          return;
        case 'isInstalled':
          result.success(bundleManager.canOpenLink(WEIBO_LINK));
          return;
        case 'isSupportMultipleImage':
          result.success(bundleManager.canOpenLink(WEIBO_LINK));
          return;
        case 'auth':
          this.authorize(result);
          return;
        case 'shareText':
        case 'shareImage':
        case 'shareMultiImage':
        case 'shareVideo':
          this.share(call, result);
          return;
        case 'shareWebpage':
          result.error(
            'unsupported',
            'The official Weibo OpenSDK for HarmonyOS does not support webpage sharing',
            null,
          );
          return;
        default:
          result.notImplemented();
      }
    } catch (error) {
      result.error('weibo_kit_error', this.errorMessage(error), null);
    }
  }

  private registerApp(call: MethodCall, result: MethodResult): void {
    if (this.registered) {
      result.success(null);
      return;
    }

    const authInfo: AuthInfo = new AuthInfo(
      this.requireAbilityContext(),
      this.stringArg(call, 'appKey'),
      this.stringArg(call, 'redirectUrl'),
      this.optionalStringArg(call, 'scope') ?? '',
      true,
    );
    this.wbApi = WBAPI.getInstance();
    const listener: SdkListener = {
      onInitSuccess: (): void => {
        this.registered = true;
        this.handleInitialWant();
        result.success(null);
      },
      onInitFail: (error: Error): void => {
        this.registered = false;
        result.error('register_failed', this.errorMessage(error), null);
      },
    };
    this.wbApi.registerApp(authInfo, listener);
  }

  private authorize(result: MethodResult): void {
    const listener: WbASListener = {
      onComplete: (token: Oauth2AccessToken): void => {
        this.channel?.invokeMethod('onAuthResp', {
          'errorCode': SUCCESS,
          'userId': token.getUid(),
          'accessToken': token.getAccessToken(),
          'expiresTime': token.getExpiresTime(),
        });
      },
      onError: (error: UiError): void => {
        this.channel?.invokeMethod('onAuthResp', this.errorResponse(error, UNKNOWN));
      },
      onCancel: (): void => {
        this.channel?.invokeMethod('onAuthResp', {
          'errorCode': USER_CANCEL,
          'errorMessage': 'Authorization cancelled',
        });
      },
    };
    this.requireWBApi().authorize(this.requireAbilityContext(), listener);
    result.success(null);
  }

  private share(call: MethodCall, result: MethodResult): void {
    const message: WeiboMultiMessage = new WeiboMultiMessage();
    const text: string | undefined = this.optionalStringArg(call, 'text');
    if (call.method === 'shareText') {
      const textObject: TextObject = new TextObject();
      textObject.text = this.stringArg(call, 'text');
      message.textObject = textObject;
    } else {
      if (text !== undefined) {
        const textObject: TextObject = new TextObject();
        textObject.text = text;
        message.textObject = textObject;
      }
      if (call.method === 'shareImage') {
        const imageUri: string | undefined = this.optionalStringArg(call, 'imageUri');
        if (imageUri === undefined) {
          throw new Error('HarmonyOS image sharing requires imageUri');
        }
        const image: MultiImageObject = new MultiImageObject();
        image.uriStrs = [imageUri];
        message.multiImageObject = image;
      } else if (call.method === 'shareMultiImage') {
        const image: MultiImageObject = new MultiImageObject();
        image.uriStrs = this.stringListArg(call, 'imageUris');
        message.multiImageObject = image;
      } else if (call.method === 'shareVideo') {
        const video: VideoSourceObject = new VideoSourceObject();
        video.videoPath = this.stringArg(call, 'videoUri');
        video.coverPath = this.stringArg(call, 'videoCoverUri');
        message.videoSourceObject = video;
      }
    }

    const listener: WbASListener = {
      onComplete: (): void => {
        this.channel?.invokeMethod('onShareMsgResp', { 'errorCode': SUCCESS });
      },
      onError: (error: UiError): void => {
        this.channel?.invokeMethod('onShareMsgResp', this.errorResponse(error, SHARE_FAILED));
      },
      onCancel: (): void => {
        this.channel?.invokeMethod('onShareMsgResp', {
          'errorCode': USER_CANCEL,
          'errorMessage': 'Sharing cancelled',
        });
      },
    };
    this.requireWBApi().shareMessage(this.requireAbilityContext(), message, listener);
    result.success(null);
  }

  private handleInitialWant(): void {
    if (this.initialWantHandled) {
      return;
    }
    const want: Want | undefined = this.ability?.launchWant;
    if (want !== undefined) {
      this.requireWBApi().doWBAsResult(want, this.requireAbilityContext());
      this.initialWantHandled = true;
    }
  }

  private requireWBApi(): IWBAPI {
    if (!this.registered || this.wbApi === null) {
      throw new Error('Call registerApp before using Weibo OpenSDK');
    }
    return this.wbApi;
  }

  private requireAbilityContext(): common.UIAbilityContext {
    if (this.ability === null) {
      throw new Error('weibo_kit requires a foreground UIAbility');
    }
    return this.ability.context;
  }

  private stringArg(call: MethodCall, key: string): string {
    const value: ESObject = call.argument(key);
    if (typeof value !== 'string' || value.trim().length === 0) {
      throw new Error(`${key} must be a non-empty string`);
    }
    return value;
  }

  private optionalStringArg(call: MethodCall, key: string): string | undefined {
    const value: ESObject = call.argument(key);
    return typeof value === 'string' && value.length > 0 ? value : undefined;
  }

  private stringListArg(call: MethodCall, key: string): string[] {
    const value: ESObject = call.argument(key);
    if (!Array.isArray(value) || value.length === 0 ||
      !value.every((item: ESObject): boolean => typeof item === 'string' && item.length > 0)) {
      throw new Error(`${key} must be a non-empty string array`);
    }
    return value as string[];
  }

  private errorResponse(error: UiError, fallbackCode: number): Record<string, Object> {
    return {
      'errorCode': error.errorCode === 0 ? fallbackCode : error.errorCode,
      'errorMessage': error.errorMessage,
    };
  }

  private errorMessage(error: ESObject): string {
    return error instanceof Error ? error.message : `${error}`;
  }
}
