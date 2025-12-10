// Amap implementation for Android
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';

AmapFlutterLocation? _amapLocation;
StreamSubscription<Map<String, Object>>? _amapSubscription;

/// Get location using Amap SDK (Android only)
Future<Map<String, dynamic>?> getAmapLocation() async {
  // Only run on Android
  if (kIsWeb || !Platform.isAndroid) {
    return null;
  }
  
  try {
    // Required privacy agreement for Amap
    AmapFlutterLocation.updatePrivacyShow(true, true);
    AmapFlutterLocation.updatePrivacyAgree(true);
    
    _amapLocation ??= AmapFlutterLocation();
    
    final completer = Completer<Map<String, dynamic>?>();
    
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
      _amapSubscription?.cancel();
      _amapLocation!.stopLocation();
      
      // Parse result
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
        completer.complete({
          'latitude': lat,
          'longitude': lng,
          'address': (address != null && address.isNotEmpty) ? address : null,
        });
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

double? _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is String) return double.tryParse(value);
  return null;
}

void disposeAmap() {
  _amapSubscription?.cancel();
  _amapLocation?.stopLocation();
  _amapLocation?.destroy();
}
