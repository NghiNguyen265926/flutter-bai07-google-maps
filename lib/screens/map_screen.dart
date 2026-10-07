import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config.dart';
import '../models/favorite_route.dart';
import '../services/database_helper.dart';
import '../services/google_maps_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _defaultPosition = LatLng(10.7769, 106.7009);

  final Completer<GoogleMapController> _mapController = Completer();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _placeController = TextEditingController();

  late final GoogleMapsService _mapsService;

  LatLng? _start;
  LatLng? _destination;
  String _mode = 'driving';
  String _modeLabel = 'Ô tô';
  String _distance = '';
  String _duration = '';
  String _status = 'Sẵn sàng.';
  bool _loading = false;
  bool _locationReady = false;

  final Set<Marker> _markers = <Marker>{};
  final Set<Polyline> _polylines = <Polyline>{};

  @override
  void initState() {
    super.initState();
    _mapsService = GoogleMapsService(AppConfig.googleApiKey);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _status = 'GPS đang tắt.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _status = 'Chưa được cấp quyền vị trí.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      _start = LatLng(position.latitude, position.longitude);
      _startController.text = _formatLatLng(_start!);
      _locationReady = true;

      _setMarker(
        _start!,
        'start',
        'Xuất phát - vị trí hiện tại',
      );

      if (AppConfig.hasGoogleApiKey && _mapController.isCompleted) {
        final controller = await _mapController.future;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_start!, 15),
        );
      }

      if (mounted) {
        setState(() {
          _status = 'Đã lấy vị trí hiện tại.';
        });
      }
    } catch (e) {
      setState(() => _status = 'Không lấy được vị trí: $e');
    }
  }

  String _formatLatLng(LatLng point) {
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  void _setMarker(LatLng point, String id, String title) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == id);
      _markers.add(
        Marker(
          markerId: MarkerId(id),
          position: point,
          infoWindow: InfoWindow(title: title),
        ),
      );
    });
  }

  Future<LatLng?> _resolveInput(String text) async {
    final value = text.trim();
    final parts = value.split(',');

    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    if (!AppConfig.hasGoogleApiKey) {
      _showMessage('Chưa có API key nên chưa thể đổi địa chỉ thành tọa độ.');
      return null;
    }

    final result = await _mapsService.geocodeAddress(value);
    if (result == null) {
      _showMessage('Không tìm thấy địa chỉ: $value');
      return null;
    }
    return result.location;
  }

  Future<void> _findRoute() async {
    FocusScope.of(context).unfocus();
    if (_startController.text.trim().isEmpty ||
        _endController.text.trim().isEmpty) {
      _showMessage('Vui lòng nhập điểm xuất phát và điểm đích.');
      return;
    }

    if (!AppConfig.hasGoogleApiKey) {
      setState(() {
        _status = 'Demo: phần kiểm tra dữ liệu đã chạy; cần API key để gọi Directions API.';
        _distance = 'Chưa có API key';
        _duration = 'Chưa có API key';
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final start = await _resolveInput(_startController.text);
      final end = await _resolveInput(_endController.text);
      if (start == null || end == null) return;

      _start = start;
      _destination = end;
      _setMarker(start, 'start', 'Xuất phát');
      _setMarker(end, 'end', 'Đích đến');

      final result = await _mapsService.getDirections(
        origin: start,
        destination: end,
        mode: _mode == 'motorcycle' ? 'driving' : _mode,
      );

      if (result == null) {
        _showMessage('Không tìm thấy tuyến đường.');
        return;
      }

      setState(() {
        _distance = result.distanceText;
        _duration = result.durationText;
        _status = 'Đã tìm thấy tuyến đường $_modeLabel.';
        _polylines
          ..clear()
          ..add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: result.points,
              width: 5,
              color: Colors.blue,
            ),
          );
      });

      if (_mapController.isCompleted) {
        final controller = await _mapController.future;
        await controller.animateCamera(CameraUpdate.newLatLngZoom(start, 13));
      }
    } catch (e) {
      _showMessage('Lỗi tìm đường: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setCurrentAsDestination() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage('Vui lòng bật GPS.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Chưa có quyền vị trí.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final current = LatLng(position.latitude, position.longitude);
      _destination = current;
      _endController.text = _formatLatLng(current);
      _setMarker(current, 'end', 'Đích đến - vị trí hiện tại');
      _showMessage('Đã lấy vị trí hiện tại làm điểm đích.');
    } catch (e) {
      _showMessage('Không lấy được vị trí hiện tại: $e');
    }
  }

  void _onMapTap(LatLng point) {
    _destination = point;
    _endController.text = _formatLatLng(point);
    _setMarker(point, 'end', 'Điểm đích đã chọn trên bản đồ');
    _showMessage('Đã chọn điểm đích trên bản đồ.');
  }

  Future<void> _searchPlace() async {
    final query = _placeController.text.trim();
    if (query.isEmpty) {
      _showMessage('Nhập từ khóa địa điểm trước.');
      return;
    }

    if (!AppConfig.hasGoogleApiKey) {
      _showMessage('Chưa có API key nên chưa gọi được Google Places API.');
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await _mapsService.searchPlaces(query);
      if (!mounted) return;

      if (results.isEmpty) {
        _showMessage('Không có kết quả.');
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Kết quả: $query'),
            content: SizedBox(
              width: 420,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length > 5 ? 5 : results.length,
                itemBuilder: (context, index) {
                  final item = results[index];
                  return ListTile(
                    leading: const Icon(Icons.place),
                    title: Text(item.name),
                    subtitle: Text(item.address),
                    onTap: () {
                      Navigator.pop(context);
                      _destination = item.location;
                      _endController.text = _formatLatLng(item.location);
                      _setMarker(item.location, 'end', item.name);
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showMessage('Lỗi tìm địa điểm: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveFavorite() async {
    if (_start == null || _destination == null || _distance.isEmpty) {
      _showMessage('Hãy tìm đường trước khi lưu yêu thích.');
      return;
    }

    final route = FavoriteRoute(
      start: _startController.text,
      destination: _endController.text,
      mode: _modeLabel,
      distance: _distance,
      duration: _duration,
      startLat: _start!.latitude,
      startLng: _start!.longitude,
      endLat: _destination!.latitude,
      endLng: _destination!.longitude,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertFavorite(route);
    _showMessage('Đã lưu tuyến đường vào yêu thích.');
  }

  Future<void> _showFavorites() async {
    final routes = await DatabaseHelper.instance.getFavorites();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.70,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: routes.isEmpty
                  ? const Center(child: Text('Chưa có tuyến yêu thích.'))
                  : ListView.separated(
                      itemCount: routes.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final route = routes[index];
                        return ListTile(
                          leading: const Icon(Icons.star),
                          title: Text('${route.start}\n→ ${route.destination}'),
                          subtitle: Text(
                            '${route.mode} | ${route.distance} | ${route.duration}',
                          ),
                          isThreeLine: true,
                          onTap: () {
                            _loadFavorite(route);
                            Navigator.pop(context);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (route.id != null) {
                                await DatabaseHelper.instance.deleteFavorite(route.id!);
                              }
                              Navigator.pop(context);
                              _showFavorites();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  void _loadFavorite(FavoriteRoute route) {
    _startController.text = route.start;
    _endController.text = route.destination;
    _distance = route.distance;
    _duration = route.duration;
    _modeLabel = route.mode;
    _mode = route.mode == 'Đi bộ' ? 'walking' : 'driving';
    _start = LatLng(route.startLat, route.startLng);
    _destination = LatLng(route.endLat, route.endLng);

    _setMarker(_start!, 'start', 'Xuất phát');
    _setMarker(_destination!, 'end', 'Đích đến');

    setState(() {
      _status = 'Đã nạp tuyến yêu thích. Bấm Tìm đường để vẽ lại route.';
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildMapArea() {
    if (!AppConfig.hasGoogleApiKey) {
      return Container(
        width: double.infinity,
        color: Colors.blueGrey.shade50,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 80),
                const SizedBox(height: 12),
                const Text(
                  'DEMO MODE - CHƯA CÓ GOOGLE MAPS API KEY',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ứng dụng vẫn chạy giao diện, nhập tọa độ và lưu tuyến. '
                  'Muốn hiện bản đồ thật, thay API key trong lib/config.dart '
                  'và AndroidManifest.xml.',
                  textAlign: TextAlign.center,
                ),
                if (_start != null) ...[
                  const SizedBox(height: 14),
                  Text('Vị trí hiện tại: ${_formatLatLng(_start!)}'),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _defaultPosition,
        zoom: 13,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onTap: _onMapTap,
      onMapCreated: (controller) {
        if (!_mapController.isCompleted) {
          _mapController.complete(controller);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bài 07 - Google Maps'),
        actions: [
          IconButton(
            onPressed: _showFavorites,
            tooltip: 'Tuyến yêu thích',
            icon: const Icon(Icons.star_border),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!AppConfig.hasGoogleApiKey)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.amber.shade100,
              child: const Text(
                'Chưa có API key: đang ở DEMO MODE. Không đưa API key thật lên GitHub.',
              ),
            ),
          Expanded(
            flex: 5,
            child: _buildMapArea(),
          ),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
              child: Column(
                children: [
                  TextField(
                    controller: _startController,
                    decoration: const InputDecoration(
                      labelText: 'Điểm xuất phát (địa chỉ hoặc lat,lng)',
                      prefixIcon: Icon(Icons.trip_origin),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _endController,
                    decoration: const InputDecoration(
                      labelText: 'Điểm đích (địa chỉ hoặc lat,lng)',
                      prefixIcon: Icon(Icons.flag),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _mode,
                          decoration: const InputDecoration(
                            labelText: 'Phương tiện',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'driving',
                              child: Text('Ô tô'),
                            ),
                            DropdownMenuItem(
                              value: 'walking',
                              child: Text('Đi bộ'),
                            ),
                            DropdownMenuItem(
                              value: 'motorcycle',
                              child: Text('Xe máy*'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _mode = value ?? 'driving';
                              _modeLabel = _mode == 'walking'
                                  ? 'Đi bộ'
                                  : (_mode == 'motorcycle' ? 'Xe máy*' : 'Ô tô');
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _findRoute,
                          icon: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.route),
                          label: const Text('Tìm đường'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Vị trí hiện tại'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _setCurrentAsDestination,
                          icon: const Icon(Icons.flag_circle),
                          label: const Text('Làm điểm đích'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _placeController,
                    decoration: InputDecoration(
                      labelText: 'Tìm địa điểm: khách sạn, quán ăn, bệnh viện...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _searchPlace,
                        icon: const Icon(Icons.send),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trạng thái: $_status'),
                          const SizedBox(height: 6),
                          Text('Khoảng cách: ${_distance.isEmpty ? '-' : _distance}'),
                          Text('Thời gian: ${_duration.isEmpty ? '-' : _duration}'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saveFavorite,
                                  icon: const Icon(Icons.star),
                                  label: const Text('Lưu yêu thích'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _polylines.clear();
                                      _distance = '';
                                      _duration = '';
                                      _status = 'Đã xóa route hiện tại.';
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Xóa route'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '* Bài yêu cầu xe máy. Google Directions API dùng mode driving cho lựa chọn này; nhãn xe máy được giữ ở giao diện để thể hiện yêu cầu bài tập.',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _locationReady
                                ? 'GPS: đã lấy vị trí.'
                                : 'GPS: chưa lấy được vị trí.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chọn điểm bằng cách click trên bản đồ: điểm vừa chọn sẽ được đặt làm điểm đích.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
