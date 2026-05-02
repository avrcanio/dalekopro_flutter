import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/screen_insets.dart';
import '../../cattle_transfer/data/cattle_transfer_repository.dart';
import '../../cattle_transfer/models/holding.dart';
import '../../farms/data/farms_repository.dart';
import '../../farms/models/farm.dart';
import '../data/uparivanje_teladi_repository.dart';
import '../models/uparivanje_telad.dart';
import 'uparivanje_telad_form_screen.dart';

class UparivanjeTeladiScreen extends StatefulWidget {
  const UparivanjeTeladiScreen({
    super.key,
    required this.farmsRepository,
    required this.transferRepository,
    required this.uparivanjeRepository,
  });

  final FarmsRepository farmsRepository;
  final CattleTransferRepository transferRepository;
  final UparivanjeTeladiRepository uparivanjeRepository;

  @override
  State<UparivanjeTeladiScreen> createState() => _UparivanjeTeladiScreenState();
}

class _UparivanjeTeladiScreenState extends State<UparivanjeTeladiScreen> {
  bool _loading = true;
  String? _error;
  List<Farm> _farms = const [];
  Farm? _activeFarm;
  List<Holding> _holdings = const [];
  List<UparivanjeTelad> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final farms = await widget.farmsRepository.fetchFarms();
      final farm = farms.isNotEmpty ? farms.first : null;
      final holdings = farm == null
          ? const <Holding>[]
          : await widget.transferRepository.fetchHoldings(farm.id);
      final items = farm == null
          ? const <UparivanjeTelad>[]
          : await widget.uparivanjeRepository.fetchList(farm.id);
      if (!mounted) return;
      setState(() {
        _farms = farms;
        _activeFarm = farm;
        _holdings = holdings;
        _items = items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Neuspjelo učitavanje podataka za uparivanje teladi.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
      final holdings = await widget.transferRepository.fetchHoldings(farm.id);
      final items = await widget.uparivanjeRepository.fetchList(farm.id);
      if (!mounted) return;
      setState(() {
        _holdings = holdings;
        _items = items;
      });
    } catch (_) {
      if (!mounted) return;
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
      final items = await widget.uparivanjeRepository.fetchList(farm.id);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Osvježavanje liste nije uspjelo.')),
      );
    }
  }

  String _posjedLabel(UparivanjeTelad e) {
    if (e.posjedDisplay.isNotEmpty) {
      return e.posjedDisplay;
    }
    for (final h in _holdings) {
      if (h.id == e.posjedVezaId) {
        return h.label;
      }
    }
    return 'Posjed #${e.posjedVezaId}';
  }

  String _datumStr(UparivanjeTelad e) {
    final d = e.datumTelenja;
    if (d == null) {
      return '—';
    }
    return DateFormat.yMMMd('hr').format(d);
  }

  Future<void> _openForm({UparivanjeTelad? existing}) async {
    final farm = _activeFarm;
    if (farm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema odabranog gospodarstva.')),
      );
      return;
    }
    if (_holdings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nema posjeda na gospodarstvu. Dodaj posjed u sustavu prije uparivanja.',
          ),
        ),
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UparivanjeTeladFormScreen(
          farmId: farm.id,
          farmLabel: farm.label,
          holdings: _holdings,
          repository: widget.uparivanjeRepository,
          existing: existing,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uparivanje teladi')),
      floatingActionButton: _activeFarm == null || _holdings.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _loading ? null : () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _farms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _farms.isEmpty) {
      return Center(
        child: Padding(
          padding: screenBodyPadding(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadInitial,
                child: const Text('Pokušaj ponovno'),
              ),
            ],
          ),
        ),
      );
    }

    if (_farms.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: screenBodyPadding(context),
          child: const Text('Nema dostupnih gospodarstava.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_farms.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<Farm>(
              key: ValueKey<int?>(_activeFarm?.id),
              initialValue: _activeFarm,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Gospodarstvo',
                border: OutlineInputBorder(),
              ),
              items: _farms
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Text(
                        f.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _loading ? null : _selectFarm,
            ),
          ),
        if (_activeFarm != null && _holdings.isEmpty && !_loading)
          Padding(
            padding: screenBodyPadding(context),
            child: Text(
              'Na gospodarstvu "${_activeFarm!.label}" nema posjeda. '
              'Uparivanje teladi zahtijeva odabir posjeda.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: _buildListContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    if (_loading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: screenBodyPadding(context),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_items.isEmpty &&
        !_loading &&
        _error == null &&
        _holdings.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: screenBodyPadding(context),
        children: const [
          SizedBox(height: 48),
          Text(
            'Nema zapisa uparivanja. Dodaj novo telad gumbom Novo.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: screenBodyPadding(context, top: 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final e = _items[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.child_care_outlined),
            ),
            title: Text(
              e.zivotniBroj,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                _posjedLabel(e),
                e.spolZaPrikaz,
                _datumStr(e),
                if (e.majkaDisplay.isNotEmpty) 'Majka: ${e.majkaDisplay}',
                if (e.otacDisplay.isNotEmpty) 'Otac: ${e.otacDisplay}',
              ].join('\n'),
              maxLines: 8,
            ),
            isThreeLine: true,
            onTap: _loading ? null : () => _openForm(existing: e),
          ),
        );
      },
    );
  }
}
