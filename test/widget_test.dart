import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/features/cattle/models/cattle.dart';

void main() {
  test('uses potomci when present', () {
    final cattle = Cattle.fromApi({
      'govedo': {
        'id': 1,
        'zivotni_broj': 'HR1',
        'ime': 'Mila',
        'potomci': [
          {'id': 2, 'govedo_id': 2, 'zivotni_broj': 'HR2', 'ime': 'Lina'},
        ],
      },
    });

    expect(cattle.hasPotomciField, isTrue);
    expect(cattle.potomci.length, 1);
    expect(cattle.potomci.first.zivotniBroj, 'HR2');
    expect(cattle.potomci.first.govedoId, 2);
  });

  test('hides potomci section when potomci is null', () {
    final cattle = Cattle.fromApi({
      'govedo': {
        'id': 1,
        'zivotni_broj': 'HR1',
        'ime': 'Mila',
        'potomci': null,
      },
    });

    expect(cattle.hasPotomciField, isFalse);
    expect(cattle.potomci, isEmpty);
  });

  test('fallbacks for optional detail fields', () {
    final cattle = Cattle.fromApi({
      'govedo': {'id': 1, 'zivotni_broj': 'HR1', 'ime': 'Mila'},
    });

    expect(cattle.uzrast, '');
    expect(cattle.majka, '');
    expect(cattle.otac, '');
    expect(cattle.majkaRef, isNull);
    expect(cattle.otacRef, isNull);
  });

  test('maps posjed from root entry when missing in govedo', () {
    final cattle = Cattle.fromApi({
      'posjed': {'naziv': 'Kuca'},
      'govedo': {
        'id': 1,
        'zivotni_broj': 'HR1',
        'ime': 'Mila',
      },
    });

    expect(cattle.posjed, 'Kuca');
  });

  test('maps majka and otac structured refs', () {
    final cattle = Cattle.fromApi({
      'govedo': {
        'id': 314,
        'zivotni_broj': 'HR 5201996842',
        'ime': 'JOVICA',
        'majka': {
          'id': 114,
          'zivotni_broj': 'HR 1201164650',
          'ime': 'BELA B126',
        },
        'otac': {
          'id': 1,
          'hb_broj': '87000000158',
          'ime': 'JABLAN LB4',
        },
      },
    });

    expect(cattle.majkaRef, isNotNull);
    expect(cattle.majkaRef!.id, 114);
    expect(cattle.majkaRef!.broj, 'HR 1201164650');
    expect(cattle.majkaRef!.ime, 'BELA B126');

    expect(cattle.otacRef, isNotNull);
    expect(cattle.otacRef!.id, 1);
    expect(cattle.otacRef!.broj, '87000000158');
    expect(cattle.otacRef!.ime, 'JABLAN LB4');
  });

  test('maps redni broj and pasmina from animals payload', () {
    final cattle = Cattle.fromApi({
      'redni_broj': 7,
      'govedo': {
        'id': 314,
        'zivotni_broj': 'HR 5201996842',
        'ime': 'JOVICA',
        'pasmina': {
          'id': 87,
          'naziv': 'Busa',
        },
      },
    });

    expect(cattle.redniBroj, '7');
    expect(cattle.pasmina, 'Busa');
  });

  test('prefers full image url over thumbnail in gallery items', () {
    final cattle = Cattle.fromApi({
      'govedo': {
        'id': 1,
        'zivotni_broj': 'HR1',
        'ime': 'Mila',
        'slike': [
          {
            'thumbnail_url': '/media/thumb-same.jpg',
            'image_url': '/media/full-1.jpg',
          },
          {
            'thumbnail_url': '/media/thumb-same.jpg',
            'image_url': '/media/full-2.jpg',
          },
        ],
      },
    });

    expect(cattle.imageUrls, hasLength(2));
    expect(cattle.imageUrls[0], endsWith('/media/full-1.jpg'));
    expect(cattle.imageUrls[1], endsWith('/media/full-2.jpg'));
    expect(cattle.imageUrl, endsWith('/media/full-1.jpg'));
  });

  test('prefers image_url over url when both exist in gallery item map', () {
    final cattle = Cattle.fromApi({
      'govedo': {
        'id': 1,
        'zivotni_broj': 'HR1',
        'ime': 'Mila',
        'slike': [
          {
            'url': '/media/thumb-shared.jpg',
            'image_url': '/media/full-1.jpg',
          },
          {
            'url': '/media/thumb-shared.jpg',
            'image_url': '/media/full-2.jpg',
          },
        ],
      },
    });

    expect(cattle.imageUrls, hasLength(2));
    expect(cattle.imageUrls[0], endsWith('/media/full-1.jpg'));
    expect(cattle.imageUrls[1], endsWith('/media/full-2.jpg'));
  });
}
