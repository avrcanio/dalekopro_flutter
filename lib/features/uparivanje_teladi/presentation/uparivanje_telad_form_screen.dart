import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../cattle_transfer/models/holding.dart';
import '../data/uparivanje_teladi_repository.dart';
import '../models/parent_candidate.dart';
import '../models/uparivanje_telad.dart';
import 'parent_candidate_picker_screen.dart';

class UparivanjeTeladFormScreen extends StatefulWidget {
  const UparivanjeTeladFormScreen({
    super.key,
    required this.farmId,
    required this.farmLabel,
    required this.holdings,
    required this.repository,
    this.existing,
  });

  final int farmId;
  final String farmLabel;
  final List<Holding> holdings;
  final UparivanjeTeladiRepository repository;
  final UparivanjeTelad? existing;

  @override
  State<UparivanjeTeladFormScreen> createState() =>
      _UparivanjeTeladFormScreenState();
}

class _UparivanjeTeladFormScreenState extends State<UparivanjeTeladFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _zbController = TextEditingController();
  static final _zbOk = RegExp(r'^HR \d{10}$');

  Holding? _posjed;
  String _spol = 'Ž';
  DateTime? _datum;
  int? _majkaId;
  int? _otacId;
  String _majkaLabel = '';
  String _otacLabel = '';
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _zbController.text = e.zivotniBroj;
      _spol = e.spol == 'M' ? 'M' : 'Ž';
      _datum = e.datumTelenja ?? DateTime.now();
      _majkaId = e.majkaNaGospodarstvuId;
      _otacId = e.otacId;
      _majkaLabel = e.majkaDisplay;
      _otacLabel = e.otacDisplay;
      for (final h in widget.holdings) {
        if (h.id == e.posjedVezaId) {
          _posjed = h;
          break;
        }
      }
    } else {
      _datum = DateTime.now();
      if (widget.holdings.length == 1) {
        _posjed = widget.holdings.first;
      }
    }
  }

  @override
  void dispose() {
    _zbController.dispose();
    super.dispose();
  }

  static String normalizeZivotniBroj(String raw) {
    final t = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    if (t.startsWith('HR')) {
      final after = t.substring(2).trim().replaceAll(' ', '');
      if (after.length == 10 && RegExp(r'^\d{10}$').hasMatch(after)) {
        return 'HR $after';
      }
    }
    return raw.trim();
  }

  Future<void> _pickDate() async {
    final initial = _datum ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _datum = picked);
    }
  }

  Future<void> _openMajkaPicker() async {
    final veza = _posjed?.id;
    if (veza == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prvo odaberite posjed.')),
      );
      return;
    }
    final result = await Navigator.of(context).push<ParentCandidate>(
      MaterialPageRoute(
        builder: (_) => ParentCandidatePickerScreen(
          title: 'Majka (krava / junica)',
          farmId: widget.farmId,
          repository: widget.repository,
          pickMother: true,
          posjedVezaId: veza,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _majkaId = result.id;
        _majkaLabel = result.label;
      });
    }
  }

  Future<void> _openOtacPicker() async {
    final result = await Navigator.of(context).push<ParentCandidate>(
      MaterialPageRoute(
        builder: (_) => ParentCandidatePickerScreen(
          title: 'Otac (bik)',
          farmId: widget.farmId,
          repository: widget.repository,
          pickMother: false,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _otacId = result.id;
        _otacLabel = result.label;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final posjed = _posjed;
    if (posjed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberite posjed na gospodarstvu.')),
      );
      return;
    }
    final d = _datum;
    if (d == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberite datum telenja.')),
      );
      return;
    }

    final zb = normalizeZivotniBroj(_zbController.text);
    final body = <String, dynamic>{
      'zivotni_broj': zb,
      'spol': _spol,
      'datum_telenja': DateFormat('yyyy-MM-dd').format(d),
      'posjed_veza': posjed.id,
      'majka_na_gospodarstvu': _majkaId,
      'otac': _otacId,
    };

    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        body.removeWhere((k, v) => v == null);
        await widget.repository.create(widget.farmId, body);
      } else {
        await widget.repository.update(
          widget.farmId,
          widget.existing!.id,
          body,
        );
      }
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

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brisanje zapisa'),
        content: Text(
          'Obrisati uparivanje za ${existing.zivotniBroj}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await widget.repository.delete(widget.farmId, existing.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final dateLabel = _datum == null
        ? 'Odaberi datum'
        : DateFormat.yMMMd('hr').format(_datum!);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Uredi uparivanje' : 'Novo uparivanje teladi'),
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _deleting ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Gospodarstvo: ${widget.farmLabel}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Holding>(
              key: ValueKey<int?>(_posjed?.id),
              initialValue: _posjed,
              decoration: const InputDecoration(
                labelText: 'Posjed na gospodarstvu',
                border: OutlineInputBorder(),
              ),
              items: widget.holdings
                  .map(
                    (h) => DropdownMenuItem(
                      value: h,
                      child: Text(
                        h.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _posjed = v;
                  _majkaId = null;
                  _majkaLabel = '';
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _zbController,
              decoration: const InputDecoration(
                labelText: 'Životni broj teladi',
                hintText: 'HR 1234567890',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = normalizeZivotniBroj(v ?? '');
                if (!_zbOk.hasMatch(n)) {
                  return 'Format: HR razmak 10 znamenki';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(_spol),
              initialValue: _spol,
              decoration: const InputDecoration(
                labelText: 'Spol',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('Muško')),
                DropdownMenuItem(value: 'Ž', child: Text('Žensko')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _spol = v);
                }
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Datum telenja'),
              subtitle: Text(dateLabel),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const Divider(),
            const Text('Majka (opcionalno)'),
            const SizedBox(height: 4),
            Text(
              _majkaLabel.isEmpty ? 'Nije odabrano' : _majkaLabel,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            Wrap(
              spacing: 8,
              children: [
                if (_majkaId != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _majkaId = null;
                        _majkaLabel = '';
                      });
                    },
                    child: const Text('Ukloni majku'),
                  ),
                FilledButton.tonal(
                  onPressed: _openMajkaPicker,
                  child: const Text('Odaberi majku'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Otac / bik (opcionalno)'),
            const SizedBox(height: 4),
            Text(
              _otacLabel.isEmpty ? 'Nije odabrano' : _otacLabel,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            Wrap(
              spacing: 8,
              children: [
                if (_otacId != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _otacId = null;
                        _otacLabel = '';
                      });
                    },
                    child: const Text('Ukloni oca'),
                  ),
                FilledButton.tonal(
                  onPressed: _openOtacPicker,
                  child: const Text('Odaberi oca'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_saving || _deleting) ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Spremi izmjene' : 'Spremi'),
            ),
          ],
        ),
      ),
    );
  }
}
