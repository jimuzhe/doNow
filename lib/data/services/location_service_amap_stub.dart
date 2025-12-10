// Stub implementation for non-Android platforms
// This file is used when compiling for iOS, Web, etc.

/// Stub - returns null on non-Android platforms
Future<Map<String, dynamic>?> getAmapLocation() async {
  return null;
}

/// Stub - does nothing on non-Android platforms
void disposeAmap() {
  // No-op
}
