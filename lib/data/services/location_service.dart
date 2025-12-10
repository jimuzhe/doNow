import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? address;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  String toString() => 'LocationResult(lat: $latitude, lng: $longitude, address: $address)';
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Platform channel for Amap on Android
  static const MethodChannel _amapChannel = MethodChannel('com.donow.app/amap_location');

  /// Get current location
  /// On Android: Uses Amap SDK (requires API Key in AndroidManifest.xml)
  /// On iOS/Web/Other: Uses Geolocator + Geocoding
  Future<LocationResult?> getCurrentLocation() async {
    // 1. Check Permissions (Universal)
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever');
        return null;
      }
    } catch (e) {
      debugPrint('Error checking permission: $e');
      // Continue anyway as Amap might handle it internally or we want to try
    }

    // 2. Platform Specific Logic
    if (!kIsWeb && Platform.isAndroid) {
      // Try Amap first on Android
      final amapResult = await _getAmapLocation();
      if (amapResult != null) {
        return amapResult;
      }
      // Fallback to system location if Amap fails
      debugPrint('Amap failed, falling back to system location');
    }
    
    return _getSystemLocation();
  }

  /// Get location using Amap SDK via platform channel (Android only)
  Future<LocationResult?> _getAmapLocation() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    try {
      final result = await _amapChannel.invokeMethod<Map<dynamic, dynamic>>('getLocation');
      
      if (result == null) {
        debugPrint('Amap returned null');
        return null;
      }

      final lat = result['latitude'] as double?;
      final lng = result['longitude'] as double?;
      final address = result['address'] as String?;

      if (lat != null && lng != null) {
        return LocationResult(
          latitude: lat,
          longitude: lng,
          address: address,
        );
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('Amap platform error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error getting Amap location: $e');
      return null;
    }
  }

  /// Get location using Geolocator + Geocoding (iOS/Web/fallback)
  Future<LocationResult?> _getSystemLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      String? addressText;
      
      // Reverse Geocoding (Not supported on Web)
      if (!kIsWeb) {
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 5));

          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final List<String> addressParts = [];
            
            if (p.street != null && p.street!.isNotEmpty && p.street != p.name) addressParts.add(p.street!);
            if (p.name != null && p.name!.isNotEmpty && !addressParts.contains(p.name)) {
               if (!RegExp(r'^\d+$').hasMatch(p.name!)) addressParts.add(p.name!);
            }
            if (p.subLocality != null && p.subLocality!.isNotEmpty && !addressParts.contains(p.subLocality)) {
              addressParts.add(p.subLocality!);
            }
            if (p.locality != null && p.locality!.isNotEmpty && !addressParts.contains(p.locality)) {
              addressParts.add(p.locality!);
            }
            
            if (addressParts.isNotEmpty) {
              addressText = addressParts.take(3).join(", ");
            }
          }
        } catch (e) {
          debugPrint('Geocoding error: $e');
        }
      } else {
        // Web: just coords
        addressText = "${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      }
      
      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        address: addressText,
      );
      
    } catch (e) {
      debugPrint('Error getting system location: $e');
      return null;
    }
  }
  
  void dispose() {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        _amapChannel.invokeMethod('dispose');
      } catch (_) {}
    }
  }
}
