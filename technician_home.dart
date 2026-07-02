import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'main.dart'; // for MyApp reference

class TechnicianHomePage extends StatefulWidget {
  const TechnicianHomePage({Key? key}) : super(key: key);

  @override
  State<TechnicianHomePage> createState() => _TechnicianHomePageState();
}

class _TechnicianHomePageState extends State<TechnicianHomePage> {
  bool isSharingLocation = false;
  StreamSubscription<Position>? _positionSub;

  String? technicianName;
  String? contactInfo;
  String? technicianId;
  bool isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadTechnicianProfile();
  }

  Future<void> _loadTechnicianProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => isLoadingProfile = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('technicians').doc(uid).get();
      final data = doc.data();
      if (mounted && data != null) {
        setState(() {
          technicianName = data['Name'] ?? 'No Name';
          contactInfo = data['email'] ?? 'No Email';
          technicianId = data['techId'] ?? 'No Technician ID';
          isLoadingProfile = false;
        });
      } else {
        setState(() {
          technicianName = 'No Name';
          contactInfo = 'No Email';
          technicianId = 'No Technician ID';
          isLoadingProfile = false;
        });
      }
    } catch (e) {
      // Error fetching profile
      setState(() {
        technicianName = 'Error loading name';
        contactInfo = 'Error loading email';
        technicianId = 'Error loading ID';
        isLoadingProfile = false;
      });
    }
  }

  Future<void> _toggleLocationSharing() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (isSharingLocation) {
      await _positionSub?.cancel();
      _positionSub = null;
      await FirebaseFirestore.instance.collection('technicians').doc(uid).update({'online': false});
      setState(() => isSharingLocation = false);
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions denied')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('technicians').doc(uid).set({'online': true}, SetOptions(merge: true));

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen((Position pos) {
      FirebaseFirestore.instance.collection('technicians').doc(uid).update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    setState(() => isSharingLocation = true);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MyApp()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingProfile) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Technician Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Name: $technicianName',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Email: $contactInfo',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Technician ID: $technicianId',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _toggleLocationSharing,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isSharingLocation ? 'Stop Sharing Location' : 'Start Sharing Location',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
