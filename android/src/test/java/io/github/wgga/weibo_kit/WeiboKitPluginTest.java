package io.github.wgga.weibo_kit;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import org.junit.Test;

/** Unit tests for the Java plugin implementation. */
public class WeiboKitPluginTest {
  @Test
  public void onMethodCall_isInstalled_requiresRegistration() {
    WeiboKitPlugin plugin = new WeiboKitPlugin();
    MethodChannel.Result result = mock(MethodChannel.Result.class);

    plugin.onMethodCall(new MethodCall("isInstalled", null), result);

    verify(result).error("FAILED", "请先调用registerApp", null);
  }
}
