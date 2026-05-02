import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/screen_insets.dart';
import '../../cattle/cattle_gallery_urls.dart';
import '../../cattle/data/cattle_repository.dart';
import '../../cattle/models/cattle.dart';
import '../../cattle/presentation/cattle_gallery_fullscreen_dialog.dart';
import '../../cattle/presentation/cattle_thumbnail.dart';
import '../../cattle/zivotni_broj_digits.dart';
import '../../cattle/zivotni_broj_highlight_title.dart';
import '../../farms/data/farms_repository.dart';
import '../../farms/models/farm.dart';
import '../data/nedostatak_markica_repository.dart';
import '../models/nedostatak_markica_record.dart';
import 'nedostatak_markica_form_screen.dart';

class NedostatakMarkicaScreen extends StatefulWidget {
  const NedostatakMarkicaScreen({
    super.key,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.nedostatakRepository,
  });

  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final NedostatakMarkicaRepository nedostatakRepository;

  @override
  State<NedostatakMarkicaScreen> createState() =>
      _NedostatakMarkicaScreenState();
}

/// Redoslijed grupa na listi (backend: PR, NA, ZA, OT, MK).
const List<String> _kStatusGroupOrder = <String>['PR', 'NA', 'ZA', 'MK', 'OT'];

class _NedostatakMarkicaScreenState extends State<NedostatakMarkicaScreen> {
  bool _loading = true;
  String? _error;
  List<Farm> _farms = const [];
  Farm? _activeFarm;
  List<Cattle> _farmCattle = const [];
  List<NedostatakMarkicaRecord> _items = const [];
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

  Map<int, Cattle> get _cattleByGovedoId {
    final m = <int, Cattle>{};
    for (final c in _farmCattle) {
      if (c.id > 0) {
        m[c.id] = c;
      }
    }
    return m;
  }

  Set<int> get _govedoIds =>
      _farmCattle.map((c) => c.id).where((id) => id > 0).toSet();

  List<NedostatakMarkicaRecord> get _filteredItems {
    final q = _searchController.text.replaceAll(RegExp(r'\D'), '');
    if (q.isEmpty) {
      return _items;
    }
    return _items
        .where(
          (e) => matchesZivotniBrojDigitsQuery(e.govedo.zivotniBroj, q),
        )
        .toList();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final farms = await widget.farmsRepository.fetchFarms();
      final farm = farms.isNotEmpty ? farms.first : null;
      final cattle = farm == null
          ? const <Cattle>[]
          : await widget.cattleRepository.fetchCattleByFarm(farm.id);
      final ids = cattle.map((c) => c.id).where((id) => id > 0).toSet();
      final items = ids.isEmpty
          ? const <NedostatakMarkicaRecord>[]
          : await widget.nedostatakRepository.fetchAllForFarmCattleIds(ids);
      if (!mounted) return;
      setState(() {
        _farms = farms;
        _activeFarm = farm;
        _farmCattle = cattle;
        _items = items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Neuspjelo učitavanje nedostataka markica.';
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
      final cattle = await widget.cattleRepository.fetchCattleByFarm(farm.id);
      final ids = cattle.map((c) => c.id).where((id) => id > 0).toSet();
      final items = ids.isEmpty
          ? const <NedostatakMarkicaRecord>[]
          : await widget.nedostatakRepository.fetchAllForFarmCattleIds(ids);
      if (!mounted) return;
      setState(() {
        _farmCattle = cattle;
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
      final cattle = await widget.cattleRepository.fetchCattleByFarm(farm.id);
      final ids = cattle.map((c) => c.id).where((id) => id > 0).toSet();
      final items = ids.isEmpty
          ? const <NedostatakMarkicaRecord>[]
          : await widget.nedostatakRepository.fetchAllForFarmCattleIds(ids);
      if (!mounted) return;
      setState(() {
        _farmCattle = cattle;
        _items = items;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Osvježavanje liste nije uspjelo.')),
      );
    }
  }

  String _datumStr(NedostatakMarkicaRecord e) {
    final d = e.datumPrijave;
    if (d == null) {
      return '—';
    }
    return DateFormat.yMMMd('hr').format(d);
  }

  String _brojMarkicaLabel(NedostatakMarkicaRecord e) {
    if (e.brojNedostajucihDisplay.isNotEmpty) {
      return e.brojNedostajucihDisplay;
    }
    if (e.brojNedostajucih == 1) {
      return 'Jedna markica';
    }
    if (e.brojNedostajucih == 2) {
      return 'Dvije markice';
    }
    return 'Broj: ${e.brojNedostajucih}';
  }

  /// Svijetla pozadina kartice po statusu; ostalo neutralno.
  Color _cardColorForStatus(String status) {
    switch (status) {
      case 'PR':
        return const Color(0xFFFFEBEE);
      case 'NA':
        return const Color(0xFFFFFDE7);
      case 'ZA':
        return const Color(0xFFE8F5E9);
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  Map<String, List<NedostatakMarkicaRecord>> _groupByStatus(
    List<NedostatakMarkicaRecord> items,
  ) {
    final map = <String, List<NedostatakMarkicaRecord>>{};
    for (final e in items) {
      final key = e.status.isNotEmpty ? e.status : '?';
      map.putIfAbsent(key, () => <NedostatakMarkicaRecord>[]).add(e);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        final da = a.datumPrijave ?? a.createdAt;
        final db = b.datumPrijave ?? b.createdAt;
        if (da != null && db != null) {
          final c = db.compareTo(da);
          if (c != 0) {
            return c;
          }
        }
        final ca = a.createdAt;
        final cb = b.createdAt;
        if (ca != null && cb != null) {
          return cb.compareTo(ca);
        }
        return b.id.compareTo(a.id);
      });
    }
    return map;
  }

  List<String> _sortedStatusKeys(Map<String, List<NedostatakMarkicaRecord>> map) {
    final keys = map.keys.toList();
    keys.sort((a, b) {
      final ia = _kStatusGroupOrder.indexOf(a);
      final ib = _kStatusGroupOrder.indexOf(b);
      if (ia < 0 && ib < 0) {
        return a.compareTo(b);
      }
      if (ia < 0) {
        return 1;
      }
      if (ib < 0) {
        return -1;
      }
      return ia.compareTo(ib);
    });
    return keys;
  }

  String _groupTitle(String statusKey, List<NedostatakMarkicaRecord> group) {
    if (group.isEmpty) {
      return statusKey;
    }
    final d = group.first.statusDisplay.trim();
    if (d.isNotEmpty) {
      return d;
    }
    return statusKey;
  }

  Future<void> _openForm() async {
    final farm = _activeFarm;
    if (farm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema odabranog gospodarstva.')),
      );
      return;
    }
    if (_farmCattle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema goveda na gospodarstvu za novu prijavu.'),
        ),
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NedostatakMarkicaFormScreen(
          farmId: farm.id,
          farmLabel: farm.label,
          farmCattle: _farmCattle,
          repository: widget.nedostatakRepository,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _refresh();
    }
  }

  void _onCardLongPress(NedostatakMarkicaRecord e) {
    final cow = _cattleByGovedoId[e.govedo.id];
    if (cow == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema učitanih podataka o slikama za ovo govedo.'),
        ),
      );
      return;
    }
    final urls = cattleGalleryImageUrls(cow);
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema dostupnih slika za pregled.')),
      );
      return;
    }
    showCattleGalleryFullscreenDialog(
      context,
      urls: urls,
      subtitle: e.govedo.zivotniBroj,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nedostatak markica')),
      floatingActionButton: _activeFarm == null || _farmCattle.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _loading ? null : _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            ),
      body: SafeArea(child: _buildBody()),
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
        if (_activeFarm != null && _govedoIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pretraži po zadnjim znamenkama životnog broja',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
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
    if (_loading && _items.isEmpty && _activeFarm != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: screenBodyPadding(context),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_activeFarm != null &&
        _farmCattle.isNotEmpty &&
        _items.isEmpty &&
        !_loading &&
        _error == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: screenBodyPadding(context),
        children: const [
          SizedBox(height: 48),
          Text(
            'Nema prijava nedostatka markica za ovo gospodarstvo. '
            'Dodaj novu gumbom Novo.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_activeFarm != null && _farmCattle.isEmpty && !_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: screenBodyPadding(context),
        children: const [
          SizedBox(height: 48),
          Text(
            'Nema goveda na gospodarstvu.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final visible = _filteredItems;
    if (visible.isEmpty && _items.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: screenBodyPadding(context),
        children: const [
          SizedBox(height: 48),
          Text(
            'Nema rezultata za unesene znamenke.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final byCow = _cattleByGovedoId;
    final grouped = _groupByStatus(visible);
    final statusKeys = _sortedStatusKeys(grouped);
    final children = <Widget>[];

    for (final key in statusKeys) {
      final group = grouped[key]!;
      final title = _groupTitle(key, group);
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                '${group.length}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      );

      for (final e in group) {
        final cow = byCow[e.govedo.id];
        final thumb = cow == null
            ? ''
            : (cow.thumbnailUrl.isNotEmpty ? cow.thumbnailUrl : cow.imageUrl);
        children.add(
          Card(
            color: _cardColorForStatus(e.status),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: InkWell(
              onLongPress: () => _onCardLongPress(e),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CattleThumbnail(imageUrl: thumb),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ZivotniBrojHighlightTitle(
                            zbroj: e.govedo.zivotniBroj,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              _brojMarkicaLabel(e),
                              'Datum prijave: ${_datumStr(e)}',
                              if (e.napomena.trim().isNotEmpty)
                                'Napomena: ${e.napomena.trim()}',
                            ].join('\n'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: screenBodyPadding(context, top: 8),
      children: children,
    );
  }
}
