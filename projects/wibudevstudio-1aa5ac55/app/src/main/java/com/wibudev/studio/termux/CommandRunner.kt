package com.wibudev.studio.termux

import android.content.Context
import android.content.pm.PackageManager

/** Satu pintu eksekusi. Status tidak dianggap berhasil sebelum hasil dari Termux diterima. */
object CommandRunner {
    const val RUN_COMMAND_PERMISSION = "com.termux.permission.RUN_COMMAND"
    const val HOME = "/data/data/com.termux/files/home"
    private const val RUN_DIR = "\$HOME/.wibudev/run"

    fun hasPermission(context: Context): Boolean =
        context.checkSelfPermission(RUN_COMMAND_PERMISSION) == PackageManager.PERMISSION_GRANTED

    fun execute(context: Context, command: String, workDir: String = HOME): Int {
        CommandRepository.ensureLoaded(context)
        val id = CommandRepository.submit(command, workDir)
        when {
            !TermuxBridge.isInstalled(context) -> CommandRepository.fail(id, "Termux belum terpasang.")
            !hasPermission(context) -> CommandRepository.fail(
                id, "Izin RUN_COMMAND belum diberikan. Buka Dashboard untuk memberikannya."
            )
            else -> try {
                // Simpan PID shell agar perintah bisa dihentikan dari aplikasi.
                val wrapped = "mkdir -p $RUN_DIR; echo \$\$ > $RUN_DIR/$id.pid; " +
                    "$command; s=\$?; rm -f $RUN_DIR/$id.pid; exit \$s"
                TermuxBridge.send(context, wrapped, workDir, id)
            } catch (e: Exception) {
                CommandRepository.fail(id, "Gagal mengirim ke Termux: ${e.message}")
            }
        }
        return id
    }

    /**
     * Menghentikan shell perintah dengan SIGTERM memakai PID yang disimpan.
     * Batasan: proses anak yang sudah berjalan bisa tetap hidup.
     */
    fun stop(context: Context, id: Int) {
        CommandRepository.ensureLoaded(context)
        CommandRepository.requestStop(id)
        if (!TermuxBridge.isInstalled(context) || !hasPermission(context)) return
        val script = "P=$RUN_DIR/$id.pid; if [ -f \"\$P\" ]; then " +
            "kill -TERM \$(cat \"\$P\") 2>/dev/null && echo stopped || echo gagal; " +
            "else echo tidak_berjalan; fi"
        TermuxBridge.send(context, script, HOME, null)
    }
}
