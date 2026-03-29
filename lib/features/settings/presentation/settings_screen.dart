import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/saf_bridge.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/screen_insets.dart';
import '../../../core/widgets/status_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.storage,
    this.safBridge,
  });

  final TokenStorage? storage;
  final SafBridge? safBridge;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TokenStorage _storage;
  late final SafBridge _safBridge;

  String? _folderUri;
  String? _message;
  StatusType _messageType = StatusType.info;
  bool _loading = true;
  bool _savingFolder = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? const TokenStorage();
    _safBridge = widget.safBridge ?? const SafBridge();
    _loadFolderUri();
  }

  Future<void> _loadFolderUri() async {
    final uri = await _storage.readFolderUri();
    if (!mounted) return;
    setState(() {
      _folderUri = uri;
      _loading = false;
    });
  }

  void _setMessage(String message, StatusType type) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageType = type;
    });
  }

  Future<void> _selectFolder() async {
    if (_savingFolder) return;

    setState(() {
      _savingFolder = true;
      _message = null;
    });

    try {
      final uri = await _safBridge.selectDocumentTree(initialTreeUri: _folderUri);
      if (uri == null || uri.isEmpty) {
        _setMessage('Odabir SAF foldera je otkazan.', StatusType.info);
        return;
      }

      await _storage.saveFolderUri(uri);
      if (!mounted) return;
      setState(() {
        _folderUri = uri;
      });
      _setMessage('SAF folder je uspjesno spremljen.', StatusType.success);
    } on PlatformException {
      _setMessage(
        'Nije moguce pristupiti odabranom SAF folderu.',
        StatusType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingFolder = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFolder = _folderUri != null && _folderUri!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: screenBodyPadding(context, bottomSpacing: 0),
                children: [
                  Text(
                    'Postavke aplikacije',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SAF folder',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasFolder ? _folderUri! : 'Nije odabran SAF folder.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _savingFolder ? null : _selectFolder,
                            child: Text(
                              hasFolder
                                  ? 'Promijeni SAF folder'
                                  : 'Odaberi SAF folder',
                            ),
                          ),
                        ],
                      ),
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
      ),
    );
  }
}
