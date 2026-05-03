import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../cattle/data/cattle_repository.dart';
import '../../cattle/models/cattle.dart';
import '../../cattle/presentation/cattle_thumbnail.dart';
import '../../cattle/zivotni_broj_digits.dart';
import '../../farms/models/farm.dart';
import '../data/odlasci_repository.dart';
import '../models/odlazak_models.dart';
import 'lookup_autocomplete_field.dart';

class OdlazakWizardScreen extends StatefulWidget {
  const OdlazakWizardScreen({
    super.key,
    required this.farm,
    required this.cattleRepository,
    required this.odlasciRepository,
  });

  final Farm farm;
  final CattleRepository cattleRepository;
  final OdlasciRepository odlasciRepository;

  @override
  State<OdlazakWizardScreen> createState() => _OdlazakWizardScreenState();
}

class _OdlazakWizardScreenState extends State<OdlazakWizardScreen> {
  int _step = 0;
  bool _loadingCattle = true;
  bool _loadingLookup = true;
  bool _submitting = false;
  String? _loadError;

  final _serijskiController = TextEditingController();
  final _certController = TextEditingController();
  final _napomenaController = TextEditingController();
  final _napomenaPrijevozController = TextEditingController();
  final _cattleSearchController = TextEditingController();

  DateTime _datumOdlaska = DateTime.now();
  int _razlog = RazlogOdlaska.naDrugoGospodarstvo;

  List<Cattle> _cattle = const [];
  final Set<int> _selectedGovedoIds = {};

  OdlasciLookupData _lookup = const OdlasciLookupData();

  int? _drugoGospodarstvoId;
  int? _klaonicaId;
  int? _kafilerijaId;
  DateTime? _datumPrijaveVet;
  int? _veterinarId;
  int? _voziloId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingCattle = true;
      _loadingLookup = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        widget.cattleRepository.fetchCattleByFarm(widget.farm.id),
        widget.odlasciRepository.fetchLookup(widget.farm.id),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _cattle = results[0] as List<Cattle>;
        _lookup = results[1] as OdlasciLookupData;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCattle = false;
          _loadingLookup = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _serijskiController.dispose();
    _certController.dispose();
    _napomenaController.dispose();
    _napomenaPrijevozController.dispose();
    _cattleSearchController.dispose();
    super.dispose();
  }

  String _dateStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Briše odabir goveda (2/3) i sva polja koraka 3/3 — poziva se kad se na 1/3 promijeni razlog.
  void _resetWizardStepsTwoAndThree() {
    _selectedGovedoIds.clear();
    _cattleSearchController.clear();
    _certController.clear();
    _drugoGospodarstvoId = null;
    _klaonicaId = null;
    _kafilerijaId = null;
    _datumPrijaveVet = null;
    _veterinarId = null;
    _voziloId = null;
    _napomenaPrijevozController.clear();
  }

  Future<void> _pickDate({
    required DateTime initial,
    required void Function(DateTime) onPick,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onPick(picked);
      setState(() {});
    }
  }

  Future<void> _showNapomenaDialog() async {
    final ctrl = TextEditingController(text: _napomenaController.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Napomena'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Opcionalna napomena',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Spremi'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _napomenaController.text = ctrl.text;
      setState(() {});
    }
    ctrl.dispose();
  }

  Future<void> _showNapomenaPrijevozDialog() async {
    final ctrl = TextEditingController(text: _napomenaPrijevozController.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Napomena prijevoz'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Spremi'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _napomenaPrijevozController.text = ctrl.text;
      setState(() {});
    }
    ctrl.dispose();
  }

  bool _validateStep0() {
    final s = _serijskiController.text.trim();
    if (!RegExp(r'^\d{9}$').hasMatch(s)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serijski broj mora imati točno 9 znamenki.'),
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateStep1() {
    if (_selectedGovedoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberite barem jedno govedo.')),
      );
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    switch (_razlog) {
      case RazlogOdlaska.naDrugoGospodarstvo:
        if (_drugoGospodarstvoId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Odaberite drugo gospodarstvo.')),
          );
          return false;
        }
        if (_certController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Broj veterinarskog certifikata je obavezan.'),
            ),
          );
          return false;
        }
        return true;
      case RazlogOdlaska.klaonica:
        if (_klaonicaId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Odaberite klaonicu.')),
          );
          return false;
        }
        if (_certController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Broj veterinarskog certifikata je obavezan.'),
            ),
          );
          return false;
        }
        return true;
      case RazlogOdlaska.uginuce:
        if (_kafilerijaId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Odaberite kafileriju.')),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Map<String, dynamic> _buildBody() {
    final body = <String, dynamic>{
      'serijski_broj': _serijskiController.text.trim(),
      'datum_odlaska': _dateStr(_datumOdlaska),
      'razlog': _razlog,
      'goveda_ids': _selectedGovedoIds.toList(),
    };
    final nap = _napomenaController.text.trim();
    if (nap.isNotEmpty) {
      body['napomena'] = nap;
    }
    switch (_razlog) {
      case RazlogOdlaska.naDrugoGospodarstvo:
        body['drugo_gospodarstvo'] = _drugoGospodarstvoId;
        body['broj_veterinarskog_certifikata'] = _certController.text.trim();
        if (_datumPrijaveVet != null) {
          body['datum_prijave_veterinaru'] = _dateStr(_datumPrijaveVet!);
        }
        if (_veterinarId != null) {
          body['veterinar'] = _veterinarId;
        }
        if (_voziloId != null) {
          body['vozilo'] = _voziloId;
        }
        break;
      case RazlogOdlaska.klaonica:
        body['klaonica'] = _klaonicaId;
        body['broj_veterinarskog_certifikata'] = _certController.text.trim();
        if (_datumPrijaveVet != null) {
          body['datum_prijave_veterinaru'] = _dateStr(_datumPrijaveVet!);
        }
        if (_veterinarId != null) {
          body['veterinar'] = _veterinarId;
        }
        if (_voziloId != null) {
          body['vozilo'] = _voziloId;
        }
        final np = _napomenaPrijevozController.text.trim();
        if (np.isNotEmpty) {
          body['napomena_prijevoz'] = np;
        }
        break;
      case RazlogOdlaska.uginuce:
        body['kafilerija'] = _kafilerijaId;
        if (_datumPrijaveVet != null) {
          body['datum_prijave_veterinaru'] = _dateStr(_datumPrijaveVet!);
        }
        if (_veterinarId != null) {
          body['veterinar'] = _veterinarId;
        }
        if (_voziloId != null) {
          body['vozilo'] = _voziloId;
        }
        break;
      case RazlogOdlaska.kradjaGubitak:
        if (_datumPrijaveVet != null) {
          body['datum_prijave_veterinaru'] = _dateStr(_datumPrijaveVet!);
        }
        if (_veterinarId != null) {
          body['veterinar'] = _veterinarId;
        }
        break;
      default:
        break;
    }
    return body;
  }

  Future<void> _submit() async {
    if (!_validateStep2()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.odlasciRepository.createOdlazak(
        widget.farm.id,
        _buildBody(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _next() {
    if (_step == 0) {
      if (!_validateStep0()) {
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (!_validateStep1()) {
        return;
      }
      setState(() => _step = 2);
      return;
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  Widget _buildStep0() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.farm.label,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _serijskiController,
          decoration: const InputDecoration(
            labelText: 'Serijski broj (9 znamenki)',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Datum odlaska'),
          subtitle: Text(DateFormat.yMMMd('hr').format(_datumOdlaska)),
          trailing: const Icon(Icons.calendar_today),
          onTap: () => _pickDate(
            initial: _datumOdlaska,
            onPick: (d) => _datumOdlaska = d,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(labelText: 'Razlog'),
          value: _razlog,
          items: RazlogOdlaska.all
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(RazlogOdlaska.labelHr(r)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) {
              return;
            }
            setState(() {
              if (v != _razlog) {
                _resetWizardStepsTwoAndThree();
              }
              _razlog = v;
            });
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showNapomenaDialog,
          icon: const Icon(Icons.note_alt_outlined),
          label: Text(
            _napomenaController.text.trim().isEmpty
                ? 'Napomena'
                : 'Napomena (ispunjeno)',
          ),
        ),
      ],
    );
  }

  List<Cattle> get _cattleFilteredBySearch {
    final q = _cattleSearchController.text;
    return _cattle
        .where(
          (c) =>
              c.id > 0 &&
              matchesZivotniBrojSearchQuery(c.zivotniBroj, q),
        )
        .toList();
  }

  /// Redoslijed prikaza: June → muško tele → bik → žensko tele → junica → krava → ostalo.
  static int _uzrastCategoryRank(Cattle c) {
    final u = c.uzrast.toLowerCase();
    if (u.contains('june')) {
      return 0;
    }
    if (u.contains('tele') && (u.contains('mušk') || u.contains('(m)'))) {
      return 1;
    }
    if (u.contains('bik')) {
      return 2;
    }
    if (u.contains('tele') && (u.contains('žen') || u.contains('(ž)'))) {
      return 3;
    }
    if (u.contains('junic')) {
      return 4;
    }
    if (u.contains('krav')) {
      return 5;
    }
    if (u.contains('tele')) {
      return 6;
    }
    return 20;
  }

  static void _sortCattleByUzrastOrder(List<Cattle> list) {
    list.sort((a, b) {
      final cmp = _uzrastCategoryRank(a).compareTo(_uzrastCategoryRank(b));
      if (cmp != 0) {
        return cmp;
      }
      return a.zivotniBroj.compareTo(b.zivotniBroj);
    });
  }

  String _cattleThumbUrl(Cattle c) {
    final t = c.thumbnailUrl.trim();
    if (t.isNotEmpty) {
      return t;
    }
    return c.imageUrl.trim();
  }

  Widget _cattleSelectCard(Cattle c, {required bool selected}) {
    final theme = Theme.of(context);
    final subtitle = c.uzrast.isEmpty
        ? c.zivotniBroj
        : '${c.zivotniBroj} · ${c.uzrast}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.dividerColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              _selectedGovedoIds.remove(c.id);
            } else {
              _selectedGovedoIds.add(c.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CattleThumbnail(imageUrl: _cattleThumbUrl(c)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.displayName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Ukloni s odabira',
                  onPressed: () {
                    setState(() => _selectedGovedoIds.remove(c.id));
                  },
                  icon: const Icon(Icons.close),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    if (_cattle.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nema goveda na ovom gospodarstvu.'),
        ),
      );
    }
    final filtered = _cattleFilteredBySearch;
    final selected = <Cattle>[];
    final rest = <Cattle>[];
    for (final c in filtered) {
      if (_selectedGovedoIds.contains(c.id)) {
        selected.add(c);
      } else {
        rest.add(c);
      }
    }
    _sortCattleByUzrastOrder(selected);
    _sortCattleByUzrastOrder(rest);

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _cattleSearchController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Pretraga životnog broja',
              hintText: 'HR… ili do 4 znamenke (zadnje četiri)',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _cattleSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Očisti',
                      onPressed: () {
                        _cattleSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nema goveda za ovaj upit.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (selected.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Text(
                          'Odabrano (${selected.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...selected.map(
                        (c) => _cattleSelectCard(c, selected: true),
                      ),
                      if (selected.isNotEmpty && rest.isNotEmpty)
                        const SizedBox(height: 8),
                    ],
                    if (rest.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          selected.isEmpty
                              ? 'Odaberi goveda'
                              : 'Ostala goveda',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...rest.map(
                        (c) => _cattleSelectCard(c, selected: false),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _tileDatumPrijaveVeterinaru() {
    return ListTile(
      title: const Text('Datum prijave veterinaru'),
      subtitle: Text(
        _datumPrijaveVet == null
            ? 'Nije odabrano'
            : DateFormat.yMMMd('hr').format(_datumPrijaveVet!),
      ),
      trailing: const Icon(Icons.calendar_today),
      onTap: () => _pickDate(
        initial: _datumPrijaveVet ?? DateTime.now(),
        onPick: (d) => _datumPrijaveVet = d,
      ),
    );
  }

  Widget _buildStep2() {
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          RazlogOdlaska.labelHr(_razlog),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ];

    switch (_razlog) {
      case RazlogOdlaska.naDrugoGospodarstvo:
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Drugo gospodarstvo',
              hintText: 'Upišite naziv ili IKG…',
              items: _lookup.drugaGospodarstva,
              value: _drugoGospodarstvoId,
              onChanged: (v) => setState(() => _drugoGospodarstvoId = v),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _certController,
              decoration: const InputDecoration(
                labelText: 'Broj veterinarskog certifikata',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        );
        children.add(_tileDatumPrijaveVeterinaru());
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Veterinar',
              hintText: 'Ime ili prezime…',
              items: _lookup.veterinari,
              value: _veterinarId,
              onChanged: (v) => setState(() => _veterinarId = v),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Vozilo',
              hintText: 'Registracija ili prijevoznik…',
              items: _lookup.vozila,
              value: _voziloId,
              onChanged: (v) => setState(() => _voziloId = v),
            ),
          ),
        );
        break;
      case RazlogOdlaska.klaonica:
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Klaonica',
              hintText: 'Naziv klaonice…',
              items: _lookup.klaonice,
              value: _klaonicaId,
              onChanged: (v) => setState(() => _klaonicaId = v),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _certController,
              decoration: const InputDecoration(
                labelText: 'Broj veterinarskog certifikata',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        );
        children.add(_tileDatumPrijaveVeterinaru());
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Veterinar',
              hintText: 'Ime ili prezime…',
              items: _lookup.veterinari,
              value: _veterinarId,
              onChanged: (v) => setState(() => _veterinarId = v),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Vozilo',
              hintText: 'Registracija ili prijevoznik…',
              items: _lookup.vozila,
              value: _voziloId,
              onChanged: (v) => setState(() => _voziloId = v),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _showNapomenaPrijevozDialog,
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(
                _napomenaPrijevozController.text.trim().isEmpty
                    ? 'Napomena prijevoz'
                    : 'Napomena prijevoz (ispunjeno)',
              ),
            ),
          ),
        );
        break;
      case RazlogOdlaska.kradjaGubitak:
        children.add(_tileDatumPrijaveVeterinaru());
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Veterinar',
              hintText: 'Ime ili prezime…',
              items: _lookup.veterinari,
              value: _veterinarId,
              onChanged: (v) => setState(() => _veterinarId = v),
            ),
          ),
        );
        break;
      case RazlogOdlaska.uginuce:
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Kafilerija',
              hintText: 'Naziv ili OIB…',
              items: _lookup.kafilerije,
              value: _kafilerijaId,
              onChanged: (v) => setState(() => _kafilerijaId = v),
            ),
          ),
        );
        children.add(_tileDatumPrijaveVeterinaru());
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Veterinar',
              hintText: 'Ime ili prezime…',
              items: _lookup.veterinari,
              value: _veterinarId,
              onChanged: (v) => setState(() => _veterinarId = v),
            ),
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LookupAutocompleteField(
              label: 'Vozilo',
              hintText: 'Registracija ili prijevoznik…',
              items: _lookup.vozila,
              value: _voziloId,
              onChanged: (v) => setState(() => _voziloId = v),
            ),
          ),
        );
        break;
      default:
        break;
    }

    return ListView(
      key: ValueKey<String>('odlazak_wizard_step3_razlog_$_razlog'),
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null && !_loadingCattle && !_loadingLookup) {
      return Scaffold(
        appBar: AppBar(title: const Text('Novi odlazak')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _bootstrap,
                  child: const Text('Pokušaj ponovo'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final busy = _loadingCattle || _loadingLookup;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _step > 0) {
          _back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Novi odlazak (${_step + 1}/3)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_step > 0) {
                _back();
              } else {
                Navigator.of(context).pop(false);
              }
            },
          ),
        ),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: _step,
                children: [
                  _buildStep0(),
                  _buildStep1(),
                  _buildStep2(),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_step < 2)
                  FilledButton(
                    onPressed: _submitting ? null : _next,
                    child: const Text('Dalje'),
                )
                else
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Završi'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
