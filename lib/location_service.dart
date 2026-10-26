import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http show get;
import 'package:url_launcher/url_launcher.dart';

Future<void> _launchWalkingDirections() async {
  Position? position = await LocationService.getCurrentPosition();
  if (position == null) return;
  
  final lat = position.latitude;
  final lng = position.longitude;
  
  // Google Maps Universal URL enforcing walking travel mode
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');
  
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    debugPrint('Could not launch maps');
  }
}

class LocationService {
  /// Ensures permissions are granted. Returns true when permitted.
  static Future<bool> _handlePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Returns current position or null when permission is not granted.
  static Future<Position?> getCurrentPosition() async {
    final permitted = await _handlePermission();
    if (!permitted) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (_) {
      return null;
    }
  }
}

class JunctionAlertService {
  StreamSubscription? _positionStreamSubscription;
  bool _isMonitoring = false;
  
  static const String _apiKey = 'AIzaSyCdXnvqkVroxylctsYFPRULYBrjjhmxnIE';

  /// Starts monitoring the user's live position and checks nearby roads
  void startMonitoring(Function(String) onAlert) {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // Listen to real-time position updates while walking
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Trigger check every 10 meters walked
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        await _checkRoadsAndAlert(position.latitude, position.longitude, onAlert);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  /// Stops monitoring location
  void stopMonitoring() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isMonitoring = false;
  }

  /// Queries the Google Roads API with live coordinates
  Future _checkRoadsAndAlert(double lat, double lng, Function(String) onAlert) async {
    try {
      // Fixed string interpolation for coordinates
      final points = '$lat,$lng';
      final url = Uri.https(
        'roads.googleapis.com',
        '/v1/nearestRoads',
        {
          'points': points,
          'key': _apiKey,
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map;
        final snappedPoints = data['snappedPoints'] as List? ?? [];

        if (snappedPoints.isNotEmpty) {
          for (var point in snappedPoints) {
            final placeId = point['placeId'];
            // Fixed string interpolation for the alert message
            onAlert('Nearby road detected (Place ID: $placeId at lat:$lat, lng: $lng)');
          }
        } else {
          onAlert('Off-road or unmapped area detected.');
        }
      } else {
        debugPrint('Roads API failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking roads: $e');
    }
  }
}