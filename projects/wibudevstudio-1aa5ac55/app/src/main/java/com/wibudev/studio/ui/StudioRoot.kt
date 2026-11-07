package com.wibudev.studio.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationDrawerItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

private val menuItems = listOf(
    "Dashboard", "Terminal", "File Manager", "Code Editor", "Project Manager",
    "Localhost Manager", "Package Manager", "APK Builder", "Build History",
    "Terminal Appearance", "Settings", "About"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StudioRoot() {
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf("Dashboard") }

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            ModalDrawerSheet {
                menuItems.forEach { item ->
                    NavigationDrawerItem(
                        label = { Text(item) },
                        selected = item == selected,
                        onClick = {
                            selected = item
                            scope.launch { drawerState.close() }
                        },
                        modifier = Modifier.padding(horizontal = 12.dp)
                    )
                }
            }
        }
    ) {
        Scaffold(
            topBar = {
                CenterAlignedTopAppBar(
                    title = { Text(selected) },
                    navigationIcon = {
                        IconButton(onClick = { scope.launch { drawerState.open() } }) {
                            Icon(Icons.Filled.Menu, contentDescription = "Menu")
                        }
                    }
                )
            }
        ) { padding ->
            when (selected) {
                "Dashboard" -> DashboardScreen(Modifier.padding(padding))
                "Terminal" -> TerminalScreen(Modifier.padding(padding))
                "Terminal Appearance" -> AppearanceScreen(Modifier.padding(padding))
                "APK Builder" -> BuildScreen(Modifier.padding(padding))
                "Build History" -> BuildScreen(Modifier.padding(padding), historyOnly = true)
                "File Manager" -> FileManagerScreen(Modifier.padding(padding))
                "Localhost Manager" -> LocalhostScreen(Modifier.padding(padding))
                "Package Manager" -> PackageManagerScreen(Modifier.padding(padding))
                "Settings" -> SettingsScreen(Modifier.padding(padding))
                "About" -> AboutScreen(Modifier.padding(padding))
                else -> Text(
                    "Belum diimplementasikan. Akan dikerjakan pada tahap berikutnya.",
                    modifier = Modifier.padding(padding).padding(16.dp)
                )
            }
        }
    }
}
