package com.wakuplay.gifurl;

import android.app.Activity;
import android.app.Dialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.net.http.SslError;
import android.provider.OpenableColumns;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.SslErrorHandler;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.regex.Pattern;

@CapacitorPlugin(name = "GifUrl", requestCodes = { 9417 })
public class GifUrlPlugin extends Plugin {

    private static final int REQ_FILE = 9417;
    private static final long MAX_BYTES = 5L * 1024 * 1024;
    private static final Pattern GIF_URL = Pattern.compile("^https://[^\\s\"'<>()\\\\]+\\.gif(\\?[^\\s\"'<>()\\\\]*)?$", Pattern.CASE_INSENSITIVE);

    private Dialog dialog;
    private WebView web;
    private TextView copyBtn;
    private TextView status;
    private String foundUrl = null;
    private ValueCallback<Uri[]> fileCb = null;
    private String script = null;

    private int dp(int v) { return Math.round(v * getActivity().getResources().getDisplayMetrics().density); }

    private String loadScript() {
        if (script != null) return script;
        try {
            InputStream in = getContext().getAssets().open("wp-gifurl.js");
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buf = new byte[4096]; int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            in.close();
            script = out.toString("UTF-8");
        } catch (Exception e) { script = ""; }
        return script;
    }

    private static boolean allowed(String url) {
        try {
            Uri u = Uri.parse(url);
            String h = u.getHost();
            return "https".equals(u.getScheme()) && h != null && (h.equals("picturetolink.com") || h.endsWith(".picturetolink.com"));
        } catch (Exception e) { return false; }
    }

    private class Bridge {
        @JavascriptInterface
        public void url(final String u) {
            if (u == null || u.length() > 500 || !GIF_URL.matcher(u).matches()) return;
            getActivity().runOnUiThread(new Runnable() {
                @Override public void run() {
                    try {
                        if (web == null || !allowed(web.getUrl())) return;
                        foundUrl = u;
                        if (copyBtn != null) { copyBtn.setAlpha(1f); copyBtn.setEnabled(true); }
                        if (status != null) status.setText("Link siap, tekan Salin");
                        JSObject o = new JSObject();
                        o.put("url", u);
                        notifyListeners("gifUrl", o);
                    } catch (Exception ignored) { }
                }
            });
        }
    }

    private void injectScript(WebView v, String url) {
        if (url == null || !allowed(url)) return;
        String s = loadScript();
        if (!s.isEmpty()) v.evaluateJavascript(s, null);
    }

    private void cancelChooser() {
        if (fileCb != null) { try { fileCb.onReceiveValue(null); } catch (Exception ignored) { } fileCb = null; }
    }

    private long sizeOf(Uri u) {
        Cursor c = null;
        try {
            c = getContext().getContentResolver().query(u, new String[] { OpenableColumns.SIZE }, null, null, null);
            if (c != null && c.moveToFirst() && !c.isNull(0)) return c.getLong(0);
        } catch (Exception ignored) { } finally { if (c != null) c.close(); }
        return -1;
    }

    private String typeOf(Uri u) {
        try { return getContext().getContentResolver().getType(u); } catch (Exception e) { return null; }
    }

    @Override
    protected void handleOnActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != REQ_FILE) return;
        ValueCallback<Uri[]> cb = fileCb; fileCb = null;
        if (cb == null) return;
        Uri[] r = WebChromeClient.FileChooserParams.parseResult(resultCode, data);
        if (r == null || r.length == 0) { cb.onReceiveValue(null); return; }
        Uri u = r[0];
        String t = typeOf(u);
        long sz = sizeOf(u);
        if (t == null || !t.equals("image/gif")) { Toast.makeText(getContext(), "File harus berformat .gif", Toast.LENGTH_LONG).show(); cb.onReceiveValue(null); return; }
        if (sz < 0 || sz >= MAX_BYTES) { Toast.makeText(getContext(), "GIF harus di bawah 5 MB", Toast.LENGTH_LONG).show(); cb.onReceiveValue(null); return; }
        foundUrl = null;
        if (copyBtn != null) { copyBtn.setAlpha(.4f); copyBtn.setEnabled(false); }
        if (status != null) status.setText("Mengunggah…");
        if (web != null) web.evaluateJavascript("window.__wpUploaded=true", null);
        cb.onReceiveValue(new Uri[] { u });
    }

    @PluginMethod
    public void open(final PluginCall call) {
        final String url = call.getString("url");
        final String title = call.getString("title", "GIF ke Link");
        if (url == null || !allowed(url)) { call.reject("Alamat tidak valid"); return; }
        final Activity act = getActivity();
        act.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    closeInternal(false);
                    foundUrl = null;
                    dialog = new Dialog(act, android.R.style.Theme_Black_NoTitleBar);
                    Window w = dialog.getWindow();
                    if (w != null) {
                        w.setStatusBarColor(Color.parseColor("#0a0b0d"));
                        w.setNavigationBarColor(Color.parseColor("#0a0b0d"));
                        w.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
                    }
                    LinearLayout root = new LinearLayout(act);
                    root.setOrientation(LinearLayout.VERTICAL);
                    root.setBackgroundColor(Color.parseColor("#111214"));

                    LinearLayout bar = new LinearLayout(act);
                    bar.setOrientation(LinearLayout.HORIZONTAL);
                    bar.setGravity(Gravity.CENTER_VERTICAL);
                    bar.setBackgroundColor(Color.parseColor("#0a0b0d"));
                    bar.setPadding(dp(16), 0, dp(4), 0);

                    LinearLayout titles = new LinearLayout(act);
                    titles.setOrientation(LinearLayout.VERTICAL);
                    TextView tv = new TextView(act);
                    tv.setText(title); tv.setTextColor(Color.WHITE); tv.setTextSize(16);
                    tv.setTypeface(null, android.graphics.Typeface.BOLD); tv.setSingleLine(true);
                    titles.addView(tv);
                    status = new TextView(act);
                    status.setText("Pilih GIF (di bawah 5 MB), tunggu link muncul"); status.setTextColor(Color.parseColor("#9aa4b8")); status.setTextSize(11); status.setSingleLine(true);
                    status.setEllipsize(android.text.TextUtils.TruncateAt.END);
                    titles.addView(status);
                    bar.addView(titles, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

                    copyBtn = new TextView(act);
                    copyBtn.setText("Salin"); copyBtn.setTextColor(Color.parseColor("#3a2500")); copyBtn.setTextSize(14);
                    copyBtn.setTypeface(null, android.graphics.Typeface.BOLD); copyBtn.setGravity(Gravity.CENTER);
                    copyBtn.setBackgroundColor(Color.parseColor("#ffd45a"));
                    copyBtn.setPadding(dp(16), 0, dp(16), 0);
                    copyBtn.setAlpha(.4f); copyBtn.setEnabled(false);
                    copyBtn.setOnClickListener(new View.OnClickListener() {
                        @Override public void onClick(View v) {
                            if (foundUrl == null) return;
                            try {
                                ClipboardManager cm = (ClipboardManager) act.getSystemService(Context.CLIPBOARD_SERVICE);
                                cm.setPrimaryClip(ClipData.newPlainText("GIF", foundUrl));
                                Toast.makeText(act, "Link .gif disalin", Toast.LENGTH_SHORT).show();
                            } catch (Exception ignored) { }
                        }
                    });
                    LinearLayout.LayoutParams clp = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(36));
                    clp.rightMargin = dp(4);
                    bar.addView(copyBtn, clp);

                    TextView x = new TextView(act);
                    x.setText("\u2715"); x.setTextColor(Color.WHITE); x.setTextSize(22); x.setGravity(Gravity.CENTER);
                    x.setContentDescription("Tutup");
                    x.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View v) { closeInternal(true); } });
                    bar.addView(x, new LinearLayout.LayoutParams(dp(52), dp(52)));
                    root.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)));

                    final ProgressBar pb = new ProgressBar(act, null, android.R.attr.progressBarStyleHorizontal);
                    pb.setMax(100);
                    root.addView(pb, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(3)));

                    web = new WebView(act);
                    web.setBackgroundColor(Color.parseColor("#111214"));
                    web.addJavascriptInterface(new Bridge(), "WPGif");
                    WebSettings s = web.getSettings();
                    s.setJavaScriptEnabled(true);
                    s.setDomStorageEnabled(true);
                    s.setAllowFileAccess(false);
                    s.setAllowContentAccess(true);
                    s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
                    s.setSupportMultipleWindows(false);
                    s.setJavaScriptCanOpenWindowsAutomatically(false);
                    CookieManager cm = CookieManager.getInstance();
                    cm.setAcceptCookie(true);
                    cm.setAcceptThirdPartyCookies(web, true);

                    web.setWebChromeClient(new WebChromeClient() {
                        @Override public void onProgressChanged(WebView v, int p) { pb.setProgress(p); pb.setVisibility(p >= 100 ? View.GONE : View.VISIBLE); }
                        @Override public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams params) {
                            cancelChooser();
                            fileCb = cb;
                            try {
                                Intent it = new Intent(Intent.ACTION_GET_CONTENT);
                                it.addCategory(Intent.CATEGORY_OPENABLE);
                                it.setType("image/gif");
                                it.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false);
                                act.startActivityForResult(Intent.createChooser(it, "Pilih GIF"), REQ_FILE);
                            } catch (Exception e) { cancelChooser(); return false; }
                            return true;
                        }
                    });
                    web.setWebViewClient(new WebViewClient() {
                        @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
                            return !allowed(r.getUrl().toString());
                        }
                        @Override public void onPageStarted(WebView v, String u, Bitmap f) { injectScript(v, u); }
                        @Override public void onPageFinished(WebView v, String u) { injectScript(v, u); v.evaluateJavascript("window.__wpGifApply&&window.__wpGifApply()", null); }
                        @Override public void onReceivedSslError(WebView v, SslErrorHandler h, SslError e) { h.cancel(); }
                    });

                    root.addView(web, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
                    dialog.setContentView(root);
                    dialog.setOnKeyListener(new Dialog.OnKeyListener() {
                        @Override public boolean onKey(android.content.DialogInterface d, int code, KeyEvent ev) {
                            if (code == KeyEvent.KEYCODE_BACK && ev.getAction() == KeyEvent.ACTION_UP) { closeInternal(true); return true; }
                            return code == KeyEvent.KEYCODE_BACK;
                        }
                    });
                    dialog.setCancelable(false);
                    dialog.show();
                    web.loadUrl(url);
                    call.resolve();
                } catch (Exception e) {
                    call.reject("Gagal membuka GIF ke Link");
                }
            }
        });
    }

    @PluginMethod
    public void close(final PluginCall call) {
        getActivity().runOnUiThread(new Runnable() { @Override public void run() { closeInternal(false); call.resolve(); } });
    }

    private void closeInternal(boolean notify) {
        try {
            cancelChooser();
            if (web != null) { web.stopLoading(); web.destroy(); web = null; }
            if (dialog != null) { dialog.dismiss(); dialog = null; }
        } catch (Exception ignored) { }
        copyBtn = null; status = null;
        if (notify) notifyListeners("closed", new JSObject());
    }

    @Override
    protected void handleOnDestroy() { closeInternal(false); }
}
