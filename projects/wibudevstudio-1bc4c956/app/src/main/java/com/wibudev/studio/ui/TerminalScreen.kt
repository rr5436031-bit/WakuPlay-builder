package com.wibudev.studio.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.wibudev.studio.termux.CommandRecord
import com.wibudev.studio.termux.CommandRepository
import com.wibudev.studio.termux.CommandRunner
import com.wibudev.studio.termux.CommandStatus

private const val PROMPT_TOP = "┌──(wibudev㉿termux)-[~]"
private const val PROMPT_BOTTOM = "└─$ "

@Composable
fun TerminalScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val records by CommandRepository.records.collectAsState()
    var input by remember { mutableStateOf("") }

    val send: () -> Unit = {
        val cmd = input.trim()
        if (cmd.isNotEmpty()) {
            CommandRunner.execute(context, cmd)
            input = ""
        }
    }

    Column(modifier = modifier.fillMaxSize().padding(12.dp)) {
        LazyColumn(
            modifier = Modifier.fillMaxWidth().weight(1f),
            reverseLayout = true,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(records, key = { it.id }) { record ->
                RecordItem(record, onRecall = { input = record.command })
            }
        }

        OutlinedTextField(
            value = input,
            onValueChange = { input = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            placeholder = { Text("ketik perintah, mis. node -v") },
            textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
            keyboardActions = KeyboardActions(onSend = { send() })
        )

        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            TextButton(onClick = { CommandRepository.clear() }) { Text("Clear") }
            Button(onClick = send) { Text("Kirim") }
        }
    }
}

@Composable
private fun RecordItem(record: CommandRecord, onRecall: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().clickable(onClick = onRecall)) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(PROMPT_TOP, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
            Text(
                PROMPT_BOTTOM + record.command,
                fontFamily = FontFamily.Monospace,
                style = MaterialTheme.typography.bodyMedium
            )

            when (record.status) {
                CommandStatus.WAITING -> Text(
                    "Menunggu hasil dari Termux...",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                CommandStatus.SUCCESS -> Text("Selesai (exit 0)")
                CommandStatus.FAILED -> Text(
                    "Gagal" + (record.exitCode?.let { " (exit $it)" } ?: ""),
                    color = MaterialTheme.colorScheme.error
                )
            }

            record.message?.let {
                Text(it, color = MaterialTheme.colorScheme.error)
            }
            if (record.stdout.isNotBlank()) {
                SelectionContainer {
                    Text(record.stdout, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
                }
            }
            if (record.stderr.isNotBlank()) {
                SelectionContainer {
                    Text(
                        record.stderr,
                        fontFamily = FontFamily.Monospace,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        }
    }
}
