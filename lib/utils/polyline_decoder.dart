import 'package:google_maps_flutter/google_maps_flutter.dart';

List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0;
  int latitude = 0;
  int longitude = 0;

  while (index < encoded.length) {
    int shift = 0;
    int result = 0;

    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    latitude += deltaLat;

    shift = 0;
    result = 0;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    longitude += deltaLng;

    points.add(LatLng(latitude / 1e5, longitude / 1e5));
  }

  return points;
}
