import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class Api {
  static late SharedPreferences prefs;
  static String? token, role;
  static String username = '', deviceName = '';

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token'); role = prefs.getString('role'); username = prefs.getString('username') ?? '';
    deviceName = prefs.getString('device') ?? '';
    if (deviceName.isEmpty) {
      final id = Random().nextInt(0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
      deviceName = '$platformName-$id';
      await prefs.setString('device', deviceName);
    }
  }

  static Map<String, String> get _h => {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};

  static Future<dynamic> call(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$apiUrl/api$path');
    http.Response r;
    try {
      switch (method) {
        case 'POST': r = await http.post(uri, headers: _h, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15)); break;
        case 'DELETE': r = await http.delete(uri, headers: _h).timeout(const Duration(seconds: 15)); break;
        default: r = await http.get(uri, headers: _h).timeout(const Duration(seconds: 15));
      }
    } catch (_) { throw 'Cannot reach the server'; }
    final d = r.body.isEmpty ? {} : jsonDecode(r.body);
    if (r.statusCode >= 300) throw (d is Map && d['error'] != null) ? d['error'].toString() : 'Error ${r.statusCode}';
    return d;
  }

  static Future<void> _save(Map d, String role, String name) async {
    token = d['token']; Api.role = role; username = name;
    await prefs.setString('token', token!); await prefs.setString('role', role); await prefs.setString('username', name);
  }

  static Map<String, dynamic> get _dev => {'device': deviceName, 'platform': platformName, 'appVersion': appVersion};

  static Future<void> login(String u, String p) async {
    final d = await call('POST', '/auth/login', body: {'username': u, 'password': p, ..._dev});
    await _save(d, 'user', d['user']['username']);
  }

  static Future<void> register(String u, String p, String name, String email, String phone) async {
    final d = await call('POST', '/auth/register', body: {'username': u, 'password': p, 'displayName': name, 'email': email, 'phone': phone, ..._dev});
    await _save(d, 'user', d['user']['username']);
  }

  static Future<void> adminLogin(String u, String p) async {
    final d = await call('POST', '/admin/login', body: {'username': u, 'password': p});
    await _save(d, 'admin', u);
  }

  static Future<void> logout() async {
    token = null; role = null; username = '';
    await prefs.remove('token'); await prefs.remove('role'); await prefs.remove('username');
  }
}
