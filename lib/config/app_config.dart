class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  String get backendUrl => _backendUrl;
  String get liveKitUrl => _liveKitUrl;

  String _backendUrl = 'http://192.168.1.199:8080';
  String _liveKitUrl = 'ws://192.168.1.216:7880';

  void configure({String? backendUrl, String? liveKitUrl}) {
    if (backendUrl != null) {
      _backendUrl = backendUrl;
    }
    if (liveKitUrl != null) {
      _liveKitUrl = liveKitUrl;
    }
  }

  void reset() {
    _backendUrl = 'http://192.168.1.199:8080';
    _liveKitUrl = 'ws://192.168.1.216:7880';
  }
}
