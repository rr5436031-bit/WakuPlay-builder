package com.wibuplay.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import com.wibuplay.app.ui.AppRoot
import com.wibuplay.app.ui.WibuTheme

class MainActivity : ComponentActivity() {
    private val vm: AppVM by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        setContent {
            WibuTheme { AppRoot(vm) }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(i: Intent?) {
        if (i == null) return
        val d = i.data ?: return
        if (d.scheme == "wibuplay" && d.host == "auth-callback") {
            i.data = null // agar kode OAuth tidak diproses dua kali
            vm.handleAuthUri(d)
        }
    }
}
