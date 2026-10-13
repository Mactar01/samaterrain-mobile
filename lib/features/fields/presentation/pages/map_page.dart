import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../data/field_options.dart';
import '../bloc/field_cubit.dart';

/// Carte des terrains, avec la position du joueur (point bleu) suivie en direct.
class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _dakar = LatLng(14.6928, -17.4467);
  static final _money = NumberFormat.decimalPattern('fr_FR');

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  LatLng? _me;
  bool _mapReady = false;
  bool _centeredOnce = false;
  String? _locationIssue;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationIssue = 'Activez la localisation du téléphone pour voir votre position.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationIssue = 'Autorisez la localisation pour voir votre position sur la carte.');
        return;
      }

      setState(() => _locationIssue = null);
      final first = await Geolocator.getCurrentPosition();
      _onPosition(first);

      // Mise à jour quand le joueur se déplace d'au moins 10 m
      _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen(_onPosition);
    } catch (_) {
      if (mounted) setState(() => _locationIssue = 'Position introuvable pour le moment.');
    }
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    setState(() => _me = LatLng(p.latitude, p.longitude));
    if (!_centeredOnce) {
      _centeredOnce = true;
      _centerOnMe();
    }
  }

  void _centerOnMe() {
    if (_me == null) {
      _startLocation();
      return;
    }
    if (_mapReady) _mapController.move(_me!, 14);
  }

  String _price(dynamic v) {
    final n = v is num ? v : num.tryParse('${v ?? ''}');
    return n == null ? '' : '${_money.format(n.round())} FCFA / h';
  }

  void _showField(BuildContext context, dynamic field) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${field['city'] ?? ''} · ${fieldTypeLabel(field['type'])}', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text(_price(field['price_per_hour']), style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_me != null) ...[
                const SizedBox(height: 4),
                Text('À ${_distance(field)} de vous', style: TextStyle(color: Colors.grey.shade700)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push('/field/${field['id']}');
                  },
                  child: const Text('Voir le terrain'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LatLng? _fieldPoint(dynamic field) {
    final lat = double.tryParse('${field['latitude'] ?? ''}');
    final lng = double.tryParse('${field['longitude'] ?? ''}');
    return (lat == null || lng == null) ? null : LatLng(lat, lng);
  }

  String _distance(dynamic field) {
    final point = _fieldPoint(field);
    if (point == null || _me == null) return '';
    final meters = const Distance().as(LengthUnit.Meter, _me!, point);
    return meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte des terrains')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ma position',
        onPressed: _centerOnMe,
        child: const Icon(Icons.my_location),
      ),
      body: BlocBuilder<FieldCubit, FieldState>(
        builder: (context, state) {
          final fields = state is FieldLoaded ? state.fields : <dynamic>[];

          final fieldMarkers = fields.where((f) => _fieldPoint(f) != null).map((field) {
            return Marker(
              point: _fieldPoint(field)!,
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => _showField(context, field),
                child: const Icon(Icons.location_on, color: Colors.red, size: 44),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _me ?? _dakar,
                  initialZoom: 12,
                  onMapReady: () {
                    _mapReady = true;
                    if (_me != null) _mapController.move(_me!, 14);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.my_terrain',
                  ),
                  MarkerLayer(markers: fieldMarkers),
                  if (_me != null)
                    MarkerLayer(markers: [
                      Marker(point: _me!, width: 24, height: 24, child: const _MyLocationDot()),
                    ]),
                ],
              ),
              if (state is FieldLoading) const LinearProgressIndicator(),
              if (_locationIssue != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.location_off),
                      title: Text(_locationIssue!, style: const TextStyle(fontSize: 14)),
                      trailing: TextButton(
                        onPressed: () async {
                          if (await Geolocator.checkPermission() == LocationPermission.deniedForever) {
                            await Geolocator.openAppSettings();
                          } else if (!await Geolocator.isLocationServiceEnabled()) {
                            await Geolocator.openLocationSettings();
                          }
                          _startLocation();
                        },
                        child: const Text('Activer'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Point bleu « vous êtes ici », comme dans les applis de carte.
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
    );
  }
}
