import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/screen_insets.dart';
import '../../cattle/zivotni_broj_digits.dart';
import '../../cattle/data/cattle_repository.dart';
import '../../farms/data/farms_repository.dart';
import '../../farms/models/farm.dart';
import '../data/odlasci_repository.dart';
import '../models/odlazak_models.dart';
import 'odlazak_detail_screen.dart';
import 'odlazak_wizard_screen.dart';

class OdlasciScreen extends StatefulWidget {
  const OdlasciScreen({
    super.key,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.odlasciRepository,
  });

  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final OdlasciRepository odlasciRepository;

  @override
  State<OdlasciScreen> createState() => _OdlasciScreenState();
}

const List<int> _razlogGroupOrder = <int>[
  RazlogOdlaska.naDrugoGospodarstvo,
  RazlogOdlaska.klaonica,
  RazlogOdlaska.kradjaGubitak,
  RazlogOdlaska.uginuce,
];

class _OdlasciScreenState extends State<OdlasciScreen> {
  bool _loading = true;
  String? _error;
  List<Farm> _farms = const [];
  Farm? _activeFarm;
  List<OdlazakRecord> _items = const [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OdlazakRecord> get _filteredItems {
    final q = _searchController.text;
    if (q.trim().isEmpty) {
      return _items;
    }
    return _items
        .where(
          (o) => o.matchesZivotniBrojQuery(
            (zb) => matchesZivotniBrojSearchQuery(zb, q),
          ),
        )
        .toList();
  }

  Map<int, List<OdlazakRecord>> get _grouped {
    final m = <int, List<OdlazakRecord>>{};
    for (final r in _razlogGroupOrder) {
      m[r] = [];
    }
    for (final o in _filteredItems) {
      m.putIfAbsent(o.razlog, () => []).add(o);
    }
    for (final list in m.values) {
      list.sort((a, b) {
        final c = b.datumOdlaska.compareTo(a.datumOdlaska);
        if (c != 0) {
          return c;
        }
        return b.id.compareTo(a.id);
      });
    }
    return m;
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final farms = await widget.farmsRepository.fetchFarms();
      final farm = farms.isNotEmpty ? farms.first : null;
      final items = farm == null
          ? const <OdlazakRecord>[]
          : await widget.odlasciRepository.fetchOdlasci(farm.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _farms = farms;
        _activeFarm = farm;
        _items = items;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Neuspjelo učitavanje odlazaka.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectFarm(Farm? farm) async {
    if (farm == null) {
      return;
    }
    setState(() {
      _loading = true;
      _activeFarm = farm;
      _error = null;
    });
    try {
      final items = await widget.odlasciRepository.fetchOdlasci(farm.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Neuspjelo učitavanje za odabrano gospodarstvo.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    final farm = _activeFarm;
    if (farm == null) {
      return;
    }
    try {
      final items = await widget.odlasciRepository.fetchOdlasci(farm.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Osvježavanje liste nije uspjelo.')),
      );
    }
  }

  String _formatDatum(String raw) {
    if (raw.isEmpty) {
      return '—';
    }
    try {
      final d = DateTime.parse(raw);
      return DateFormat.yMMMd('hr').format(d);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _openWizard() async {
    final farm = _activeFarm;
    if (farm == null) {
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OdlazakWizardScreen(
          farm: farm,
          cattleRepository: widget.cattleRepository,
          odlasciRepository: widget.odlasciRepository,
        ),
      ),
    );
    if (created == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Odlasci'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _activeFarm == null || _loading ? null : _openWizard,
        icon: const Icon(Icons.add),
        label: const Text('Novi odlazak'),
      ),
      body: SafeArea(
        child: _loading && _activeFarm == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: screenBodyPadding(context),
                  children: [
                    if (_farms.length > 1)
                      DropdownButtonFormField<Farm>(
                        decoration: const InputDecoration(
                          labelText: 'Gospodarstvo',
                        ),
                        value: _activeFarm,
                        items: _farms
                            .map(
                              (f) => DropdownMenuItem<Farm>(
                                value: f,
                                child: Text(f.label),
                              ),
                            )
                            .toList(),
                        onChanged: _loading ? null : _selectFarm,
                      ),
                    if (_farms.length > 1) const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Pretraga životnog broja',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_activeFarm == null)
                      const Text('Nema dostupnih gospodarstava.')
                    else if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ..._buildGroupedSections(),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _buildGroupedSections() {
    final grouped = _grouped;
    final widgets = <Widget>[];
    final extraKeys = grouped.keys
        .where((k) => !_razlogGroupOrder.contains(k))
        .toList()
      ..sort();
    final order = <int>[..._razlogGroupOrder, ...extraKeys];
    var first = true;
    for (final razlog in order) {
      final list = grouped[razlog];
      if (list == null || list.isEmpty) {
        continue;
      }
      if (!first) {
        widgets.add(const SizedBox(height: 20));
      }
      first = false;
      final label = list.first.razlogLabel.isNotEmpty
          ? list.first.razlogLabel
          : RazlogOdlaska.labelHr(razlog);
      widgets.add(
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      for (final o in list) {
        widgets.add(
          Card(
            child: ListTile(
              title: Text(o.serijskiBroj),
              subtitle: Text(
                '${_formatDatum(o.datumOdlaska)} · ${o.govedaSummary()}',
              ),
              isThreeLine: false,
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => OdlazakDetailScreen(record: o),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
    if (widgets.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nema odlazaka za prikaz (uz ovaj filter).'),
        ),
      ];
    }
    return widgets;
  }
}
