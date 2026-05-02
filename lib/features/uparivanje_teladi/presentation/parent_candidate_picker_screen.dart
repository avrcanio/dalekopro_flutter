import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/app_cached_network_image.dart';
import '../../cattle/models/cattle.dart';
import '../../cattle/presentation/cattle_thumbnail.dart';
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
    this.cattleForThumbnails = const <Cattle>[],
  });

  final String title;
  final int farmId;
  final UparivanjeTeladiRepository repository;
  final bool pickMother;
  final int? posjedVezaId;

  /// Za majku: slika s liste goveda (mapiranje po `govedoNaGospodarstvuId` == `ParentCandidate.id`).
  final List<Cattle> cattleForThumbnails;

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

  Map<int, Cattle> _cattleByMembershipId() {
    final map = <int, Cattle>{};
    for (final cow in widget.cattleForThumbnails) {
      final mid = cow.govedoNaGospodarstvuId;
      if (mid > 0) {
        map[mid] = cow;
      }
    }
    return map;
  }

  String _thumbnailUrl(Cattle? cow) {
    if (cow == null) {
      return '';
    }
    return cow.thumbnailUrl.isNotEmpty ? cow.thumbnailUrl : cow.imageUrl;
  }

  /// Isti redoslijed kao u detalju goveda: galerija, zatim profil/thumbnail.
  List<String> _galleryUrls(Cattle? cow) {
    if (cow == null) {
      return const <String>[];
    }
    final seen = <String>{};
    final ordered = <String>[];
    void add(String raw) {
      final u = raw.trim();
      if (u.isEmpty || seen.contains(u)) {
        return;
      }
      seen.add(u);
      ordered.add(u);
    }

    for (final u in cow.imageUrls) {
      add(u);
    }
    if (ordered.isEmpty) {
      add(cow.imageUrl);
      add(cow.thumbnailUrl);
    }
    return ordered;
  }

  void _onCardLongPress(BuildContext context, Cattle? cow) {
    if (!widget.pickMother) {
      return;
    }
    if (cow == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema učitanih podataka o slikama za ovu stavku.'),
        ),
      );
      return;
    }
    final urls = _galleryUrls(cow);
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema dostupnih slika za pregled.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      useSafeArea: false,
      builder: (ctx) => _CattleGalleryModal(urls: urls, subtitle: cow.zivotniBroj),
    );
  }

  @override
  Widget build(BuildContext context) {
    final byGng = widget.pickMother ? _cattleByMembershipId() : const <int, Cattle>{};

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
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final c = _results[index];
                      final cow = byGng[c.id];
                      final url = _thumbnailUrl(cow);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () =>
                              Navigator.of(context).pop<ParentCandidate>(c),
                          onLongPress: widget.pickMother
                              ? () => _onCardLongPress(context, cow)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CattleThumbnail(imageUrl: url),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    c.label,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
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

class _CattleGalleryModal extends StatefulWidget {
  const _CattleGalleryModal({
    required this.urls,
    required this.subtitle,
  });

  final List<String> urls;
  final String subtitle;

  @override
  State<_CattleGalleryModal> createState() => _CattleGalleryModalState();
}

class _CattleGalleryModalState extends State<_CattleGalleryModal> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.urls.length;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: n,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final url = widget.urls[i];
              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 4,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AppCachedNetworkImage(
                          imageUrl: url,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          fit: BoxFit.contain,
                          placeholder: const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          ),
                          errorBuilder: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 64,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, left: 8),
                      child: Text(
                        widget.subtitle.trim().isEmpty
                            ? 'Pregled slika'
                            : widget.subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Zatvori',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (n > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Text(
                '${_index + 1} / $n',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
