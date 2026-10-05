import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<dynamic> _listAbsen = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAbsens();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // FETCH ABSENSI DARI BACKEND (API Tetap Sama)
  // ==========================================
  Future<void> _fetchAbsens() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/api/admin/absensi'));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _listAbsen = resData['data'] ?? [];
          });
        }
      } else {
        if (mounted) {
          _showSnackBar('Gagal memuat rekap absensi (${response.statusCode})', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal terhubung ke backend server: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showPhotoDialog(String fotoUrl, String namaMurid, String waktu) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                namaMurid,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                waktu,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Image.network(
                      fotoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 250,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_rounded, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 8),
                              Text('Foto gagal dimuat', style: TextStyle(color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<dynamic> get _filteredAbsen {
    if (_searchQuery.isEmpty) return _listAbsen;
    final q = _searchQuery.toLowerCase();
    return _listAbsen.where((item) {
      final nama = (item['nama_murid'] ?? '').toString().toLowerCase();
      final kelas = (item['kelas'] ?? '').toString().toLowerCase();
      final nis = (item['nis'] ?? '').toString().toLowerCase();
      return nama.contains(q) || kelas.contains(q) || nis.contains(q);
    }).toList();
  }

  String _formatDateTime(dynamic waktu) {
    if (waktu == null) return '-';
    try {
      final dt = DateTime.parse(waktu.toString()).toLocal();
      final year = dt.year.toString().padLeft(4, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute:$second WIB';
    } catch (_) {
      return waktu.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAbsen;

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
              child: const Icon(Icons.dashboard_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Dashboard Admin',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Rekap Data Presensi Kehadiran Siswa',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: _fetchAbsens,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            tooltip: 'Logout',
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: RefreshIndicator(
            onRefresh: _fetchAbsens,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Kartu Ringkasan Statistik
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Total Kehadiran',
                        value: _listAbsen.length.toString(),
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Terfilter',
                        value: filtered.length.toString(),
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Kolom Pencarian
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan nama siswa, kelas, atau NIS...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
                const SizedBox(height: 16),

                // Daftar Absensi
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.event_busy_rounded, size: 40, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'Belum Ada Data Presensi' : 'Tidak Ditemukan',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Presensi yang dikirim oleh siswa akan tampil di sini secara real-time.'
                              : 'Tidak ada data siswa yang cocok dengan kata kunci "$_searchQuery".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                else
                  ...filtered.map((item) {
                    final nama = item['nama_murid'] ?? 'Siswa';
                    final kelas = item['kelas'] ?? '-';
                    final nis = item['nis'] ?? '-';
                    final lokasi = item['lokasi'] ?? '-';
                    final fotoUrl = item['fotoUrl'] ?? '';
                    final waktu = _formatDateTime(item['waktuAbsen']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Foto Selfie Siswa (Dapat diklik untuk memperbesar)
                            GestureDetector(
                              onTap: () => _showPhotoDialog(fotoUrl, nama, waktu),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      fotoUrl,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 72,
                                        height: 72,
                                        color: const Color(0xFFF1F5F9),
                                        child: const Icon(Icons.person_rounded, size: 36, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Informasi Siswa & Kehadiran
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          nama,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBEAFE),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Kelas: $kelas',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text('NIS: $nis', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Lokasi: $lokasi',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        waktu,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}