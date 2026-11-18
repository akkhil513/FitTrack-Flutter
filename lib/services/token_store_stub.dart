/// Fallback store used when secure storage is unavailable. Non-web builds keep
/// nothing here, so [read] always reports no value.
class FallbackTokenStore {
  static String? read(String key) => null;
  static bool write(String key, String value) => false;
  static void delete(String key) {}
}
