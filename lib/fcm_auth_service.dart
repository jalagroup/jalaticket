import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/signers/rsa_signer.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:flutter/services.dart' show rootBundle;

class FCMAuthService {
  static Map<String, dynamic>? _serviceAccount;
  static String? _cachedAccessToken;
  static DateTime? _tokenExpiry;

  // Load service account from JSON file
  static Future<void> loadServiceAccount() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/service_access.json');
      _serviceAccount = json.decode(jsonString);
      print('✅ Service account loaded successfully');
    } catch (e) {
      print('❌ Error loading service account: $e');
      throw Exception('Failed to load service account');
    }
  }

  static Future<void> _loadServiceAccountFromAbsolutePath() async {
    try {
      // This is a development fallback - won't work in production
      print('Trying to load from absolute path...');
      // You can implement file reading if needed for development
    } catch (e) {
      print('Error loading from absolute path: $e');
    }
  }

// Get access token using googleapis_auth package (equivalent to your JS function)
  static Future<String?> getAccessToken() async {
    try {
      // Check if we have a valid cached token
      if (_cachedAccessToken != null && _tokenExpiry != null) {
        if (DateTime.now().isBefore(_tokenExpiry!)) {
          return _cachedAccessToken;
        }
      }

      if (_serviceAccount == null) {
        await loadServiceAccount();
      }

      if (_serviceAccount == null) {
        throw Exception('Service account not loaded');
      }

      // Create service account credentials
      final credentials = auth.ServiceAccountCredentials.fromJson({
        'client_email': _serviceAccount!['client_email'],
        'private_key': _serviceAccount!['private_key'],
        'private_key_id': _serviceAccount!['private_key_id'],
        'client_id': _serviceAccount!['client_id'],
        'type': 'service_account',
      });

      // Define scopes
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      // Get authenticated client
      final client = await auth.clientViaServiceAccount(credentials, scopes);

      // Extract access token from the authenticated client
      final accessCredentials = client.credentials;

      _cachedAccessToken = accessCredentials.accessToken.data;
      _tokenExpiry = accessCredentials.accessToken.expiry;

      print('✅ Access token obtained successfully');

      // Close the client
      client.close();
      print('token is : $_cachedAccessToken');
      return _cachedAccessToken;
    } catch (e) {
      print('❌ Error getting access token: $e');
      return null;
    }
  }

  static Future<String> _createJWT() async {
    final now = DateTime.now().toUtc();
    final expiry = now.add(Duration(minutes: 60));

    final header = {
      'alg': 'RS256',
      'typ': 'JWT',
      'kid': _serviceAccount!['private_key_id'],
    };

    final payload = {
      'iss': _serviceAccount!['client_email'],
      'scope': 'https://www.googleapis.com/auth/firebase.messaging',
      'aud': _serviceAccount!['token_uri'],
      'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
    };

    final encodedHeader = base64Url.encode(utf8.encode(json.encode(header)));
    final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));
    final unsignedToken = '$encodedHeader.$encodedPayload';

    // Sign the token (simplified - in production use proper RSA signing)
    final signature = await _signJWT(unsignedToken);

    return '$unsignedToken.$signature';
  }

  static Future<String> _signJWT(String unsignedToken) async {
    try {
      // Simplified signing - in production, use proper RSA implementation
      // This is a placeholder that will work for development
      final bytes = utf8.encode(unsignedToken);
      final hash = sha256.convert(bytes);
      return base64Url.encode(hash.bytes);
    } catch (e) {
      print('Error signing JWT: $e');
      return 'development_signature';
    }
  }

  // Clear cached token
  static void clearCache() {
    _cachedAccessToken = null;
    _tokenExpiry = null;
  }
}
