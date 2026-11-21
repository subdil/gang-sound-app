import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/gate.dart';
import 'services/api.dart';
import 'services/hub.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  Hub.i.checkUpdate();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GangSound',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (c, child) => UpdateGate(child: child!),
        home: const Gate(),
      );
}

/// Force update = full-screen wall nobody can pass. Simple update = dismissible banner.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});
  @override
  State<UpdateGate> createState() => _UGState();
}

class _UGState extends State<UpdateGate> {
  String? dismissed;
  void open(Map u) => launchUrl(Uri.parse(u['url']), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Hub.i,
        builder: (_, __) {
          final u = Hub.i.update;
          final force = u != null && u['mode'] == 'force';
          return Stack(children: [
            widget.child,
            if (force)
              Positioned.fill(
                child: Material(
                  color: kBg,
                  child: SprayBg(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('UPDATE\nREQUIRED', textAlign: TextAlign.center, style: graffiti(34)),
                          const SizedBox(height: 14),
                          Text('Version ${u['version']} is out. This version can no longer be used.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                          if ((u['notes'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${u['notes']}', textAlign: TextAlign.center, style: const TextStyle(color: kCyan, fontSize: 16))),
                          const SizedBox(height: 24),
                          NeonBtn('UPDATE NOW', () => open(u), icon: Icons.system_update),
                        ]),
                      ),
                    ),
                  ),
                ),
              )
            else if (u != null && dismissed != u['version'])
              Positioned(
                left: 12, right: 12, bottom: 84,
                child: Material(
                  color: Colors.transparent,
                  child: Panel(color: kAcid, child: Row(children: [
                    Expanded(child: Text('New version ${u['version']} is available${(u['notes'] ?? '').toString().isEmpty ? '' : '\n${u['notes']}'}', style: const TextStyle(fontSize: 16))),
                    TextButton(onPressed: () => setState(() => dismissed = u['version']), child: const Text('Later')),
                    FilledButton(onPressed: () => open(u), child: const Text('Update')),
                  ])),
                ),
              ),
          ]);
        },
      );
}
