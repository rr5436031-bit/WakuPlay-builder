package com.wibudev.studio.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.item
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wibudev.studio.termux.CommandRecord
import com.wibudev.studio.termux.CommandRepository
import com.wibudev.studio.termux.CommandRunner
import com.wibudev.studio.termux.CommandStatus

private val TermBg = Color(0xFF101214)
private val TermText = Color(0xFFE6E6E6)
private val TermDim = Color(0xFF8A9199)
private val TermErr = Color(0xFFFF6B6B)
private val TermPrompt = Color(0xFF5FD7FF)
private val monoStyle = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 13.sp, lineHeight = 18.sp, color = TermText)

/**
 * Tampilan ala Termux. Output muncul di bawah setiap perintah, prompt dua baris
 * diketik langsung di bawah, dan baris tombol khusus ada di paling bawah.
 * Eksekusi tetap lewat RUN_COMMAND, jadi ini bukan TTY interaktif.
 */
@Composable
fun TerminalScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val records by CommandRepository.records.collectAsState()
    var input by remember { mutableStateOf("") }
    var histIdx by remember { mutableStateOf(-1) }

    val promptLines = PromptStore.format(
        PromptStore.preset, PromptStore.username, PromptStore.hostname, PromptStore.customTemplate
    ).split("\n")

    fun submit() {
        val cmd = input.trim()
        input = ""
        histIdx = -1
        if (cmd.isEmpty()) return
        if (cmd == "clear") {
            CommandRepository.clear()
            return
        }
        CommandRunner.execute(context, cmd)
    }

    fun onKey(k: String) {
        when (k) {
            "ESC" -> { input = ""; histIdx = -1 }
            "CTRL-C" -> records.firstOrNull { it.status == CommandStatus.WAITING }
                ?.let { CommandRunner.stop(context, it.id) }
            "↑" -> {
                val cmds = records.map { it.command }
                if (cmds.isNotEmpty()) {
                    histIdx = (histIdx + 1).coerceAtMost(cmds.lastIndex)
                    input = cmds[histIdx]
                }
            }
            "↓" -> {
                val cmds = records.map { it.command }
                if (histIdx > 0) {
                    histIdx--
                    input = cmds[histIdx]
                } else if (histIdx == 0) {
                    histIdx = -1
                    input = ""
                }
            }
            else -> input += k
        }
    }

    Column(modifier = modifier.fillMaxSize().background(TermBg).padding(horizontal = 8.dp)) {
        LazyColumn(modifier = Modifier.fillMaxWidth().weight(1f), reverseLayout = true) {
            items(records, key = { it.id }) { r -> RecordBlock(r, promptLines) }
            item {
                Text(
                    "WibuDev Studio. Ketik 'clear' untuk membersihkan layar.",
                    style = monoStyle.copy(color = TermDim)
                )
            }
        }

        promptLines.dropLast(1).forEach { Text(it, style = monoStyle.copy(color = TermPrompt)) }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(promptLines.last(), style = monoStyle.copy(color = TermPrompt))
            BasicTextField(
                value = input,
                onValueChange = { input = it },
                modifier = Modifier.weight(1f),
                textStyle = monoStyle,
                singleLine = true,
                cursorBrush = SolidColor(TermText),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { submit() })
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            listOf("ESC", "CTRL-C", "↑", "↓", "-", "/", "~", "|").forEach { k ->
                Text(
                    k,
                    style = monoStyle.copy(fontSize = 12.sp, color = TermDim),
                    modifier = Modifier.clickable { onKey(k) }.padding(horizontal = 6.dp, vertical = 6.dp)
                )
            }
        }
    }
}

@Composable
private fun RecordBlock(r: CommandRecord, promptLines: List<String>) {
    val context = LocalContext.current
    SelectionContainer {
        Column(modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp)) {
            promptLines.dropLast(1).forEach { Text(it, style = monoStyle.copy(color = TermPrompt)) }
            Text(promptLines.last() + r.command, style = monoStyle)
            if (r.stdout.isNotBlank()) Text(r.stdout.trimEnd(), style = monoStyle)
            if (r.stderr.isNotBlank()) Text(r.stderr.trimEnd(), style = monoStyle.copy(color = TermErr))
            when (r.status) {
                CommandStatus.WAITING -> Text(
                    "berjalan... ketuk untuk hentikan",
                    style = monoStyle.copy(color = TermDim),
                    modifier = Modifier.clickable { CommandRunner.stop(context, r.id) }
                )
                CommandStatus.SUCCESS -> Unit
                CommandStatus.FAILED -> {
                    val code = r.exitCode?.takeIf { it != 0 }?.let { "[exit $it] " }.orEmpty()
                    val msg = r.message.orEmpty()
                    if (code.isNotEmpty() || msg.isNotEmpty()) {
                        Text(code + msg, style = monoStyle.copy(color = TermErr))
                    }
                }
            }
        }
    }
}
