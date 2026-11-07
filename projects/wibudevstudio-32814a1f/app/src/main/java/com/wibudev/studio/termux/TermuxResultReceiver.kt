package com.wibudev.studio.termux

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Menerima bundle "result" dari Termux berisi stdout, stderr, exitCode, dan errmsg. */
class TermuxResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        CommandRepository.ensureLoaded(context)
        val id = intent.getIntExtra(TermuxBridge.EXTRA_EXEC_ID, -1)
        if (id < 0) return

        val result = intent.getBundleExtra("result")
        if (result == null) {
            CommandRepository.fail(id, "Termux tidak mengembalikan hasil. Pastikan allow-external-apps aktif.")
            return
        }
        val errmsg = result.getString("errmsg")
        if (!errmsg.isNullOrBlank()) {
            CommandRepository.fail(id, errmsg)
            return
        }
        CommandRepository.complete(
            id = id,
            stdout = result.getString("stdout").orEmpty(),
            stderr = result.getString("stderr").orEmpty(),
            exitCode = result.getInt("exitCode", -1)
        )
    }
}
