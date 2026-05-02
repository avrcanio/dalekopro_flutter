import 'dart:async';
import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/saf_bridge.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/screen_insets.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../cattle/models/cattle.dart';
import '../data/upload_repository.dart';
import 'saf_image_picker_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    required this.cattle,
    required this.repository,
    this.storage,
    this.safBridge,
    this.imagePicker,
    this.initialImageForTest,
    this.cropImageOverride,
    this.initialSelectedImageSourceDocumentUri,
    this.initialSelectedImageSourceName,
    this.initialSelectedCattleForTest,
    this.initialSharedCachePath,
    this.skipExifForTest,
  });

  final List<Cattle> cattle;
  final UploadRepository repository;
  final TokenStorage? storage;
  final SafBridge? safBridge;
  final ImagePicker? imagePicker;
  final File? initialImageForTest;
  final Future<File?> Function(File sourceFile)? cropImageOverride;
  final String? initialSelectedImageSourceDocumentUri;
  final String? initialSelectedImageSourceName;
  final Cattle? initialSelectedCattleForTest;
  final String? initialSharedCachePath;
  /// When true, skips async EXIF reads (widget tests only; real devices use EXIF).
  final bool? skipExifForTest;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final TokenStorage _storage;
  late final SafBridge _safBridge;
  late final ImagePicker _picker;
  final ImageCropper _cropper = ImageCropper();
  final DateFormat _serverDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  late final TextEditingController _cattleSearchController;
  late final FocusNode _cattleSearchFocusNode;

  Cattle? _selectedCattle;
  File? _selectedImage;
  bool _uploading = false;
  String? _message;
  StatusType _messageType = StatusType.info;
  String? _folderUri;
  String? _exifDate;
  double? _exifLatitude;
  double? _exifLongitude;
  String? _selectedImageSourceDocumentUri;
  String? _selectedImageSourceName;
  double? _uploadProgressPercent;
  bool _loadingSafImages = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? const TokenStorage();
    _safBridge = widget.safBridge ?? const SafBridge();
    _picker = widget.imagePicker ?? ImagePicker();
    _cattleSearchController = TextEditingController();
    _cattleSearchFocusNode = FocusNode();

    _selectedImage = widget.initialImageForTest;
    _selectedImageSourceDocumentUri = widget.initialSelectedImageSourceDocumentUri;
    _selectedImageSourceName = widget.initialSelectedImageSourceName;
    _selectedCattle = widget.initialSelectedCattleForTest;
    if (_selectedCattle != null) {
      _cattleSearchController.text = _cattleOptionLabel(_selectedCattle!);
    }
    _loadFolderUri();
    final sharedPath = widget.initialSharedCachePath;
    if (sharedPath != null && sharedPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openInitialSharedImage(sharedPath));
      });
    }
  }

  Future<void> _openInitialSharedImage(String path) async {
    try {
      _clearSelectedImageSource();
      final file = File(path);
      if (!file.existsSync()) {
        if (!mounted) return;
        _setMessage(
          'Podijeljena slika vise nije dostupna. Podijeli ponovo.',
          StatusType.error,
        );
        return;
      }
      final cropped = await _cropAndSet(file);
      if (!mounted) return;
      if (!cropped) {
        _setMessage('Obrada podijeljene slike je otkazana.', StatusType.info);
      }
    } catch (e) {
      if (!mounted) return;
      _setMessage(
        'Nije moguce obraditi podijeljenu sliku. Podijeli ponovo.',
        StatusType.error,
      );
    }
  }

  @override
  void dispose() {
    _cattleSearchController.dispose();
    _cattleSearchFocusNode.dispose();
    super.dispose();
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String _compact(String value) {
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  static String _cattleOptionLabel(Cattle item) {
    final name = item.ime.trim();
    return name.isEmpty ? item.zivotniBroj : '${item.zivotniBroj} - $name';
  }

  bool _matchesCattleQuery(Cattle item, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return true;
    }

    final compactQuery = _compact(trimmed);
    final queryDigits = _digitsOnly(compactQuery);
    final isDigitsOnly =
        compactQuery.isNotEmpty && queryDigits.length == compactQuery.length;
    final cattleDigits = _digitsOnly(item.zivotniBroj);

    if (isDigitsOnly && queryDigits.length <= 4) {
      final lastFour = cattleDigits.length > 4
          ? cattleDigits.substring(cattleDigits.length - 4)
          : cattleDigits;
      return lastFour.contains(queryDigits);
    }

    final queryUpper = compactQuery.toUpperCase();
    final fullNumber = _compact(item.zivotniBroj).toUpperCase();
    final fullName = _compact(item.ime).toUpperCase();
    return fullNumber.contains(queryUpper) || fullName.contains(queryUpper);
  }

  void _setMessage(String message, StatusType type) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageType = type;
    });
  }

  Future<void> _loadFolderUri() async {
    final uri = await _storage.readFolderUri();
    if (!mounted) return;
    setState(() {
      _folderUri = uri;
    });
    if (uri != null && uri.isNotEmpty) {
      unawaited(_safBridge.prefetchTreeContents(treeUri: uri));
    }
  }

  Future<void> _selectFolder() async {
    try {
      final uri = await _safBridge.selectDocumentTree(
        initialTreeUri: _folderUri,
      );
      if (uri == null || uri.isEmpty) {
        _setMessage('Odabir foldera je otkazan.', StatusType.info);
        return;
      }

      await _storage.saveFolderUri(uri);
      if (!mounted) return;
      setState(() {
        _folderUri = uri;
      });
      unawaited(_safBridge.prefetchTreeContents(treeUri: uri));
      _setMessage('SAF folder je uspjesno postavljen.', StatusType.success);
    } on PlatformException {
      _setMessage(
        'Nije moguce pristupiti odabranom SAF folderu.',
        StatusType.error,
      );
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (xFile == null) {
        _setMessage('Slikanje je otkazano.', StatusType.info);
        return;
      }
      _clearSelectedImageSource();
      final cropped = await _cropAndSet(File(xFile.path));
      if (!cropped) {
        _clearSelectedImageSource();
        _setMessage('Crop je otkazan.', StatusType.info);
      }
    } on PlatformException {
      _setMessage('Kamera nije dostupna ili nema dozvolu.', StatusType.error);
    }
  }

  Future<void> _pickFromSelectedFolder() async {
    if (_folderUri == null || _folderUri!.isEmpty) {
      _setMessage('Prvo odaberi SAF folder slika.', StatusType.warning);
      return;
    }

    setState(() {
      _loadingSafImages = true;
    });

    try {
      while (mounted) {
        final images =
            _safBridge.getCachedImagesForTree(treeUri: _folderUri!) ??
            await _safBridge.listImagesFromTree(treeUri: _folderUri!);
        if (!mounted) return;
        if (images.isEmpty) {
          _setMessage('U odabranom SAF folderu nema dostupnih slika.', StatusType.info);
          return;
        }

        final selected = await Navigator.of(context).push<SafImageEntry>(
          MaterialPageRoute(
            builder: (_) => SafImagePickerScreen(images: images, safBridge: _safBridge),
          ),
        );
        if (!mounted) return;
        if (selected == null) {
          _setMessage('Odabir slike iz foldera je otkazan.', StatusType.info);
          return;
        }

        final filePath = await _safBridge.copyDocumentToCache(
          documentUri: selected.uri,
          suggestedFileName: selected.displayName,
        );
        if (filePath == null || filePath.isEmpty) {
          _setMessage('Odabir slike iz foldera je otkazan.', StatusType.info);
          return;
        }
        _selectedImageSourceDocumentUri = selected.uri;
        _selectedImageSourceName = selected.displayName;
        final cropped = await _cropAndSet(File(filePath));
        if (!mounted) return;
        if (cropped) {
          return;
        }
      }
    } on PlatformException {
      _setMessage(
        'Nije moguce procitati sliku iz odabranog foldera.',
        StatusType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingSafImages = false;
        });
      }
    }
  }

  static String _readTagPrintable(Map<String, IfdTag> exif, String key) {
    final tag = exif[key];
    if (tag == null) return '';
    return tag.printable.toString().trim();
  }

  /// Prvi ne-prazan datum snimanja / digitalizacije / izmjene (EXIF redoslijed).
  static String _readCaptureDateRaw(Map<String, IfdTag> exif) {
    const keys = <String>[
      'EXIF DateTimeOriginal',
      'EXIF DateTimeDigitized',
      'Image DateTime',
    ];
    for (final k in keys) {
      final v = _readTagPrintable(exif, k);
      if (v.isNotEmpty) {
        return v;
      }
    }
    return '';
  }

  /// Pretvara EXIF tekst u `yyyy-MM-dd HH:mm:ss` za API (tolerira različite OEM formate).
  String? _formatExifDateForServer(String raw) {
    var s = raw.trim();
    if (s.isEmpty) {
      return null;
    }
    // Ukloni završni timezone ako postoji (npr. +02:00 ili Z).
    s = s.replaceFirst(RegExp(r'\s*([Zz]|[\+\-]\d{2}:?\d{2}(?::\d{2})?)$'), '').trim();

    final candidates = <DateFormat>[
      DateFormat('yyyy:MM:dd HH:mm:ss'),
      DateFormat('yyyy:MM:dd HH:mm:ss.SSS'),
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      DateFormat('yyyy-MM-dd HH:mm:ss.SSS'),
    ];
    for (final fmt in candidates) {
      try {
        final d = fmt.parseStrict(s);
        return _serverDateFormat.format(d);
      } catch (_) {
        try {
          final d = fmt.parse(s);
          return _serverDateFormat.format(d);
        } catch (_) {}
      }
    }

    final isoish = s.replaceFirstMapped(
      RegExp(r'^(\d{4}):(\d{2}):(\d{2})'),
      (m) => '${m[1]}-${m[2]}-${m[3]}',
    );
    try {
      final normalized = isoish.contains('T') ? isoish : isoish.replaceFirst(' ', 'T');
      final d = DateTime.parse(normalized);
      return _serverDateFormat.format(d);
    } catch (_) {
      return null;
    }
  }

  static double? _parseExifPart(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('/')) {
      final pieces = trimmed.split('/');
      if (pieces.length != 2) return null;
      final numerator = double.tryParse(pieces[0]);
      final denominator = double.tryParse(pieces[1]);
      if (numerator == null || denominator == null || denominator == 0) {
        return null;
      }
      return numerator / denominator;
    }
    return double.tryParse(trimmed);
  }

  static double? _parseGpsCoordinate(String raw, String ref) {
    final matches = RegExp(
      r'(-?\d+(?:\.\d+)?(?:/\d+(?:\.\d+)?)?)',
    ).allMatches(raw).map((m) => m.group(0)!).toList();
    if (matches.length < 3) return null;

    final deg = _parseExifPart(matches[0]);
    final min = _parseExifPart(matches[1]);
    final sec = _parseExifPart(matches[2]);
    if (deg == null || min == null || sec == null) return null;

    var value = deg + (min / 60.0) + (sec / 3600.0);
    final refUpper = ref.toUpperCase();
    if (refUpper == 'S' || refUpper == 'W') {
      value = -value;
    }
    return value;
  }

  Future<Map<String, IfdTag>> _readExif(File file) async {
    final bytes = await file.readAsBytes();
    return readExifFromBytes(bytes);
  }

  Future<void> _extractExifFromImage({
    required File sourceFile,
    required File uploadFile,
  }) async {
    if (widget.skipExifForTest == true) {
      if (!mounted) return;
      setState(() {
        _exifDate = null;
        _exifLatitude = null;
        _exifLongitude = null;
      });
      return;
    }
    try {
      final uploadExif = await _readExif(uploadFile);
      final sourceExif = sourceFile.path != uploadFile.path
          ? await _readExif(sourceFile)
          : uploadExif;

      // Datum snimanja: uvijek prvo iz izvorne datoteke (share/galerija prije cropa —
      // image_cropper često ukloni DateTimeOriginal, pa bi inače backend mogao uzeti "sad").
      String dateRaw = '';
      if (sourceFile.path != uploadFile.path) {
        dateRaw = _readCaptureDateRaw(sourceExif);
      }
      if (dateRaw.isEmpty) {
        dateRaw = _readCaptureDateRaw(uploadExif);
      }

      // GPS: prvo iz obrađene slike; ako nedostaje, iz izvornika.
      var latRaw = _readTagPrintable(uploadExif, 'GPS GPSLatitude');
      var latRef = _readTagPrintable(uploadExif, 'GPS GPSLatitudeRef');
      var lonRaw = _readTagPrintable(uploadExif, 'GPS GPSLongitude');
      var lonRef = _readTagPrintable(uploadExif, 'GPS GPSLongitudeRef');
      if (latRaw.isEmpty || lonRaw.isEmpty) {
        latRaw = _readTagPrintable(sourceExif, 'GPS GPSLatitude');
        latRef = _readTagPrintable(sourceExif, 'GPS GPSLatitudeRef');
        lonRaw = _readTagPrintable(sourceExif, 'GPS GPSLongitude');
        lonRef = _readTagPrintable(sourceExif, 'GPS GPSLongitudeRef');
      }

      final formattedDate =
          dateRaw.isNotEmpty ? _formatExifDateForServer(dateRaw) : null;

      final latitude = latRaw.isEmpty
          ? null
          : _parseGpsCoordinate(latRaw, latRef);
      final longitude = lonRaw.isEmpty
          ? null
          : _parseGpsCoordinate(lonRaw, lonRef);

      if (!mounted) return;
      setState(() {
        _exifDate = formattedDate;
        _exifLatitude = latitude;
        _exifLongitude = longitude;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exifDate = null;
        _exifLatitude = null;
        _exifLongitude = null;
      });
    }
  }

  Future<bool> _cropAndSet(File file) async {
    try {
      final overriddenCrop = widget.cropImageOverride;
      final File? croppedFile;
      if (overriddenCrop != null) {
        croppedFile = await overriddenCrop(file);
      } else {
        final cropped = await _cropper.cropImage(
          sourcePath: file.path,
          // Keep the crop frame fixed to a portrait 9:16 ratio.
          // Users can still resize it, but only proportionally.
          aspectRatio: const CropAspectRatio(ratioX: 9, ratioY: 16),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Uredi sliku',
              toolbarColor: Colors.white,
              toolbarWidgetColor: Colors.black,
              backgroundColor: Colors.black,
              statusBarLight: true,
              // uCrop bottom controls can sit under Android 3-button navigation.
              // Hide them so the crop screen stays usable across devices.
              hideBottomControls: true,
              lockAspectRatio: true,
            ),
          ],
        );
        croppedFile = cropped == null ? null : File(cropped.path);
      }

      if (croppedFile == null) {
        return false;
      }
      final uploadFile = croppedFile;
      await _extractExifFromImage(sourceFile: file, uploadFile: uploadFile);

      if (!mounted) return false;
      setState(() {
        _selectedImage = uploadFile;
      });
      final hasExifDate = _exifDate != null;
      final hasExifGps = _exifLatitude != null && _exifLongitude != null;
      if (hasExifDate || hasExifGps) {
        _setMessage('Slika je spremna. EXIF metadata je ucitana.', StatusType.success);
      } else {
        _setMessage(
          'Slika je spremna, ali EXIF datum/GPS nisu dostupni.',
          StatusType.warning,
        );
      }
      return true;
    } on PlatformException {
      _setMessage('Obrada slike nije uspjela.', StatusType.error);
      return false;
    }
  }

  bool _validateBeforeUpload() {
    if (_selectedCattle == null) {
      _setMessage('Odaberi govedo prije slanja.', StatusType.warning);
      return false;
    }

    if (_selectedImage == null) {
      _setMessage('Odaberi i obradi sliku prije slanja.', StatusType.warning);
      return false;
    }

    if (!_selectedImage!.existsSync()) {
      _setMessage(
        'Odabrana slika vise nije dostupna na uredaju.',
        StatusType.error,
      );
      return false;
    }

    return true;
  }

  void _clearSelectedImageSource() {
    _selectedImageSourceDocumentUri = null;
    _selectedImageSourceName = null;
  }

  void _resetSelectedCattle() {
    _selectedCattle = null;
    _cattleSearchController.clear();
  }

  String _uploadButtonLabel() {
    if (!_uploading) {
      return 'Upload';
    }
    final progress = _uploadProgressPercent;
    if (progress == null) {
      return 'Saljem...';
    }
    return 'Upload ${progress.round()}%';
  }

  Future<bool?> _showDeleteOriginalDialog() {
    final name = _selectedImageSourceName;
    final suffix = name == null || name.trim().isEmpty ? '' : '\n\n$name';

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Obrisati originalnu sliku?'),
          content: Text(
            'Upload je uspjesno zavrsen. Zelite li obrisati originalnu sliku iz SAF foldera / telefona?$suffix',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Zadrzi'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Obrisi'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePostUploadSuccess(UploadResult result) async {
    final sourceUri = _selectedImageSourceDocumentUri;
    final successPrefix =
        'Upload uspjesan: status=${result.status}, slika_id=${result.slikaId ?? '-'}';

    if (sourceUri == null || sourceUri.isEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedImage = null;
        _clearSelectedImageSource();
        _resetSelectedCattle();
      });
      _setMessage(successPrefix, StatusType.success);
      return;
    }

    final shouldDelete = await _showDeleteOriginalDialog();
    if (!mounted) return;

    if (shouldDelete == true) {
      try {
        final deleted = await _safBridge.deleteDocument(documentUri: sourceUri);
        if (!mounted) return;
        setState(() {
          _selectedImage = null;
          _clearSelectedImageSource();
          _resetSelectedCattle();
        });
        if (deleted) {
          _safBridge.removeDocumentFromCache(documentUri: sourceUri);
          _setMessage(
            '$successPrefix. Originalna slika je obrisana.',
            StatusType.success,
          );
        } else {
          _setMessage(
            '$successPrefix. Originalna slika nije obrisana.',
            StatusType.warning,
          );
        }
      } on PlatformException {
        if (!mounted) return;
        setState(() {
          _selectedImage = null;
          _clearSelectedImageSource();
          _resetSelectedCattle();
        });
        _setMessage(
          '$successPrefix. Originalna slika nije obrisana.',
          StatusType.warning,
        );
      }
      return;
    }

    setState(() {
      _selectedImage = null;
      _clearSelectedImageSource();
      _resetSelectedCattle();
    });
    _setMessage('$successPrefix. Originalna slika je zadrzana.', StatusType.success);
  }

  Future<void> _upload() async {
    if (_uploading) return;
    if (!_validateBeforeUpload()) return;

    setState(() {
      _uploading = true;
      _message = null;
      _uploadProgressPercent = null;
    });

    try {
      final result = await widget.repository.uploadCattlePhoto(
        zivotniBroj: _selectedCattle!.zivotniBroj,
        image: _selectedImage!,
        datum: _exifDate,
        latitude: _exifLatitude,
        longitude: _exifLongitude,
        onSendProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _uploadProgressPercent = total > 0
                ? (sent / total * 100).clamp(0, 100).toDouble()
                : null;
          });
        },
      );

      if (!mounted) return;
      await _handlePostUploadSuccess(result);
    } catch (e) {
      _setMessage(
        e.toString().replaceFirst('Exception: ', ''),
        StatusType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgressPercent = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFolder = _folderUri != null && _folderUri!.isNotEmpty;
    final disableImageActions = _uploading || _loadingSafImages;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload slike goveda')),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 16),
        child: ListView(
          padding: screenBodyPadding(context, bottomSpacing: 0),
          children: [
            RawAutocomplete<Cattle>(
              textEditingController: _cattleSearchController,
              focusNode: _cattleSearchFocusNode,
              optionsBuilder: (value) {
                if (_uploading) {
                  return const Iterable<Cattle>.empty();
                }
                final query = value.text;
                return widget.cattle.where((item) => _matchesCattleQuery(item, query));
              },
              displayStringForOption: _cattleOptionLabel,
              onSelected: (value) {
                setState(() {
                  _selectedCattle = value;
                });
                _cattleSearchController.text = _cattleOptionLabel(value);
                _cattleSearchFocusNode.unfocus();
                FocusScope.of(context).unfocus();
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !_uploading,
                  decoration: InputDecoration(
                    labelText: 'Zivotni broj goveda (search)',
                    hintText: 'Unesi 1-4 znamenke, vise od 4 ili ime',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: controller.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              controller.clear();
                              setState(() {
                                _selectedCattle = null;
                              });
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onChanged: (value) {
                    final selected = _selectedCattle;
                    if (selected != null && value != _cattleOptionLabel(selected)) {
                      setState(() {
                        _selectedCattle = null;
                      });
                    } else {
                      setState(() {});
                    }
                  },
                  onFieldSubmitted: (_) => onSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final optionList = options.toList(growable: false);
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: optionList.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Nema rezultata pretrage.'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: optionList.length,
                              itemBuilder: (context, index) {
                                final item = optionList[index];
                                return ListTile(
                                  title: Text(item.zivotniBroj),
                                  subtitle: Text(item.displayName),
                                  onTap: () => onSelected(item),
                                );
                              },
                            ),
                    ),
                  ),
                );
              },
            ),
            if (_selectedCattle == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Odaberi govedo iz rezultata pretrage.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('EXIF metadata'),
              subtitle: Text(
                'Datum: ${_exifDate ?? "Nije dostupan"}\n'
                'GPS: ${(_exifLatitude != null && _exifLongitude != null) ? "${_exifLatitude!.toStringAsFixed(6)}, ${_exifLongitude!.toStringAsFixed(6)}" : "Nije dostupan"}',
              ),
            ),
            const SizedBox(height: 16),
            if (!hasFolder) ...[
              ListTile(
                title: const Text('SAF folder URI'),
                subtitle: Text(_folderUri ?? 'Nije odabran folder'),
                trailing: OutlinedButton(
                  onPressed: _uploading ? null : _selectFolder,
                  child: const Text('Odaberi'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: disableImageActions ? null : _pickFromCamera,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Slikaj'),
                ),
                OutlinedButton(
                  onPressed: disableImageActions ? null : _pickFromSelectedFolder,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loadingSafImages) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        const Text('Ucitavanje...'),
                      ] else ...[
                        const Icon(Icons.folder_open),
                        const SizedBox(width: 8),
                        const Text('Iz SAF foldera'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              )
            else
              const InlineStatusMessage(
                message: 'Nema odabrane slike za upload.',
                type: StatusType.info,
              ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('upload-button'),
                  onPressed: _uploading ? null : _upload,
                  child: Text(_uploadButtonLabel()),
                ),
              ),
            ],
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InlineStatusMessage(
                  message: _message!,
                  type: _messageType,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
