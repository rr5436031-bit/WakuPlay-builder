import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/providers.dart';
import 'core/theme/theme.dart';
import 'features/login/login_page.dart';
import 'features/shell/shell_page.dart';
import 'services/notify/notif_router.dart';

class WakuPlayApp extends ConsumerWidget {
  const WakuPlayApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'WakuPlay',
        navigatorKey: navKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: StreamBuilder<AuthState>(
          stream: ref.read(authProvider).changes,
          builder: (_, __) => ref.read(authProvider).user == null ? const LoginPage() : const ShellPage(),
        ),
      );
}
