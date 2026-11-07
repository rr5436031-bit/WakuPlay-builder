package com.wibudev.studio.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.wibudev.studio.termux.CommandRunner

private val packages = listOf(
    "nodejs", "git", "python", "openjdk-17", "gradle", "cmake",
    "clang", "php", "ruby", "ffmpeg", "zip", "unzip"
)

/** Setiap perintah pkg harus disetujui dulu. Hasilnya muncul di Terminal. */
@Composable
fun PackageManagerScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var pendingCmd by remember { mutableStateOf<String?>(null) }
    var pendingLabel by remember { mutableStateOf("") }
    var notice by remember { mutableStateOf("") }

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("Pemeliharaan", style = MaterialTheme.typography.titleMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = {
                pendingCmd = "pkg update -y"
                pendingLabel = "Perbarui daftar paket"
            }) { Text("Update") }
            Button(onClick = {
                pendingCmd = "pkg upgrade -y"
                pendingLabel = "Upgrade semua paket"
            }) { Text("Upgrade") }
        }

        Text("Paket", style = MaterialTheme.typography.titleMedium)
        packages.forEach { name ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(name, fontFamily = FontFamily.Monospace)
                OutlinedButton(onClick = {
                    pendingCmd = "pkg install -y $name"
                    pendingLabel = "Pasang paket $name"
                }) { Text("Pasang") }
            }
        }

        if (notice.isNotEmpty()) {
            Text(notice, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }

    pendingCmd?.let { cmd ->
        AlertDialog(
            onDismissRequest = { pendingCmd = null },
            title = { Text("Konfirmasi") },
            text = { Text("$pendingLabel?\n\nPerintah: $cmd") },
            confirmButton = {
                Button(onClick = {
                    CommandRunner.execute(context, cmd)
                    notice = "Dikirim: $cmd. Cek hasilnya di Terminal."
                    pendingCmd = null
                }) { Text("Jalankan") }
            },
            dismissButton = { TextButton(onClick = { pendingCmd = null }) { Text("Batal") } }
        )
    }
}
