import 'package:flutter/material.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:thisjowi/data/repository/otp_repository.dart';
import 'package:thisjowi/components/error_snack_bar.dart';

class OtpQrScannerScreen extends StatefulWidget {
  const OtpQrScannerScreen({super.key});

  @override
  State<OtpQrScannerScreen> createState() => _OtpQrScannerScreenState();
}

class _OtpQrScannerScreenState extends State<OtpQrScannerScreen> {
  late final OtpRepository _otpRepository;
  bool scanned = false;

  @override
  void initState() {
    super.initState();
    _otpRepository = OtpRepository();
  }

  Future<void> _processCode(String code) async {
    if (scanned) return;
    scanned = true;
    
    if (code.startsWith('otpauth://')) {
      final result = await _otpRepository.addOtpFromUri(code, '');
      if (mounted) {
        if (result['success'] == true) {
          ErrorSnackBar.showSuccess(context, 'OTP added');
          Navigator.pop(context, true);
        } else {
          ErrorSnackBar.show(context, result['message'] ?? 'Error');
          Navigator.pop(context, false);
        }
      }
    } else {
      if (mounted) {
        ErrorSnackBar.show(context, 'Invalid QR');
        Navigator.pop(context, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AiBarcodeScanner(
      onDetect: (BarcodeCapture capture) {
        final List<Barcode> barcodes = capture.barcodes;
        for (final barcode in barcodes) {
          if (barcode.rawValue != null) {
            _processCode(barcode.rawValue!);
            return;
          }
        }
      },
      controller: MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      ),
      onDispose: () {
        debugPrint("Barcode scanner disposed!");
      },
    );
  }
}
