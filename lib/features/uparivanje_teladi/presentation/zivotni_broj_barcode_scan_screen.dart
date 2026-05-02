import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Puni zaslon: kamera + [MobileScanner], rezultat je prvi pročitan tekst barkoda.
class ZivotniBrojBarcodeScanScreen extends StatefulWidget {
  const ZivotniBrojBarcodeScanScreen({super.key});

  @override
  State<ZivotniBrojBarcodeScanScreen> createState() =>
      _ZivotniBrojBarcodeScanScreenState();
}

class _ZivotniBrojBarcodeScanScreenState
    extends State<ZivotniBrojBarcodeScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) {
      return;
    }
    for (final b in capture.barcodes) {
      final v = b.rawValue ?? b.displayValue;
      if (v != null && v.trim().isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop<String>(v.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Skeniraj životni broj'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop<String>(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Kamera nije dostupna: ${error.errorCode.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              'Držite barkod u kadru dok se ne pročita.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.85),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
