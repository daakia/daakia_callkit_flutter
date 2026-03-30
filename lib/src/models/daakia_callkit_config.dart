import 'daakia_platform.dart';

class DaakiaCallkitConfig {
  const DaakiaCallkitConfig({
    required this.baseUrl,
    required this.secret,
    this.defaultIosSandbox = false,
  });

  final String baseUrl;
  final String secret;
  final bool defaultIosSandbox;

  String resolveConfigName({
    required DaakiaPlatform platform,
    bool? isIosSandbox,
  }) {
    if (platform == DaakiaPlatform.android) {
      return 'prod';
    }

    final sandbox = isIosSandbox ?? defaultIosSandbox;
    return sandbox ? 'dev' : 'prod';
  }
}
