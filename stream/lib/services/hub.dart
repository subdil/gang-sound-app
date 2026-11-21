import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';
import 'api.dart';

List<Map<String, dynamic>> _ml(dynamic x) => (x as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

int cmpVer(String a, String b) {
  final x = a.split('.').map((e) => int.tryParse(e) ?? 0).toList(), y = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d > 0 ? 1 : -1;
  }
  return 0;
}

/// Socket + WebRTC brain. Host captures audio and sends one stream per listener. Listener plays it.
class Hub extends ChangeNotifier {
  static final Hub i = Hub._();
  Hub._();

  io.Socket? sock;
  bool connected = false, hosting = false, rReady = false;
  String? error, token, hostId;
  String mode = 'others', status = 'idle'; // status: idle | waiting | connecting | playing
  List<Map<String, dynamic>> listeners = [], waiting = [], ice = [{'urls': 'stun:stun.l.google.com:19302'}];
  MediaStream? local;
  final peers = <String, RTCPeerConnection>{};
  RTCPeerConnection? inPc;
  final renderer = RTCVideoRenderer();
  final _pendingIce = <RTCIceCandidate>[];
  Future<void> _q = Future.value();
  Map<String, dynamic>? _upd;

  // ---------- updates ----------
  Map<String, dynamic>? get update {
    final u = _upd;
    if (u == null) return null;
    final p = u['platform'] ?? 'all';
    if (p != 'all' && p != platformName) return null;
    return cmpVer(appVersion, u['version'].toString()) < 0 ? u : null;
  }

  Future<void> checkUpdate() async {
    try {
      final r = await Api.call('GET', '/update/latest?platform=$platformName&version=$appVersion');
      if (r['available'] == true) { _upd = Map<String, dynamic>.from(r); notifyListeners(); }
    } catch (_) {}
  }

  // ---------- connection ----------
  Future<void> connect() async {
    if (sock != null) return;
    if (!rReady) { await renderer.initialize(); rReady = true; notifyListeners(); }
    try { final c = await Api.call('GET', '/config/ice'); ice = _ml(c['iceServers']); } catch (_) {}
    final s = io.io(apiUrl, io.OptionBuilder().setTransports(['websocket']).disableAutoConnect()
        .setAuth({'token': Api.token, 'device': Api.deviceName, 'platform': platformName, 'appVersion': appVersion}).build());
    sock = s;
    s.onConnect((_) { connected = true; error = null; notifyListeners(); });
    s.onDisconnect((_) { connected = false; notifyListeners(); });
    s.onConnectError((e) {
      final upd = '$e'.contains('update_required');
      error = upd ? 'Update required' : 'Connection problem: $e';
      if (upd) checkUpdate();
      notifyListeners();
    });
    s.on('update:available', (d) { _upd = Map<String, dynamic>.from(d as Map); notifyListeners(); });
    s.on('session:state', (d) { mode = d['mode']; listeners = _ml(d['listeners']); waiting = _ml(d['waiting']); notifyListeners(); });
    s.on('listener:ready', (d) { if (hosting) _offerTo(d['id']); });
    s.on('listener:gone', (d) { peers.remove(d['id'])?.close(); });
    s.on('session:approved', (d) { hostId = d['hostId']; token = d['token']; status = 'connecting'; notifyListeners(); });
    s.on('session:denied', (_) { _resetListen('The host said no'); });
    s.on('session:kicked', (_) { _resetListen('You were removed by the host'); });
    s.on('session:ended', (d) { _resetListen('${d['why'] ?? 'Session ended'}'); });
    s.on('signal', (d) { _q = _q.then((_) => _onSignal(Map<String, dynamic>.from(d as Map))).catchError((_) {}); });
    s.connect();
  }

  Future<void> disconnect() async {
    await stopHosting(); await stopListening();
    sock?.dispose(); sock = null; connected = false; notifyListeners();
  }

  Future<Map> _emit(String ev, Map data) {
    final c = Completer<Map>();
    sock!.emitWithAck(ev, data, ack: (r) { if (!c.isCompleted) c.complete(Map.from(r as Map)); });
    return c.future.timeout(const Duration(seconds: 10), onTimeout: () => {'ok': false, 'error': 'Server did not answer'});
  }

  // ---------- host ----------
  Future<MediaStream> _capture(String src) async {
    if (src == 'mic') {
      return navigator.mediaDevices.getUserMedia({'audio': {'echoCancellation': false, 'noiseSuppression': false, 'autoGainControl': false}, 'video': false});
    }
    return navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': true}); // video track stays alive but is never sent
  }

  Future<bool> startHosting(String m, String src) async {
    error = null;
    if (sock == null || !connected) { error = 'Not connected to the server'; notifyListeners(); return false; }
    try { local = await _capture(src); } catch (e) { error = 'Could not capture audio: $e'; notifyListeners(); return false; }
    final tracks = local!.getAudioTracks();
    if (tracks.isEmpty) {
      error = 'No audio was captured. When sharing, tick "Share audio" (or use Microphone).';
      for (final t in local!.getTracks()) { t.stop(); }
      local = null; notifyListeners(); return false;
    }
    tracks.first.onEnded = () => stopHosting();
    final r = await _emit('session:create', {'mode': m});
    if (r['ok'] != true) { error = '${r['error']}'; notifyListeners(); return false; }
    hosting = true; token = r['token']; mode = m; notifyListeners();
    return true;
  }

  Future<void> _offerTo(String id) async {
    final pc = await createPeerConnection({'iceServers': ice, 'sdpSemantics': 'unified-plan'});
    peers[id] = pc;
    for (final t in local!.getAudioTracks()) { await pc.addTrack(t, local!); }
    pc.onIceCandidate = (c) { if (c.candidate != null) sock?.emit('signal', {'to': id, 'data': {'ice': c.toMap()}}); };
    pc.onConnectionState = (s) { if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) { peers.remove(id)?.close(); } };
    final o = await pc.createOffer({'offerToReceiveAudio': false});
    // stereo + high bitrate opus so music sounds like music
    final sdp = o.sdp!.replaceAll('useinbandfec=1', 'useinbandfec=1;stereo=1;sprop-stereo=1;maxaveragebitrate=192000');
    await pc.setLocalDescription(RTCSessionDescription(sdp, o.type));
    sock?.emit('signal', {'to': id, 'data': {'sdp': {'type': o.type, 'sdp': sdp}}});
  }

  void decide(String id, bool allow) => sock?.emit('session:decide', {'id': id, 'allow': allow});
  void kick(String id) => sock?.emit('session:kick', {'id': id});
  void setMode(String m) { mode = m; sock?.emit('session:setMode', {'mode': m}); notifyListeners(); }

  Future<void> stopHosting() async {
    if (!hosting && local == null) return;
    sock?.emit('session:end', {});
    for (final p in peers.values) { p.close(); }
    peers.clear();
    for (final t in local?.getTracks() ?? <MediaStreamTrack>[]) { t.stop(); }
    await local?.dispose(); local = null;
    hosting = false; token = null; listeners = []; waiting = [];
    notifyListeners();
  }

  // ---------- listener ----------
  Future<void> join(String t) async {
    error = null;
    if (sock == null || !connected) { error = 'Not connected to the server'; notifyListeners(); return; }
    final r = await _emit('session:join', {'token': t});
    if (r['ok'] != true) { error = '${r['error']}'; notifyListeners(); return; }
    token = t.toUpperCase();
    if (r['status'] == 'waiting') { status = 'waiting'; } else if (status != 'playing') { status = 'connecting'; }
    notifyListeners();
  }

  void _resetListen(String? msg) {
    inPc?.close(); inPc = null; _pendingIce.clear(); renderer.srcObject = null;
    status = 'idle'; if (!hosting) token = null; error = msg; notifyListeners();
  }

  Future<void> stopListening() async {
    if (status == 'idle') return;
    sock?.emit('session:leave', {});
    _resetListen(null);
  }

  // ---------- signalling ----------
  RTCIceCandidate _cand(Map m) => RTCIceCandidate(m['candidate'], m['sdpMid'], m['sdpMLineIndex']);

  Future<void> _onSignal(Map<String, dynamic> d) async {
    final from = d['from'] as String, data = Map<String, dynamic>.from(d['data']);
    if (hosting) {
      final pc = peers[from];
      if (pc == null) return;
      if (data['sdp'] != null) await pc.setRemoteDescription(RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
      if (data['ice'] != null) await pc.addCandidate(_cand(data['ice']));
      return;
    }
    if (data['sdp'] != null) {
      inPc?.close();
      final pc = inPc = await createPeerConnection({'iceServers': ice, 'sdpSemantics': 'unified-plan'});
      pc.onIceCandidate = (c) { if (c.candidate != null) sock?.emit('signal', {'to': from, 'data': {'ice': c.toMap()}}); };
      pc.onTrack = (e) { if (e.streams.isNotEmpty) { renderer.srcObject = e.streams[0]; status = 'playing'; notifyListeners(); } };
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
      for (final c in _pendingIce) { await pc.addCandidate(c); }
      _pendingIce.clear();
      final a = await pc.createAnswer();
      await pc.setLocalDescription(a);
      sock?.emit('signal', {'to': from, 'data': {'sdp': {'type': a.type, 'sdp': a.sdp}}});
    } else if (data['ice'] != null) {
      final c = _cand(data['ice']);
      if (inPc == null) { _pendingIce.add(c); } else { await inPc!.addCandidate(c); }
    }
  }
}
