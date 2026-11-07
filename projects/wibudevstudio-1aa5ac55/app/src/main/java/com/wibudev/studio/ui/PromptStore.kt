package com.wibudev.studio.ui

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** Hanya tampilan prompt. Tidak mengubah akun Linux di Termux. */
enum class PromptPreset(val label: String, val template: String) {
    LINUX_CLASSIC("Linux Classic", "┌──(%u@%h)-[%d]\n└─\$ "),
    KALI("Kali Style", "┌──(%u㉿%h)-[%d]\n└─\$ "),
    UBUNTU("Ubuntu Style", "%u@%h:%d\$ "),
    MINIMAL("Minimal", "\$ "),
    CUSTOM("Custom", "")
}

object PromptStore {
    private const val PREFS = "wibudev_prompt"

    var preset by mutableStateOf(PromptPreset.LINUX_CLASSIC)
        private set
    var username by mutableStateOf("wibudev")
        private set
    var hostname by mutableStateOf("termux")
        private set
    var customTemplate by mutableStateOf("%u@%h:%d\$ ")
        private set

    fun load(context: Context) {
        val p = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        preset = PromptPreset.entries.firstOrNull { it.name == p.getString("preset", null) } ?: preset
        username = p.getString("user", username) ?: username
        hostname = p.getString("host", hostname) ?: hostname
        customTemplate = p.getString("custom", customTemplate) ?: customTemplate
    }

    fun save(context: Context, newPreset: PromptPreset, newUser: String, newHost: String, newCustom: String) {
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("preset", newPreset.name)
            .putString("user", newUser)
            .putString("host", newHost)
            .putString("custom", newCustom)
            .apply()
        preset = newPreset
        username = newUser
        hostname = newHost
        customTemplate = newCustom
    }

    fun format(
        preset: PromptPreset,
        user: String,
        host: String,
        custom: String,
        cwd: String = "~"
    ): String {
        val template = if (preset == PromptPreset.CUSTOM) custom else preset.template
        return template.replace("\\n", "\n").replace("%u", user).replace("%h", host).replace("%d", cwd)
    }
}
