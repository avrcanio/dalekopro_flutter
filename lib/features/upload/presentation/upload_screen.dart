import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/saf_bridge.dart';
import '../../../core/storage/token_storage.dart';
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
  });

  final List<Cattle> cattle;
  final UploadRepository repository;
  final TokenStorage? storage;
  final SafBridge? safBridge;
  final ImagePicker? imagePicker;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final TokenStorage _storage;
  late final SafBridge _safBridge;
  late final ImagePicker _picker;
  final ImageCropper _cropper = ImageCropper();

  Cattle? _selectedCattle;
  File? _selectedImage;
  bool _uploading = false;
  String? _message;
  String? _folderUri;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? const TokenStorage();
    _safBridge = widget.safBridge ?? const SafBridge();
    _picker = widget.imagePicker ?? ImagePicker();

    if (widget.cattle.isNotEmpty) {
      _selectedCattle = widget.cattle.first;
    }
    _loadFolderUri();
  }

  Future<void> _loadFolderUri() async {
    final uri = await _storage.readFolderUri();
    if (!mounted) return;
    setState(() {
      _folderUri = uri;
    });
  }

  Future<void> _selectFolder() async {
    final uri = await _safBridge.selectDocumentTree(initialTreeUri: _folderUri);
    if (uri == null || uri.isEmpty) return;

    await _storage.saveFolderUri(uri);
    if (!mounted) return;
    setState(() {
      _folderUri = uri;
      _message = 'SAF folder postavljen.';
    });
  }

  Future<void> _pickFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    if (xFile == null) return;
    await _cropAndSet(File(xFile.path));
  }

  Future<void> _pickFromSelectedFolder() async {
    if (_folderUri == null || _folderUri!.isEmpty) {
      setState(() {
        _message = 'Prvo odaberi SAF folder slika.';
      });
      return;
    }

    final filePath = await _safBridge.pickImageFromTree(treeUri: _folderUri!);
    if (filePath == null || filePath.isEmpty) return;
    await _cropAndSet(File(filePath));
  }

  Future<void> _cropAndSet(File file) async {
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

    if (cropped == null) return;
    if (!mounted) return;
    setState(() {
      _selectedImage = File(cropped.path);
      _message = 'Slika je spremna za upload.';
    });
  }

  Future<(double?, double?)> _resolveLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return (null, null);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return (null, null);
    }

    final position = await Geolocator.getCurrentPosition();
    return (position.latitude, position.longitude);
  }

  Future<void> _upload() async {
    if (_selectedCattle == null) {
      setState(() {
        _message = 'Odaberi govedo prije slanja.';
      });
      return;
    }

    if (_selectedImage == null) {
      setState(() {
        _message = 'Odaberi i obradi sliku prije slanja.';
      });
      return;
    }

    setState(() {
      _uploading = true;
      _message = null;
    });

    try {
      final (latitude, longitude) = await _resolveLocation();
      final datum = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final result = await widget.repository.uploadCattlePhoto(
        zivotniBroj: _selectedCattle!.zivotniBroj,
        image: _selectedImage!,
        datum: datum,
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;
      setState(() {
        _message =
            'Upload uspjesan: status=${result.status}, slika_id=${result.slikaId ?? '-'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceFirst('Exception: ', '');
      });
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
          DropdownButtonFormField<Cattle>(
            initialValue: _selectedCattle,
            decoration: const InputDecoration(labelText: 'Zivotni broj goveda'),
            items: widget.cattle
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text('${item.zivotniBroj} - ${item.ime}'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedCattle = value),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('SAF folder URI'),
            subtitle: Text(_folderUri ?? 'Nije odabran folder'),
            trailing: OutlinedButton(
              onPressed: _selectFolder,
              child: const Text('Odaberi'),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _pickFromCamera,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Slikaj'),
              ),
              OutlinedButton.icon(
                onPressed: _pickFromSelectedFolder,
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
              child: Text(_message!),
            ),
        ],
      ),
    );
  }
}
