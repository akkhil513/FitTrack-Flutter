import 'package:web/web.dart' as web;

/// Browser localStorage fallback for when flutter_secure_storage cannot encrypt
/// (WebCrypto is unavailable on plain-HTTP origins). Every call is guarded
/// because storage can throw in private windows or with site data blocked.
class FallbackTokenStore {
  static String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  static bool write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  static void delete(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }
}
