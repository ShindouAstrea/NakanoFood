/// Fill these in with your Supabase project credentials.
/// Project Settings → API → Project URL & anon public key
class SupabaseConfig {
  static const String url = 'https://bermboxqhqobhawuoahk.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlcm1ib3hxaHFvYmhhd3VvYWhrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyNjg3MTMsImV4cCI6MjA4OTg0NDcxM30.8nVvUFzaxEmODy0cw0gUH0uze5Xz8J_jX0en2KpihbA';

  /// Returns false when the placeholder values have not been replaced yet.
  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
