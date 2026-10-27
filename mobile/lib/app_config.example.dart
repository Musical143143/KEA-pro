/// Copy to app_config.dart for local builds, or let the GitHub Actions
/// release workflow generate app_config.dart from repository secrets.
/// Use only the Supabase project URL and publishable/anon key in this client.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
