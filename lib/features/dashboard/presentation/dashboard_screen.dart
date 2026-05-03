import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/platform/share_intent_bridge.dart';
import '../../../core/storage/saf_bridge.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/screen_insets.dart';
import '../../cattle/data/cattle_repository.dart';
import '../../cattle/presentation/cattle_list_screen.dart';
import '../../cattle_transfer/data/cattle_transfer_repository.dart';
import '../../cattle_transfer/presentation/cattle_transfer_screen.dart';
import '../../farms/data/farms_repository.dart';
import '../../nedostatak_markica/data/nedostatak_markica_repository.dart';
import '../../nedostatak_markica/presentation/nedostatak_markica_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../upload/data/upload_repository.dart';
import '../../upload/presentation/upload_screen.dart';
import '../../uparivanje_teladi/data/uparivanje_teladi_repository.dart';
import '../../odlasci/data/odlasci_repository.dart';
import '../../odlasci/presentation/odlasci_screen.dart';
import '../../uparivanje_teladi/presentation/uparivanje_teladi_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.cattleTransferRepository,
    required this.uploadRepository,
    required this.uparivanjeTeladiRepository,
    required this.nedostatakMarkicaRepository,
    required this.odlasciRepository,
    required this.onLogout,
    this.storage,
    this.safBridge,
  });

  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final CattleTransferRepository cattleTransferRepository;
  final UploadRepository uploadRepository;
  final UparivanjeTeladiRepository uparivanjeTeladiRepository;
  final NedostatakMarkicaRepository nedostatakMarkicaRepository;
  final OdlasciRepository odlasciRepository;
  final Future<void> Function() onLogout;
  final TokenStorage? storage;
  final SafBridge? safBridge;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_tryConsumeSharedImage());
    });
  }

  Future<void> _tryConsumeSharedImage() async {
    if (!mounted) return;
    final path = await ShareIntentBridge.consumePendingSharePath();
    if (!mounted) return;
    if (path == null || path.isEmpty) return;
    await _openUploadScreen(initialSharedCachePath: path);
  }

  static const String _uploadOption = 'Upload';
  static const String _transferOption = 'Premjestanje';
  static const String _pairingOption = 'Uparivanje teladi';
  static const String _nedostatakOption = 'Nedostatak markica';
  static const String _odlasciOption = 'Odlasci';
  static const List<String> _options = <String>[
    'Odaberi opciju',
    _uploadOption,
    _transferOption,
    _pairingOption,
    _nedostatakOption,
    _odlasciOption,
  ];

  String _selectedOption = _options.first;

  Future<void> _openUploadScreen({String? initialSharedCachePath}) async {
    try {
      final farms = await widget.farmsRepository.fetchFarms();
      if (!mounted) return;
      if (farms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              initialSharedCachePath != null
                  ? 'Nema dostupnih gospodarstava. Podijeli sliku ponovo nakon prijave.'
                  : 'Nema dostupnih gospodarstava za upload.',
            ),
          ),
        );
        return;
      }

      final cattle = await widget.cattleRepository.fetchCattleByFarm(
        farms.first.id,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UploadScreen(
            cattle: cattle,
            repository: widget.uploadRepository,
            initialSharedCachePath: initialSharedCachePath,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initialSharedCachePath != null
                ? 'Neuspjelo ucitavanje podataka. Podijeli sliku ponovo.'
                : 'Neuspjelo ucitavanje podataka za upload.',
          ),
        ),
      );
    }
  }

  void _openTransferScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CattleTransferScreen(
          farmsRepository: widget.farmsRepository,
          cattleRepository: widget.cattleRepository,
          transferRepository: widget.cattleTransferRepository,
        ),
      ),
    );
  }

  void _openUparivanjeTeladiScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UparivanjeTeladiScreen(
          farmsRepository: widget.farmsRepository,
          cattleRepository: widget.cattleRepository,
          transferRepository: widget.cattleTransferRepository,
          uparivanjeRepository: widget.uparivanjeTeladiRepository,
        ),
      ),
    );
  }

  void _openNedostatakMarkicaScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NedostatakMarkicaScreen(
          farmsRepository: widget.farmsRepository,
          cattleRepository: widget.cattleRepository,
          nedostatakRepository: widget.nedostatakMarkicaRepository,
        ),
      ),
    );
  }

  void _openOdlasciScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OdlasciScreen(
          farmsRepository: widget.farmsRepository,
          cattleRepository: widget.cattleRepository,
          odlasciRepository: widget.odlasciRepository,
        ),
      ),
    );
  }

  void _openSettingsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          storage: widget.storage,
          safBridge: widget.safBridge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Početni dashboard'),
        actions: [
          IconButton(
            onPressed: _openSettingsScreen,
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 16),
        child: ListView(
          padding: screenBodyPadding(context, bottomSpacing: 0),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedOption,
              decoration: const InputDecoration(labelText: 'Brzi odabir'),
              items: _options
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedOption = value;
                });
                if (value == _uploadOption) {
                  _openUploadScreen();
                } else if (value == _transferOption) {
                  _openTransferScreen();
                } else if (value == _pairingOption) {
                  _openUparivanjeTeladiScreen();
                } else if (value == _nedostatakOption) {
                  _openNedostatakMarkicaScreen();
                } else if (value == _odlasciOption) {
                  _openOdlasciScreen();
                }
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CattleListScreen(
                      farmsRepository: widget.farmsRepository,
                      cattleRepository: widget.cattleRepository,
                      uploadRepository: widget.uploadRepository,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.pets),
              label: const Text('Goveda'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openUploadScreen,
              icon: const Icon(Icons.add_a_photo),
              label: const Text(_uploadOption),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openTransferScreen,
              icon: const Icon(Icons.swap_horiz),
              label: const Text(_transferOption),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openUparivanjeTeladiScreen,
              icon: const Icon(Icons.child_care_outlined),
              label: const Text(_pairingOption),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openNedostatakMarkicaScreen,
              icon: const Icon(Icons.label_off_outlined),
              label: const Text(_nedostatakOption),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openOdlasciScreen,
              icon: const Icon(Icons.exit_to_app_outlined),
              label: const Text(_odlasciOption),
            ),
          ],
        ),
      ),
    );
  }
}
