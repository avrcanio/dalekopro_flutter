# Dalekopro Farma Flutter

Flutter Android-first aplikacija za:
- prijavu korisnika
- odabir gospodarstva
- prikaz i pretragu goveda
- detalj goveda (slike, potomci, metadata)
- upload slike goveda (kamera ili SAF folder)

## Glavne funkcionalnosti

- Auth preko `POST /api/auth/login/` (token + user persist)
- Lista goveda po gospodarstvu `GET /api/gospodarstva/{id}/animals/`
- Grupiranje goveda po `uzrast` + broj u svakoj grupi
- Sticky search na vrhu liste:
  - unos `1-4` znamenke -> pretraga po zadnje 4 znamenke životnog broja
  - unos `>4` ili slova -> pretraga po cijelom životnom broju i imenu
- Prikaz `posjed` na kartici (desno) i u detalju goveda
- Potomci:
  - sekcija se prikazuje samo kad backend vrati `potomci != null`
  - svaki potomak je klikabilan i otvara profil potomka
- Upload slike:
  - kamera (`image_picker`) ili Android SAF DocumentTree URI
  - crop (`image_cropper`)
  - `datum`, `latitude`, `longitude` čitaju se iz EXIF-a slike
  - upload na `POST /api/slike_goveda/upload/`

## Tehnologije

- Flutter / Dart
- Dio (interceptori: auth, retry policy, error mapping)
- `flutter_secure_storage`
- `image_picker`
- `image_cropper`
- `exif`

## Pokretanje lokalno

1. Instaliraj dependency-je:
```bash
flutter pub get
```

2. Pokreni na emulatoru/uređaju:
```bash
flutter run
```

3. Android debug build:
```bash
flutter build apk --debug
```

## API baza

`ApiConfig.baseUrl` je definiran u:

- `lib/core/config/api_config.dart`

## Testovi i kvaliteta

```bash
flutter analyze
flutter test
```

## Android SAF napomena (emulator)

Slike ubaci u emulator npr.:

```bash
adb push "C:\\Users\\<user>\\Pictures\\slika.jpg" /sdcard/DCIM/
```

U aplikaciji zatim:
1. `Odaberi` SAF folder
2. odaberi `DCIM`
3. `Iz SAF foldera`
