package com.wakuplay.notify;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class PollReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(final Context context, Intent intent) {
        if (!NotifyCore.configured(context)) return;
        final Context app = context.getApplicationContext();

        // Mode cepat: alarm ini hanya penjaga. Pastikan layanan latar hidup; kalau Android menolak memulainya
        // dari latar, jatuh ke satu kali pengecekan biasa di bawah.
        if (NotifyCore.fast(app)) {
            if (PollService.running || NotifyCore.startService(app)) {
                NotifyCore.schedule(app, NotifyCore.WATCHDOG_MS);
                return;
            }
        }

        final PendingResult pr = goAsync();
        new Thread(new Runnable() {
            @Override
            public void run() {
                boolean keep = true;
                try {
                    if (!NotifyCore.foreground) keep = NotifyCore.pollOnce(app);
                } catch (Throwable ignored) {
                    keep = true;
                } finally {
                    if (keep) {
                        long next = NotifyCore.fast(app) ? 30000L : NotifyCore.sp(app).getLong("interval", NotifyCore.DEFAULT_INTERVAL_MS);
                        NotifyCore.schedule(app, next);
                    } else NotifyCore.clear(app);
                    pr.finish();
                }
            }
        }).start();
    }
}
