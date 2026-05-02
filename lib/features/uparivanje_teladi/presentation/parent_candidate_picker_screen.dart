import 'dart:async';

import 'package:flutter/material.dart';

import '../data/uparivanje_teladi_repository.dart';
import '../models/parent_candidate.dart';

/// Pretraga i odabir majke (ovisno o posjedu) ili oca (bikovi na gospodarstvu).
class ParentCandidatePickerScreen extends StatefulWidget {
  const ParentCandidatePickerScreen({
    super.key,
    required this.title,
    required this.farmId,
    required this.repository,
    required this.pickMother,
    this.posjedVezaId,
  });

  final String title;
  final int farmId;
  final UparivanjeTeladiRepository repository;
  final bool pickMother;
  final int? posjedVezaId;

  @override
  State<ParentCandidatePickerScreen> createState() =>
      _ParentCandidatePickerScreenState();
}

class _ParentCandidatePickerScreenState
    extends State<ParentCandidatePickerScreen> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<ParentCandidate> _results = const <ParentCandidate>[];

  @override
  void initState() {
    super.initState();
    _scheduleFetch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _scheduleFetch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_fetch(q));
    });
  }

  Future<void> _fetch(String q) async {
    if (widget.pickMother && widget.posjedVezaId == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Nije odabran posjed.';
        _results = const <ParentCandidate>[];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = widget.pickMother
          ? await widget.repository.searchMajke(
              widget.farmId,
              widget.posjedVezaId!,
              q,
            )
          : await widget.repository.searchBikovi(widget.farmId, q);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Neuspjelo učitavanje kandidata.';
        _results = const <ParentCandidate>[];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Pretraga',
                hintText: 'Životni broj, ime, HB…',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _scheduleFetch,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _loading && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final c = _results[index];
                      return ListTile(
                        title: Text(
                          c.label,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop<ParentCandidate>(
                          c,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
