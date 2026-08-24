import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_storage.dart';

class FactoryHubApi {
  static const String baseUrl = 'https://exim-raw-api.onrender.com';
  static const String basePath = '/fh';
  static const Duration timeout = Duration(seconds: 60);

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static String get role => _currentUser?['role'] ?? '';
  static int? get userId => int.tryParse(_currentUser?['id']?.toString() ?? '');
  static String get username => _currentUser?['username']?.toString() ?? '';
  static bool get isLoggedIn => _token != null;

  // ─── Sessiya ────────────────────────────────────────────────
  static Future<bool> restoreSession() async {
    try {
      final token = await AuthStorage.getToken();
      final user = await AuthStorage.getUser();
      if (token != null && user != null) {
        _token = token;
        _currentUser = user;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _post(
      '/login',
      {'email': email, 'password': password},
      requiresAuth: false,
    );
    if (result['error'] == null) {
      _token = result['token'] as String?;
      _currentUser = result['user'] as Map<String, dynamic>?;
      if (_token != null && _currentUser != null) {
        await AuthStorage.saveSession(_token!, _currentUser!);
      }
    }
    return result;
  }

  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await AuthStorage.clearSession();
  }

  static Future<Map<String, dynamic>> setupSuperAdmin(
    String username,
    String email,
    String password,
    String secret,
  ) =>
      _post('/setup', {
        'username': username,
        'email': email,
        'password': password,
        'secret_key': secret,
      }, requiresAuth: false);

  // ─── Dashboard / statistika ────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard() async => _get('/dashboard/summary');

  // ─── Katalog (exim_raw) ────────────────────────────────────
  static Future<Map<String, dynamic>> getRawMaterials() async => _get('/catalog/raw-materials');

  static Future<Map<String, dynamic>> getProducts({String? search}) async =>
      _get('/catalog/products${search == null || search.isEmpty ? '' : '?search=$search'}');

  static Future<Map<String, dynamic>> getPartners() async => _get('/catalog/partners');

  // ─── Omborlar va zaxira ────────────────────────────────────
  static Future<Map<String, dynamic>> getWarehouses() async => _get('/warehouses');

  static Future<Map<String, dynamic>> createWarehouse(String name, String type) async =>
      _post('/warehouses', {'name': name, 'type': type});

  static Future<Map<String, dynamic>> getWarehouseDetail(int id) async => _get('/warehouses/$id');

  static Future<Map<String, dynamic>> addTransaction(Map<String, dynamic> data) async =>
      _post('/warehouse/transaction', data);

  static Future<Map<String, dynamic>> getStock({int? warehouseId}) async =>
      _get('/stock${warehouseId == null ? '' : '?warehouse_id=$warehouseId'}');

  // ─── Rejalar ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> getPlans({String? status}) async =>
      _get('/plans${status == null ? '' : '?status=$status'}');

  static Future<Map<String, dynamic>> createPlan(Map<String, dynamic> data) async =>
      _post('/plans', data);

  static Future<Map<String, dynamic>> updatePlanStatus(int id, String status) async =>
      _put('/plans/$id', {'status': status});

  // ─── Ta'minotchi buyurtmalari ──────────────────────────────
  static Future<Map<String, dynamic>> getSupplierOrders({String? status}) async =>
      _get('/supplier-orders${status == null ? '' : '?status=$status'}');

  static Future<Map<String, dynamic>> createSupplierOrder(Map<String, dynamic> data) async =>
      _post('/supplier-orders', data);

  static Future<Map<String, dynamic>> updateSupplierOrderStatus(int id, String status) async =>
      _put('/supplier-orders/$id', {'status': status});

  // ─── Ishlab chiqarish ──────────────────────────────────────
  static Future<Map<String, dynamic>> getNorms(String barcode) async =>
      _get('/production/norms/$barcode');

  static Future<Map<String, dynamic>> startProduction(Map<String, dynamic> data) async =>
      _post('/production/start', data);

  static Future<Map<String, dynamic>> updateBatch(int id, Map<String, dynamic> data) async =>
      _put('/production/$id', data);

  static Future<Map<String, dynamic>> getBatches({String? status}) async =>
      _get('/reports/production${status == null ? '' : '?status=$status'}');

  // ─── Ogohlantirishlar ──────────────────────────────────────
  static Future<Map<String, dynamic>> getAlerts() async => _get('/alerts');

  // ─── Foydalanuvchilar ──────────────────────────────────────
  static Future<Map<String, dynamic>> getUsers() async => _get('/users');

  static Future<Map<String, dynamic>> getUserDetail(int id) async => _get('/users/$id');

  static Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async =>
      _post('/users', data);

  static Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) async =>
      _put('/users/$id', data);

  static Future<Map<String, dynamic>> deactivateUser(int id) async => _delete('/users/$id');

  static Future<Map<String, dynamic>> assignUser({
    required int userId,
    required List<int> warehouseIds,
  }) async =>
      _post('/users/assign', {
        'user_id': userId,
        'warehouse_ids': warehouseIds,
      });

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
        if (response.statusCode == 401) {
          logout();
          return {'error': 'Sessiya tugadi. Qayta kiring.', 'unauthorized': true};
        }
        if (response.statusCode >= 400) {
          return {'error': data['error'] ?? 'Xatolik: ${response.statusCode}'};
        }
        return {'success': true, ...data};
      }
      return {'success': true, 'data': data};
    } catch (_) {
      return {'error': "Javob o'qishda xatolik"};
    }
  }

  static Map<String, dynamic> _handleError(Object e) {
    if (kDebugMode) print('API xatolik: $e');
    if (e.toString().contains('TimeoutException')) {
      return {'error': 'Server javob bermadi. Qayta urinib koring.'};
    }
    return {'error': 'Tarmoq xatosi. Internetni tekshiring.'};
  }

  static Future<Map<String, dynamic>> _get(
    String path, {
    bool requiresAuth = true,
  }) async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl$basePath$path'), headers: _headers(requiresAuth: requiresAuth))
          .timeout(timeout);
      return _parseResponse(r);
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseUrl$basePath$path'),
            headers: _headers(requiresAuth: requiresAuth),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _parseResponse(r);
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    try {
      final r = await http
          .put(
            Uri.parse('$baseUrl$basePath$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _parseResponse(r);
    } catch (e) {
      return _handleError(e);
    }
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final r = await http
          .delete(Uri.parse('$baseUrl$basePath$path'), headers: _headers())
          .timeout(timeout);
      return _parseResponse(r);
    } catch (e) {
      return _handleError(e);
    }
  }
}
