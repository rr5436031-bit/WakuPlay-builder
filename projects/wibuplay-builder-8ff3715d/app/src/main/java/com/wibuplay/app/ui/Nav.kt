package com.wibuplay.app.ui

import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.wibuplay.app.AppVM

class Actions(
    val openAnime: (String) -> Unit,
    val search: () -> Unit,
    val list: (String) -> Unit,
    val genre: (String, String) -> Unit,
    val level: () -> Unit,
    val premium: () -> Unit,
    val settings: () -> Unit,
    val history: () -> Unit,
    val schedule: () -> Unit,
    val chat: () -> Unit,
)

private class Tab(val route: String, val label: String, val icon: ImageVector)

private val tabs = listOf(
    Tab("home", "Home", Icons.Filled.Home),
    Tab("schedule", "Jadwal", Icons.Filled.DateRange),
    Tab("history", "Riwayat", Icons.Filled.List),
    Tab("favorites", "Favorit", Icons.Filled.Favorite),
    Tab("profile", "Profil", Icons.Filled.Person),
)

@Composable
fun AppRoot(vm: AppVM) {
    val ready by vm.ready.collectAsState()
    val session by vm.session.collectAsState()
    val ctx = LocalContext.current
    LaunchedEffect(Unit) {
        vm.messages.collect { Toast.makeText(ctx, it, Toast.LENGTH_SHORT).show() }
    }
    when {
        !ready -> SplashScreen()
        session == null -> OnboardingScreen(vm)
        else -> MainNav(vm)
    }
}

@Composable
private fun MainNav(vm: AppVM) {
    val nav = rememberNavController()
    val entry by nav.currentBackStackEntryAsState()
    val route = entry?.destination?.route

    fun go(r: String) = nav.navigate(r)

    val a = Actions(
        openAnime = { go("detail/" + Uri.encode(it)) },
        search = { go("search") },
        list = { go("list/$it") },
        genre = { slug, name -> go("genre/" + Uri.encode(slug) + "/" + Uri.encode(name)) },
        level = { go("level") },
        premium = { go("premium") },
        settings = { go("settings") },
        history = { nav.navigate("history") { launchSingleTop = true } },
        schedule = { nav.navigate("schedule") { launchSingleTop = true } },
        chat = { go("chat") },
    )
    val back: () -> Unit = { nav.popBackStack() }
    val str = NavType.StringType

    Scaffold(
        containerColor = C.Bg,
        bottomBar = {
            if (tabs.any { it.route == route }) {
                NavigationBar(containerColor = C.Surface) {
                    tabs.forEach { t ->
                        NavigationBarItem(
                            selected = route == t.route,
                            onClick = {
                                nav.navigate(t.route) {
                                    popUpTo("home") { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(t.icon, t.label) },
                            label = { Text(t.label) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = C.TextHi, selectedTextColor = C.TextHi,
                                indicatorColor = C.SurfaceHi,
                                unselectedIconColor = C.TextLo, unselectedTextColor = C.TextLo,
                            ),
                        )
                    }
                }
            }
        },
    ) { pad ->
        NavHost(nav, startDestination = "home", modifier = Modifier.padding(pad)) {
            composable("home") { HomeScreen(vm, a) }
            composable("schedule") { ScheduleScreen(vm, a.openAnime) }
            composable("history") { HistoryScreen(vm, a.openAnime) }
            composable("favorites") { FavoritesScreen(vm, a.openAnime) }
            composable("profile") { ProfileScreen(vm, a) }

            composable("search") { SearchScreen(vm, back) { q -> go("results/" + Uri.encode(q)) } }
            composable("results/{q}", listOf(navArgument("q") { type = str })) { e ->
                ResultsScreen(vm, e.arguments?.getString("q").orEmpty(), back, a.openAnime)
            }
            composable("detail/{key}", listOf(navArgument("key") { type = str })) { e ->
                DetailScreen(vm, e.arguments?.getString("key").orEmpty(), back) { go("player") }
            }
            composable("player") { PlayerScreen(vm, back) }
            composable("genre/{slug}/{name}", listOf(navArgument("slug") { type = str }, navArgument("name") { type = str })) { e ->
                GenreScreen(vm, e.arguments?.getString("slug").orEmpty(), e.arguments?.getString("name").orEmpty(), back, a.openAnime)
            }
            composable("list/{kind}", listOf(navArgument("kind") { type = str })) { e ->
                ListScreen(vm, e.arguments?.getString("kind").orEmpty(), back, a.openAnime)
            }
            composable("level") { LevelScreen(vm, back) }
            composable("premium") { PremiumScreen(vm, back) { go("premiumweb") } }
            composable("premiumweb") { PremiumWebScreen(back) }
            composable("settings") { SettingsScreen(vm, back) { go("diag") } }
            composable("diag") { DiagScreen(back) }
            composable("chat") { ChatScreen(vm, back) }
        }
    }
}
