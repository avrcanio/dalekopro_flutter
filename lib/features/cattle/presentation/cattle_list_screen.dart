import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_cached_network_image.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../farms/data/farms_repository.dart';
import '../../farms/models/farm.dart';
import '../../upload/data/upload_repository.dart';
import '../data/cattle_repository.dart';
import '../models/cattle.dart';

class CattleDetailScreen extends StatefulWidget {
  const CattleDetailScreen({
    super.key,
    required this.cattle,
    required this.allCattle,
    required this.cattleRepository,
    required this.uploadRepository,
    this.showOutsideFarmNotice = false,
  });

  final Cattle cattle;
  final List<Cattle> allCattle;
  final CattleRepository cattleRepository;
  final UploadRepository uploadRepository;
  final bool showOutsideFarmNotice;

  @override
  State<CattleDetailScreen> createState() => _CattleDetailScreenState();
}

class _CattleDetailScreenState extends State<CattleDetailScreen> {
  late final PageController _pageController;
  late List<String> _galleryUrls;
  Timer? _autoPlayTimer;
  int _currentImageIndex = 0;
  final Set<String> _resolvingParents = <String>{};

  @override
  void initState() {
    super.initState();
    _galleryUrls = _buildGalleryUrls();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<String> _buildGalleryUrls() {
    final seen = <String>{};
    final ordered = <String>[];

    void addUrl(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      ordered.add(normalized);
    }

    // Prefer explicit gallery when backend provides it.
    // Profile image is only a fallback when gallery is empty.
    if (widget.cattle.imageUrls.isNotEmpty) {
      for (final url in widget.cattle.imageUrls) {
        addUrl(url);
      }
    } else {
      addUrl(widget.cattle.imageUrl);
    }

    return ordered;
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (_galleryUrls.length <= 1) {
      return;
    }

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _galleryUrls.isEmpty) return;
      final nextIndex = (_currentImageIndex + 1) % _galleryUrls.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  String _displayOrFallback(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Nije dostupno' : trimmed;
  }

  String _parentDisplay(CattleParentRef? parent, String fallback) {
    if (parent == null) {
      return fallback;
    }

    final broj = parent.broj.trim();
    final ime = parent.ime.trim();
    if (broj.isNotEmpty && ime.isNotEmpty) {
      return '$broj ($ime)';
    }
    if (broj.isNotEmpty) {
      return broj;
    }
    if (ime.isNotEmpty) {
      return ime;
    }
    return fallback;
  }

  Cattle? _findParentInLoadedCattle(CattleParentRef parent) {
    for (final item in widget.allCattle) {
      if (parent.id > 0 && item.id == parent.id) {
        return item;
      }
      if (parent.broj.trim().isNotEmpty &&
          item.zivotniBroj.trim().toUpperCase() ==
              parent.broj.trim().toUpperCase()) {
        return item;
      }
    }
    return null;
  }

  Future<void> _openParent({
    required String relationKey,
    required CattleParentRef? parent,
  }) async {
    if (parent == null) return;

    final localProfile = _findParentInLoadedCattle(parent);
    if (localProfile != null) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CattleDetailScreen(
            cattle: localProfile,
            allCattle: widget.allCattle,
            cattleRepository: widget.cattleRepository,
            uploadRepository: widget.uploadRepository,
          ),
        ),
      );
      return;
    }

    if (parent.id <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detalj roditelja nije dostupan.')),
      );
      return;
    }

    setState(() {
      _resolvingParents.add(relationKey);
    });

    try {
      final fetched = await widget.cattleRepository.fetchCattleById(parent.id);
      if (!mounted) return;

      final mergedAllCattle = <Cattle>[...widget.allCattle];
      if (!mergedAllCattle.any((item) => item.id == fetched.id)) {
        mergedAllCattle.add(fetched);
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CattleDetailScreen(
            cattle: fetched,
            allCattle: mergedAllCattle,
            cattleRepository: widget.cattleRepository,
            uploadRepository: widget.uploadRepository,
            showOutsideFarmNotice: true,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Neuspjelo ucitavanje detalja roditelja.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _resolvingParents.remove(relationKey);
        });
      }
    }
  }

  Widget _buildParentField({
    required String label,
    required CattleParentRef? parent,
    required String fallback,
    required String relationKey,
    bool clickable = true,
  }) {
    final displayValue = _displayOrFallback(_parentDisplay(parent, fallback));
    final isLoading = _resolvingParents.contains(relationKey);
    final isClickable = clickable && parent != null && parent.hasValue;

    if (!isClickable) {
      return Text('$label: $displayValue');
    }

    return InkWell(
      key: Key('cattle-detail-parent-${relationKey.toLowerCase()}'),
      onTap: isLoading
          ? null
          : () => _openParent(relationKey: relationKey, parent: parent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$label: $displayValue',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.open_in_new, size: 18),
          ],
        ),
      ),
    );
  }

  Cattle _resolveDescendantProfile(CattleDescendant descendant) {
    final allCattle = widget.allCattle;
    for (final item in allCattle) {
      final matchesById =
          descendant.govedoId > 0 && item.id == descendant.govedoId;
      final matchesByNumber =
          descendant.zivotniBroj.trim().isNotEmpty &&
          item.zivotniBroj.trim().toUpperCase() ==
              descendant.zivotniBroj.trim().toUpperCase();
      if (matchesById || matchesByNumber) {
        return item;
      }
    }

    return Cattle(
      id: descendant.govedoId > 0 ? descendant.govedoId : descendant.id,
      zivotniBroj: descendant.zivotniBroj,
      ime: descendant.ime,
      spol: descendant.spol,
      datumTelenja: descendant.datumTelenja,
      uzrast: descendant.uzrast,
      posjed: '',
      majka: '',
      otac: '',
      imageUrl: '',
      thumbnailUrl: '',
      imageUrls: const [],
      potomci: const [],
      hasPotomciField: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cattle = widget.cattle;
    final allCattle = widget.allCattle;
    final uploadRepository = widget.uploadRepository;

    return Scaffold(
      appBar: AppBar(title: Text(cattle.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildImageSection(context),
          const SizedBox(height: 16),
          if (widget.showOutsideFarmNotice) ...[
            const Card(
              color: Color(0xFFFFF3CD),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('Govedo nije na aktivnom gospodarstvu.'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text('Posjed: ${_displayOrFallback(cattle.posjed)}'),
          Text('Rbr.: ${_displayOrFallback(cattle.redniBroj)}'),
          Text('Zivotni broj: ${cattle.zivotniBroj}'),
          Text('Ime: ${_displayOrFallback(cattle.ime)}'),
          Text('Spol: ${_displayOrFallback(cattle.spol)}'),
          Text('Pasmina: ${_displayOrFallback(cattle.pasmina)}'),
          Text('Datum telenja: ${_displayOrFallback(cattle.datumTelenja)}'),
          Text('Uzrast: ${_displayOrFallback(cattle.uzrast)}'),
          _buildParentField(
            label: 'Majka',
            parent: cattle.majkaRef,
            fallback: cattle.majka,
            relationKey: 'majka',
          ),
          _buildParentField(
            label: 'Otac',
            parent: cattle.otacRef,
            fallback: cattle.otac,
            relationKey: 'otac',
            clickable: false,
          ),
          if (cattle.potomci.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Potomci:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...cattle.potomci.map((descendant) {
              return Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text(
                    'Zivotni broj: ${_displayOrFallback(descendant.zivotniBroj)}',
                  ),
                  subtitle: Text(
                    'Ime: ${_displayOrFallback(descendant.ime)}\n'
                    'Datum telenja: ${_displayOrFallback(descendant.datumTelenja)}\n'
                    'Spol: ${_displayOrFallback(descendant.spol)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    final profile = _resolveDescendantProfile(descendant);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CattleDetailScreen(
                          cattle: profile,
                          allCattle: allCattle,
                          cattleRepository: widget.cattleRepository,
                          uploadRepository: uploadRepository,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    if (_galleryUrls.isEmpty) {
      return const _ImageFallback();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: PageView.builder(
              key: const Key('cattle-detail-pageview'),
              controller: _pageController,
              itemCount: _galleryUrls.length,
              onPageChanged: (value) {
                setState(() {
                  _currentImageIndex = value;
                });
              },
              itemBuilder: (context, index) {
                final url = _galleryUrls[index];
                return AppCachedNetworkImage(
                  key: Key('cattle-detail-main-image-$index'),
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  errorBuilder: const _ImageFallback(),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _galleryUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final url = _galleryUrls[index];
              final isSelected = index == _currentImageIndex;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  key: Key('cattle-detail-thumb-$index'),
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppCachedNetworkImage(
                      imageUrl: url,
                      width: 70,
                      height: 76,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: 70,
                        height: 76,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      errorBuilder: Container(
                        width: 70,
                        height: 76,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CattleListScreen extends StatefulWidget {
  const CattleListScreen({
    super.key,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.uploadRepository,
  });

  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final UploadRepository uploadRepository;

  @override
  State<CattleListScreen> createState() => _CattleListScreenState();
}

class _CattleListScreenState extends State<CattleListScreen> {
  static const List<String> _orderedUzrastGroups = <String>[
    'Bik',
    'Krava',
    'June',
    'Junica',
    'Tele muško',
    'Tele žensko',
  ];

  bool _loading = true;
  String? _error;
  List<Farm> _farms = const [];
  Farm? _activeFarm;
  List<Cattle> _cattle = const [];
  String _searchQuery = '';
  final Map<String, bool> _expandedGroups = <String, bool>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final farms = await widget.farmsRepository.fetchFarms();
      final farm = farms.isNotEmpty ? farms.first : null;
      final cattle = farm == null
          ? <Cattle>[]
          : await widget.cattleRepository.fetchCattleByFarm(farm.id);

      if (!mounted) return;
      setState(() {
        _farms = farms;
        _activeFarm = farm;
        _cattle = cattle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Neuspjelo ucitavanje podataka.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
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
      final cattle = await widget.cattleRepository.fetchCattleByFarm(farm.id);
      if (!mounted) return;
      setState(() {
        _cattle = cattle;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Neuspjelo ucitavanje goveda za gospodarstvo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String _compact(String value) {
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  static bool _matchesSearch(Cattle item, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return true;
    }

    final compactQuery = _compact(trimmed);
    final queryDigits = _digitsOnly(compactQuery);
    final isDigitsOnly =
        compactQuery.isNotEmpty && queryDigits.length == compactQuery.length;
    final cattleDigits = _digitsOnly(item.zivotniBroj);

    if (isDigitsOnly && queryDigits.length <= 4) {
      final lastFour = cattleDigits.length > 4
          ? cattleDigits.substring(cattleDigits.length - 4)
          : cattleDigits;
      return lastFour.contains(queryDigits);
    }

    final fullNumber = _compact(item.zivotniBroj).toUpperCase();
    return fullNumber.contains(compactQuery.toUpperCase());
  }

  List<Cattle> _filteredCattle() {
    return _cattle.where((item) => _matchesSearch(item, _searchQuery)).toList();
  }

  static String _uzrastGroupLabel(Cattle item) {
    final value = item.uzrast.trim();
    if (value.isEmpty) {
      return 'Nepoznato';
    }
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'bik':
        return 'Bik';
      case 'krava':
        return 'Krava';
      case 'junac':
      case 'june':
        return 'June';
      case 'junica':
        return 'Junica';
      case 'tele musko':
      case 'tele muÅ¡ko':
      case 'tele_musko':
        return 'Tele muško';
      case 'tele zensko':
      case 'tele Å¾ensko':
      case 'tele_zensko':
      case 'tele-z':
        return 'Tele žensko';
      default:
        return value;
    }
  }

  static Map<String, List<Cattle>> _groupCattleByUzrast(List<Cattle> cattle) {
    final grouped = <String, List<Cattle>>{};
    for (final item in cattle) {
      final key = _uzrastGroupLabel(item);
      grouped.putIfAbsent(key, () => <Cattle>[]).add(item);
    }
    return grouped;
  }

  static List<String> _sortGroupKeys(Map<String, List<Cattle>> groupedCattle) {
    final keys = groupedCattle.keys.toList();
    final known = <String>[];
    final unknown = <String>[];

    for (final key in keys) {
      if (_orderedUzrastGroups.contains(key)) {
        known.add(key);
      } else {
        unknown.add(key);
      }
    }

    known.sort(
      (a, b) => _orderedUzrastGroups.indexOf(a).compareTo(
        _orderedUzrastGroups.indexOf(b),
      ),
    );
    unknown.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return <String>[...known, ...unknown];
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    var contentHasInternalRefresh = false;
    final filteredCattle = _filteredCattle();
    final totalCattleCount = _cattle.length;
    final groupedCattle = _groupCattleByUzrast(filteredCattle);
    final groupedKeys = _sortGroupKeys(groupedCattle);

    if (_loading) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          FullScreenState(
            message: 'Ucitavanje...',
            icon: Icons.hourglass_empty,
          ),
        ],
      );
    } else if (_error != null) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          FullScreenState(
            message: _error!,
            icon: Icons.error_outline,
            actionLabel: 'Pokusaj ponovno',
            onAction: _loadData,
          ),
        ],
      );
    } else if (_farms.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          FullScreenState(
            message: 'Nema dostupnih gospodarstava za ovaj korisnicki racun.',
            icon: Icons.home_work_outlined,
          ),
        ],
      );
    } else if (_cattle.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 180),
          FullScreenState(
            message:
                'Nema aktivnih goveda za prikaz na gospodarstvu "${_activeFarm?.label ?? ''}".',
            icon: Icons.pets_outlined,
          ),
        ],
      );
    } else {
      final listChildren = <Widget>[];
      if (filteredCattle.isEmpty) {
        listChildren.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Nema goveda za uneseni kriterij pretrage.'),
            ),
          ),
        );
      } else {
        for (final groupKey in groupedKeys) {
          final cattleInGroup = groupedCattle[groupKey] ?? const <Cattle>[];
          final isExpanded = _expandedGroups[groupKey] ?? true;
          listChildren.add(
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ExpansionTile(
                key: PageStorageKey<String>('cattle-group-$groupKey'),
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedGroups[groupKey] = expanded;
                  });
                },
                title: Text(
                  '$groupKey (${cattleInGroup.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  ...cattleInGroup.map(
                    (item) => ListTile(
                      leading: _CattleAvatar(
                        imageUrl: item.thumbnailUrl.isNotEmpty
                            ? item.thumbnailUrl
                            : item.imageUrl,
                      ),
                      title: Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.zivotniBroj,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: item.posjed.trim().isEmpty
                          ? null
                          : SizedBox(
                              width: 96,
                              child: Text(
                                item.posjed,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                        builder: (_) => CattleDetailScreen(
                          cattle: item,
                          allCattle: _cattle,
                          cattleRepository: widget.cattleRepository,
                          uploadRepository: widget.uploadRepository,
                        ),
                      ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      contentHasInternalRefresh = true;
      content = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<Farm>(
              initialValue: _activeFarm,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Aktivno gospodarstvo',
              ),
              items: _farms
                  .map(
                    (farm) => DropdownMenuItem(
                      value: farm,
                      child: Text(
                        farm.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) => _farms
                  .map(
                    (farm) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        farm.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _loading ? null : _selectFarm,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: 'Pretraga po zivotnom broju',
                hintText: 'Npr. 6842 ili HR5201996842',
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: listChildren,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Goveda ($totalCattleCount)')),
      body: contentHasInternalRefresh
          ? content
          : RefreshIndicator(onRefresh: _loadData, child: content),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 40),
        ),
      ),
    );
  }
}

class _CattleAvatar extends StatelessWidget {
  const _CattleAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const width = 48.0;
    const height = 64.0;

    if (imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AppCachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: Container(
            width: width,
            height: height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorBuilder: const _AvatarFallback(),
        ),
      );
    }

    return const _AvatarFallback();
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    const width = 48.0;
    const height = 64.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.pets_outlined),
    );
  }
}
