import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/screen_insets.dart';
import '../models/odlazak_models.dart';

/// Prikaz stavki dokumenta za jedan odlazak — samo polja koja nisu prazna.
class OdlazakDetailScreen extends StatelessWidget {
  const OdlazakDetailScreen({super.key, required this.record});

  final OdlazakRecord record;

  static bool _hasText(String? s) => s != null && s.trim().isNotEmpty;

  static String? _formatDate(String? raw) {
    if (!_hasText(raw)) {
      return null;
    }
    try {
      return DateFormat.yMMMd('hr').format(DateTime.parse(raw!.trim()));
    } catch (_) {
      return raw!.trim();
    }
  }

  /// Label s API-ja ili samo ID ako nema teksta.
  static String? _fkDisplay(String? label, int? id) {
    if (_hasText(label)) {
      return label!.trim();
    }
    if (id != null && id > 0) {
      return 'ID $id';
    }
    return null;
  }

  List<Widget> _buildSections(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final children = <Widget>[];

    void addBlock(String title, String body) {
      if (!_hasText(body)) {
        return;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SelectableText(
            body.trim(),
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    void addRow(String label, String? value) {
      if (!_hasText(value)) {
        return;
      }
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value!.trim(),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
      children.add(Divider(height: 1, color: theme.dividerColor));
    }

    addRow('Serijski broj', record.serijskiBroj);
    final datumOdl = _formatDate(record.datumOdlaska);
    addRow('Datum odlaska', datumOdl);
    addRow('Razlog', record.razlogLabel);

    if (record.goveda.isNotEmpty) {
      final lines = <String>[];
      for (final g in record.goveda) {
        final ime = g.ime.trim();
        final uz = g.uzrast?.trim() ?? '';
        if (ime.isNotEmpty) {
          lines.add(
            uz.isNotEmpty
                ? '$ime · ${g.zivotniBroj} ($uz)'
                : '$ime · ${g.zivotniBroj}',
          );
        } else {
          lines.add(g.subtitle);
        }
      }
      addBlock('Goveda', lines.join('\n'));
    }

    addRow(
      'Drugo gospodarstvo',
      _fkDisplay(record.drugoGospodarstvoLabel, record.drugoGospodarstvoId),
    );
    addRow(
      'Klaonica',
      _fkDisplay(record.klaonicaLabel, record.klaonicaId),
    );
    addRow('Broj veterinarskog certifikata', record.brojVeterinarskogCertifikata);
    addRow(
      'Kafilerija',
      _fkDisplay(record.kafilerijaLabel, record.kafilerijaId),
    );
    addRow(
      'Datum prijave veterinaru',
      _formatDate(record.datumPrijaveVeterinaru),
    );
    addRow(
      'Veterinar',
      _fkDisplay(record.veterinarLabel, record.veterinarId),
    );
    addRow('Vozilo', _fkDisplay(record.voziloLabel, record.voziloId));
    addRow('Napomena prijevoz', record.napomenaPrijevoz);
    addRow('Napomena', record.napomena);

    if (children.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nema podataka za prikaz.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    } else if (children.last is Divider) {
      children.removeLast();
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Odlazak'),
            if (record.serijskiBroj.trim().isNotEmpty)
              Text(
                record.serijskiBroj,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: ListView(
        padding: screenBodyPadding(context, top: 8, bottomSpacing: 24),
        children: _buildSections(context),
      ),
    );
  }
}
