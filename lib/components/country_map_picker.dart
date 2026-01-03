import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:thisjowi/core/appColors.dart';

class CountryMapPicker extends StatefulWidget {
  const CountryMapPicker({super.key});

  @override
  State<CountryMapPicker> createState() => _CountryMapPickerState();
}

class _CountryMapPickerState extends State<CountryMapPicker> {
  final MapController _mapController = MapController();
  final LatLng _center = const LatLng(20.0, 0.0);
  String? _selectedCountry;
  LatLng? _selectedPoint;
  bool _loading = false;

  Future<void> _getCountryFromLatLng(LatLng point) async {
    setState(() {
      _loading = true;
      _selectedPoint = point;
    });

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=3');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'ThisJowiApp/1.0', 
        'Accept-Language': 'en'
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        if (address != null && address['country'] != null) {
          setState(() {
            _selectedCountry = address['country'];
          });
        } else {
           setState(() {
            _selectedCountry = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No country found at this location")),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error getting country: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Select Country", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedCountry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedCountry);
              },
              child: const Text("Confirm", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 2.0,
              onTap: (tapPosition, point) {
                _getCountryFromLatLng(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.thisjowi.app',
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.secondary,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            ),
          if (_selectedCountry != null && !_loading)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Card(
                color: const Color(0xFF202020),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "Selected: $_selectedCountry",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Tap 'Confirm' to use this country",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
