import 'package:flutter/material.dart';

import '../../cattle/data/cattle_repository.dart';
import '../../cattle/presentation/cattle_list_screen.dart';
import '../../farms/data/farms_repository.dart';
import '../../upload/data/upload_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.uploadRepository,
    required this.onLogout,
  });

  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final UploadRepository uploadRepository;
  final Future<void> Function() onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const List<String> _options = <String>[
    'Odaberi opciju',
    'Opcija A',
    'Opcija B',
  ];

  String _selectedOption = _options.first;

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedOption,
            decoration: const InputDecoration(
              labelText: 'Brzi odabir',
            ),
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
          const Text(
            'Dodatne opcije uskoro',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.construction_outlined),
            label: const Text('Opcija uskoro 1'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.construction_outlined),
            label: const Text('Opcija uskoro 2'),
          ),
        ],
      ),
    );
  }
}
