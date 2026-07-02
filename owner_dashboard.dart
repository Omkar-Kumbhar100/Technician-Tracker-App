import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';

// Import the TechnicianAssignments widget
import 'technician_assignments.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({Key? key}) : super(key: key);

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _techniciansList = [];
  List<Map<String, dynamic>> _filteredTechnicians = [];
  String _searchQuery = '';
  String? _selectedTechId;
  Map<String, dynamic>? _popupTech;

  // Location history storage & loading state
  List<Map<String, dynamic>> _techLocationHistory = [];
  bool _isLoadingHistory = false;

  // Polyline for technician route on map
  List<LatLng> _historyPolyline = [];

  // Add locationHistory record (for testing)
  Future<void> addLocationToHistory({
    required String technicianId,
    required double latitude,
    required double longitude,
  }) async {
    await FirebaseFirestore.instance
        .collection('technicians')
        .doc(technicianId)
        .collection('locationHistory')
        .add({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Fetch location history for technician
  Future<List<Map<String, dynamic>>> fetchLocationHistory(String technicianId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('technicians')
        .doc(technicianId)
        .collection('locationHistory')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'timestamp': data['timestamp'],
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _listenTechnicians();
  }

  void _listenTechnicians() {
    FirebaseFirestore.instance
        .collection('technicians')
        .where('online', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final technicianEntries = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final latitude = data['latitude'];
        final longitude = data['longitude'];
        final technicianName = data['Name'] ?? 'Technician';
        if (latitude != null && longitude != null) {
          final lat = latitude is double ? latitude : double.tryParse(latitude.toString());
          final lng = longitude is double ? longitude : double.tryParse(longitude.toString());
          if (lat != null && lng != null) {
            technicianEntries.add({
              'uid': doc.id,
              'name': technicianName,
              'lat': lat,
              'lng': lng,
            });
          }
        }
      }
      setState(() {
        _techniciansList = technicianEntries;
        _applySearch();
        if (_selectedTechId != null &&
            !_techniciansList.any((t) => t['uid'] == _selectedTechId)) {
          _selectedTechId = null;
          _popupTech = null;
          _techLocationHistory = [];
          _historyPolyline = [];
        }
      });
    });
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredTechnicians = List.from(_techniciansList);
    } else {
      _filteredTechnicians = _techniciansList
          .where((t) => (t['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  // Navigate to TechnicianAssignments screen on technician card tap
  void _onTechListTap(Map<String, dynamic> tech) {
    // Open assignments screen here
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TechnicianAssignments(
          technicianId: tech['uid'],
          technicianName: tech['name'],
        ),
      ),
    );
  }

  // Keep marker tap showing location history and route polyline
  void _onMarkerTap(Map<String, dynamic> tech) async {
    setState(() {
      _selectedTechId = tech['uid'];
      _popupTech = tech;
      _isLoadingHistory = true;
      _techLocationHistory = [];
      _historyPolyline = [];
    });

    final history = await fetchLocationHistory(tech['uid']);

    setState(() {
      _techLocationHistory = history;
      _isLoadingHistory = false;
      _historyPolyline = history
          .map((point) => LatLng(
                (point['latitude'] as num).toDouble(),
                (point['longitude'] as num).toDouble(),
              ))
          .toList();
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyApp()),
      (route) => false,
    );
  }

  void _fitMapToMarkers() {
    if (_techniciansList.isEmpty) return;
    double minLat = _techniciansList[0]['lat'];
    double maxLat = _techniciansList[0]['lat'];
    double minLng = _techniciansList[0]['lng'];
    double maxLng = _techniciansList[0]['lng'];

    for (var tech in _techniciansList) {
      final lat = tech['lat'];
      final lng = tech['lng'];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    final sw = LatLng(minLat - 0.01, minLng - 0.01);
    final ne = LatLng(maxLat + 0.01, maxLng + 0.01);

    _mapController.fitBounds(
      LatLngBounds(sw, ne),
      options: const FitBoundsOptions(padding: EdgeInsets.all(60)),
    );
  }

  List<Marker> _buildMarkers() {
    return _techniciansList.map((tech) {
      final isSelected = tech['uid'] == _selectedTechId;
      return Marker(
        point: LatLng(tech['lat'], tech['lng']),
        width: 130,
        height: 90,
        child: GestureDetector(
          onTap: () => _onMarkerTap(tech),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withOpacity(0.85) : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                  border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                ),
                child: Text(
                  tech['name'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Icon(
                Icons.location_pin,
                color: isSelected ? Colors.blue : Colors.red,
                size: isSelected ? 46 : 40,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPopup() {
    if (_popupTech == null) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: Material(
        elevation: 9,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.account_circle, size: 38, color: Colors.blue.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _popupTech!['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Latitude: ${_popupTech!['lat'].toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Longitude: ${_popupTech!['lng'].toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _popupTech = null),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Owner Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: 'Fit to all technicians',
            onPressed: _fitMapToMarkers,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search technician name...',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _applySearch();
                    });
                  },
                ),
              ),
              Expanded(
                flex: 5,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(20.5937, 78.9629),
                    zoom: 5,
                    onTap: (_, __) => setState(() {
                      _popupTech = null;
                      _selectedTechId = null;
                      _techLocationHistory = [];
                      _historyPolyline = [];
                    }),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.technician_tracker',
                    ),
                    MarkerLayer(markers: _buildMarkers()),

                    // Draw route polyline for selected technician's history
                    PolylineLayer(
                      polylines: _historyPolyline.isNotEmpty
                          ? [
                              Polyline(
                                points: _historyPolyline,
                                color: Colors.blue,
                                strokeWidth: 5,
                              ),
                            ]
                          : [],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 110,
                child: _filteredTechnicians.isEmpty
                    ? const Center(child: Text("No technicians online"))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filteredTechnicians.length + 1, // Extra for test button
                        itemBuilder: (context, index) {
                          if (index == _filteredTechnicians.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (_filteredTechnicians.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No technicians available')),
                                    );
                                    return;
                                  }
                                  final technicianId = _selectedTechId ?? _filteredTechnicians[0]['uid'];
                                  await addLocationToHistory(
                                    technicianId: technicianId,
                                    latitude: 18.5204,
                                    longitude: 73.8567,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Location history added for technician $technicianId',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Test Add Location History'),
                              ),
                            );
                          }

                          final tech = _filteredTechnicians[index];
                          final isSelected = tech['uid'] == _selectedTechId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: GestureDetector(
                              onTap: () => _onTechListTap(tech),  // <-- Navigate to assignments here
                              child: Container(
                                width: 140,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.07),
                                      blurRadius: 3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      tech['name'] ?? 'Technician',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Lat: ${tech['lat'].toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Lng: ${tech['lng'].toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // Popup for technician info
          if (_popupTech != null) _buildPopup(),

          // Location history panel with close button
          if (_selectedTechId != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              height: 200,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Close Button Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Close history panel',
                            onPressed: () {
                              setState(() {
                                _selectedTechId = null;
                                _popupTech = null;
                                _techLocationHistory = [];
                                _historyPolyline = [];
                              });
                            },
                          ),
                        ],
                      ),

                      // Location History List or Loader
                      Expanded(
                        child: _isLoadingHistory
                            ? const Center(child: CircularProgressIndicator())
                            : _techLocationHistory.isEmpty
                                ? const Center(child: Text('No location history found'))
                                : ListView.builder(
                                    itemCount: _techLocationHistory.length,
                                    itemBuilder: (context, index) {
                                      final entry = _techLocationHistory[index];
                                      final Timestamp? ts = entry['timestamp'] as Timestamp?;
                                      final dateTime = ts != null ? ts.toDate() : null;
                                      final timeString = dateTime != null
                                          ? '${dateTime.year.toString().padLeft(4, '0')}-'
                                              '${dateTime.month.toString().padLeft(2, '0')}-'
                                              '${dateTime.day.toString().padLeft(2, '0')} '
                                              '${dateTime.hour.toString().padLeft(2, '0')}:'
                                              '${dateTime.minute.toString().padLeft(2, '0')}:'
                                              '${dateTime.second.toString().padLeft(2, '0')}'
                                          : 'Unknown time';

                                      return ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        leading: const Icon(Icons.location_on, color: Colors.blue),
                                        title: Text(
                                          'Lat: ${entry['latitude'].toStringAsFixed(5)}, '
                                          'Lng: ${entry['longitude'].toStringAsFixed(5)}',
                                        ),
                                        subtitle: Text(timeString),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
