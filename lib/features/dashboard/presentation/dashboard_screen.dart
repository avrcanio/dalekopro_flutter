import 'package:flutter/material.dart';

import '../../../core/widgets/screen_insets.dart';
import '../../cattle/data/cattle_repository.dart';
import '../../cattle/presentation/cattle_list_screen.dart';
import '../../cattle_transfer/data/cattle_transfer_repository.dart';
import '../../cattle_transfer/presentation/cattle_transfer_screen.dart';
import '../../farms/data/farms_repository.dart';
import '../../upload/data/upload_repository.dart';
import '../../upload/presentation/upload_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.cattleTransferRepository,
    required this.uploadRepository,
    required this.onLogout,
  });

  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final CattleTransferRepository cattleTransferRepository;
  final UploadRepository uploadRepository;
  final Future<void> Function() onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _uploadOption = 'Upload';
  static const String _transferOption = 'Premjestanje';
  static const List<String> _options = <String>[
    'Odaberi opciju',
    _uploadOption,
    _transferOption,
  ];

  String _selectedOption = _options.first;

  Future<void> _openUploadScreen() async {
    try {
      final farms = await widget.farmsRepository.fetchFarms();
      if (!mounted) return;
      if (farms.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nema dostupnih gospodarstava za upload.'),
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
          builder: (_) =>
              UploadScreen(cattle: cattle, repository: widget.uploadRepository),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Neuspjelo ucitavanje podataka za upload.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocetni dashboard'),
        actions: [
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
          ],
        ),
      ),
    );
  }
}
