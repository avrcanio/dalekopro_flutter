/// Google Maps – ključ za Dart (npr. web ili dodatni SDK koji traži string u kodu).
///
/// Na Androidu `google_maps_flutter` koristi ključ iz AndroidManifesta
/// (Gradle ga puni iz root `.env`, varijabla GOOGLE_MAPS_API_KEY).
///
/// Za vrijednost u Dartu bez `.env` builda:
/// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=tvoj_kljuc`
const String kGoogleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: '',
);
