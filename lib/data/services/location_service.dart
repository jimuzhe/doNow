import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';

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

  // Amap instance
  AmapFlutterLocation? _amapLocation;
  StreamSubscription<Map<String, Object>>? _amapSubscription;

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
      return _getAmapLocation();
    } else {
      return _getSystemLocation();
    }
  }

  /// Get location using Amap SDK (Android)
  Future<LocationResult?> _getAmapLocation() async {
    try {
      // Required privacy agreement for Amap
      AmapFlutterLocation.updatePrivacyShow(true, true);
      AmapFlutterLocation.updatePrivacyAgree(true);
      
      _amapLocation ??= AmapFlutterLocation();
      
      final completer = Completer<LocationResult?>();
      
      // Configure options
      final options = AMapLocationOption(
        onceLocation: true,
        needAddress: true,
        geoLanguage: GeoLanguage.DEFAULT,
        desiredLocationAccuracyAuthorizationMode: AMapLocationAccuracyAuthorizationMode.ReduceAccuracy,
        locationInterval: 2000,
      );
      
      _amapLocation!.setLocationOption(options);
      
      _amapSubscription?.cancel();
      _amapSubscription = _amapLocation!.onLocationChanged().listen((Map<String, Object> result) {
        // debugPrint('Amap Result: $result');
        _amapSubscription?.cancel();
        _amapLocation!.stopLocation();
        
        // Parse result
        // Amap returns strings for lat/lng usually, or doubles. Handle both.
        final lat = _parseDouble(result['latitude']);
        final lng = _parseDouble(result['longitude']);
        final address = result['address'] as String?;
        final errorCode = result['errorCode'] as int? ?? 0;
        final errorInfo = result['errorInfo'] as String?;
        
        if (errorCode != 0) {
          debugPrint('Amap Error: $errorCode - $errorInfo');
          completer.complete(null);
          return;
        }

        if (lat != null && lng != null) {
          completer.complete(LocationResult(
            latitude: lat,
            longitude: lng,
            address: (address != null && address.isNotEmpty) ? address : null,
          ));
        } else {
          completer.complete(null);
        }
      });

      _amapLocation!.startLocation();
      
      return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
        _amapLocation!.stopLocation();
        _amapSubscription?.cancel();
        return null;
      });
      
    } catch (e) {
      debugPrint('Error getting Amap location: $e');
      return null;
    }
  }

  /// Get location using Geolocator + Geocoding (iOS/Web)
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

  double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is String) return double.tryParse(value);
    return null;
  }
  
  void dispose() {
    _amapSubscription?.cancel();
    _amapLocation?.stopLocation();
    _amapLocation?.destroy();
  }
}
