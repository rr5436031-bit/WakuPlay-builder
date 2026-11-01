package com.wakuplay.pay;

import android.app.Activity;
import android.app.Dialog;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.net.http.SslError;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.SslErrorHandler;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

@CapacitorPlugin(name = "Pay")
public class PayPlugin extends Plugin {

    private Dialog dialog;
    private WebView web;
    private String basePath = "";
    private String lastReported = "";
    private String fillJson = "{}";
    private boolean autoFill = true;
    private String fillScript = null;

    private int dp(int v) { return Math.round(v * getActivity().getResources().getDisplayMetrics().density); }

    private String loadScript() {
        if (fillScript != null) return fillScript;
        try {
            InputStream in = getContext().getAssets().open("wp-pay-fill.js");
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[4096]; int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            in.close();
            fillScript = out.toString("UTF-8");
        } catch (Exception e) { fillScript = ""; }
        return fillScript;
    }

    private static boolean isSocia(String url) {
        try {
            Uri u = Uri.parse(url);
            String h = u.getHost();
            return "https".equals(u.getScheme()) && h != null && (h.equals("sociabuzz.com") || h.endsWith(".sociabuzz.com"));
        } catch (Exception e) { return false; }
    }

    private void injectFill(WebView v, String url) {
        if (url == null || !isSocia(url)) return;
        String s = loadScript();
        if (s.isEmpty()) return;

        v.evaluateJavascript("window.__WPAUTO=" + (autoFill ? "true" : "false") + ";window.__WPFILL=" + fillJson + ";" + s, null);
    }

    private void reportUrl(String url) {
        if (url == null || !isSocia(url)) return;
        try {
            Uri u = Uri.parse(url);
            String clean = u.buildUpon().fragment(null).build().toString();
            String path = u.getPath() == null ? "" : u.getPath();

            if (path.equals(basePath) || path.equals(basePath + "/") || clean.equals(lastReported)) return;
            lastReported = clean;
            JSObject o = new JSObject();
            o.put("url", clean);
            notifyListeners("payUrl", o);
        } catch (Exception ignored) { }
    }

    private class Bridge {
        @android.webkit.JavascriptInterface
        public void qr(final String src) {
            if (src == null || src.length() > 400000 || !(src.startsWith("data:image/") || src.startsWith("https://"))) return;
            getActivity().runOnUiThread(new Runnable() {
                @Override public void run() {
                    try {
                        if (web == null || !isSocia(web.getUrl())) return;
                        JSObject o = new JSObject();
                        o.put("src", src);
                        notifyListeners("qr", o);
                    } catch (Exception ignored) { }
                }
            });
        }
    }

    @PluginMethod
    public void open(final PluginCall call) {
        final String url = call.getString("url");
        final String title = call.getString("title", "Pembayaran Premium");
        final JSObject fill = call.getObject("fill");
        autoFill = call.getBoolean("autoFill", true);
        if (url == null || !isSocia(url)) { call.reject("Alamat pembayaran tidak valid"); return; }
        fillJson = fill == null ? "{}" : fill.toString();
        lastReported = "";
        try { basePath = Uri.parse(call.getString("basePath", url)).getPath(); } catch (Exception e) { basePath = ""; }
        if (basePath == null) basePath = "";

        final Activity act = getActivity();
        act.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    closeInternal(false);
                    dialog = new Dialog(act, android.R.style.Theme_Black_NoTitleBar);
                    Window w = dialog.getWindow();
                    if (w != null) {
                        w.setStatusBarColor(Color.parseColor("#0a0b0d"));
                        w.setNavigationBarColor(Color.parseColor("#0a0b0d"));
                        w.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
                    }

                    LinearLayout root = new LinearLayout(act);
                    root.setOrientation(LinearLayout.VERTICAL);
                    root.setBackgroundColor(Color.WHITE);

                    LinearLayout bar = new LinearLayout(act);
                    bar.setOrientation(LinearLayout.HORIZONTAL);
                    bar.setGravity(Gravity.CENTER_VERTICAL);
                    bar.setBackgroundColor(Color.parseColor("#0a0b0d"));
                    bar.setPadding(dp(16), 0, dp(4), 0);
                    TextView tv = new TextView(act);
                    tv.setText(title);
                    tv.setTextColor(Color.WHITE);
                    tv.setTextSize(16);
                    tv.setTypeface(null, android.graphics.Typeface.BOLD);
                    tv.setSingleLine(true);
                    tv.setEllipsize(android.text.TextUtils.TruncateAt.END);
                    bar.addView(tv, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
                    TextView x = new TextView(act);
                    x.setText("\u2715");
                    x.setTextColor(Color.WHITE);
                    x.setTextSize(22);
                    x.setGravity(Gravity.CENTER);
                    x.setContentDescription("Tutup");
                    x.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { closeInternal(true); } });
                    bar.addView(x, new LinearLayout.LayoutParams(dp(52), dp(52)));
                    root.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));

                    ProgressBar pb = new ProgressBar(act, null, android.R.attr.progressBarStyleHorizontal);
                    pb.setMax(100);
                    root.addView(pb, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(3)));

                    web = new WebView(act);
                    web.addJavascriptInterface(new Bridge(), "WPPay");
                    WebSettings s = web.getSettings();
                    s.setJavaScriptEnabled(true);
                    s.setDomStorageEnabled(true);
                    s.setAllowFileAccess(false);
                    s.setAllowContentAccess(false);
                    s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
                    s.setSupportMultipleWindows(false);
                    CookieManager cm = CookieManager.getInstance();
                    cm.setAcceptCookie(true);
                    cm.setAcceptThirdPartyCookies(web, true);

                    final ProgressBar fpb = pb;
                    web.setWebChromeClient(new WebChromeClient() {
                        @Override public void onProgressChanged(WebView v, int p) {
                            fpb.setProgress(p);
                            fpb.setVisibility(p >= 100 ? View.GONE : View.VISIBLE);
                        }
                    });
                    web.setWebViewClient(new WebViewClient() {
                        @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                            Uri u = r.getUrl();
                            String sc = u.getScheme();
                            if ("https".equals(sc)) return false;
                            if ("http".equals(sc)) return true;
                            try {
                                Intent it = "intent".equals(sc) ? Intent.parseUri(u.toString(), Intent.URI_INTENT_SCHEME) : new Intent(Intent.ACTION_VIEW, u);
                                it.addCategory(Intent.CATEGORY_BROWSABLE);
                                it.setComponent(null);
                                act.startActivity(it);
                            } catch (Exception ignored) { }
                            return true;
                        }
                        @Override public void onPageStarted(WebView v, String u, Bitmap f) { reportUrl(u); }
                        @Override public void onPageFinished(WebView v, String u) { injectFill(v, u); reportUrl(u); }
                        @Override public void doUpdateVisitedHistory(WebView v, String u, boolean reload) { reportUrl(u); }
                        @Override public void onReceivedSslError(WebView v, SslErrorHandler h, SslError e) { h.cancel(); }
                    });

                    root.addView(web, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
                    dialog.setContentView(root);
                    dialog.setOnKeyListener(new Dialog.OnKeyListener() {
                        @Override public boolean onKey(android.content.DialogInterface d, int code, KeyEvent ev) {
                            if (code == KeyEvent.KEYCODE_BACK && ev.getAction() == KeyEvent.ACTION_UP) {
                                if (web != null && web.canGoBack()) web.goBack(); else closeInternal(true);
                                return true;
                            }
                            return code == KeyEvent.KEYCODE_BACK;
                        }
                    });
                    dialog.setCancelable(false);
                    dialog.show();
                    web.loadUrl(url);
                    call.resolve();
                } catch (Exception e) {
                    call.reject("Gagal membuka pembayaran");
                }
            }
        });
    }

    @PluginMethod
    public void close(final PluginCall call) {
        getActivity().runOnUiThread(new Runnable() {
            @Override public void run() { closeInternal(false); call.resolve(); }
        });
    }

    private void closeInternal(boolean notify) {
        try {
            if (web != null) { web.stopLoading(); web.destroy(); web = null; }
            if (dialog != null) { dialog.dismiss(); dialog = null; }
        } catch (Exception ignored) { }
        if (notify) notifyListeners("closed", new JSObject());
    }

    @Override
    protected void handleOnDestroy() { closeInternal(false); }
}
