import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AbsenPage extends StatefulWidget {
  const AbsenPage({super.key});

  @override
  State<AbsenPage> createState() => _AbsenPageState();
}

class _AbsenPageState extends State<AbsenPage> {
  List<dynamic> _listMurid = [];
  String? _selectedMuridId;
  XFile? _capturedImage;
  String? _locationString;
  bool _isLoading = false;
  bool _isFetchingMurid = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchMuridList();
  }

  // Ambil daftar murid dari Backend MySQL
  Future<void> _fetchMuridList() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/api/murid'));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        setState(() {
          _listMurid = resData['data'];
        });
      }
    } catch (e) {
      _showSnackBar('Gagal mengambil daftar murid dari server');
    } finally {
      setState(() => _isFetchingMurid = false);
    }
  }

  // Ambil Foto dari Kamera
  
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
    );
    if (photo != null) {
      setState(() => _capturedImage = photo);
    }
  }

  // Ambil Lokasi GPS
  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Aktifkan GPS pada perangkat/browser Anda');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Izin lokasi ditolak');
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _locationString = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    });
  }

  // Kirim Absen ke Backend
  Future<void> _submitAbsen() async {
    if (_selectedMuridId == null) {
      _showSnackBar('Pilih nama murid terlebih dahulu');
      return;
    }
    if (_capturedImage == null) {
      _showSnackBar('Ambil foto selfie terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);

    if (_locationString == null) {
      await _getLocation();
    }

    if (_locationString == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/api/absen'),
      );

      request.fields['murid_id'] = _selectedMuridId!;
      request.fields['lokasi'] = _locationString!;

      var bytes = await _capturedImage!.readAsBytes();
      var multipartFile = http.MultipartFile.fromBytes(
        'foto',
        bytes,
        filename: _capturedImage!.name,
      );

      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var resData = jsonDecode(response.body);

      if (response.statusCode == 201 && resData['success'] == true) {
        _showSnackBar('Absensi Berhasil Dikirim!');
        setState(() {
          _selectedMuridId = null;
          _capturedImage = null;
          _locationString = null;
        });
      } else {
        _showSnackBar(resData['message'] ?? 'Gagal mengirim absensi');
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke backend server');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Absensi Murid'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Login Admin',
            onPressed: () => Navigator.pushNamed(context, '/login'),
          )
        ],
      ),
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dropdown Pilihan Murid
                _isFetchingMurid
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _selectedMuridId,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Murid',
                          border: OutlineInputBorder(),
                        ),
                        items: _listMurid.map((murid) {
                          return DropdownMenuItem<String>(
                            value: murid['id'].toString(),
                            child: Text('${murid['nama']} (${murid['kelas']})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedMuridId = value);
                        },
                      ),
                const SizedBox(height: 16),

                // Preview Foto Selfie
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: _capturedImage != null
                      ? Image.network(_capturedImage!.path, fit: BoxFit.cover)
                      : const Center(child: Text('Foto selfie belum diambil')),
                ),
                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Ambil Foto Kamera'),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: _getLocation,
                  icon: const Icon(Icons.location_on),
                  label: Text(_locationString == null ? 'Dapatkan Lokasi GPS' : 'Lokasi: $_locationString'),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isLoading ? null : _submitAbsen,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('KIRIM ABSENSI', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}