import 'package:flutter/material.dart';

import '../models/odlazak_models.dart';

/// Pretraživi odabir stavke iz lookup liste (label + id).
class LookupAutocompleteField extends StatefulWidget {
  const LookupAutocompleteField({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hintText,
  });

  final String label;
  final List<LookupItem> items;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? hintText;

  @override
  State<LookupAutocompleteField> createState() =>
      _LookupAutocompleteFieldState();
}

class _LookupAutocompleteFieldState extends State<LookupAutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ignoreTextListener = false;

  void _setControllerText(String text) {
    _ignoreTextListener = true;
    _controller.text = text;
    _ignoreTextListener = false;
  }

  void _onTextEdited() {
    if (_ignoreTextListener) {
      return;
    }
    final id = widget.value;
    if (id == null) {
      return;
    }
    final label = _labelFor(id);
    if (label.isEmpty) {
      return;
    }
    if (_controller.text.trim() != label.trim()) {
      widget.onChanged(null);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _labelFor(widget.value));
    _focusNode = FocusNode();
    _controller.addListener(_onTextEdited);
  }

  @override
  void didUpdateWidget(LookupAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nova lista (npr. druga gospodarstva → klaonice): uvijek sinkroniziraj tekst,
    // inače RawAutocomplete zadrži stari upis i opcije iz prethodnog polja.
    if (oldWidget.value != widget.value ||
        !identical(oldWidget.items, widget.items)) {
      _setControllerText(_labelFor(widget.value));
    }
  }

  String _labelFor(int? id) {
    if (id == null) {
      return '';
    }
    for (final e in widget.items) {
      if (e.id == id) {
        return e.label;
      }
    }
    return '';
  }

  Iterable<LookupItem> _options(TextEditingValue te) {
    final q = te.text.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.items.take(50);
    }
    return widget.items
        .where((e) => e.label.toLowerCase().contains(q))
        .take(50);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextEdited);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<LookupItem>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: _options,
      onSelected: (LookupItem o) {
        widget.onChanged(o.id);
        _setControllerText(o.label);
        _focusNode.unfocus();
        setState(() {});
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode fieldFocus,
        VoidCallback onSubmitted,
      ) {
        return TextFormField(
          controller: fieldController,
          focusNode: fieldFocus,
          onFieldSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fieldController.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Očisti',
                    onPressed: () {
                      _ignoreTextListener = true;
                      fieldController.clear();
                      _ignoreTextListener = false;
                      widget.onChanged(null);
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          onChanged: (_) => setState(() {}),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<LookupItem> onSelected,
        Iterable<LookupItem> options,
      ) {
        final opts = options.toList(growable: false);
        if (opts.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 200),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final o = opts[index];
                  return InkWell(
                    onTap: () => onSelected(o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        o.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
