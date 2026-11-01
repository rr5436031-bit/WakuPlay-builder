import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _S();
}

class _S extends ConsumerState<LoginPage> {
  bool busy = false; String? err;

  Future<void> _go() async {
    setState(() { busy = true; err = null; });
    try { await ref.read(authProvider).signInWithGoogle(); }
    catch (e) { if (mounted) setState(() => err = '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 20),
              const Center(child: Text('WAKUPLAY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1))),
              const SizedBox(height: 70),
              const Text('Login', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              const Text('Aplikasi kami mewajibkan kamu untuk login menggunakan email Google',
                  style: TextStyle(fontSize: 16, color: C.textDim)),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: busy ? null : _go,
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 40, height: 40, alignment: Alignment.center,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 22))),
                    const SizedBox(width: 14),
                    busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                         : const Text('Tekan di sini untuk Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              if (err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(err!, style: const TextStyle(color: C.danger))),
            ]),
          ),
        ),
      );
}
