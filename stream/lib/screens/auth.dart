import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'gate.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  bool reg = false, busy = false;
  String? err;
  final u = TextEditingController(), p = TextEditingController(), dn = TextEditingController(), em = TextEditingController(), ph = TextEditingController();

  void next() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Gate()));

  Future<void> go() async {
    setState(() { busy = true; err = null; });
    try {
      if (reg) { await Api.register(u.text.trim(), p.text, dn.text.trim(), em.text.trim(), ph.text.trim()); }
      else { await Api.login(u.text.trim(), p.text); }
      if (mounted) next();
    } catch (e) { if (mounted) setState(() => err = '$e'); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> adminDialog() async {
    final au = TextEditingController(), ap = TextEditingController();
    String? e;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: kPanel,
          title: Text('ADMIN ACCESS', style: graffiti(18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: au, decoration: const InputDecoration(labelText: 'Admin username')),
            const SizedBox(height: 10),
            TextField(controller: ap, obscureText: true, decoration: const InputDecoration(labelText: 'Admin password')),
            if (e != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(e!, style: const TextStyle(color: Colors.redAccent))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try { await Api.adminLogin(au.text.trim(), ap.text); if (ctx.mounted) Navigator.pop(ctx); if (mounted) next(); }
                catch (x) { set(() => e = '$x'); }
              },
              child: const Text('Enter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SprayBg(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(children: [
                    Text('GANG\nSOUND', textAlign: TextAlign.center, style: graffiti(48)),
                    const SizedBox(height: 4),
                    const Text('Throw your sound to any screen.', style: TextStyle(color: kCyan, fontSize: 18)),
                    const SizedBox(height: 22),
                    Panel(child: Column(children: [
                      TextField(controller: u, decoration: const InputDecoration(labelText: 'Username')),
                      const SizedBox(height: 10),
                      TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                      if (reg) ...[
                        const SizedBox(height: 10),
                        TextField(controller: dn, decoration: const InputDecoration(labelText: 'Display name')),
                        const SizedBox(height: 10),
                        TextField(controller: em, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)')),
                        const SizedBox(height: 10),
                        TextField(controller: ph, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
                      ],
                      if (err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 16))),
                      const SizedBox(height: 16),
                      NeonBtn(reg ? 'CREATE ACCOUNT' : 'LOG IN', busy ? null : go),
                    ])),
                    TextButton(onPressed: () => setState(() { reg = !reg; err = null; }), child: Text(reg ? 'Have an account? Log in' : 'New here? Create an account')),
                    TextButton(onPressed: adminDialog, child: const Text('Admin panel', style: TextStyle(color: Colors.white54))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
