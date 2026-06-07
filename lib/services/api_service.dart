import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FactoryHubApi {
  static const String baseUrl = 'https://flutter-backend-m8is.onrender.com';
  static const Duration timeout = Duration(seconds: 60);

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static String get role => _currentUser?['role'] ?? 'employee';
  static int? get userId => int.tryParse(_currentUser?['id']?.toString() ?? '');
  static int? get factoryId => _currentUser?['factoryId'] as int?;
  static bool get isLoggedIn => _token != null;

  static void logout() {
    _token = null;
    _currentUser = null;
  }

  // ─── Auth ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _post('/login', {'email': email, 'password': password}, requiresAuth: false);
    if (result['error'] == null) {
      _token = result['token'] as String?;
      _currentUser = result['user'] as Map<String, dynamic>?;
    }
    return result;
  }

  static Future<Map<String, dynamic>> setupSuperAdmin(
    String username, String email, String password, String secret) async =>
      _post('/setup', {'username': username, 'email': email, 'password': password, 'secret_key': secret}, requiresAuth: false);

  // ─── Dashboard ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard() async =>
      _get('/dashboard/summary');

  // ─── Materiallar ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getMaterials() async =>
      _get('/materials?user_id=$userId&role=$role');

  static Future<Map<String, dynamic>> createMaterial(Map<String, dynamic> data) async =>
      _post('/materials', data);

  // ─── Omborlar ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWarehouses() async =>
      _get('/warehouses');

  static Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async =>
      _post('/warehouse/transaction', data);

  // ─── BOM ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getBoms() async => _get('/boms');

  static Future<Map<String, dynamic>> createBom(Map<String, dynamic> data) async =>
      _post('/boms', data);

  // ─── Ishlab chiqarish ─────────────────────────────────────
  static Future<Map<String, dynamic>> startProduction(Map<String, dynamic> data) async =>
      _post('/production/start', data);

  static Future<Map<String, dynamic>> updateProduction(int id, Map<String, dynamic> data) async =>
      _put('/production/$id', data);

  // ─── Hisobotlar ───────────────────────────────────────────
  static Future<Map<String, dynamic>> getProductionReport(String period) async =>
      _get('/reports/production?period=$period');

  static Future<Map<String, dynamic>> getStockReport() async =>
      _get('/reports/stock');

  static Future<Map<String, dynamic>> getForecastReport() async =>
      _get('/reports/forecast');

  // ─── Ogohlantirishlar ─────────────────────────────────────
  static Future<Map<String, dynamic>> getAlerts() async => _get('/alerts');

  static Future<Map<String, dynamic>> generateAlerts() async =>
      _post('/alerts', {});

  // ─── Foydalanuvchilar ─────────────────────────────────────
  static Future<Map<String, dynamic>> getUsers() async => _get('/users');

  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async =>
      _post('/users', data);

  // ─── Kategoriyalar ────────────────────────────────────────
  static Future<Map<String, dynamic>> getCategories() async => _get('/categories');

  static Future<Map<String, dynamic>> getProductTypes() async => _get('/product-types');

  // ═══════════════════════════════════════════════════════════
  // PRIVATE HTTP METHODS
  // ═══════════════════════════════════════════════════════════

  static Map<String, String> _headers({bool requiresAuth = true}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth && _token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.body.isEmpty) {
      return response.statusCode < 300
          ? {'success': true}
          : {'error': 'Server xatosi: ${response.statusCode}'};
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (response.statusCode >= 400) {
          return {'error': data['error'] ?? 'Xatolik: ${response.statusCode}'};
        }
        return {'success': true, ...data};
      }
      return {'success': true, 'data': data};
    } catch (e) {
      return {'error': 'JSON parse xatosi'};
    }
  }

  static Map<String, dynamic> _handleError(Object e) {
    if (kDebugMode) print('API xatolik: $e');
    if (e.toString().contains('TimeoutException')) return {'error': 'Server javob bermadi'};
    return {'error': 'Tarmoq xatosi. Internetni tekshiring.'};
  }

  static Future<Map<String, dynamic>> _get(String path, {bool requiresAuth = true}) async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers(requiresAuth: requiresAuth),
      ).timeout(timeout);
      return _parseResponse(r);
    } catch (e) { return _handleError(e); }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {bool requiresAuth = true}) async {
    try {
      final r = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(requiresAuth: requiresAuth),
        body: jsonEncode(body),
      ).timeout(timeout);
      return _parseResponse(r);
    } catch (e) { return _handleError(e); }
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    try {
      final r = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers(),
        body: jsonEncode(body),
      ).timeout(timeout);
      return _parseResponse(r);
    } catch (e) { return _handleError(e); }
  }
}
