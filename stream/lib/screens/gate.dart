import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api.dart';
import '../theme.dart';
import 'admin.dart';
import 'auth.dart';
import 'home.dart';

/// Decides which screen to show: login -> admin panel | permissions (first run) -> home
class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) {
    if (Api.token == null) return const AuthScreen();
    if (Api.role == 'admin') return const AdminScreen();
    return Api.prefs.getBool('perms') == true ? const Home() : const PermScreen();
  }
}

class PermScreen extends StatelessWidget {
  const PermScreen({super.key});

  Future<void> grant(BuildContext c) async {
    final mobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (mobile) {
      try { await [Permission.microphone, Permission.notification, Permission.storage].request(); } catch (_) {}
    }
    await Api.prefs.setBool('perms', true);
    if (c.mounted) Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const Home()));
  }

  Widget row(IconData i, String t, String s) => Panel(child: Row(children: [
        Icon(i, color: kCyan, size: 30), const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: graffiti(14)), Text(s, style: const TextStyle(fontSize: 16))])),
      ]));

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SprayBg(
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('BEFORE WE ROLL', style: graffiti(26)),
              const SizedBox(height: 6),
              const Text('GangSound needs a few permissions to work:', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 14),
              row(Icons.wifi, 'Network', 'Internet access to stream audio between your devices. Granted automatically.'),
              row(Icons.mic, 'Microphone', 'Needed to capture sound when you broadcast from the mic.'),
              row(Icons.notifications_active, 'Notifications', 'Keeps a broadcast alive while the app is in the background.'),
              row(Icons.folder, 'Files', 'Lets the app save downloaded updates. Optional.'),
              const SizedBox(height: 10),
              NeonBtn('ALLOW AND CONTINUE', () => grant(c), icon: Icons.check),
            ]),
          ),
        ),
      );
}
