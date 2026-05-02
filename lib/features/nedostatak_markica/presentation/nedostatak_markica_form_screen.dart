import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../cattle/cattle_gallery_urls.dart';
import '../../cattle/models/cattle.dart';
import '../../cattle/presentation/cattle_gallery_fullscreen_dialog.dart';
import '../../cattle/presentation/cattle_thumbnail.dart';
import '../../cattle/zivotni_broj_digits.dart';
import '../../cattle/zivotni_broj_highlight_title.dart';
import '../data/nedostatak_markica_repository.dart';

class NedostatakMarkicaFormScreen extends StatefulWidget {
  const NedostatakMarkicaFormScreen({
    super.key,
    required this.farmId,
    required this.farmLabel,
    required this.farmCattle,
    required this.repository,
  });

  final int farmId;
  final String farmLabel;
  final List<Cattle> farmCattle;
  final NedostatakMarkicaRepository repository;

  @override
  State<NedostatakMarkicaFormScreen> createState() =>
      _NedostatakMarkicaFormScreenState();
}

class _NedostatakMarkicaFormScreenState
    extends State<NedostatakMarkicaFormScreen> {
  static const int _kLastStepIndex = 2;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _napomenaController = TextEditingController();

  int _step = 0;
  Cattle? _selected;
  int _brojNedostajucih = 1;
  DateTime _datumPrijave = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _napomenaController.dispose();
    super.dispose();
  }

  List<Cattle> get _filteredCattle {
    final q = _searchController.text.replaceAll(RegExp(r'\D'), '');
    if (q.isEmpty) {
      return widget.farmCattle;
    }
    return widget.farmCattle
        .where((c) => matchesZivotniBrojDigitsQuery(c.zivotniBroj, q))
        .toList();
  }

  String _thumbnailUrl(Cattle c) =>
      c.thumbnailUrl.isNotEmpty ? c.thumbnailUrl : c.imageUrl;

  void _onCattleLongPress(Cattle c) {
    final urls = cattleGalleryImageUrls(c);
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema dostupnih slika za pregled.')),
      );
      return;
    }
    showCattleGalleryFullscreenDialog(
      context,
      urls: urls,
      subtitle: c.zivotniBroj,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datumPrijave,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _datumPrijave = picked);
    }
  }

  void _goNext() {
    if (_step >= _kLastStepIndex) {
      return;
    }
    if (_step == 0) {
      if (_selected == null || _selected!.id <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Odaberite govedo.')),
        );
        return;
      }
    }
    setState(() => _step++);
  }

  void _goBack() {
    if (_step <= 0) {
      return;
    }
    setState(() => _step--);
  }

  Future<void> _submit() async {
    final cow = _selected;
    if (cow == null || cow.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberite govedo.')),
      );
      return;
    }

    final napomena = _napomenaController.text.trim();
    final body = <String, dynamic>{
      'govedo_id': cow.id,
      'broj_nedostajucih': _brojNedostajucih,
      'datum_prijave': DateFormat('yyyy-MM-dd').format(_datumPrijave),
      'status': 'PR',
      if (napomena.isNotEmpty) 'napomena': napomena,
    };

    setState(() => _saving = true);
    try {
      await widget.repository.create(body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String get _appBarTitle {
    switch (_step) {
      case 0:
        return 'Odabir goveda';
      case 1:
        return 'Detalji prijave';
      case 2:
        return 'Napomena';
      default:
        return 'Nova prijava';
    }
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: done ? 1 : (active ? 1 : 0),
                  minHeight: 4,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep0() {
    final visible = _filteredCattle;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const Text('Odabir goveda'),
        const SizedBox(height: 8),
        TextField(
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
        const SizedBox(height: 8),
        if (_selected != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Odabrano: ${_selected!.zivotniBroj} (${_selected!.displayName})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Nema goveda za prikaz ili pretragu.')),
          )
        else
          ...visible.map((c) {
            final sel = _selected?.id == c.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              color: sel
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.35)
                  : null,
              child: InkWell(
                onTap: () => setState(() => _selected = c),
                onLongPress: () => _onCattleLongPress(c),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      CattleThumbnail(imageUrl: _thumbnailUrl(c)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ZivotniBrojHighlightTitle(zbroj: c.zivotniBroj),
                      ),
                      if (sel)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStep1() {
    final dateLabel = DateFormat.yMMMd('hr').format(_datumPrijave);
    final cow = _selected;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (cow != null) ...[
          Text(
            'Govedo: ${cow.zivotniBroj} (${cow.displayName})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 20),
        ],
        const Text('Broj nedostajućih markica'),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Jedna')),
            ButtonSegment(value: 2, label: Text('Dvije')),
          ],
          selected: {_brojNedostajucih},
          onSelectionChanged: (s) {
            final v = s.first;
            setState(() => _brojNedostajucih = v);
          },
        ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Datum prijave'),
          subtitle: Text(dateLabel),
          trailing: const Icon(Icons.calendar_today),
          onTap: _pickDate,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Napomena (opcionalno)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _napomenaController,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              expands: true,
              maxLines: null,
              minLines: null,
              decoration: const InputDecoration(
                hintText: 'Unesite napomenu ako je potrebno…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0)
              OutlinedButton(
                onPressed: _saving ? null : _goBack,
                child: const Text('Natrag'),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              child: switch (_step) {
                0 => FilledButton(
                    onPressed: _saving ? null : _goNext,
                    child: const Text('Dalje'),
                  ),
                1 => FilledButton(
                    onPressed: _saving ? null : _goNext,
                    child: const Text('Dalje'),
                  ),
                _ => FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Spremi'),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitle),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Gospodarstvo: ${widget.farmLabel}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              'Korak ${_step + 1} od 3',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            _buildStepIndicator(),
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  _buildStep0(),
                  _buildStep1(),
                  _buildStep2(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }
}
