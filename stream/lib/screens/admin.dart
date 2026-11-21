import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../theme.dart';
import 'gate.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminState();
}

class _AdminState extends State<AdminScreen> {
  Map ov = {'online': [], 'sessions': [], 'userCount': 0};
  List users = [], ups = [];
  String? err;
  Timer? timer;
  final ver = TextEditingController(), url = TextEditingController(), notes = TextEditingController();
  String umode = 'simple', uplat = 'all';

  @override
  void initState() { super.initState(); load(); timer = Timer.periodic(const Duration(seconds: 5), (_) => load()); }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> load() async {
    try {
      final o = await Api.call('GET', '/admin/overview'), u = await Api.call('GET', '/admin/users'), p = await Api.call('GET', '/admin/updates');
      if (mounted) setState(() { ov = o; users = u; ups = p; err = null; });
    } catch (e) { if (mounted) setState(() => err = '$e'); }
  }

  void snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  String when(dynamic x) => x == null ? '-' : DateTime.parse('$x').toLocal().toString().substring(0, 16);

  Future<void> push() async {
    try {
      await Api.call('POST', '/admin/updates', body: {'version': ver.text.trim(), 'url': url.text.trim(), 'mode': umode, 'platform': uplat, 'notes': notes.text.trim()});
      snack('Update sent to every connected device');
      ver.clear(); url.clear(); notes.clear(); load();
    } catch (e) { snack('$e'); }
  }

  Future<void> act(String m, String p) async { try { await Api.call(m, p); } catch (e) { snack('$e'); } load(); }

  Widget online() => ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          Expanded(child: Panel(color: kPink, child: Column(children: [Text('${(ov['online'] as List).length}', style: graffiti(30)), const Text('Online now')]))),
          const SizedBox(width: 8),
          Expanded(child: Panel(child: Column(children: [Text('${ov['userCount']}', style: graffiti(30)), const Text('Accounts')]))),
          const SizedBox(width: 8),
          Expanded(child: Panel(color: kAcid, child: Column(children: [Text('${(ov['sessions'] as List).length}', style: graffiti(30)), const Text('Live tokens')]))),
        ]),
        Text('LIVE TOKENS', style: graffiti(15, c: kAcid)),
        if ((ov['sessions'] as List).isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No broadcasts right now.', style: TextStyle(color: Colors.white60))),
        for (final s in ov['sessions']) Panel(color: kAcid, child: Text('${s['token']}   host @${s['host']}   mode ${s['mode']}\n${s['listeners']} listening, ${s['waiting']} waiting, since ${when(DateTime.fromMillisecondsSinceEpoch(s['startedAt']).toIso8601String())}', style: const TextStyle(fontSize: 16))),
        const SizedBox(height: 6),
        Text('CONNECTED DEVICES', style: graffiti(15, c: kCyan)),
        for (final d in ov['online'])
          Panel(child: Row(children: [
            Expanded(child: Text('@${d['username']}  (${d['device']})\n${d['platform']}  v${d['appVersion']}  ip ${d['ip']}\nsession: ${d['session'] ?? 'none'}', style: const TextStyle(fontSize: 15))),
            IconButton(icon: const Icon(Icons.bolt, color: Colors.redAccent), tooltip: 'Disconnect', onPressed: () => act('POST', '/admin/kick/${d['socketId']}')),
          ])),
      ]);

  Widget usersTab() => ListView(padding: const EdgeInsets.all(14), children: [
        for (final u in users)
          Panel(color: u['banned'] == true ? Colors.redAccent : kCyan, child: Row(children: [
            Expanded(child: Text(
              '@${u['username']}  ${u['banned'] == true ? '(BANNED)' : ''}\n${u['displayName'] ?? ''}  ${u['email'] ?? ''}  ${u['phone'] ?? ''}\n'
              'last login ${when(u['lastLoginAt'])}  x${u['loginCount']}\n${u['lastDevice'] ?? '-'}  ${u['lastPlatform'] ?? ''}  v${u['lastAppVersion'] ?? ''}  ip ${u['lastIp'] ?? ''}',
              style: const TextStyle(fontSize: 15))),
            Column(children: [
              IconButton(icon: Icon(u['banned'] == true ? Icons.lock_open : Icons.block, color: kAcid), tooltip: 'Ban / unban', onPressed: () => act('POST', '/admin/users/${u['_id']}/ban')),
              IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), tooltip: 'Delete', onPressed: () => act('DELETE', '/admin/users/${u['_id']}')),
            ]),
          ])),
      ]);

  Widget updatesTab() => ListView(padding: const EdgeInsets.all(14), children: [
        Text('SEND AN UPDATE', style: graffiti(16, c: kAcid)),
        const SizedBox(height: 8),
        Panel(color: kAcid, child: Column(children: [
          TextField(controller: ver, decoration: const InputDecoration(labelText: 'New version (e.g. 1.1.0)')),
          const SizedBox(height: 10),
          TextField(controller: url, decoration: const InputDecoration(labelText: 'GitHub release or app link')),
          const SizedBox(height: 10),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'What is new (optional)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: uplat, decoration: const InputDecoration(labelText: 'Platform'),
            items: [for (final p in ['all', 'android', 'windows', 'web', 'ios', 'macos', 'linux']) DropdownMenuItem(value: p, child: Text(p))],
            onChanged: (v) => setState(() => uplat = v!),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'simple', label: Text('Simple update')), ButtonSegment(value: 'force', label: Text('Force update'))],
            selected: {umode}, onSelectionChanged: (s) => setState(() => umode = s.first),
          ),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(umode == 'force' ? 'Users cannot use the app until they update.' : 'Users can skip it and update later.', style: const TextStyle(color: Colors.white70)))),
          const SizedBox(height: 12),
          NeonBtn('SEND UPDATE', push, color: kAcid, icon: Icons.send),
        ])),
        Text('HISTORY', style: graffiti(15, c: kCyan)),
        for (final u in ups)
          Panel(child: Row(children: [
            Expanded(child: Text('v${u['version']}  ${u['mode']}  ${u['platform']}\n${u['url']}\n${when(u['createdAt'])}', style: const TextStyle(fontSize: 15))),
            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => act('DELETE', '/admin/updates/${u['_id']}')),
          ])),
      ]);

  @override
  Widget build(BuildContext c) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: kPanel, title: Text('ADMIN', style: graffiti(20)),
            actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () async { await Api.logout(); if (c.mounted) Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const Gate())); })],
            bottom: const TabBar(indicatorColor: kPink, tabs: [Tab(text: 'Live'), Tab(text: 'Users'), Tab(text: 'Updates')]),
          ),
          body: SprayBg(child: Column(children: [
            if (err != null) Container(width: double.infinity, color: Colors.redAccent.withOpacity(.3), padding: const EdgeInsets.all(8), child: Text(err!)),
            Expanded(child: TabBarView(children: [online(), usersTab(), updatesTab()])),
          ])),
        ),
      );
}
