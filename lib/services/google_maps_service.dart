import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingResult {
  final String formattedAddress;
  final LatLng location;

  GeocodingResult({
    required this.formattedAddress,
    required this.location,
  });
}

class DirectionResult {
  final List<LatLng> points;
  final String distanceText;
  final String durationText;

  DirectionResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
  });
}

class PlaceResultItem {
  final String name;
  final String address;
  final LatLng location;

  PlaceResultItem({
    required this.name,
    required this.address,
    required this.location,
  });
}

class GoogleMapsService {
  final String apiKey;

  GoogleMapsService(this.apiKey);

  Future<GeocodingResult?> geocodeAddress(String address) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': address,
        'key': apiKey,
        'language': 'vi',
        'region': 'vn',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Geocoding HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final result = (data['results'] as List).first as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return GeocodingResult(
      formattedAddress: result['formatted_address'] as String,
      location: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
    );
  }

  Future<DirectionResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    required String mode,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': mode,
        'alternatives': 'true',
        'key': apiKey,
        'language': 'vi',
        'region': 'vn',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Directions HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      return null;
    }

    final routes = data['routes'] as List;
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final overview = route['overview_polyline'] as Map<String, dynamic>;
    final legs = route['legs'] as List;
    final leg = legs.first as Map<String, dynamic>;
    final distance = leg['distance'] as Map<String, dynamic>;
    final duration = leg['duration'] as Map<String, dynamic>;

    return DirectionResult(
      points: _decodePolylineFallback(overview['points'] as String),
      distanceText: distance['text'] as String,
      durationText: duration['text'] as String,
    );
  }

  Future<List<PlaceResultItem>> searchPlaces(String query) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      {
        'query': query,
        'key': apiKey,
        'language': 'vi',
        'region': 'vn',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Places HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
      return [];
    }

    final results = (data['results'] as List?) ?? [];
    return results.map((item) {
      final map = item as Map<String, dynamic>;
      final geometry = map['geometry'] as Map<String, dynamic>;
      final location = geometry['location'] as Map<String, dynamic>;
      return PlaceResultItem(
        name: (map['name'] as String?) ?? 'Không tên',
        address: (map['formatted_address'] as String?) ?? '',
        location: LatLng(
          (location['lat'] as num).toDouble(),
          (location['lng'] as num).toDouble(),
        ),
      );
    }).toList();
  }

  List<LatLng> _decodePolylineFallback(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
