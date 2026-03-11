import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class BusInfo {
  final String name;
  final String number;
  final double distanceKm;

  const BusInfo({
    required this.name,
    required this.number,
    required this.distanceKm,
  });
}

class BusSearchScreen extends StatefulWidget {
  const BusSearchScreen({super.key});

  @override
  State<BusSearchScreen> createState() => _BusSearchScreenState();
}

class _BusSearchScreenState extends State<BusSearchScreen> {
  bool _isFetchingLocation = false;
  String? _locationLabel;
  String? _errorMessage;

  final TextEditingController _busSearchController = TextEditingController();
  BusInfo? _searchedBus;

  /// GET USER LOCATION
  Future<void> _fetchLocationAndNearbyBuses() async {
    if (_isFetchingLocation) return;

    setState(() {
      _isFetchingLocation = true;
      _errorMessage = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission denied.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      setState(() {
        _locationLabel =
            '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  /// SEARCH BUS FROM FIRESTORE
  Future<void> _searchBusByNumber() async {
    final query = _busSearchController.text.trim().toUpperCase();

    if (query.isEmpty) {
      setState(() {
        _searchedBus = null;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('buses')
          .where('busNumber', isEqualTo: query)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No bus found with that number.';
        });
        return;
      }

      final data = snap.docs.first.data();

      setState(() {
        _searchedBus = BusInfo(
          name: data['busName'] ?? 'Bus $query',
          number: data['busNumber'] ?? query,
          distanceKm: 0,
        );
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch bus.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "BusBee",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  /// LOCATION BUTTON
                  ElevatedButton.icon(
                    onPressed: _fetchLocationAndNearbyBuses,
                    icon: const Icon(Icons.my_location),
                    label: Text(_locationLabel ?? "Use Location"),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              /// SEARCH FIELD
              TextField(
                controller: _busSearchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search by Bus Number",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchBusByNumber,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// RESULT
              if (_searchedBus != null) _BusCard(bus: _searchedBus!),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  final BusInfo bus;

  const _BusCard({required this.bus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_bus, color: Colors.white),
          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bus.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Bus No: ${bus.number}",
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),

          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        ],
      ),
    );
  }
}
