package com.wakuplay.pip;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.graphics.Color;
import android.content.pm.ActivityInfo;
import android.os.Build;
import android.provider.Settings;
import android.util.Rational;
import android.view.Window;
import android.view.WindowManager;

import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "Pip")
public class PipPlugin extends Plugin {

    private float insetTop = 0f;
    private float insetBottom = 0f;
    private float insetKb = 0f;

    @Override
    public void load() {
        final Activity act = getActivity();
        if (act == null) return;
        act.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    Window w = act.getWindow();
                    WindowCompat.setDecorFitsSystemWindows(w, false);
                    w.setStatusBarColor(Color.TRANSPARENT);
                    w.setNavigationBarColor(Color.TRANSPARENT);
                    if (Build.VERSION.SDK_INT >= 29) {
                        w.setNavigationBarContrastEnforced(false);
                        w.setStatusBarContrastEnforced(false);
                    }
                    if (Build.VERSION.SDK_INT >= 28) {
                        WindowManager.LayoutParams lp = w.getAttributes();
                        lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
                        w.setAttributes(lp);
                    }
                    WindowInsetsControllerCompat c = WindowCompat.getInsetsController(w, w.getDecorView());
                    c.setAppearanceLightStatusBars(false);
                    c.setAppearanceLightNavigationBars(false);

                    final float density = act.getResources().getDisplayMetrics().density;
                    ViewCompat.setOnApplyWindowInsetsListener(w.getDecorView(), new androidx.core.view.OnApplyWindowInsetsListener() {
                        @Override
                        public WindowInsetsCompat onApplyWindowInsets(android.view.View v, WindowInsetsCompat insets) {
                            Insets bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout());
                            insetTop = bars.top / density;
                            insetBottom = bars.bottom / density;
                            Insets ime = insets.getInsets(WindowInsetsCompat.Type.ime());
                            insetKb = insets.isVisible(WindowInsetsCompat.Type.ime()) ? ime.bottom / density : 0f;
                            notifyListeners("insets", insetsObj());
                            return ViewCompat.onApplyWindowInsets(v, insets);
                        }
                    });
                    ViewCompat.requestApplyInsets(w.getDecorView());
                } catch (Exception ignored) {
                }
            }
        });
    }

    private JSObject insetsObj() {
        JSObject o = new JSObject();
        o.put("top", insetTop);
        o.put("bottom", insetBottom);
        o.put("kb", insetKb);
        return o;
    }

    @PluginMethod
    public void getDeviceId(PluginCall call) {
        JSObject o = new JSObject();
        String id = "";
        try { id = Settings.Secure.getString(getContext().getContentResolver(), Settings.Secure.ANDROID_ID); } catch (Exception ignored) { }
        o.put("id", id == null ? "" : id);
        call.resolve(o);
    }

    @PluginMethod
    public void getInsets(PluginCall call) {
        call.resolve(insetsObj());
    }

    private PictureInPictureParams params(boolean autoEnter) {
        PictureInPictureParams.Builder b = new PictureInPictureParams.Builder().setAspectRatio(new Rational(16, 9));
        if (Build.VERSION.SDK_INT >= 31) {
            b.setAutoEnterEnabled(autoEnter);
        }
        return b.build();
    }

    @PluginMethod
    public void setActive(final PluginCall call) {
        final boolean active = Boolean.TRUE.equals(call.getBoolean("active", false));
        final Activity act = getActivity();
        if (act == null || Build.VERSION.SDK_INT < 26) {
            call.resolve();
            return;
        }
        act.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    act.setPictureInPictureParams(params(active));
                } catch (Exception ignored) {
                }
                call.resolve();
            }
        });
    }

    @PluginMethod
    public void isActive(PluginCall call) {
        JSObject o = new JSObject();
        Activity act = getActivity();
        o.put("active", act != null && Build.VERSION.SDK_INT >= 24 && act.isInPictureInPictureMode());
        call.resolve(o);
    }

    @PluginMethod
    public void enter(final PluginCall call) {
        final Activity act = getActivity();
        if (act == null || Build.VERSION.SDK_INT < 26) {
            call.reject("PiP tidak didukung");
            return;
        }
        act.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    act.enterPictureInPictureMode(params(false));
                    call.resolve();
                } catch (Exception e) {
                    call.reject("PiP gagal: " + e.getMessage());
                }
            }
        });
    }

    @PluginMethod
    public void setLandscape(final PluginCall call) {
        final boolean on = Boolean.TRUE.equals(call.getBoolean("enabled", false));
        final Activity act = getActivity();
        if (act == null) {
            call.resolve();
            return;
        }
        act.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    act.setRequestedOrientation(on
                            ? ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                            : ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
                    if (Build.VERSION.SDK_INT >= 28) {
                        WindowManager.LayoutParams lp = act.getWindow().getAttributes();
                        lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
                        act.getWindow().setAttributes(lp);
                    }
                } catch (Exception ignored) {
                }
                call.resolve();
            }
        });
    }

    @PluginMethod
    public void setImmersive(final PluginCall call) {
        final boolean on = Boolean.TRUE.equals(call.getBoolean("enabled", false));
        final Activity act = getActivity();
        if (act == null) {
            call.resolve();
            return;
        }
        act.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    Window w = act.getWindow();
                    WindowInsetsControllerCompat c = WindowCompat.getInsetsController(w, w.getDecorView());
                    if (on) {
                        c.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
                        c.hide(WindowInsetsCompat.Type.systemBars());
                    } else {
                        c.show(WindowInsetsCompat.Type.systemBars());
                    }
                } catch (Exception ignored) {
                }
                call.resolve();
            }
        });
    }
}
