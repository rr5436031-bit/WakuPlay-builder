package com.wibuplay.app

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
        setContent {
            WibuTheme { AppRoot(vm) }
        }
    }
}
