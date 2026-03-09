import 'package:flutter/material.dart';

import '../../farms/data/farms_repository.dart';
import '../../farms/models/farm.dart';
import '../../upload/data/upload_repository.dart';
import '../../upload/presentation/upload_screen.dart';
import '../data/cattle_repository.dart';
import '../models/cattle.dart';

class CattleDetailScreen extends StatelessWidget {
  const CattleDetailScreen({
    super.key,
    required this.cattle,
    required this.allCattle,
    required this.uploadRepository,
  });

  final Cattle cattle;
  final List<Cattle> allCattle;
  final UploadRepository uploadRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cattle.ime.isEmpty ? cattle.zivotniBroj : cattle.ime),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Zivotni broj: ${cattle.zivotniBroj}'),
          Text('Ime: ${cattle.ime}'),
          Text('Spol: ${cattle.spol}'),
          Text('Datum telenja: ${cattle.datumTelenja}'),
          const SizedBox(height: 12),
          const Text('Potomci:', style: TextStyle(fontWeight: FontWeight.bold)),
          if (cattle.potomci.isEmpty)
            const Text('Nema dostupnih potomaka')
          else
            ...cattle.potomci.map(Text.new),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UploadScreen(
                    cattle: allCattle,
                    repository: uploadRepository,
                  ),
                ),
              );
            },
            label: const Text('Dodaj i uploadaj sliku'),
          ),
        ],
      ),
    );
  }
}

class CattleListScreen extends StatefulWidget {
  const CattleListScreen({
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
  State<CattleListScreen> createState() => _CattleListScreenState();
}

class _CattleListScreenState extends State<CattleListScreen> {
  bool _loading = true;
  String? _error;
  List<Farm> _farms = const [];
  Farm? _activeFarm;
  List<Cattle> _cattle = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final farms = await widget.farmsRepository.fetchFarms();
      final farm = farms.isNotEmpty ? farms.first : null;
      final cattle = farm == null
          ? <Cattle>[]
          : await widget.cattleRepository.fetchCattleByFarm(farm.id);

      if (!mounted) return;
      setState(() {
        _farms = farms;
        _activeFarm = farm;
        _cattle = cattle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Neuspjelo ucitavanje podataka.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectFarm(Farm? farm) async {
    if (farm == null) return;
    setState(() {
      _loading = true;
      _activeFarm = farm;
      _error = null;
    });

    try {
      final cattle = await widget.cattleRepository.fetchCattleByFarm(farm.id);
      if (!mounted) return;
      setState(() {
        _cattle = cattle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Neuspjelo ucitavanje goveda za gospodarstvo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goveda'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_farms.isNotEmpty)
              DropdownButtonFormField<Farm>(
                initialValue: _activeFarm,
                decoration: const InputDecoration(
                  labelText: 'Aktivno gospodarstvo',
                ),
                items: _farms
                    .map(
                      (farm) => DropdownMenuItem(
                        value: farm,
                        child: Text(farm.label),
                      ),
                    )
                    .toList(),
                onChanged: _loading ? null : _selectFarm,
              ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_cattle.isEmpty)
              const Text('Nema aktivnih goveda za prikaz.')
            else
              ..._cattle.map(
                (item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.pets),
                    title: Text(item.ime.isEmpty ? item.zivotniBroj : item.ime),
                    subtitle: Text(item.zivotniBroj),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CattleDetailScreen(
                            cattle: item,
                            allCattle: _cattle,
                            uploadRepository: widget.uploadRepository,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cattle.isEmpty
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UploadScreen(
                      cattle: _cattle,
                      repository: widget.uploadRepository,
                    ),
                  ),
                );
              },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Upload'),
      ),
    );
  }
}
