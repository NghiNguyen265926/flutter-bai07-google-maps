class AppConfig {
  // KHONG commit API key that vao GitHub neu key dang co quyen su dung that.
  // Thay chuoi nay bang API key cua ban khi da co billing/API.
  static const String googleApiKey = 'YOUR_API_KEY_HERE';

  static bool get hasGoogleApiKey =>
      googleApiKey.isNotEmpty && googleApiKey != 'YOUR_API_KEY_HERE';
}
