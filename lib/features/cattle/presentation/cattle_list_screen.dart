import 'package:flutter/material.dart';

import '../../../core/widgets/status_widgets.dart';
import '../../farms/data/farms_repository.dart';
import '../../farms/models/farm.dart';
import '../../upload/data/upload_repository.dart';
import '../../upload/presentation/upload_screen.dart';
import '../data/cattle_repository.dart';
import '../models/cattle.dart';

class CattleDetailScreen extends StatelessWidget {
  const CattleDetailScreen({
    super.key,
    required this.cattle,
    required this.allCattle,
    required this.uploadRepository,
  });

  final Cattle cattle;
  final List<Cattle> allCattle;
  final UploadRepository uploadRepository;

  String _displayOrFallback(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Nije dostupno' : trimmed;
  }

  Cattle _resolveDescendantProfile(CattleDescendant descendant) {
    for (final item in allCattle) {
      final matchesById = descendant.govedoId > 0 && item.id == descendant.govedoId;
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
    return Scaffold(
      appBar: AppBar(title: Text(cattle.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (cattle.imageUrl.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  cattle.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _ImageFallback(),
                ),
              ),
            )
          else
            const _ImageFallback(),
          const SizedBox(height: 16),
          Text('Zivotni broj: ${cattle.zivotniBroj}'),
          Text('Ime: ${_displayOrFallback(cattle.ime)}'),
          Text('Spol: ${_displayOrFallback(cattle.spol)}'),
          Text('Datum telenja: ${_displayOrFallback(cattle.datumTelenja)}'),
          Text('Posjed: ${_displayOrFallback(cattle.posjed)}'),
          Text('Uzrast: ${_displayOrFallback(cattle.uzrast)}'),
          Text('Majka: ${_displayOrFallback(cattle.majka)}'),
          Text('Otac: ${_displayOrFallback(cattle.otac)}'),
          if (cattle.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Galerija slika',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cattle.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final url = cattle.imageUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 90,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 90,
                        height: 120,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (cattle.hasPotomciField) ...[
            const SizedBox(height: 12),
            const Text('Potomci:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (cattle.potomci.isEmpty)
              const Text('Nema dostupnih potomaka')
            else
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
}

class CattleListScreen extends StatefulWidget {
  const CattleListScreen({
    super.key,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.uploadRepository,
    required this.onLogout,
  });

  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final UploadRepository uploadRepository;
  final Future<void> Function() onLogout;

  @override
  State<CattleListScreen> createState() => _CattleListScreenState();
}

class _CattleListScreenState extends State<CattleListScreen> {
  bool _loading = true;
  String? _error;
  List<Farm> _farms = const [];
  Farm? _activeFarm;
  List<Cattle> _cattle = const [];
  String _searchQuery = '';
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
    return value;
  }

  static Map<String, List<Cattle>> _groupCattleByUzrast(List<Cattle> cattle) {
    final grouped = <String, List<Cattle>>{};
    for (final item in cattle) {
      final key = _uzrastGroupLabel(item);
      grouped.putIfAbsent(key, () => <Cattle>[]).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    var contentHasInternalRefresh = false;
    final filteredCattle = _filteredCattle();
    final totalCattleCount = _cattle.length;
    final groupedCattle = _groupCattleByUzrast(filteredCattle);
    final groupedKeys = groupedCattle.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
          listChildren.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '$groupKey (${cattleInGroup.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
          listChildren.addAll(
            cattleInGroup.map(
              (item) => Card(
                child: ListTile(
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
                          uploadRepository: widget.uploadRepository,
                        ),
                      ),
                    );
                  },
                ),
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
      appBar: AppBar(
        title: Text('Goveda ($totalCattleCount)'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: contentHasInternalRefresh
          ? content
          : RefreshIndicator(onRefresh: _loadData, child: content),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cattle.isEmpty
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UploadScreen(
                      cattle: _cattle,
                      repository: widget.uploadRepository,
                    ),
                  ),
                );
              },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Upload'),
      ),
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
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _AvatarFallback(),
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
