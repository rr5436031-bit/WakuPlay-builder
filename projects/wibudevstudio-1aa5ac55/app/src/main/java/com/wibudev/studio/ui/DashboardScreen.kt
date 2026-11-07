package com.wibudev.studio.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.wibudev.studio.termux.CommandRepository
import com.wibudev.studio.termux.CommandRunner
import com.wibudev.studio.termux.TermuxBridge

@Composable
fun DashboardScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val records by CommandRepository.records.collectAsState()
    var granted by remember { mutableStateOf(CommandRunner.hasPermission(context)) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted = it }

    val installed = TermuxBridge.isInstalled(context)
    val latest = records.firstOrNull()

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            if (installed) "Termux: terpasang" else "Termux: belum terpasang",
            style = MaterialTheme.typography.titleMedium
        )
        Text(if (granted) "Izin RUN_COMMAND: aktif" else "Izin RUN_COMMAND: belum diberikan")

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { TermuxBridge.openTermux(context) }) { Text("Buka Termux") }
            if (!granted) {
                Button(onClick = { permissionLauncher.launch(CommandRunner.RUN_COMMAND_PERMISSION) }) {
                    Text("Beri Izin")
                }
            }
        }

        Button(
            onClick = { CommandRunner.execute(context, "node -v; npm -v; python3 --version") },
            enabled = installed && granted
        ) { Text("Cek versi Node / npm / Python") }

        latest?.let {
            Text("Perintah terakhir: ${it.command}")
            Text("Status: ${it.status}")
        }
    }
}
