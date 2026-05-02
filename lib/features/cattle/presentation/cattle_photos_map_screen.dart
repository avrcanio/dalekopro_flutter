import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_cached_network_image.dart';
import '../models/cattle.dart';

/// Marker ključ slike s najnovijim `capturedAt` (jednako vrijeme → veći `id`).
String? _markerKeyForLatestCapturedPhoto(List<CattleGalleryPhoto> photos) {
  if (photos.isEmpty) return null;
  var best = photos.first;
  for (final p in photos.skip(1)) {
    final a = p.capturedAt!;
    final b = best.capturedAt!;
    if (a.isAfter(b)) {
      best = p;
    } else if (a == b && p.id > best.id) {
      best = p;
    }
  }
  return best.markerKey;
}

CattleGalleryPhoto? _photoForMarkerKey(
  List<CattleGalleryPhoto> photos,
  String? key,
) {
  if (key == null) return null;
  for (final p in photos) {
    if (p.markerKey == key) return p;
  }
  return null;
}

class CattlePhotosMapScreen extends StatefulWidget {
  const CattlePhotosMapScreen({super.key, required this.cattle});

  final Cattle cattle;

  @override
  State<CattlePhotosMapScreen> createState() => _CattlePhotosMapScreenState();
}

class _CattlePhotosMapScreenState extends State<CattlePhotosMapScreen> {
  final _dateFmt = DateFormat('dd.MM.yyyy HH:mm', 'hr');
  GoogleMapController? _controller;
  MapType _mapType = MapType.satellite;

  /// Odabrani marker — prilagođeni balon (slika + tekst) jer InfoWindow ne podržava slike.
  CattleGalleryPhoto? _selectedPhoto;
  /// Točka markera u **logičkim** pikselima u odnosu na GoogleMap (0,0 gore lijevo).
  Offset? _markerScreenPx;

  /// Izvorne slike (backend) ~ 909×1616 — visina thumba = širina × ovaj omjer.
  static const double _sourceImageWidth = 909;
  static const double _sourceImageHeight = 1616;
  static const double _pinClearance = 52;
  static const double _textPadding = 10;
  static const double _minBubbleWidth = 100;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _refreshMarkerScreenPoint() async {
    final photo = _selectedPhoto;
    final c = _controller;
    if (photo == null || c == null) {
      if (mounted) setState(() => _markerScreenPx = null);
      return;
    }
    final sc = await c.getScreenCoordinate(
      LatLng(photo.latitude!, photo.longitude!),
    );
    if (!mounted) return;
    // Na Androidu projection.toScreenLocation vraća piksele u gustoći zaslona;
    // Positioned u Stacku koristi logičke (dp) piksele — bez dijeljenja balon završi uz rub.
    final dpr = defaultTargetPlatform == TargetPlatform.android
        ? MediaQuery.devicePixelRatioOf(context)
        : 1.0;
    setState(() {
      _markerScreenPx = Offset(sc.x / dpr, sc.y / dpr);
    });
  }

  double _thumbHeight(double bubbleWidth) =>
      bubbleWidth * _sourceImageHeight / _sourceImageWidth;

  /// Širina balona = širina retka datuma/vremena + horizontalni padding (ime se lomi u tom stupcu).
  double _calloutWidth(BuildContext context, CattleGalleryPhoto photo) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final dateStr = _dateFmt.format(photo.capturedAt!.toLocal());
    final style = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final tp = TextPainter(
      text: TextSpan(text: dateStr, style: style),
      textScaler: scaler,
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return math.max(_minBubbleWidth, tp.width + _textPadding * 2);
  }

  double _calloutTextBlockHeight(
    BuildContext context,
    double bubbleWidth,
    CattleGalleryPhoto photo,
    String cattleName,
  ) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final maxTextW = bubbleWidth - _textPadding * 2;
    final dateStr = _dateFmt.format(photo.capturedAt!.toLocal());
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final tpDate = TextPainter(
      text: TextSpan(text: dateStr, style: titleStyle),
      textScaler: scaler,
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxTextW);
    final tpName = TextPainter(
      text: TextSpan(text: cattleName, style: bodyStyle),
      textScaler: scaler,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxTextW);
    return _textPadding * 2 + tpDate.height + 4 + tpName.height;
  }

  double _calloutTotalHeight(
    BuildContext context,
    double bubbleWidth,
    CattleGalleryPhoto photo,
    String cattleName,
  ) =>
      _thumbHeight(bubbleWidth) +
      _calloutTextBlockHeight(context, bubbleWidth, photo, cattleName);

  double _bubbleLeft(double mapWidth, double bubbleWidth) {
    final sx = _markerScreenPx!.dx;
    return (sx - bubbleWidth / 2).clamp(
      8.0,
      math.max(8.0, mapWidth - bubbleWidth - 8),
    );
  }

  double _bubbleTop(
    BuildContext context,
    double bubbleWidth,
    CattleGalleryPhoto photo,
    String cattleName,
  ) {
    final sy = _markerScreenPx!.dy;
    final h = _calloutTotalHeight(context, bubbleWidth, photo, cattleName);
    return sy - h - _pinClearance;
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.cattle.geoTaggedPhotos;
    final latestKey = _markerKeyForLatestCapturedPhoto(photos);
    final markers = <Marker>{
      for (final p in photos)
        Marker(
          markerId: MarkerId(p.markerKey),
          position: LatLng(p.latitude!, p.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            latestKey != null && p.markerKey == latestKey
                ? BitmapDescriptor.hueYellow
                : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(),
          onTap: () {
            setState(() => _selectedPhoto = p);
            _refreshMarkerScreenPoint();
          },
        ),
    };

    final first = photos.first;
    final initial = CameraPosition(
      target: LatLng(first.latitude!, first.longitude!),
      zoom: 15,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa slika'),
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Tip karte',
            onSelected: (type) => setState(() => _mapType = type),
            itemBuilder: (context) => [
              CheckedPopupMenuItem<MapType>(
                value: MapType.satellite,
                checked: _mapType == MapType.satellite,
                child: const Text('Satelit'),
              ),
              CheckedPopupMenuItem<MapType>(
                value: MapType.hybrid,
                checked: _mapType == MapType.hybrid,
                child: const Text('Satelit s nazivima'),
              ),
              CheckedPopupMenuItem<MapType>(
                value: MapType.normal,
                checked: _mapType == MapType.normal,
                child: const Text('Karta'),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              GoogleMap(
                initialCameraPosition: initial,
                mapType: _mapType,
                markers: markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                onMapCreated: (c) async {
                  _controller = c;
                  await _fitCamera(photos, c);
                  if (!mounted) return;
                  final initialPhoto =
                      _photoForMarkerKey(photos, latestKey) ?? photos.first;
                  setState(() => _selectedPhoto = initialPhoto);
                  await _refreshMarkerScreenPoint();
                },
                onCameraIdle: () {
                  _refreshMarkerScreenPoint();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _refreshMarkerScreenPoint();
                  });
                },
                onTap: (_) {
                  setState(() {
                    _selectedPhoto = null;
                    _markerScreenPx = null;
                  });
                },
              ),
              if (_selectedPhoto != null && _markerScreenPx != null)
                Builder(
                  builder: (ctx) {
                    final bubbleW = _calloutWidth(ctx, _selectedPhoto!);
                    final thumbH = _thumbHeight(bubbleW);
                    return Positioned(
                      left: _bubbleLeft(constraints.maxWidth, bubbleW),
                      top: _bubbleTop(
                        ctx,
                        bubbleW,
                        _selectedPhoto!,
                        widget.cattle.displayName,
                      ),
                      width: bubbleW,
                      child: _PhotoMapCallout(
                        photo: _selectedPhoto!,
                        cattleName: widget.cattle.displayName,
                        dateFmt: _dateFmt,
                        thumbWidth: bubbleW,
                        thumbHeight: thumbH,
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _fitCamera(
    List<CattleGalleryPhoto> photos,
    GoogleMapController c,
  ) async {
    if (photos.isEmpty) return;
    if (photos.length == 1) {
      final p = photos.first;
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(p.latitude!, p.longitude!),
          15,
        ),
      );
      return;
    }

    var minLat = photos.first.latitude!;
    var maxLat = minLat;
    var minLng = photos.first.longitude!;
    var maxLng = minLng;
    for (final p in photos) {
      final lat = p.latitude!;
      final lng = p.longitude!;
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLng = math.min(minLng, lng);
      maxLng = math.max(maxLng, lng);
    }

    if (minLat == maxLat && minLng == maxLng) {
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
    } catch (_) {
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          12,
        ),
      );
    }
  }
}

class _PhotoMapCallout extends StatelessWidget {
  const _PhotoMapCallout({
    required this.photo,
    required this.cattleName,
    required this.dateFmt,
    required this.thumbWidth,
    required this.thumbHeight,
  });

  final CattleGalleryPhoto photo;
  final String cattleName;
  final DateFormat dateFmt;
  final double thumbWidth;
  final double thumbHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Puna slika s backenda; UI je mali — memCache širina/visina ≈ widget × DPR za oštrinu.
    final fullUrl = photo.imageUrl.trim().isNotEmpty
        ? photo.imageUrl
        : photo.thumbnailUrl.trim();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (thumbWidth * dpr).round().clamp(1, 4096);
    final memH = (thumbHeight * dpr).round().clamp(1, 4096);

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: thumbWidth,
            height: thumbHeight,
            child: AppCachedNetworkImage(
              imageUrl: fullUrl,
              width: thumbWidth,
              height: thumbHeight,
              fit: BoxFit.cover,
              memCacheWidth: memW,
              memCacheHeight: memH,
              filterQuality: FilterQuality.medium,
              placeholder: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorBuilder: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dateFmt.format(photo.capturedAt!.toLocal()),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cattleName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
