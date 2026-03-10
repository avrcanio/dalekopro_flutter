import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/saf_bridge.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../cattle/models/cattle.dart';
import '../data/upload_repository.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    required this.cattle,
    required this.repository,
    this.storage,
    this.safBridge,
    this.imagePicker,
    this.initialImageForTest,
  });

  final List<Cattle> cattle;
  final UploadRepository repository;
  final TokenStorage? storage;
  final SafBridge? safBridge;
  final ImagePicker? imagePicker;
  final File? initialImageForTest;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final TokenStorage _storage;
  late final SafBridge _safBridge;
  late final ImagePicker _picker;
  final ImageCropper _cropper = ImageCropper();
  final DateFormat _exifDateFormat = DateFormat('yyyy:MM:dd HH:mm:ss');
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

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? const TokenStorage();
    _safBridge = widget.safBridge ?? const SafBridge();
    _picker = widget.imagePicker ?? ImagePicker();
    _cattleSearchController = TextEditingController();
    _cattleSearchFocusNode = FocusNode();

    if (widget.cattle.isNotEmpty) {
      _selectedCattle = widget.cattle.first;
      _cattleSearchController.text = _cattleOptionLabel(_selectedCattle!);
    }
    _selectedImage = widget.initialImageForTest;
    _loadFolderUri();
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
      await _cropAndSet(File(xFile.path));
    } on PlatformException {
      _setMessage('Kamera nije dostupna ili nema dozvolu.', StatusType.error);
    }
  }

  Future<void> _pickFromSelectedFolder() async {
    if (_folderUri == null || _folderUri!.isEmpty) {
      _setMessage('Prvo odaberi SAF folder slika.', StatusType.warning);
      return;
    }

    try {
      final filePath = await _safBridge.pickImageFromTree(treeUri: _folderUri!);
      if (filePath == null || filePath.isEmpty) {
        _setMessage('Odabir slike iz foldera je otkazan.', StatusType.info);
        return;
      }
      await _cropAndSet(File(filePath));
    } on PlatformException {
      _setMessage(
        'Nije moguce procitati sliku iz odabranog foldera.',
        StatusType.error,
      );
    }
  }

  static String _readTagPrintable(Map<String, IfdTag> exif, String key) {
    final tag = exif[key];
    if (tag == null) return '';
    return tag.printable.toString().trim();
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
    try {
      var exif = await _readExif(uploadFile);
      var dateRaw =
          _readTagPrintable(exif, 'EXIF DateTimeOriginal').isNotEmpty
          ? _readTagPrintable(exif, 'EXIF DateTimeOriginal')
          : _readTagPrintable(exif, 'Image DateTime');

      var latRaw = _readTagPrintable(exif, 'GPS GPSLatitude');
      var latRef = _readTagPrintable(exif, 'GPS GPSLatitudeRef');
      var lonRaw = _readTagPrintable(exif, 'GPS GPSLongitude');
      var lonRef = _readTagPrintable(exif, 'GPS GPSLongitudeRef');

      // If crop removed EXIF, fallback to the original file metadata.
      if ((dateRaw.isEmpty || latRaw.isEmpty || lonRaw.isEmpty) &&
          sourceFile.path != uploadFile.path) {
        exif = await _readExif(sourceFile);
        dateRaw =
            _readTagPrintable(exif, 'EXIF DateTimeOriginal').isNotEmpty
            ? _readTagPrintable(exif, 'EXIF DateTimeOriginal')
            : _readTagPrintable(exif, 'Image DateTime');
        latRaw = _readTagPrintable(exif, 'GPS GPSLatitude');
        latRef = _readTagPrintable(exif, 'GPS GPSLatitudeRef');
        lonRaw = _readTagPrintable(exif, 'GPS GPSLongitude');
        lonRef = _readTagPrintable(exif, 'GPS GPSLongitudeRef');
      }

      String? formattedDate;
      if (dateRaw.isNotEmpty) {
        try {
          final parsed = _exifDateFormat.parseStrict(dateRaw);
          formattedDate = _serverDateFormat.format(parsed);
        } catch (_) {
          formattedDate = null;
        }
      }

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

  Future<void> _cropAndSet(File file) async {
    try {
      final cropped = await _cropper.cropImage(
        sourcePath: file.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Uredi sliku',
            hideBottomControls: false,
            lockAspectRatio: false,
          ),
        ],
      );

      if (cropped == null) {
        _setMessage('Crop je otkazan.', StatusType.info);
        return;
      }
      if (!mounted) return;
      final uploadFile = File(cropped.path);
      await _extractExifFromImage(sourceFile: file, uploadFile: uploadFile);

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
    } on PlatformException {
      _setMessage('Obrada slike nije uspjela.', StatusType.error);
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

  Future<void> _upload() async {
    if (_uploading) return;
    if (!_validateBeforeUpload()) return;

    setState(() {
      _uploading = true;
      _message = null;
    });

    try {
      final result = await widget.repository.uploadCattlePhoto(
        zivotniBroj: _selectedCattle!.zivotniBroj,
        image: _selectedImage!,
        datum: _exifDate,
        latitude: _exifLatitude,
        longitude: _exifLongitude,
      );

      if (!mounted) return;
      setState(() {
        _selectedImage = null;
      });
      _setMessage(
        'Upload uspjesan: status=${result.status}, slika_id=${result.slikaId ?? '-'}',
        StatusType.success,
      );
    } catch (e) {
      _setMessage(
        e.toString().replaceFirst('Exception: ', ''),
        StatusType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload slike goveda')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          ListTile(
            title: const Text('SAF folder URI'),
            subtitle: Text(_folderUri ?? 'Nije odabran folder'),
            trailing: OutlinedButton(
              onPressed: _uploading ? null : _selectFolder,
              child: const Text('Odaberi'),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _uploading ? null : _pickFromCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Slikaj'),
              ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickFromSelectedFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Iz SAF foldera'),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload'),
            ),
          ),
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
    );
  }
}
