package com.wakuplay.notify;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;

import androidx.core.app.NotificationManagerCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "WpNotify")
public class WpNotifyPlugin extends Plugin {

    @Override
    public void load() {
        try {
            if (getActivity() != null) emitTap(getActivity().getIntent());
        } catch (Throwable ignored) {  }
    }

    @Override
    protected void handleOnNewIntent(Intent intent) {
        super.handleOnNewIntent(intent);
        emitTap(intent);
    }

    private void emitTap(Intent intent) {
        if (intent == null || !intent.hasExtra("wp_type")) return;
        JSObject o = new JSObject();
        o.put("nid", String.valueOf(intent.getLongExtra("wp_nid", 0)));
        o.put("type", intent.getStringExtra("wp_type"));
        o.put("title", intent.getStringExtra("wp_title"));
        o.put("data", intent.getStringExtra("wp_data"));
        intent.removeExtra("wp_type");
        notifyListeners("notifTap", o, true);
    }

    private Context ctx() { return getContext().getApplicationContext(); }

    @PluginMethod
    public void configure(PluginCall call) {
        String url = call.getString("url", "");
        String key = call.getString("key", "");
        String device = call.getString("device", "");
        String secret = call.getString("secret", "");
        if (url == null || !url.startsWith("https://") || key == null || key.isEmpty() || device == null || device.isEmpty() || secret == null || secret.length() < 32) {
            call.reject("data tidak valid");
            return;
        }
        while (url.endsWith("/")) url = url.substring(0, url.length() - 1);
        long interval = call.getLong("interval", NotifyCore.DEFAULT_INTERVAL_MS);
        if (interval < 5000L) interval = 5000L;
        NotifyCore.sp(ctx()).edit()
                .putString("url", url).putString("key", key).putString("device", device).putString("secret", secret)
                .putString("uid", call.getString("uid", ""))
                .putString("since", call.getString("since", ""))
                .putLong("interval", interval).apply();
        NotifyCore.apply(ctx());
        call.resolve();
    }

    @PluginMethod
    public void setSpeed(PluginCall call) {
        long interval = call.getLong("interval", NotifyCore.DEFAULT_INTERVAL_MS);
        if (interval < 5000L) interval = 5000L;
        NotifyCore.sp(ctx()).edit().putLong("interval", interval).apply();
        NotifyCore.apply(ctx());
        call.resolve();
    }

    private boolean ignoringBattery() {
        try {
            if (Build.VERSION.SDK_INT < 23) return true;
            PowerManager pm = (PowerManager) ctx().getSystemService(Context.POWER_SERVICE);
            return pm != null && pm.isIgnoringBatteryOptimizations(ctx().getPackageName());
        } catch (Throwable t) {
            return false;
        }
    }

    @PluginMethod
    public void status(PluginCall call) {
        JSObject o = new JSObject();
        o.put("configured", NotifyCore.configured(ctx()));
        o.put("uid", NotifyCore.sp(ctx()).getString("uid", ""));
        o.put("device", NotifyCore.sp(ctx()).getString("device", ""));
        o.put("enabled", NotificationManagerCompat.from(ctx()).areNotificationsEnabled());
        o.put("ignoringBattery", ignoringBattery());
        o.put("service", PollService.running);
        call.resolve(o);
    }

    @PluginMethod
    public void advance(PluginCall call) {
        String t = call.getString("since", "");
        if (t != null && !t.isEmpty()) {
            String cur = NotifyCore.sp(ctx()).getString("since", "");
            NotifyCore.sp(ctx()).edit().putString("since", NotifyCore.newer(cur, t)).apply();
        }
        call.resolve();
    }

    @PluginMethod
    public void setForeground(PluginCall call) {
        NotifyCore.foreground = Boolean.TRUE.equals(call.getBoolean("on", false));
        call.resolve();
    }

    @PluginMethod
    public void clear(PluginCall call) {
        NotifyCore.clear(ctx());
        call.resolve();
    }

    @PluginMethod
    public void openBatterySettings(PluginCall call) {
        boolean ignoring = ignoringBattery();
        boolean opened = false;
        if (!ignoring && Build.VERSION.SDK_INT >= 23) {
            try {
                Intent i = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:" + getContext().getPackageName()));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(i);
                opened = true;
            } catch (Throwable t) {
                try {
                    Intent i = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
                    i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    getContext().startActivity(i);
                    opened = true;
                } catch (Throwable ignored) {  }
            }
        }
        if (!opened) {
            try {
                Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + getContext().getPackageName()));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(i);
            } catch (Throwable ignored) {  }
        }
        JSObject o = new JSObject();
        o.put("ignoring", ignoring);
        call.resolve(o);
    }

    @PluginMethod
    public void openNotifSettings(PluginCall call) {
        try {
            Intent i = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
            i.putExtra(Settings.EXTRA_APP_PACKAGE, getContext().getPackageName());
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            getContext().startActivity(i);
        } catch (Throwable t) {
            try {
                Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + getContext().getPackageName()));
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                getContext().startActivity(i);
            } catch (Throwable ignored) {  }
        }
        call.resolve();
    }
}
