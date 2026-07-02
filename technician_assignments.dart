import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Replace this dummy list with your actual customer list from Firestore when ready
const List<Map<String, dynamic>> customers = [
  {'id': 'cust1', 'name': 'Client A', 'latitude': 19.01, 'longitude': 72.85},
  {'id': 'cust2', 'name': 'Client B', 'latitude': 19.02, 'longitude': 72.86},
  {'id': 'cust3', 'name': 'Client C', 'latitude': 19.03, 'longitude': 72.87},
];

class TechnicianAssignments extends StatefulWidget {
  final String technicianId;
  final String technicianName;

  const TechnicianAssignments({
    Key? key,
    required this.technicianId,
    required this.technicianName,
  }) : super(key: key);

  @override
  State<TechnicianAssignments> createState() => _TechnicianAssignmentsState();
}

class _TechnicianAssignmentsState extends State<TechnicianAssignments> {
  late String todayDate;
  List<Map<String, dynamic>> assignedLocations = [];
  String? selectedCustomerId;

  @override
  void initState() {
    super.initState();
    todayDate = _getFormattedDate(DateTime.now());
    _loadAssignments();
  }

  String _getFormattedDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}'
           '${dt.month.toString().padLeft(2, '0')}'
           '${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAssignments() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('assignments')
        .doc(todayDate)
        .collection(widget.technicianId)
        .doc(widget.technicianId)
        .collection('customerVisits')
        .get();
    if (!mounted) return;
    setState(() {
      assignedLocations = snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'customerName': d['customerName'],
          'latitude': d['latitude'],
          'longitude': d['longitude'],
          'arrival': d['arrival'],
          'departure': d['departure'],
          'status': d['status'],
        };
      }).toList();
    });
  }

  Future<void> _addAssignment() async {
    if (selectedCustomerId == null) return;
    final c = customers.firstWhere((c) => c['id'] == selectedCustomerId);
    final ref = FirebaseFirestore.instance
        .collection('assignments')
        .doc(todayDate)
        .collection(widget.technicianId)
        .doc(widget.technicianId)
        .collection('customerVisits')
        .doc(selectedCustomerId);
    await ref.set({
      'customerName': c['name'],
      'latitude': c['latitude'],
      'longitude': c['longitude'],
      'radiusMeters': 50,
      'arrival': null,
      'departure': null,
      'status': 'pending',
    });
    await _loadAssignments();
    if (!mounted) return;
    setState(() => selectedCustomerId = null);
  }

  Future<void> _removeAssignment(String id) async {
    await FirebaseFirestore.instance
        .collection('assignments')
        .doc(todayDate)
        .collection(widget.technicianId)
        .doc(widget.technicianId)
        .collection('customerVisits')
        .doc(id)
        .delete();
    await _loadAssignments();
  }

  // Photon geocoding (OSM)
  Future<Map<String, double>?> geocodePhoton(String address) async {
    try {
      final url =
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(address)}&limit=1';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final jsonData = json.decode(res.body) as Map<String, dynamic>;
        final feats = jsonData['features'] as List<dynamic>;
        if (feats.isNotEmpty) {
          final geom = feats[0]['geometry'] as Map<String, dynamic>;
          final coords = geom['coordinates'] as List<dynamic>;
          return {'latitude': coords[1] as double, 'longitude': coords[0] as double};
        }
      }
    } catch (_) {}
    return null;
  }

  // Manual entry dialog with loading indicator
  void _showAddNewLocationDialog() {
    final parentCtx = context;
    final formKey = GlobalKey<FormState>();
    String name = '', addr = '';

    showDialog(
      context: parentCtx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add New Location'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                onChanged: (v) => name = v,
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Customer Address'),
                validator: (v) => v == null || v.isEmpty ? 'Enter address' : null,
                onChanged: (v) => addr = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              // Show loading spinner
              showDialog(
                context: dialogCtx,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              // Perform geocoding
              final geo = await geocodePhoton(addr);
              // Dismiss loading & input dialogs
              Navigator.pop(dialogCtx); // spinner
              Navigator.pop(parentCtx); // input
              final messenger = ScaffoldMessenger.of(parentCtx);
              if (geo == null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Location not found. Try a more specific address.',
                    ),
                  ),
                );
                return;
              }
              // Save assignment
              await _addManualAssignment(name, addr, geo['latitude']!, geo['longitude']!);
              messenger.showSnackBar(
                SnackBar(content: Text('Assigned: $name')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualAssignment(
      String name, String addr, double lat, double lng) async {
    final docRef = FirebaseFirestore.instance
        .collection('assignments')
        .doc(todayDate)
        .collection(widget.technicianId)
        .doc(widget.technicianId)
        .collection('customerVisits')
        .doc();
    await docRef.set({
      'customerName': name,
      'address': addr,
      'latitude': lat,
      'longitude': lng,
      'radiusMeters': 50,
      'arrival': null,
      'departure': null,
      'status': 'pending',
    });
    await _loadAssignments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Assignments for ${widget.technicianName}')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButton<String>(
              hint: const Text('Select Customer to Assign'),
              value: selectedCustomerId,
              onChanged: (v) => setState(() => selectedCustomerId = v),
              items: customers
                  .map((c) => DropdownMenuItem<String>(
                        value: c['id'],
                        child: Text(c['name']),
                      ))
                  .toList(),
            ),
            ElevatedButton(
              onPressed: _addAssignment,
              child: const Text('Add Assignment from list'),
            ),
            TextButton.icon(
              onPressed: _showAddNewLocationDialog,
              icon: const Icon(Icons.add_location_alt, color: Colors.blue),
              label: const Text(
                '+ Add New Location Manually',
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: assignedLocations.isEmpty
                  ? const Center(child: Text('No assignments yet'))
                  : ListView.builder(
                      itemCount: assignedLocations.length,
                      itemBuilder: (ctx, i) {
                        final a = assignedLocations[i];
                        return ListTile(
                          title: Text(a['customerName']),
                          subtitle: Text(
                            'Status: ${a['status']} - Arrival: ${a['arrival'] ?? 'N/A'}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeAssignment(a['id']),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
