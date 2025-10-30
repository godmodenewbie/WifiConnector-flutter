import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Wi-Fi Connector',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WifiHomePage(),
    );
  }
}

class WifiHomePage extends StatefulWidget {
  const WifiHomePage({super.key});

  @override
  State<WifiHomePage> createState() => _WifiHomePageState();
}

class _WifiHomePageState extends State<WifiHomePage> {
  List<WifiNetwork> _wifiNetworks = [];
  bool _isScanning = false;
  String _connectionStatus = 'Memeriksa status...';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _scanTimer;

  // State untuk Analisa Jaringan
  bool _isConnected = false;
  String? _gatewayPing;
  String? _googlePing;
  final String _ontAttenuation = '-20 dBm'; // Dummy value
  String? _wifiBand;
  int? _wifiChannel;
  int? _currentSignalStrength;
  bool _isAnalyzingLatency = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndScan();
    _listenToConnectionChanges();
    // Mulai timer untuk memindai secara berkala
    _scanTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) => _startScan());
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _scanTimer?.cancel(); // Jangan lupa membatalkan timer
    super.dispose();
  }

  // Mirip dengan WifiConnectionMonitor di Kotlin
  Future<void> _listenToConnectionChanges() async {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      _updateConnectionStatus();
    });
    _updateConnectionStatus(); // Panggil sekali saat inisialisasi
  }

  Future<void> _updateConnectionStatus() async {
    final isConnected = await WiFiForIoTPlugin.isConnected();
    if (!mounted) return;

    if (isConnected) {
      final ssid = await WiFiForIoTPlugin.getSSID();
      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _connectionStatus = 'Terhubung ke: $ssid';
      });
      // Panggil analisa jaringan saat terhubung
      _updateNetworkAnalysis();
    } else {
      setState(() {
        _connectionStatus = 'Tidak ada koneksi Wi-Fi';
        _isConnected = false;
      });
    }
  }

  Future<void> _checkPermissionsAndScan() async {
    // Cek izin terlebih dahulu
    var permissionStatus = await Permission.location.request();
    if (permissionStatus.isGranted) {
      // Jika izin diberikan, lanjutkan untuk memindai
      _startScan();
    } else {
      // Jika izin ditolak, tampilkan pesan dan jangan lakukan apa-apa
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Izin lokasi diperlukan untuk memindai jaringan Wi-Fi.')),
      );
    }
  }

  Future<void> _startScan() async {
    // Cek prasyarat sebelum memulai scan
    final isLocationServiceEnabled =
        await Permission.location.serviceStatus.isEnabled;
    if (!isLocationServiceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Aktifkan layanan lokasi (GPS) untuk memindai Wi-Fi.')),
      );
      return;
    }

    final isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
    if (!isWifiEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Harap aktifkan Wi-Fi untuk memindai jaringan.')),
      );
      return;
    }

    // Jika semua prasyarat terpenuhi, baru jalankan scan
    if (_isScanning) return;
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _connectionStatus = 'Memindai jaringan...';
    });

    try {
      List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();
      if (!mounted) return;
      setState(() {
        // Sort networks by signal strength (strongest first)
        networks.sort((a, b) => (b.level ?? -100).compareTo(a.level ?? -100));
        _wifiNetworks = networks;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memindai jaringan: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });
      _updateConnectionStatus(); // Perbarui status setelah scan selesai
    }
  }

  Future<void> _updateNetworkAnalysis() async {
    if (!_isConnected || _isAnalyzingLatency) return;

    setState(() {
      _isAnalyzingLatency = true;
      _gatewayPing = 'Menganalisa...';
      _googlePing = 'Menganalisa...';
    });
    // Beri jeda singkat agar UI sempat menampilkan "Menganalisa..."
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Kumpulkan semua data analisa secara paralel untuk efisiensi
    final results = await Future.wait([
      WiFiForIoTPlugin.getFrequency(),
      WiFiForIoTPlugin.getCurrentSignalStrength(),
      NetworkInfo().getWifiGatewayIP().then((ip) => ip != null ? _getPingResult(ip) : 'Gagal mendapatkan gateway'),
      _getPingResult('google.com'),
    ]);

    // Panggil setState HANYA SEKALI dengan semua data yang sudah terkumpul
    if (mounted) {
      setState(() {
        final frequency = results[0] as int?;
        _wifiBand = _getWifiBand(frequency);
        _wifiChannel = _getWifiChannel(frequency);
        _currentSignalStrength = results[1] as int?;
        _gatewayPing = results[2] as String;
        _googlePing = results[3] as String;
        _isAnalyzingLatency = false;
      });
    }
  }

  Future<String> _getPingResult(String host) async {
    try {
      final ping = Ping(host, count: 3, timeout: 2);
      final results = await ping.stream.toList();
      final validResponses =
          results.where((r) => r.response != null).toList();

      if (validResponses.isNotEmpty) {
        final avgTime = validResponses
                .map((r) => r.response!.time!.inMilliseconds)
                .reduce((a, b) => a + b) /
            validResponses.length;
        return '${avgTime.toStringAsFixed(0)} ms';
      } else {
        final error = results.last.error;
        if (error != null) {
          return 'Timeout';
        }
        return 'Gagal';
      }
    } catch (e) {
      return 'Error';
    }
  }

  Future<void> _connectToNetwork(WifiNetwork network) async {
    final passwordController = TextEditingController();

    // Menampilkan dialog untuk password
    // Mirip dengan suggestion API, kita minta password lalu serahkan ke sistem
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Simpan Jaringan ${network.ssid}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Jaringan akan disimpan ke ponsel Anda. Masukkan kata sandi jika diperlukan.'),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kata Sandi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performConnection(network, passwordController.text);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // Helper function untuk mengonversi String security ke enum NetworkSecurity
  NetworkSecurity _getSecurityType(String? security) {
    if (security == null) return NetworkSecurity.NONE;
    if (security.toUpperCase().contains('WPA')) {
      return NetworkSecurity.WPA;
    } else if (security.toUpperCase().contains('WEP')) {
      return NetworkSecurity.WEP;
    } else {
      return NetworkSecurity.NONE;
    }
  }

  void _performConnection(WifiNetwork network, String password) async {
    // Di Android Q (10) ke atas, `connect` akan menggunakan suggestion API.
    // Ini adalah pendekatan yang direkomendasikan dan mirip dengan kode Kotlin.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mencoba menyimpan jaringan ${network.ssid}...')),
    );

    try {
      await WiFiForIoTPlugin.registerWifiNetwork(
        network.ssid!,
        password: password,
        security: _getSecurityType(network.capabilities), // Menggunakan helper function
      );

      // Tunggu sebentar lalu perbarui status
      await Future.delayed(const Duration(seconds: 5));
      _updateConnectionStatus();
      _startScan(); // Pindai ulang untuk refresh daftar
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan/terhubung: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('WiFi Connector Flutter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _connectionStatus,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                // Tambahkan tombol refresh manual untuk analisa
                if (_isConnected)
                  TextButton(
                      onPressed: _isAnalyzingLatency ? null : _updateNetworkAnalysis,
                      child: Text(_isAnalyzingLatency ? "Menganalisa..." : "Refresh Analisa")),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isScanning ? null : _startScan,
                  child: Text(
                      _isScanning ? 'Memindai...' : 'Pindai Ulang Jaringan'),
                ),
              ],
            ),
          ),
          if (_isConnected) _buildNetworkAnalysisSection(),
          const Divider(),
          Expanded(
            child: _wifiNetworks.isEmpty
                ? Center(
                    child: _isScanning
                        ? const CircularProgressIndicator()
                        : const Text('Tidak ada jaringan Wi-Fi ditemukan.'),
                  )
                : ListView.builder(
                    itemCount: _wifiNetworks.length,
                    itemBuilder: (context, index) {
                      final network = _wifiNetworks[index];
                      if (network.ssid == null || network.ssid!.isEmpty) {
                        return const SizedBox
                            .shrink(); // Sembunyikan jaringan tanpa SSID
                      }
                      return ListTile(
                        title: Text(network.ssid!),
                          subtitle: Text('${network.level ?? 'N/A'} dBm'),
                        leading: _getSignalIcon(network.level), // Ikon sinyal dinamis
                        trailing: (network.capabilities ?? "")
                                .toUpperCase()
                                .contains(RegExp(r'WPA|WEP'))
                            ? const Icon(Icons.lock,
                                color:
                                    Colors.grey) // Ikon gembok untuk jaringan aman
                            : null,
                        onTap: () => _connectToNetwork(network),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkAnalysisSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysisCard(
            title: 'Analisa Latensi Jaringan',
            items: {
              'Ping ke Gateway': _gatewayPing ?? 'N/A',
              'Redaman ONT': _ontAttenuation,
              'Ping ke google.com': _googlePing ?? 'N/A',
            },
          ),
          const SizedBox(height: 12),
          _buildAnalysisCard(
            title: 'Analisa Radio Jaringan',
            items: {
              'Spektrum': _wifiBand ?? 'N/A',
              'Sinyal WiFi': '${_currentSignalStrength ?? 'N/A'} dBm',
              'Channel WiFi': _wifiChannel?.toString() ?? 'N/A',
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(
      {required String title, required Map<String, String> items}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.entries.map((entry) => Text('${entry.key}: ${entry.value}')),
          ],
        ),
      ),
    );
  }
}

// -- Helper Functions (di luar class State) --

String? _getWifiBand(int? frequency) {
  if (frequency == null) return null;
  if (frequency >= 2400 && frequency < 3000) {
    return '2.4 GHz';
  } else if (frequency >= 5000 && frequency < 6000) {
    return '5 GHz';
  }
  return 'Unknown';
}

int? _getWifiChannel(int? frequency) {
  if (frequency == null) return null;
  if (frequency >= 2412 && frequency <= 2484) {
    if (frequency == 2484) return 14;
    return ((frequency - 2412) ~/ 5) + 1;
  } else if (frequency >= 5180 && frequency <= 5825) {
    return ((frequency - 5180) ~/ 5) + 36;
  }
  return null;
}

// Helper function untuk mendapatkan ikon sinyal berdasarkan level dBm
Icon _getSignalIcon(int? level) {
  if (level == null) {
    return const Icon(Icons.wifi_off, color: Colors.grey);
  }
  // Nilai ambang batas sinyal bisa didefinisikan sebagai konstanta
  const int strongSignal = -60;
  const int goodSignal = -75;
  const int fairSignal = -85;

  if (level > strongSignal) {
    return const Icon(Icons.wifi, color: Colors.blue); // Sinyal sangat kuat
  } else if (level > goodSignal) {
    return const Icon(Icons.network_wifi_3_bar, color: Colors.blue); // Sinyal kuat
  } else if (level > fairSignal) {
    return const Icon(Icons.network_wifi_2_bar, color: Colors.grey); // Sinyal sedang
  } else {
    return const Icon(Icons.network_wifi_1_bar, color: Colors.grey); // Sinyal lemah
  }
}
