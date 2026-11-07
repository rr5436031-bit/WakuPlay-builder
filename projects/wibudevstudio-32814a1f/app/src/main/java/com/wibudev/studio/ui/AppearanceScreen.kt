package com.wibudev.studio.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp

@Composable
fun AppearanceScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var preset by remember { mutableStateOf(PromptStore.preset) }
    var user by remember { mutableStateOf(PromptStore.username) }
    var host by remember { mutableStateOf(PromptStore.hostname) }
    var custom by remember { mutableStateOf(PromptStore.customTemplate) }

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("Preset prompt", style = MaterialTheme.typography.titleMedium)
        PromptPreset.entries.forEach { p ->
            FilterChip(selected = preset == p, onClick = { preset = p }, label = { Text(p.label) })
        }

        OutlinedTextField(
            value = user, onValueChange = { user = it.take(32) },
            label = { Text("Username (tampilan)") }, singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = host, onValueChange = { host = it.take(32) },
            label = { Text("Hostname (tampilan)") }, singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = custom, onValueChange = { custom = it.take(120) },
            label = { Text("Template Custom (%u %h %d, \\n untuk baris baru)") },
            singleLine = true, enabled = preset == PromptPreset.CUSTOM,
            modifier = Modifier.fillMaxWidth()
        )

        Text("Pratinjau", style = MaterialTheme.typography.titleSmall)
        Text(
            PromptStore.format(preset, user, host, custom) + "ls",
            fontFamily = FontFamily.Monospace
        )

        Button(onClick = {
            PromptStore.save(context, preset, user.trim(), host.trim(), custom)
        }) { Text("Simpan") }

        Text(
            "Perubahan ini hanya memengaruhi tampilan prompt. Username dan hostname di Termux tidak berubah.",
            style = MaterialTheme.typography.bodySmall
        )
    }
}
