package com.wibuplay.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wibuplay.app.AppVM

@Composable
fun SplashScreen() {
    Box(Modifier.fillMaxSize().background(C.Bg), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            LogoMark(72.dp)
            Spacer(Modifier.height(14.dp))
            Text("WibuPlay", color = C.TextHi, fontSize = 30.sp, fontWeight = FontWeight.ExtraBold)
        }
    }
}

/** Tiga halaman vertikal: sambutan → informasi → login Google. Geser ke atas untuk lanjut. */
@Composable
fun OnboardingScreen(vm: AppVM) {
    val pager = rememberPagerState(pageCount = { 3 })
    val busy by vm.loginBusy.collectAsState()
    val ctx = LocalContext.current

    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        Box(Modifier.fillMaxWidth().padding(top = 18.dp), contentAlignment = Alignment.Center) { LogoRow() }
        VerticalPager(state = pager, modifier = Modifier.weight(1f)) { page ->
            when (page) {
                0 -> Page(
                    title = "Selamat datang",
                    body = "Nonton anime favoritmu, simpan riwayat dan favorit di akunmu, dan naik level dari setiap episode yang kamu tonton.",
                    hint = true,
                )
                1 -> Page(
                    title = "Sebelum mulai",
                    body = "WibuPlay adalah aplikasi tidak resmi. Video berasal dari situs pihak ketiga dan hak cipta tetap milik pemiliknya. " +
                        "Kami tidak menyimpan atau mengunggah file video apa pun.",
                    hint = true,
                )
                else -> LoginPage(busy) { vm.startGoogleLogin(ctx) }
            }
        }
    }
}

@Composable
private fun Page(title: String, body: String, hint: Boolean) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 28.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(title, color = C.TextHi, fontSize = 36.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(16.dp))
        Text(body, color = C.TextLo, fontSize = 17.sp, lineHeight = 26.sp)
        if (hint) {
            Spacer(Modifier.height(60.dp))
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Filled.KeyboardArrowUp, null, tint = C.Accent, modifier = Modifier.size(36.dp))
                Text("Geser ke atas untuk lanjut", color = C.TextLo, fontSize = 14.sp)
            }
        }
    }
}

@Composable
private fun LoginPage(busy: Boolean, onLogin: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text("Masuk", color = C.TextHi, fontSize = 36.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(10.dp))
        Text("Akun Google diperlukan agar riwayat, favorit, level, dan XP-mu tersimpan dan tersinkron di semua perangkat.", color = C.TextLo, fontSize = 16.sp, lineHeight = 24.sp)
        Spacer(Modifier.height(28.dp))
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(C.SurfaceHi)
                .clickable(enabled = !busy, onClick = onLogin).padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.size(44.dp).clip(CircleShape).background(Color.White), contentAlignment = Alignment.Center) {
                if (busy) CircularProgressIndicator(Modifier.size(22.dp), color = C.Accent, strokeWidth = 2.dp)
                else Text("G", color = Color(0xFF4285F4), fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
            }
            Spacer(Modifier.size(16.dp))
            Text(if (busy) "Menunggu login…" else "Masuk dengan Google", color = C.TextHi, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        }
        Spacer(Modifier.height(24.dp))
        Text(
            "Login memakai Supabase Auth. Tidak ada login uji/dummy: jika autentikasi gagal, kamu tidak akan masuk.",
            color = C.TextLo, fontSize = 12.sp, textAlign = TextAlign.Start,
        )
    }
}
