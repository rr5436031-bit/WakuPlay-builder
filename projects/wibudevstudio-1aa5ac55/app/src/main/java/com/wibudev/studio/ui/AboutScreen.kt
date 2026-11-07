package com.wibudev.studio.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun AboutScreen(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("WibuDev Studio", style = MaterialTheme.typography.titleLarge)
        Text("Versi 0.7.0")
        Text(
            "IDE Android berbasis Termux. Termux harus dipasang dan dikonfigurasi secara terpisah. " +
                "Aplikasi ini tidak membutuhkan root."
        )
        Text("Termux, Node.js, Git, Python, dan paket lain tetap milik proyek masing-masing.")
    }
}
