package com.wibudev.studio.termux

import android.content.Context
import android.content.pm.PackageManager

/** Satu pintu untuk menjalankan perintah. Tidak menganggap berhasil sebelum hasil diterima. */
object CommandRunner {
    const val RUN_COMMAND_PERMISSION = "com.termux.permission.RUN_COMMAND"
    const val HOME = "/data/data/com.termux/files/home"

    fun hasPermission(context: Context): Boolean =
        context.checkSelfPermission(RUN_COMMAND_PERMISSION) == PackageManager.PERMISSION_GRANTED

    fun execute(context: Context, command: String, workDir: String = HOME): Int {
        val id = CommandRepository.submit(command, workDir)
        if (!TermuxBridge.isInstalled(context)) {
            CommandRepository.fail(id, "Termux belum terpasang.")
        } else if (!hasPermission(context)) {
            CommandRepository.fail(id, "Izin RUN_COMMAND belum diberikan. Buka Dashboard untuk memberikannya.")
        } else {
            try {
                TermuxBridge.send(context, id, command, workDir)
            } catch (e: Exception) {
                CommandRepository.fail(id, "Gagal mengirim ke Termux: ${e.message}")
            }
        }
        return id
    }
}
