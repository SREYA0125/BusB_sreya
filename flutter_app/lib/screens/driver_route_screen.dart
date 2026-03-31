import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'driver_tracking_screen.dart';

class DriverRouteScreen extends StatefulWidget {
  final String busId;
  final String busName;
  final String busNumber;

  const DriverRouteScreen({
    super.key,
    required this.busId,
    required this.busName,
    required this.busNumber,
  });

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _stopInputController = TextEditingController();

  final List<String> _stopsList = [];

  bool _isSaving = false;
  bool _isLoading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingRoute();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _stopInputController.dispose();
    super.dispose();
  }

  /// LOAD EXISTING ROUTE
  Future<void> _loadExistingRoute() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busId)
          .get();

      final data = doc.data();

      if (data != null) {
        final start = data['start'] as String?;
        final end = data['end'] as String?;
        final stops = (data['stops'] as List?)
            ?.map((e) => e.toString())
            .toList();

        if (start != null) _startController.text = start;
        if (end != null) _endController.text = end;

        if (stops != null && stops.isNotEmpty) {
          _stopsList
            ..clear()
            ..addAll(stops);
        }
      }
    } catch (e) {
      _statusMessage = 'Could not load previous route details.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// ADD STOP
  void _addStop() {
    final stop = _stopInputController.text.trim();

    if (stop.isEmpty) return;

    if (_stopsList.any(
      (existing) => existing.toLowerCase() == stop.toLowerCase(),
    )) {
      setState(() {
        _statusMessage = 'This stop is already added.';
      });
      return;
    }

    setState(() {
      _stopsList.add(stop);
      _stopInputController.clear();
      _statusMessage = null;
    });
  }

  /// REMOVE STOP
  void _removeStop(int index) {
    setState(() {
      _stopsList.removeAt(index);
    });
  }

  /// SAVE ROUTE
  Future<void> _saveRoute() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final start = _startController.text.trim();
    final end = _endController.text.trim();
    final stops = List<String>.from(_stopsList);

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busId)
          .set({
            'routeName': '$start - $end',
            'start': start,
            'end': end,
            'stops': stops,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Route saved successfully.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to save route.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// OPEN ROUTE IN GOOGLE MAPS
  Future<void> _openInGoogleMaps() async {
    final start = _startController.text.trim();
    final end = _endController.text.trim();

    if (start.isEmpty || end.isEmpty) {
      setState(() {
        _statusMessage = 'Enter both start and end locations first.';
      });
      return;
    }

    String? busLocationParam;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bus_locations')
          .doc(widget.busId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final lat = data['lat'];
        final lng = data['lng'];
        if (lat != null && lng != null) {
          busLocationParam = '$lat,$lng';
        }
      }
    } catch (_) {
      // Ignore and proceed without live location
    }

    String url =
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${Uri.encodeComponent(start)}'
        '&destination=${Uri.encodeComponent(end)}'
        '&travelmode=driving';

    final List<String> waypointsList = [];
    if (busLocationParam != null) {
      waypointsList.add(busLocationParam);
    }
    if (_stopsList.isNotEmpty) {
      waypointsList.addAll(_stopsList);
    }

    if (waypointsList.isNotEmpty) {
      url += '&waypoints=${waypointsList.map(Uri.encodeComponent).join('|')}';
    }

    final uri = Uri.parse(url);

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      setState(() {
        _statusMessage = 'Could not open Google Maps.';
      });
    }
  }

  /// OPEN LIVE TRACKING
  void _openLiveTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverTrackingScreen(busId: widget.busId),
      ),
    );
  }

  /// INPUT STYLE
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF0B1120),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
    );
  }

  /// STOP CHIP
  Widget _buildStopChip(String stop, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${index + 1}. $stop',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _removeStop(index),
            child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: const Text('Driver Route'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              )
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        /// BUS INFO
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1120),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.busName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Bus Number: ${widget.busNumber}",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// START
                        TextFormField(
                          controller: _startController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("Starting point"),
                          validator: (v) =>
                              v == null || v.isEmpty ? "Enter start" : null,
                        ),

                        const SizedBox(height: 14),

                        /// END
                        TextFormField(
                          controller: _endController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("Ending point"),
                          validator: (v) => v == null || v.isEmpty
                              ? "Enter destination"
                              : null,
                        ),

                        const SizedBox(height: 14),

                        /// ADD STOP FIELD
                        TextFormField(
                          controller: _stopInputController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration("Add intermediate stop"),
                          onFieldSubmitted: (_) => _addStop(),
                        ),

                        const SizedBox(height: 10),

                        OutlinedButton(
                          onPressed: _addStop,
                          child: const Text("Add Stop"),
                        ),

                        const SizedBox(height: 14),

                        /// STOPS LIST
                        if (_stopsList.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(
                              _stopsList.length,
                              (i) => _buildStopChip(_stopsList[i], i),
                            ),
                          ),

                        const SizedBox(height: 20),

                        /// STATUS
                        if (_statusMessage != null)
                          Text(
                            _statusMessage!,
                            style: const TextStyle(color: Colors.white70),
                          ),

                        const SizedBox(height: 20),

                        /// MAP + SAVE
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _openInGoogleMaps,
                                child: const Text("Open Maps"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveRoute,
                                child: const Text("Save Route"),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        ElevatedButton(
                          onPressed: _openLiveTracking,
                          child: const Text("Open Live Tracking"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
