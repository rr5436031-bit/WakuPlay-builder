package com.wibudev.studio.termux

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

/**
 * Jembatan resmi ke Termux melalui RUN_COMMAND.
 * Nama extra mengikuti dokumentasi RUN_COMMAND Termux; verifikasi ulang jika versi Termux berubah.
 */
object TermuxBridge {
    const val PACKAGE = "com.termux"
    private const val ACTION_RUN_COMMAND = "com.termux.RUN_COMMAND"
    private const val BASH = "/data/data/com.termux/files/usr/bin/bash"

    private const val EXTRA_PATH = "com.termux.RUN_COMMAND_PATH"
    private const val EXTRA_ARGS = "com.termux.RUN_COMMAND_ARGUMENTS"
    private const val EXTRA_WORKDIR = "com.termux.RUN_COMMAND_WORKDIR"
    private const val EXTRA_BACKGROUND = "com.termux.RUN_COMMAND_BACKGROUND"
    private const val EXTRA_SESSION_ACTION = "com.termux.RUN_COMMAND_SESSION_ACTION"
    private const val EXTRA_PENDING_INTENT = "com.termux.RUN_COMMAND_PENDING_INTENT"

    /** Extra milik aplikasi ini untuk mencocokkan hasil dengan perintah. */
    const val EXTRA_EXEC_ID = "com.wibudev.studio.EXEC_ID"

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

    /** Mengirim perintah ke Termux. Hasil akan dikirim balik ke TermuxResultReceiver. */
    fun send(context: Context, execId: Int, command: String, workDir: String) {
        val resultIntent = Intent(context, TermuxResultReceiver::class.java)
            .putExtra(EXTRA_EXEC_ID, execId)
        val pending = PendingIntent.getBroadcast(
            context,
            execId,
            resultIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        val intent = Intent(ACTION_RUN_COMMAND).apply {
            setClassName(PACKAGE, "$PACKAGE.app.RunCommandService")
            putExtra(EXTRA_PATH, BASH)
            putExtra(EXTRA_ARGS, arrayOf("-lc", command))
            putExtra(EXTRA_WORKDIR, workDir)
            putExtra(EXTRA_BACKGROUND, true)
            putExtra(EXTRA_SESSION_ACTION, "0")
            putExtra(EXTRA_PENDING_INTENT, pending)
        }
        context.startService(intent)
    }
}
