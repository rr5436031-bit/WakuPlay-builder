package com.wibudev.studio.ui

/** Helper shell. Semua path proyek dibatasi di bawah ~/projects. */
object Shell {
    const val ROOT = "\$HOME/projects"

    fun quote(s: String): String = "'" + s.replace("'", "'\\''") + "'"

    fun pathOf(segments: List<String>): String =
        ROOT + segments.joinToString("") { "/" + quote(it) }

    /** Null jika ada ".." atau "." sehingga path bisa keluar dari ~/projects. */
    fun validSegments(input: String): List<String>? {
        val parts = input.trim().trim('/').split('/').filter { it.isNotEmpty() }
        return if (parts.any { it == ".." || it == "." }) null else parts
    }

    fun validName(n: String): Boolean =
        n.isNotBlank() && !n.contains('/') && n != "." && n != ".."
}
