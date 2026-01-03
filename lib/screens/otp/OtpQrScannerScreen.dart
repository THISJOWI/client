import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:thisjowi/data/repository/otp_repository.dart';
import 'package:thisjowi/components/error_snack_bar.dart';

class OtpQrScannerScreen extends StatefulWidget {
  const OtpQrScannerScreen({super.key});

  @override
  State<OtpQrScannerScreen> createState() => _OtpQrScannerScreenState();
}

class _OtpQrScannerScreenState extends State<OtpQrScannerScreen> {
  late final OtpRepository _otpRepository;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool scanned = false;

  @override
  void initState() {
    super.initState();
    _otpRepository = OtpRepository();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processCode(String code) async {
    if (scanned) return;
    setState(() {
      scanned = true;
    });
    
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processCode(barcode.rawValue!);
                  return;
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Text(
                  'Error: ${error.errorCode}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            switch (state.torchState) {
                              case TorchState.off:
                                return const Icon(Icons.flash_off, color: Colors.grey);
                              case TorchState.on:
                                return const Icon(Icons.flash_on, color: Colors.yellow);
                              default:
                                return const Icon(Icons.flash_off, color: Colors.grey);
                            }
                          },
                        ),
                        onPressed: () => _controller.toggleTorch(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  "Scan QR Code",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
