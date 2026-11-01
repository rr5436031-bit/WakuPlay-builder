package com.wakuplay.notify;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

final class NotifyCore {
    static final String PREF = "wp_notify";
    static final String ACTION_POLL = "com.wakuplay.notify.POLL";
    static final String CHANNEL = "wakuplay_notif_v2";
    static final long DEFAULT_INTERVAL_MS = 5 * 60 * 1000L;
    static final long FIRST_DELAY_MS = 60 * 1000L;
    static final long WATCHDOG_MS = 5 * 60 * 1000L;
    static final long FAST_BELOW_MS = 120 * 1000L;

    static volatile boolean foreground = false;
    static volatile boolean lastOk = true;

    private NotifyCore() {}

    static SharedPreferences sp(Context c) {
        return c.getApplicationContext().getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    static boolean configured(Context c) {
        SharedPreferences p = sp(c);
        return !p.getString("url", "").isEmpty() && !p.getString("device", "").isEmpty() && !p.getString("secret", "").isEmpty();
    }

    /** Mode cepat = layanan latar permanen (interval < 2 menit). Selain itu hanya alarm (hemat baterai). */
    static boolean fast(Context c) {
        return sp(c).getLong("interval", DEFAULT_INTERVAL_MS) < FAST_BELOW_MS;
    }

    static boolean startService(Context c) {
        try {
            Context app = c.getApplicationContext();
            androidx.core.content.ContextCompat.startForegroundService(app, new Intent(app, PollService.class));
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    static void stopService(Context c) {
        try {
            Context app = c.getApplicationContext();
            app.stopService(new Intent(app, PollService.class));
        } catch (Throwable ignored) {  }
    }

    /** Terapkan mode sesuai interval tersimpan: cepat -> layanan latar + alarm penjaga; hemat -> alarm saja. */
    static void apply(Context c) {
        if (!configured(c)) return;
        if (fast(c)) {
            if (!PollService.running && !startService(c)) schedule(c, FIRST_DELAY_MS);
            else schedule(c, WATCHDOG_MS);
        } else {
            stopService(c);
            schedule(c, FIRST_DELAY_MS);
        }
    }

    static PendingIntent alarmIntent(Context c) {
        Intent i = new Intent(c.getApplicationContext(), PollReceiver.class).setAction(ACTION_POLL);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        return PendingIntent.getBroadcast(c.getApplicationContext(), 4711, i, flags);
    }

    static void schedule(Context c, long delayMs) {
        try {
            AlarmManager am = (AlarmManager) c.getApplicationContext().getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            long at = System.currentTimeMillis() + Math.max(15000L, delayMs);
            if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarmIntent(c));
            else am.set(AlarmManager.RTC_WAKEUP, at, alarmIntent(c));
        } catch (Throwable ignored) {  }
    }

    static void cancel(Context c) {
        try {
            AlarmManager am = (AlarmManager) c.getApplicationContext().getSystemService(Context.ALARM_SERVICE);
            if (am != null) am.cancel(alarmIntent(c));
        } catch (Throwable ignored) {  }
    }

    static void clear(Context c) {
        cancel(c);
        stopService(c);
        sp(c).edit().clear().apply();
        try { NotificationManagerCompat.from(c.getApplicationContext()).cancelAll(); } catch (Throwable ignored) {  }
    }

    private static String post(String base, String key, String path, String json, int timeoutMs) throws Exception {
        HttpURLConnection h = (HttpURLConnection) new URL(base + path).openConnection();
        try {
            h.setConnectTimeout(timeoutMs);
            h.setReadTimeout(timeoutMs);
            h.setRequestMethod("POST");
            h.setDoOutput(true);
            h.setRequestProperty("Content-Type", "application/json");
            h.setRequestProperty("Accept", "application/json");
            h.setRequestProperty("apikey", key);
            if (key.startsWith("eyJ")) h.setRequestProperty("Authorization", "Bearer " + key);
            byte[] body = json.getBytes(StandardCharsets.UTF_8);
            h.setFixedLengthStreamingMode(body.length);
            OutputStream os = h.getOutputStream();
            os.write(body);
            os.close();
            int code = h.getResponseCode();
            InputStream is = code >= 200 && code < 300 ? h.getInputStream() : h.getErrorStream();
            if (is == null) throw new Exception("HTTP " + code);
            BufferedReader r = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            char[] buf = new char[4096];
            int n;
            while ((n = r.read(buf)) > 0 && sb.length() < 400000) sb.append(buf, 0, n);
            r.close();
            if (code < 200 || code >= 300) throw new Exception("HTTP " + code);
            return sb.toString();
        } finally {
            h.disconnect();
        }
    }

    private static Bitmap poster(String url) {
        if (url == null || !url.startsWith("https://")) return null;
        HttpURLConnection h = null;
        try {
            h = (HttpURLConnection) new URL(url).openConnection();
            h.setConnectTimeout(4000);
            h.setReadTimeout(4000);
            InputStream is = h.getInputStream();
            BitmapFactory.Options o = new BitmapFactory.Options();
            o.inSampleSize = 2;
            Bitmap b = BitmapFactory.decodeStream(is, null, o);
            is.close();
            return b;
        } catch (Throwable t) {
            return null;
        } finally {
            if (h != null) h.disconnect();
        }
    }

    static boolean pollOnce(Context c) {
        Context app = c.getApplicationContext();
        SharedPreferences p = sp(app);
        String url = p.getString("url", ""), key = p.getString("key", "");
        String device = p.getString("device", ""), secret = p.getString("secret", "");
        String since = p.getString("since", "");
        if (url.isEmpty() || key.isEmpty() || device.isEmpty() || secret.isEmpty()) return false;
        long deadline = System.currentTimeMillis() + 22000L;
        try {
            JSONObject req = new JSONObject();
            req.put("p_device", device);
            req.put("p_secret", secret);
            req.put("p_since", since.isEmpty() ? JSONObject.NULL : since);
            JSONObject res = new JSONObject(post(url, key, "/rest/v1/rpc/notif_poll", req.toString(), 8000));
            if (!res.optBoolean("ok", false)) return false;
            JSONArray items = res.optJSONArray("items");
            if (items != null && !foreground) {
                for (int i = 0; i < items.length(); i++) {
                    JSONObject it = items.optJSONObject(i);
                    if (it != null) show(app, it, System.currentTimeMillis() < deadline - 6000L);
                }
            }
            String cur = res.optString("cursor", "");
            if (!cur.isEmpty() && !foreground) p.edit().putString("since", newer(since, cur)).apply();
            lastOk = true;
            return true;
        } catch (Throwable t) {
            lastOk = false;
            return true;
        }
    }

    static String newer(String a, String b) {
        if (a == null || a.isEmpty()) return b;
        if (b == null || b.isEmpty()) return a;
        return a.replace("Z", "+00:00").compareTo(b.replace("Z", "+00:00")) >= 0 ? a : b;
    }

    static void ensureChannel(Context c) {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null || nm.getNotificationChannel(CHANNEL) != null) return;
        NotificationChannel ch = new NotificationChannel(CHANNEL, "WakuPlay", NotificationManager.IMPORTANCE_HIGH);
        ch.setDescription("Tag, balasan, teman, clan, chat pribadi, anime dan episode baru");
        ch.enableVibration(true);
        nm.createNotificationChannel(ch);
    }

    static void show(Context c, JSONObject it, boolean withPoster) {
        try {
            if (!NotificationManagerCompat.from(c).areNotificationsEnabled()) return;
            ensureChannel(c);
            long id = it.optLong("id", 0);
            String type = it.optString("type", "");
            String title = it.optString("title", "WakuPlay");
            String body = it.optString("body", "");
            JSONObject data = it.optJSONObject("data");
            if (data == null) data = new JSONObject();

            Intent open = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
            if (open == null) return;
            open.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            open.putExtra("wp_nid", id);
            open.putExtra("wp_type", type);
            open.putExtra("wp_title", title);
            open.putExtra("wp_data", data.toString());
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
            int nid = (int) (id % 2000000000L);
            PendingIntent pi = PendingIntent.getActivity(c, nid, open, flags);

            int icon = c.getResources().getIdentifier("ic_stat_wakuplay", "drawable", c.getPackageName());
            if (icon == 0) icon = c.getApplicationInfo().icon;
            NotificationCompat.Builder b = new NotificationCompat.Builder(c, CHANNEL)
                    .setSmallIcon(icon)
                    .setColor(0xFF2F86FF)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                    .setContentIntent(pi)
                    .setAutoCancel(true)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_MESSAGE);
            if (withPoster && ("episode".equals(type) || "new_anime".equals(type))) {
                Bitmap bm = poster(data.optString("poster", ""));
                if (bm != null) b.setLargeIcon(bm);
            }
            NotificationManagerCompat.from(c).notify(nid, b.build());
        } catch (SecurityException ignored) {

        } catch (Throwable ignored) {

        }
    }
}
