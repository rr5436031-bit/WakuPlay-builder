package com.wibudev.studio.termux

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/** Jembatan resmi ke Termux melalui RUN_COMMAND. Verifikasi nama extra jika versi Termux berubah. */
object TermuxBridge {
    const val PACKAGE = "com.termux"
    const val EXTRA_EXEC_ID = "com.wibudev.studio.EXEC_ID"
    private const val ACTION = "com.termux.RUN_COMMAND"
    private const val BASH = "/data/data/com.termux/files/usr/bin/bash"

    fun isInstalled(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(PACKAGE, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    fun openTermux(context: Context): Boolean {
        val launch = context.packageManager.getLaunchIntentForPackage(PACKAGE) ?: return false
        context.startActivity(launch)
        return true
    }

    /** execId null berarti tanpa hasil (fire-and-forget, misalnya untuk perintah stop). */
    fun send(context: Context, command: String, workDir: String, execId: Int?) {
        val pending = execId?.let {
            val result = Intent(context, TermuxResultReceiver::class.java).putExtra(EXTRA_EXEC_ID, it)
            PendingIntent.getBroadcast(
                context, it, result,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        }
        val intent = Intent(ACTION).apply {
            setClassName(PACKAGE, "$PACKAGE.app.RunCommandService")
            putExtra("com.termux.RUN_COMMAND_PATH", BASH)
            putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-lc", command))
            putExtra("com.termux.RUN_COMMAND_WORKDIR", workDir)
            putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
            putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
            if (pending != null) putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", pending)
        }
        context.startService(intent)
    }
}
