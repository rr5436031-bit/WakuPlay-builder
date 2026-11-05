package com.wibuadmin.panel;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.webkit.WebViewAssetLoader;

import org.json.JSONObject;

/** Wrapper tipis: menampilkan panel (assets/index.html) dan meneruskan callback login Google. */
public class MainActivity extends Activity {

    private static final String APP_URL = "https://appassets.androidplatform.net/assets/index.html";
    private static final String CALLBACK_SCHEME = "wibuadmin";

    private WebView web;
    private WebViewAssetLoader loader;
    private boolean pageReady = false;
    private String pendingCallback = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        loader = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();

        web = new WebView(this);
        setContentView(web);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);          // Supabase menyimpan sesi & code verifier PKCE di localStorage
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setSupportZoom(false);
        s.setUseWideViewPort(true);      // pakai lebar layar HP, bukan lebar desktop
        s.setLoadWithOverviewMode(true);
        s.setTextZoom(100);

        web.addJavascriptInterface(new Bridge(), "AndroidBridge");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return loader.shouldInterceptRequest(request.getUrl());
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri u = request.getUrl();
                if ("appassets.androidplatform.net".equals(u.getHost())) return false;
                startActivity(new Intent(Intent.ACTION_VIEW, u));   // link luar dibuka di browser
                return true;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                pageReady = true;
                if (pendingCallback != null) {
                    deliverCallback(pendingCallback);
                    pendingCallback = null;
                }
            }
        });

        web.loadUrl(APP_URL);
        handleIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent == null || intent.getData() == null) return;
        Uri data = intent.getData();
        if (!CALLBACK_SCHEME.equals(data.getScheme())) return;
        String url = data.toString();
        if (pageReady) deliverCallback(url);
        else pendingCallback = url;
    }

    private void deliverCallback(String url) {
        web.evaluateJavascript(
                "window.onOAuthCallback && window.onOAuthCallback(" + JSONObject.quote(url) + ");", null);
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) web.goBack();
        else super.onBackPressed();
    }

    /** Dipanggil dari JS: membuka URL login Google di browser sistem (Google memblokir login di dalam WebView). */
    public class Bridge {
        @JavascriptInterface
        public void openExternal(final String url) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                }
            });
        }
    }
}
