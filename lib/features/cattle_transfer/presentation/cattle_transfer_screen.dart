import 'package:flutter/material.dart';

import '../../../core/widgets/screen_insets.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../cattle/data/cattle_repository.dart';
import '../../cattle/models/cattle.dart';
import '../../farms/data/farms_repository.dart';
import '../../farms/models/farm.dart';
import '../data/cattle_transfer_repository.dart';
import '../models/holding.dart';

class CattleTransferScreen extends StatefulWidget {
  const CattleTransferScreen({
    super.key,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.transferRepository,
  });

  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final CattleTransferRepository transferRepository;

  @override
  State<CattleTransferScreen> createState() => _CattleTransferScreenState();
}

class _CattleTransferScreenState extends State<CattleTransferScreen> {
  static const List<String> _orderedUzrastGroups = <String>[
    'Bik',
    'Krava',
    'June',
    'Junica',
    'Tele muško',
    'Tele žensko',
  ];

  final TextEditingController _searchController = TextEditingController();
  int _currentStep = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _message;
  StatusType _messageType = StatusType.info;
  List<Farm> _farms = const <Farm>[];
  Farm? _activeFarm;
  List<Holding> _holdings = const <Holding>[];
  List<Cattle> _cattle = const <Cattle>[];
  Holding? _originHolding;
  Holding? _destinationHolding;
  final List<Cattle> _selectedCattle = <Cattle>[];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final farms = await widget.farmsRepository.fetchFarms();
      final farm = farms.isNotEmpty ? farms.first : null;
      final holdings = farm == null
          ? const <Holding>[]
          : await widget.transferRepository.fetchHoldings(farm.id);
      final cattle = farm == null
          ? const <Cattle>[]
          : await widget.cattleRepository.fetchCattleByFarm(farm.id);

      if (!mounted) return;
      setState(() {
        _farms = farms;
        _activeFarm = farm;
        _holdings = holdings;
        _cattle = cattle;
      });
    } catch (_) {
      _setMessage(
        'Neuspjelo učitavanje podataka za premještanje.',
        StatusType.error,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _changeFarm(Farm? farm) async {
    if (farm == null) return;
    setState(() {
      _loading = true;
      _activeFarm = farm;
      _originHolding = null;
      _destinationHolding = null;
      _selectedCattle.clear();
      _currentStep = 0;
      _searchController.clear();
      _message = null;
    });

    try {
      final holdings = await widget.transferRepository.fetchHoldings(farm.id);
      final cattle = await widget.cattleRepository.fetchCattleByFarm(farm.id);
      if (!mounted) return;
      setState(() {
        _holdings = holdings;
        _cattle = cattle;
      });
    } catch (_) {
      _setMessage(
        'Neuspjelo učitavanje posjeda i goveda za odabrano gospodarstvo.',
        StatusType.error,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _setMessage(String message, StatusType type) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageType = type;
    });
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String _compact(String value) {
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  static String _normalizeLabel(String value) {
    return value.trim().toUpperCase();
  }

  bool _matchesSearch(Cattle item, String query) {
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

    final queryUpper = compactQuery.toUpperCase();
    final fullNumber = _compact(item.zivotniBroj).toUpperCase();
    final fullName = _compact(item.ime).toUpperCase();
    return fullNumber.contains(queryUpper) || fullName.contains(queryUpper);
  }

  bool _isCattleOnOrigin(Cattle cattle) {
    final origin = _originHolding;
    if (origin == null) {
      return false;
    }

    if (cattle.posjedVezaId > 0) {
      return cattle.posjedVezaId == origin.id;
    }

    return _normalizeLabel(cattle.posjed) == _normalizeLabel(origin.label);
  }

  List<Cattle> _availableCattle() {
    return _cattle
        .where(_isCattleOnOrigin)
        .where((item) => _matchesSearch(item, _searchController.text))
        .toList();
  }

  List<Holding> _destinationOptions() {
    final originId = _originHolding?.id;
    if (originId == null) {
      return _holdings;
    }
    return _holdings.where((holding) => holding.id != originId).toList();
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
      case 'tele muško':
      case 'tele_musko':
        return 'Tele muško';
      case 'tele zensko':
      case 'tele žensko':
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
      (a, b) => _orderedUzrastGroups
          .indexOf(a)
          .compareTo(_orderedUzrastGroups.indexOf(b)),
    );
    unknown.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return <String>[...known, ...unknown];
  }

  bool _isSelected(Cattle cattle) {
    return _selectedCattle.any((item) => item.id == cattle.id);
  }

  void _toggleSelection(Cattle cattle) {
    setState(() {
      final index = _selectedCattle.indexWhere((item) => item.id == cattle.id);
      if (index >= 0) {
        _selectedCattle.removeAt(index);
      } else {
        _selectedCattle.add(cattle);
      }
    });
  }

  bool _validateStepOne() {
    if (_activeFarm == null) {
      _setMessage(
        'Nema dostupnog gospodarstva za premještanje.',
        StatusType.warning,
      );
      return false;
    }
    if (_originHolding == null || _destinationHolding == null) {
      _setMessage('Odaberi polazni i odredišni posjed.', StatusType.warning);
      return false;
    }
    if (_originHolding!.id == _destinationHolding!.id) {
      _setMessage(
        'Polazni i odredišni posjed ne mogu biti isti.',
        StatusType.warning,
      );
      return false;
    }
    return true;
  }

  bool _validateStepTwo() {
    if (_selectedCattle.isEmpty) {
      _setMessage(
        'Odaberi barem jedno govedo za premještanje.',
        StatusType.warning,
      );
      return false;
    }
    return true;
  }

  Future<void> _submitTransfer() async {
    if (_submitting) return;
    if (!_validateStepOne() || !_validateStepTwo()) {
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final result = await widget.transferRepository.transferCattle(
        farmId: _activeFarm!.id,
        originId: _originHolding!.id,
        destinationId: _destinationHolding!.id,
        cattleIds: _selectedCattle.map((item) => item.id).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Premješteno ${result.movedCount} grla.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      _setMessage(
        e.toString().replaceFirst('Exception: ', ''),
        StatusType.error,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
    }
  }

  void _continueStep() {
    if (_currentStep == 0 && !_validateStepOne()) {
      return;
    }
    if (_currentStep == 1 && !_validateStepTwo()) {
      return;
    }
    if (_currentStep == 2) {
      _submitTransfer();
      return;
    }

    setState(() {
      _message = null;
      _currentStep += 1;
    });
  }

  void _cancelStep() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _message = null;
      _currentStep -= 1;
    });
  }

  Widget _buildStepOne() {
    final showNoHoldingsMessage =
        !_loading && _activeFarm != null && _holdings.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Farm>(
          key: const Key('cattle-transfer-farm-dropdown'),
          initialValue: _activeFarm,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Gospodarstvo'),
          items: _farms
              .map(
                (farm) => DropdownMenuItem<Farm>(
                  value: farm,
                  child: Text(
                    farm.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _loading || _submitting ? null : _changeFarm,
        ),
        if (showNoHoldingsMessage) ...[
          const SizedBox(height: 12),
          const InlineStatusMessage(
            message:
                'Nema dostupnih posjeda za odabrano gospodarstvo ili odgovor API-ja nije u prepoznatom formatu.',
            type: StatusType.warning,
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<Holding>(
          key: const Key('cattle-transfer-origin-dropdown'),
          initialValue: _originHolding,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Polazni posjed'),
          hint: const Text('Nema dostupnih posjeda'),
          items: _holdings
              .map(
                (holding) => DropdownMenuItem<Holding>(
                  value: holding,
                  child: Text(holding.label),
                ),
              )
              .toList(),
          onChanged: _loading || _submitting
              ? null
              : (value) {
                  setState(() {
                    _originHolding = value;
                    if (_destinationHolding?.id == value?.id) {
                      _destinationHolding = null;
                    }
                    _selectedCattle.clear();
                    _searchController.clear();
                  });
                },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Holding>(
          key: const Key('cattle-transfer-destination-dropdown'),
          initialValue: _destinationHolding,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Odredišni posjed'),
          hint: const Text('Nema dostupnih posjeda'),
          items: _destinationOptions()
              .map(
                (holding) => DropdownMenuItem<Holding>(
                  value: holding,
                  child: Text(holding.label),
                ),
              )
              .toList(),
          onChanged: _loading || _submitting
              ? null
              : (value) {
                  setState(() {
                    _destinationHolding = value;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildSelectedBuffer() {
    if (_selectedCattle.isEmpty) {
      return const Text('Nijedno govedo nije dodano u buffer.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _selectedCattle.map((item) {
        return Card(
          child: ListTile(
            key: Key('cattle-transfer-buffer-${item.id}'),
            title: Text(item.displayName),
            subtitle: Text(item.zivotniBroj),
            trailing: IconButton(
              onPressed: _submitting ? null : () => _toggleSelection(item),
              icon: const Icon(Icons.close),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepTwo() {
    final availableCattle = _availableCattle();
    final groupedCattle = _groupCattleByUzrast(availableCattle);
    final groupedKeys = _sortGroupKeys(groupedCattle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('cattle-transfer-search'),
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Pretraga goveda',
            hintText: 'Unesi životni broj ili ime',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) {
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Odabrana goveda (${_selectedCattle.length})',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _buildSelectedBuffer(),
        const SizedBox(height: 16),
        Text(
          'Goveda na polaznom posjedu (${availableCattle.length})',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (availableCattle.isEmpty)
          const Text('Nema goveda na odabranom polaznom posjedu.')
        else
          ...groupedKeys.expand((groupKey) {
            final cattleInGroup = groupedCattle[groupKey] ?? const <Cattle>[];
            return <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  '$groupKey (${cattleInGroup.length})',
                  key: Key('cattle-transfer-group-$groupKey'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              ...cattleInGroup.map((item) {
                final isSelected = _isSelected(item);
                return Card(
                  child: ListTile(
                    key: Key('cattle-transfer-cattle-${item.id}'),
                    title: Text(item.displayName),
                    subtitle: Text(
                      '${item.zivotniBroj}\nPosjed: ${item.posjed}',
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.add_circle_outline,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onTap: _submitting ? null : () => _toggleSelection(item),
                  ),
                );
              }),
            ];
          }),
      ],
    );
  }

  Widget _buildStepThree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gospodarstvo: ${_activeFarm?.label ?? "-"}'),
        Text('Polazni posjed: ${_originHolding?.label ?? "-"}'),
        Text('Odredišni posjed: ${_destinationHolding?.label ?? "-"}'),
        Text('Broj grla: ${_selectedCattle.length}'),
        const SizedBox(height: 16),
        const Text(
          'Odabrana goveda',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _buildSelectedBuffer(),
      ],
    );
  }

  Widget _buildStepHeader(BuildContext context) {
    const titles = <String>['1. Posjedi', '2. Goveda', '3. Potvrda'];
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: List<Widget>.generate(titles.length, (index) {
        final isActive = index == _currentStep;
        final isComplete = index < _currentStep;
        final background = isActive || isComplete
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest;
        final foreground = isActive || isComplete
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == titles.length - 1 ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              titles[index],
              textAlign: TextAlign.center,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _farms.isEmpty
        ? const FullScreenState(
            message: 'Nema dostupnih gospodarstava za premještanje.',
            icon: Icons.home_work_outlined,
          )
        : Column(
            children: [
              _buildStepHeader(context),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_currentStep) {
                    0 => _buildStepOne(),
                    1 => _buildStepTwo(),
                    _ => _buildStepThree(),
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(
                    key: const Key('cattle-transfer-continue'),
                    onPressed: (_loading || _submitting) ? null : _continueStep,
                    child: _submitting && _currentStep == 2
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == 2 ? 'Premjesti' : 'Dalje'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    key: const Key('cattle-transfer-cancel'),
                    onPressed: (_loading || _submitting) ? null : _cancelStep,
                    child: Text(_currentStep == 0 ? 'Odustani' : 'Natrag'),
                  ),
                ],
              ),
            ],
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Premještanje goveda')),
      body: SafeArea(
        top: false,
        bottom: true,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: screenBodyPadding(context, bottomSpacing: 0),
          child: Column(
            children: [
              if (_message != null) ...[
                InlineStatusMessage(message: _message!, type: _messageType),
                const SizedBox(height: 12),
              ],
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
