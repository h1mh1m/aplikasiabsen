import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<dynamic> _listAbsen = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAbsens();
  }

  Future<void> _fetchAbsens() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/api/admin/absensi'));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        setState(() {
          _listAbsen = resData['data'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil data dari server')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin - Rekap Kehadiran'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAbsens,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listAbsen.isEmpty
              ? const Center(child: Text('Belum ada data absensi.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listAbsen.length,
                  itemBuilder: (context, index) {
                    final item = _listAbsen[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['fotoUrl'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 40),
                          ),
                        ),
                        title: Text(
                          '${item['nama_murid']} (${item['kelas']})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NIS: ${item['nis']}'),
                            Text('Lokasi GPS: ${item['lokasi']}'),
                            Text(
                              'Waktu: ${DateTime.parse(item['waktuAbsen']).toLocal().toString().split('.')[0]}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}