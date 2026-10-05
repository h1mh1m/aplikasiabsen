import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AbsenPage extends StatefulWidget {
  const AbsenPage({super.key});

  @override
  State<AbsenPage> createState() => _AbsenPageState();
}

class _AbsenPageState extends State<AbsenPage> {
  // State Data Murid
  List<dynamic> _listMurid = [];
  String? _selectedMuridId;
  Map<String, dynamic>? _selectedMuridData;
  bool _isFetchingMurid = true;

  // State Kamera & Foto
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraLoading = false;
  bool _isCameraInitialized = false;
  String? _cameraErrorMessage;
  XFile? _capturedImage;
  Uint8List? _capturedBytes;

  // State GPS
  String? _locationString;
  bool _isFetchingLocation = false;

  // State Submit
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchMuridList();
    _initCamera();
    _getLocation();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. FETCH DAFTAR MURID (API Tetap Sama)
  // ==========================================
  Future<void> _fetchMuridList() async {
    setState(() => _isFetchingMurid = true);
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/api/murid'));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _listMurid = resData['data'] ?? [];
          });
        }
      } else {
        _showSnackBar('Gagal memuat data murid (${response.statusCode})', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal terhubung ke backend server: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingMurid = false);
      }
    }
  }

  // ==========================================
  // 2. LOGIKA KAMERA & AKSES PERMISSION
  // ==========================================
  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _isCameraLoading = true;
      _cameraErrorMessage = null;
    });

    try {
      // Pada Android / iOS, minta izin runtime jika belum diberikan
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            setState(() {
              _isCameraLoading = false;
              _cameraErrorMessage = 'Izin kamera ditolak. Silakan izinkan akses kamera di pengaturan perangkat.';
            });
          }
          return;
        }
      }

      // Ambil daftar kamera perangkat
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraLoading = false;
            _cameraErrorMessage = 'Tidak ada perangkat kamera yang terdeteksi pada sistem ini.';
          });
        }
        return;
      }

      // Prioritaskan kamera depan (front camera) untuk foto selfie presensi
      int frontCameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = (frontCameraIndex != -1) ? frontCameraIndex : 0;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraLoading = false;
          _isCameraInitialized = false;
          _cameraErrorMessage = 'Gagal mengakses kamera: $e\nPastikan Anda memberikan izin kamera pada browser/perangkat Anda.';
        });
      }
    }
  }

  Future<void> _setupCameraController(CameraDescription description) async {
    final oldController = _cameraController;
    if (oldController != null) {
      _cameraController = null;
      await oldController.dispose();
    }

    final newController = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await newController.initialize();
      if (!mounted) {
        await newController.dispose();
        return;
      }

      setState(() {
        _cameraController = newController;
        _isCameraInitialized = true;
        _isCameraLoading = false;
        _cameraErrorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraLoading = false;
          _isCameraInitialized = false;
          _cameraErrorMessage = 'Gagal menginisialisasi kamera: $e';
        });
      }
    }
  }

  // Mengganti antara kamera depan dan belakang
  Future<void> _switchCamera() async {
    if (_cameras.length <= 1) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() => _isCameraLoading = true);
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  // Mengambil foto dari streaming kamera langsung
  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showSnackBar('Kamera belum siap, silakan tunggu sebentar.', isError: true);
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List bytes = await photo.readAsBytes();
      if (mounted) {
        setState(() {
          _capturedImage = photo;
          _capturedBytes = bytes;
        });
      }
    } catch (e) {
      _showSnackBar('Gagal mengambil gambar dari kamera: $e', isError: true);
    }
  }

  // Ambil ulang foto (membuka kembali kamera)
  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _capturedBytes = null;
    });
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _initCamera();
    }
  }

  // Fallback: Memilih foto dari Galeri / File
  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (photo != null) {
        final Uint8List bytes = await photo.readAsBytes();
        if (mounted) {
          setState(() {
            _capturedImage = photo;
            _capturedBytes = bytes;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Gagal memilih gambar dari galeri: $e', isError: true);
    }
  }

  // ==========================================
  // 3. LOGIKA LOKASI GPS
  // ==========================================
  Future<void> _getLocation() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Aktifkan GPS / Lokasi pada browser atau perangkat Anda', isError: true);
        setState(() => _isFetchingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Izin akses lokasi ditolak', isError: true);
          setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Izin lokasi diblokir permanen. Mohon izinkan pada pengaturan peramban/perangkat.', isError: true);
        setState(() => _isFetchingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _locationString = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal mendeteksi lokasi GPS: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  // ==========================================
  // 4. KIRIM ABSENSI KE BACKEND (API Tetap Sama)
  // ==========================================
  Future<void> _submitAbsen() async {
    if (_selectedMuridId == null) {
      _showSnackBar('Harap pilih data murid terlebih dahulu!', isError: true);
      return;
    }
    if (_capturedImage == null || _capturedBytes == null) {
      _showSnackBar('Silakan ambil foto selfie terlebih dahulu!', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    // Ambil lokasi jika belum ada
    if (_locationString == null) {
      await _getLocation();
    }

    if (_locationString == null) {
      setState(() => _isSubmitting = false);
      _showSnackBar('Lokasi GPS diperlukan untuk melakukan absensi!', isError: true);
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/api/absen'),
      );

      request.fields['murid_id'] = _selectedMuridId!;
      request.fields['lokasi'] = _locationString!;

      var multipartFile = http.MultipartFile.fromBytes(
        'foto',
        _capturedBytes!,
        filename: _capturedImage!.name.isNotEmpty ? _capturedImage!.name : 'selfie.jpg',
      );

      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var resData = jsonDecode(response.body);

      if (response.statusCode == 201 && resData['success'] == true) {
        if (!mounted) return;
        _showSuccessDialog();
        setState(() {
          _selectedMuridId = null;
          _selectedMuridData = null;
          _capturedImage = null;
          _capturedBytes = null;
        });
      } else {
        _showSnackBar(resData['message'] ?? 'Gagal mengirim absensi', isError: true);
      }
    } catch (e) {
      _showSnackBar('Gagal terhubung ke backend server: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 44),
              ),
              const SizedBox(height: 18),
              const Text(
                'Presensi Berhasil!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Data kehadiran dan foto verifikasi Anda telah berhasil dicatat oleh sistem.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop, size: 20, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Koordinat: $_locationString',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK, SELESAI', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // 5. BUILD INTERFACE USER (UI MODERN & RAPI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Presensi Siswa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Sistem Kehadiran Digital',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
              label: const Text('Portal Admin', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    _buildHeaderBanner(),
                    const SizedBox(height: 24),

                    // STEP 1: Pilih Identitas Siswa
                    _buildStepSection(
                      stepNumber: '1',
                      title: 'Pilih Data Siswa',
                      subtitle: 'Pilih nama Anda sesuai daftar kelas',
                      child: _buildStudentDropdown(),
                    ),
                    const SizedBox(height: 24),

                    // STEP 2: Verifikasi Kamera Selfie
                    _buildStepSection(
                      stepNumber: '2',
                      title: 'Foto Selfie Presensi',
                      subtitle: 'Pastikan wajah terlihat jelas dan tegak',
                      child: _buildCameraSection(),
                    ),
                    const SizedBox(height: 24),

                    // STEP 3: Verifikasi GPS
                    _buildStepSection(
                      stepNumber: '3',
                      title: 'Titik Lokasi GPS',
                      subtitle: 'Deteksi koordinat lokasi saat melakukan presensi',
                      child: _buildLocationSection(),
                    ),
                    const SizedBox(height: 32),

                    // Tombol Submit
                    _buildSubmitButton(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Form Kehadiran Harian',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Lengkapi nama, ambil foto selfie, dan verifikasi titik koordinat lokasi Anda.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSection({
    required String stepNumber,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Text(
                stepNumber,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildStudentDropdown() {
    if (_isFetchingMurid) {
      return Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Memuat daftar siswa dari database...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedMuridId),
          initialValue: _selectedMuridId,
          decoration: InputDecoration(
            labelText: 'Pilih Nama Siswa',
            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF2563EB)),
            suffixIcon: _listMurid.isEmpty
                ? IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _fetchMuridList,
                    tooltip: 'Muat Ulang',
                  )
                : null,
          ),
          hint: const Text('Cari nama Anda...', style: TextStyle(fontSize: 14)),
          items: _listMurid.map((murid) {
            final idStr = murid['id'].toString();
            final nama = murid['nama'] ?? '-';
            final kelas = murid['kelas'] ?? '-';
            final nis = murid['nis'] ?? '-';
            return DropdownMenuItem<String>(
              value: idStr,
              child: Text(
                '$nama • $kelas ($nis)',
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedMuridId = value;
              _selectedMuridData = _listMurid.firstWhere(
                (m) => m['id'].toString() == value,
                orElse: () => null,
              );
            });
          },
        ),
        if (_selectedMuridData != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    (_selectedMuridData!['nama'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMuridData!['nama'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Kelas: ${_selectedMuridData!['kelas']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NIS: ${_selectedMuridData!['nis']}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCameraSection() {
    // 1. Kondisi jika foto SUDAH diambil
    if (_capturedBytes != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Image.memory(
                _capturedBytes!,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              // Badge status sukses foto
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Foto Selfie Siap', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              // Tombol ambil ulang
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _retakePhoto,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Foto Ulang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Ganti File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Kondisi kamera sedang loading
    if (_isCameraLoading) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Menghubungkan ke kamera...',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Kondisi error kamera (izin ditolak / kamera tidak ada)
    if (_cameraErrorMessage != null || !_isCameraInitialized || _cameraController == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          children: [
            const Icon(Icons.videocam_off_rounded, color: Color(0xFFDC2626), size: 48),
            const SizedBox(height: 10),
            const Text(
              'Kamera Tidak Dapat Diakses',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF991B1B)),
            ),
            const SizedBox(height: 6),
            Text(
              _cameraErrorMessage ?? 'Pastikan izin kamera sudah diaktifkan di browser atau perangkat Anda.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _initCamera,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Akses Kamera Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Pilih dari File / Galeri'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 4. Kondisi KAMERA AKTIF (Live Viewfinder & Shutter)
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Preview Kamera
            AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio > 0 ? _cameraController!.value.aspectRatio : 4 / 3,
              child: CameraPreview(_cameraController!),
            ),

            // Panduan Wajah (Face Guide Oval Overlay)
            Container(
              width: 170,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                borderRadius: const BorderRadius.all(Radius.elliptical(170, 220)),
              ),
            ),

            // Instruksi teks di atas kamera
            Positioned(
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Posisikan wajah di dalam bingkai',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            // Tombol Switch Kamera jika kamera > 1
            if (_cameras.length > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                    onPressed: _switchCamera,
                    tooltip: 'Ganti Kamera',
                  ),
                ),
              ),

            // Tombol Shutter di bawah kamera
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Tombol galeri alternatif di pojok kiri
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                      onPressed: _pickFromGallery,
                      tooltip: 'Pilih dari File',
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Tombol Jepret Utama
                  InkWell(
                    onTap: _takePhoto,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFF2563EB),
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Placeholder penyeimbang layout
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    final bool hasLocation = _locationString != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasLocation ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasLocation ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasLocation ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasLocation ? Icons.location_on_rounded : Icons.location_searching_rounded,
              color: hasLocation ? const Color(0xFF16A34A) : const Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation ? 'Koordinat GPS Terdeteksi' : 'Titik Lokasi GPS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hasLocation ? const Color(0xFF166534) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                if (_isFetchingLocation)
                  const Text('Mendeteksi sinyal GPS...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
                else if (hasLocation)
                  Text(_locationString!, style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600))
                else
                  const Text('GPS belum diperoleh, klik tombol untuk memuat.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _isFetchingLocation ? null : _getLocation,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(color: hasLocation ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isFetchingLocation
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    hasLocation ? 'Perbarui' : 'Cek Lokasi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasLocation ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitAbsen,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                  SizedBox(width: 12),
                  Text('Mengirim Absensi...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('KIRIM KEHADIRAN SEKARANG', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                ],
              ),
      ),
    );
  }
}