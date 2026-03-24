import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/bus_info.dart';

class BusLiveTrackingScreen extends StatefulWidget {
  final BusInfo bus;

  const BusLiveTrackingScreen({super.key, required this.bus});

  @override
  State<BusLiveTrackingScreen> createState() => _BusLiveTrackingScreenState();
}

class _BusLiveTrackingScreenState extends State<BusLiveTrackingScreen> {
  GoogleMapController? _mapController;
  bool _hasCenteredInitialCamera = false;
  bool _isResolvingRoute = false;
  String? _routeError;

  List<String> _routePointLabels = const [];
  List<LatLng> _routePolylinePoints = const [];
  Set<Marker> _routeStopMarkers = const {};

  @override
  void initState() {
    super.initState();
    _resolveRoutePolyline();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  List<String> _buildRouteLabels() {
    return <String>[
      if ((widget.bus.start ?? '').trim().isNotEmpty) widget.bus.start!.trim(),
      ...widget.bus.stops
          .map((stop) => stop.trim())
          .where((stop) => stop.isNotEmpty),
      if ((widget.bus.end ?? '').trim().isNotEmpty) widget.bus.end!.trim(),
    ];
  }

  Future<LatLng?> _geocodePlaceName(String place) async {
    try {
      final locations = await locationFromAddress(place);
      if (locations.isEmpty) return null;
      final first = locations.first;
      return LatLng(first.latitude, first.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolveRoutePolyline() async {
    final labels = _buildRouteLabels();
    if (labels.length < 2) {
      if (!mounted) return;
      setState(() {
        _routePointLabels = labels;
        _routePolylinePoints = const [];
        _routeStopMarkers = const {};
        _routeError = null;
      });
      return;
    }

    setState(() {
      _isResolvingRoute = true;
      _routeError = null;
      _routePointLabels = labels;
    });

    final points = <LatLng>[];
    final stopMarkers = <Marker>{};

    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      final latLng = await _geocodePlaceName(label);
      if (latLng == null) {
        continue;
      }
      points.add(latLng);
      stopMarkers.add(
        Marker(
          markerId: MarkerId('route_stop_$i'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == 0
                ? BitmapDescriptor.hueGreen
                : i == labels.length - 1
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title: i == 0
                ? 'Start'
                : i == labels.length - 1
                ? 'Destination'
                : 'Stop $i',
            snippet: label,
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _isResolvingRoute = false;
      _routePolylinePoints = points;
      _routeStopMarkers = stopMarkers;
      if (points.length < 2) {
        _routeError = 'Could not resolve full route points for polyline.';
      }
    });
  }

  Set<Marker> _buildMarkers({
    required LatLng busLatLng,
    required double heading,
  }) {
    return <Marker>{
      Marker(
        markerId: const MarkerId('bus_live_marker'),
        position: busLatLng,
        rotation: heading.isFinite ? heading : 0,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title: widget.bus.name,
          snippet: 'Bus No: ${widget.bus.number}',
        ),
      ),
    };
  }

  void _maybeAnimateCamera(LatLng position) {
    if (_mapController == null) return;

    final camera = CameraUpdate.newCameraPosition(
      CameraPosition(target: position, zoom: 16.5),
    );

    _mapController!.animateCamera(camera);
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _routePointLabels;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.bus.name),
            Text(
              'Live tracking - ${widget.bus.number}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bus_locations')
            .doc(widget.bus.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Failed to load live location.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final data = snapshot.data?.data();
          final lat = (data?['lat'] as num?)?.toDouble();
          final lng = (data?['lng'] as num?)?.toDouble();
          final heading = (data?['heading'] as num?)?.toDouble() ?? 0;
          final speed = (data?['speed'] as num?)?.toDouble() ?? 0;

          if (lat == null || lng == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Live tracking is not started for this bus yet.\nAsk the driver to open "Live Tracking" and tap Start.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
            );
          }

          final busLatLng = LatLng(lat, lng);
          if (!_hasCenteredInitialCamera) {
            _hasCenteredInitialCamera = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _maybeAnimateCamera(busLatLng);
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _maybeAnimateCamera(busLatLng);
            });
          }

          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: busLatLng,
                    zoom: 16.5,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  markers: {
                    ..._routeStopMarkers,
                    ..._buildMarkers(busLatLng: busLatLng, heading: heading),
                  },
                  polylines: _routePolylinePoints.length >= 2
                      ? {
                          Polyline(
                            polylineId: const PolylineId('bus_route_polyline'),
                            points: _routePolylinePoints,
                            color: Colors.blueAccent,
                            width: 5,
                          ),
                        }
                      : const {},
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF161616),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live speed: ${(speed * 3.6).toStringAsFixed(1)} km/h',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Position: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (routePoints.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Route: ${routePoints.join(' -> ')}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (_isResolvingRoute) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Resolving route polyline...',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ] else if (_routeError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _routeError!,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
