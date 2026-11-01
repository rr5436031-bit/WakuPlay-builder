package com.wakuplay.notify;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;
import androidx.core.app.NotificationManagerCompat;

import java.util.HashMap;
import java.util.Map;

/** Pengganti WpNotifyPlugin (Capacitor) untuk Flutter: logika sama, tanpa dependensi Capacitor. */
public final class NotifyBridge {
    private NotifyBridge() {}

    public static boolean configure(Context c, String url, String key, String device, String secret, String uid, String since, long interval) {
        if (url == null || !url.startsWith("https://") || key == null || key.isEmpty() || device == null || device.isEmpty() || secret == null || secret.length() < 32) return false;
        while (url.endsWith("/")) url = url.substring(0, url.length() - 1);
        if (interval < 5000L) interval = 5000L;
        NotifyCore.sp(c).edit().putString("url", url).putString("key", key).putString("device", device).putString("secret", secret)
                .putString("uid", uid == null ? "" : uid).putString("since", since == null ? "" : since).putLong("interval", interval).apply();
        NotifyCore.apply(c);
        return true;
    }

    public static void setSpeed(Context c, long interval) {
        if (interval < 5000L) interval = 5000L;
        NotifyCore.sp(c).edit().putLong("interval", interval).apply();
        NotifyCore.apply(c);
    }

    private static boolean ignoringBattery(Context c) {
        try {
            if (Build.VERSION.SDK_INT < 23) return true;
            PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
            return pm != null && pm.isIgnoringBatteryOptimizations(c.getPackageName());
        } catch (Throwable t) { return false; }
    }

    public static Map<String, Object> status(Context c) {
        Map<String, Object> m = new HashMap<>();
        m.put("configured", NotifyCore.configured(c));
        m.put("uid", NotifyCore.sp(c).getString("uid", ""));
        m.put("device", NotifyCore.sp(c).getString("device", ""));
        m.put("enabled", NotificationManagerCompat.from(c).areNotificationsEnabled());
        m.put("ignoringBattery", ignoringBattery(c));
        m.put("service", PollService.running);
        return m;
    }

    public static void advance(Context c, String since) {
        if (since == null || since.isEmpty()) return;
        String cur = NotifyCore.sp(c).getString("since", "");
        NotifyCore.sp(c).edit().putString("since", NotifyCore.newer(cur, since)).apply();
    }

    public static void setForeground(boolean on) { NotifyCore.foreground = on; }

    public static void clear(Context c) { NotifyCore.clear(c); }

    public static void openBatterySettings(Context c) {
        try {
            Intent i = ignoringBattery(c) ? new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    : new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:" + c.getPackageName()));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            c.startActivity(i);
        } catch (Throwable t) {
            try { Intent i = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS); i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); c.startActivity(i); } catch (Throwable ignored) { }
        }
    }

    public static void openNotifSettings(Context c) {
        try {
            Intent i = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
            i.putExtra(Settings.EXTRA_APP_PACKAGE, c.getPackageName());
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            c.startActivity(i);
        } catch (Throwable t) {
            try { Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + c.getPackageName())); i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); c.startActivity(i); } catch (Throwable ignored) { }
        }
    }
}
