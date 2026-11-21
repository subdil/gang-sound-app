import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/api.dart';
import '../services/hub.dart';
import '../theme.dart';
import 'gate.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  @override
  void initState() { super.initState(); Hub.i.connect(); }

  Future<void> logout() async {
    await Hub.i.disconnect(); await Api.logout();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Gate()));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        bottomNavigationBar: NavigationBar(
          backgroundColor: kPanel, indicatorColor: kPink.withOpacity(.3), selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [NavigationDestination(icon: Icon(Icons.podcasts), label: 'Send'), NavigationDestination(icon: Icon(Icons.headphones), label: 'Listen')],
        ),
        body: SprayBg(
          child: SafeArea(
            child: Stack(children: [
              Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                  child: Row(children: [
                    Expanded(child: Text('GANGSOUND', style: graffiti(24))),
                    ListenableBuilder(listenable: Hub.i, builder: (_, __) => Icon(Icons.circle, size: 12, color: Hub.i.connected ? kAcid : Colors.redAccent)),
                    const SizedBox(width: 8),
                    Text('@${Api.username}', style: const TextStyle(fontSize: 16)),
                    IconButton(icon: const Icon(Icons.logout), onPressed: logout),
                  ]),
                ),
                Expanded(child: tab == 0 ? const SendTab() : const ListenTab()),
              ]),
              // hidden player: keeps remote audio alive on every platform (needed on web)
              ListenableBuilder(
                listenable: Hub.i,
                builder: (_, __) => Hub.i.rReady ? Opacity(opacity: .01, child: SizedBox(width: 2, height: 2, child: RTCVideoView(Hub.i.renderer))) : const SizedBox(),
              ),
            ]),
          ),
        ),
      );
}

const _modes = [
  ['others', 'Other devices only', 'Only devices that enter your token hear it'],
  ['all', 'All devices', 'Other devices, and this one keeps playing too'],
  ['select', 'Pick devices', 'Newcomers wait until you let them in'],
];

class SendTab extends StatefulWidget {
  const SendTab({super.key});
  @override
  State<SendTab> createState() => _SendState();
}

class _SendState extends State<SendTab> {
  String mode = 'others', src = 'system';
  bool busy = false;

  Widget opt(bool sel, String t, String s, VoidCallback f) => InkWell(
        onTap: f,
        child: Panel(color: sel ? kPink : Colors.white24, child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? kPink : Colors.white38),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)), Text(s, style: const TextStyle(color: Colors.white70, fontSize: 15))])),
        ])),
      );

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: Hub.i,
        builder: (_, __) {
          final h = Hub.i;
          if (!h.hosting) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('WHO HEARS IT?', style: graffiti(16, c: kCyan)),
              const SizedBox(height: 8),
              for (final m in _modes) opt(mode == m[0], m[1], m[2], () => setState(() => mode = m[0])),
              const SizedBox(height: 6),
              Text('SOUND SOURCE', style: graffiti(16, c: kCyan)),
              const SizedBox(height: 8),
              opt(src == 'system', 'System audio', 'Whatever this device plays (screen-share audio)', () => setState(() => src = 'system')),
              opt(src == 'mic', 'Microphone', 'Live sound from the mic', () => setState(() => src = 'mic')),
              if (h.error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(h.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 16))),
              NeonBtn('START BROADCAST', busy ? null : () async { setState(() => busy = true); await h.startHosting(mode, src); if (mounted) setState(() => busy = false); }, icon: Icons.podcasts),
            ]);
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            Panel(color: kPink, child: Column(children: [
              const Text('Your token. Type it on any other device.', style: TextStyle(fontSize: 16)),
              Text(h.token ?? '', style: graffiti(52, c: kAcid)),
              TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: h.token ?? '')), icon: const Icon(Icons.copy), label: const Text('Copy token')),
            ])),
            Wrap(spacing: 8, children: [for (final m in _modes) ChoiceChip(label: Text(m[1]), selected: h.mode == m[0], onSelected: (_) => h.setMode(m[0]))]),
            const SizedBox(height: 12),
            if (h.waiting.isNotEmpty) ...[
              Text('WAITING LIST (${h.waiting.length})', style: graffiti(15, c: kAcid)),
              for (final w in h.waiting)
                Panel(color: kAcid, child: Row(children: [
                  Expanded(child: Text('@${w['username']}\n${w['device']}', style: const TextStyle(fontSize: 16))),
                  IconButton(icon: const Icon(Icons.check_circle, color: kAcid), onPressed: () => h.decide(w['id'], true)),
                  IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), onPressed: () => h.decide(w['id'], false)),
                ])),
            ],
            Text('LISTENING (${h.listeners.length})', style: graffiti(15, c: kCyan)),
            if (h.listeners.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Nobody yet. Share the token.', style: TextStyle(color: Colors.white60, fontSize: 16))),
            for (final l in h.listeners)
              Panel(child: Row(children: [
                Expanded(child: Text('@${l['username']}\n${l['device']}', style: const TextStyle(fontSize: 16))),
                IconButton(icon: const Icon(Icons.person_remove, color: Colors.redAccent), onPressed: () => h.kick(l['id'])),
              ])),
            const SizedBox(height: 10),
            NeonBtn('STOP BROADCAST', h.stopHosting, color: Colors.redAccent, icon: Icons.stop),
          ]);
        },
      );
}

class ListenTab extends StatefulWidget {
  const ListenTab({super.key});
  @override
  State<ListenTab> createState() => _ListenState();
}

class _ListenState extends State<ListenTab> {
  final t = TextEditingController();

  @override
  Widget build(BuildContext c) => ListenableBuilder(
        listenable: Hub.i,
        builder: (_, __) {
          final h = Hub.i;
          const label = {'waiting': 'Waiting for the host to let you in…', 'connecting': 'Connecting…', 'playing': 'Playing live'};
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('ENTER TOKEN', style: graffiti(16, c: kCyan)),
            const SizedBox(height: 8),
            TextField(controller: t, maxLength: 6, textCapitalization: TextCapitalization.characters, textAlign: TextAlign.center, style: graffiti(34), decoration: const InputDecoration(counterText: '')),
            const SizedBox(height: 12),
            if (h.status == 'idle')
              NeonBtn('JOIN', () => h.join(t.text.trim()), color: kCyan, icon: Icons.headphones)
            else
              Panel(color: kCyan, child: Column(children: [
                Eq(active: h.status == 'playing'),
                const SizedBox(height: 8),
                Text(label[h.status] ?? '', style: const TextStyle(fontSize: 19)),
                const SizedBox(height: 12),
                NeonBtn('DISCONNECT', h.stopListening, color: Colors.redAccent),
              ])),
            if (h.error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(h.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 16))),
          ]);
        },
      );
}
