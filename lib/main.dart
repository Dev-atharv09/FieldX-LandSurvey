import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const LandSurveyApp());
}

class LandSurveyApp extends StatelessWidget {
  const LandSurveyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Land Survey',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> parcels = [];

  @override
  void initState() {
    super.initState();
    loadParcels();
  }

  Future<void> loadParcels() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString('parcels');

    if (data != null) {
      setState(() {
        parcels = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  Future<void> saveParcel(Map<String, dynamic> parcel) async {
    final prefs = await SharedPreferences.getInstance();

    parcels.add(parcel);

    await prefs.setString(
      'parcels',
      jsonEncode(parcels),
    );

    setState(() {});
  }

  void openSurveyForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyForm(
          onSave: saveParcel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Offline Land Survey',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: parcels.isEmpty
          ? const Center(
              child: Text(
                'No parcels surveyed yet',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: parcels.length,
              itemBuilder: (context, index) {
                final parcel = parcels[index];

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.landscape),
                    ),

                    title: Text(
                      'Khasra: ${parcel['khasra']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    subtitle: Text(
                      'Owner: ${parcel['owner']}\n'
                      'Area: ${parcel['area']}',
                    ),

                    isThreeLine: true,
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: openSurveyForm,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('New Survey'),
      ),
    );
  }
}

class SurveyForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const SurveyForm({
    super.key,
    required this.onSave,
  });

  @override
  State<SurveyForm> createState() => _SurveyFormState();
}

class _SurveyFormState extends State<SurveyForm> {
  final khasraController = TextEditingController();
  final ownerController = TextEditingController();
  final areaController = TextEditingController();

  Position? currentPosition;
  File? landPhoto;

  bool gettingLocation = false;

  Future<void> getLocation() async {
    setState(() {
      gettingLocation = true;
    });

    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      setState(() {
        gettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable GPS/location'),
        ),
      );

      return;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        gettingLocation = false;
      });

      return;
    }

    final position = await Geolocator.getCurrentPosition();

    setState(() {
      currentPosition = position;
      gettingLocation = false;
    });
  }

  Future<void> takePhoto() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        landPhoto = File(image.path);
      });
    }
  }

  Future<void> saveSurvey() async {
    if (khasraController.text.isEmpty ||
        ownerController.text.isEmpty ||
        areaController.text.isEmpty ||
        currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all details and capture GPS'),
        ),
      );

      return;
    }

    final parcel = {
      'khasra': khasraController.text,
      'owner': ownerController.text,
      'area': areaController.text,

      'latitude': currentPosition!.latitude,
      'longitude': currentPosition!.longitude,

      'photo': landPhoto?.path ?? '',

      'date': DateTime.now().toIso8601String(),
    };

    await widget.onSave(parcel);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Land Survey'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            TextField(
              controller: khasraController,
              decoration: const InputDecoration(
                labelText: 'Khasra / Survey Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: ownerController,
              decoration: const InputDecoration(
                labelText: 'Owner Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: areaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Land Area',
                hintText: 'Example: 2.5 acre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.square_foot),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: gettingLocation ? null : getLocation,

              icon: const Icon(Icons.gps_fixed),

              label: Text(
                gettingLocation
                    ? 'Getting Location...'
                    : currentPosition == null
                        ? 'Capture GPS Location'
                        : 'GPS Location Captured',
              ),
            ),

            if (currentPosition != null) ...[
              const SizedBox(height: 10),

              Text(
                'Latitude: ${currentPosition!.latitude}\n'
                'Longitude: ${currentPosition!.longitude}',
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: takePhoto,

              icon: const Icon(Icons.camera_alt),

              label: const Text('Capture Land Photo'),
            ),

            if (landPhoto != null) ...[
              const SizedBox(height: 15),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),

                child: Image.file(
                  landPhoto!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            const SizedBox(height: 30),

            FilledButton.icon(
              onPressed: saveSurvey,

              icon: const Icon(Icons.save),

              label: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'SAVE SURVEY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}