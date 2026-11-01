package com.wakuplay.notify;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

import androidx.core.app.NotificationCompat;

/**
 * Layanan latar (foreground service) yang menanyakan notifikasi baru ke server setiap beberapa detik
 * walau aplikasi ditutup. Alarm biasa ditunda Android (Doze) sampai berjam-jam; layanan ini tidak.
 */
public class PollService extends Service {
    static final int NID = 7101;
    static final String SVC_CHANNEL = "wakuplay_service";
    static volatile boolean running = false;

    private volatile boolean alive = false;
    private Thread worker;
    private PowerManager.WakeLock wl;

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Context app = getApplicationContext();
        try {
            startFg(app);
        } catch (Throwable t) {
            running = false;
            NotifyCore.schedule(app, NotifyCore.FIRST_DELAY_MS);
            stopSelf();
            return START_NOT_STICKY;
        }
        if (!NotifyCore.configured(app) || !NotifyCore.fast(app)) {
            stopSelf();
            return START_NOT_STICKY;
        }
        if (!alive) {
            alive = true;
            running = true;
            try {
                PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
                if (pm != null) {
                    wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "WakuPlay:notify");
                    wl.setReferenceCounted(false);
                    wl.acquire();
                }
            } catch (Throwable ignored) {  }
            worker = new Thread(new Runnable() {
                @Override public void run() { loop(); }
            }, "wp-notify-poll");
            worker.start();
        }
        return START_STICKY;
    }

    private void startFg(Context app) {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26 && nm != null && nm.getNotificationChannel(SVC_CHANNEL) == null) {
            NotificationChannel ch = new NotificationChannel(SVC_CHANNEL, "WakuPlay aktif di latar", NotificationManager.IMPORTANCE_MIN);
            ch.setDescription("Menjaga notifikasi tetap cepat datang walau aplikasi ditutup");
            ch.setShowBadge(false);
            nm.createNotificationChannel(ch);
        }
        int icon = app.getResources().getIdentifier("ic_stat_wakuplay", "drawable", app.getPackageName());
        if (icon == 0) icon = app.getApplicationInfo().icon;
        PendingIntent pi = null;
        Intent open = app.getPackageManager().getLaunchIntentForPackage(app.getPackageName());
        if (open != null) {
            open.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            int f = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= 23) f |= PendingIntent.FLAG_IMMUTABLE;
            pi = PendingIntent.getActivity(app, 7102, open, f);
        }
        NotificationCompat.Builder b = new NotificationCompat.Builder(app, SVC_CHANNEL)
                .setSmallIcon(icon)
                .setColor(0xFF2F86FF)
                .setContentTitle("WakuPlay aktif")
                .setContentText("Menunggu notifikasi baru")
                .setOngoing(true)
                .setShowWhen(false)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setVisibility(NotificationCompat.VISIBILITY_SECRET);
        if (pi != null) b.setContentIntent(pi);
        Notification n = b.build();
        if (Build.VERSION.SDK_INT >= 34) startForeground(NID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        else startForeground(NID, n);
    }

    private void loop() {
        Context app = getApplicationContext();
        int fails = 0;
        while (alive) {
            if (!NotifyCore.configured(app) || !NotifyCore.fast(app)) break;
            long interval = Math.max(5000L, NotifyCore.sp(app).getLong("interval", 5000L));
            long wait = interval;
            if (NotifyCore.foreground) {
                wait = 3000L;
            } else {
                boolean keep = NotifyCore.pollOnce(app);
                if (!keep) { NotifyCore.clear(app); break; }
                if (NotifyCore.lastOk) fails = 0;
                else { fails = Math.min(fails + 1, 5); wait = Math.min(60000L, interval * (1L << fails)); }
            }
            try { Thread.sleep(wait); } catch (InterruptedException e) { break; }
        }
        boolean wasAlive = alive;
        alive = false;
        running = false;
        release();
        if (wasAlive) stopSelf();
    }

    private void release() {
        try { if (wl != null && wl.isHeld()) wl.release(); } catch (Throwable ignored) {  }
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        super.onTaskRemoved(rootIntent);
        NotifyCore.schedule(getApplicationContext(), 15000L);
    }

    @Override
    public void onDestroy() {
        alive = false;
        running = false;
        if (worker != null) worker.interrupt();
        release();
        super.onDestroy();
    }
}
