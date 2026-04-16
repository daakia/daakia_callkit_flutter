import 'dart:io';

enum DaakiaPlatform {
  android('android'),
  ios('ios');

  const DaakiaPlatform(this.value);

  final String value;

  static DaakiaPlatform? get current {
    if (Platform.isAndroid) return DaakiaPlatform.android;
    if (Platform.isIOS) return DaakiaPlatform.ios;
    return null;
  }
}
