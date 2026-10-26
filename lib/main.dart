import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:safe_stride/login_page.dart';
import 'package:safe_stride/open_AI.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio_classifier_service.dart';
import 'package:intl/intl.dart';
import 'location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'home_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dashboard_page.dart';
// OpenAI helper is in lib/open_AI.dart
class OpenAIService {
  OpenAIService._();

  static final OpenAIService instance = OpenAIService._();

  Future<String> askOpenAI(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final recentLogs = logEntries
        .take(5)
        .map((log) => '${log.label} at ${DateFormat('hh:mm a').format(log.time)}')
        .join('; ');

    if (recentLogs.isEmpty) {
      return 'No recent logs available.';
    }

    return 'Summary for "${prompt}": $recentLogs';
  }
}

final AudioClassifierService globalClassifierService = AudioClassifierService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AudioSafeApp());
}

// `LogEntry` and `logEntries` are declared in `lib/home_page.dart`.
// Avoid duplicating the model here to prevent type conflicts.

class AudioSafeApp extends StatelessWidget {
  const AudioSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrideSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(0, 80, 220, 255)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// Simple LogsPage widget used by the app navigation
// Simple LogsPage widget used by the app navigation
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String _aiSummary = 'Analyzing your logs...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _analyzeLogs();
  }

  Future<void> _analyzeLogs() async {
    if (logEntries.isEmpty) {
      setState(() => _aiSummary = 'No logs recorded yet.');
      return;
    }

    setState(() => _isLoading = true);
    final logText = logEntries
        .map((e) => "- ${DateFormat('hh:mm a').format(e.time)}: ${e.label} (Confidence: ${e.confidence})")
        .join("\n");
        

    try {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_API_KEY_HERE');
      final analysisService = AiLogAnalysis(apiKey: apiKey);
      final result = await analysisService.analyzeLogs(logText);
      if (!mounted) return;
      setState(() => _aiSummary = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiSummary = 'Analysis failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = logEntries.reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      appBar: AppBar(
        title: const Text('Logs'),
        backgroundColor: const Color(0xFF030303),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DashboardPage(logEntries: List<LogEntry>.from(logEntries))),
              );
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Dashboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _analyzeLogs,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE2F1F8),
              foregroundColor: const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Analyze Logs', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          
          if (_aiSummary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _aiSummary,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
              ),
            ),

          const SizedBox(height: 8),
          
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      'No logs available',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final e = entries[index];
                      final timeFormatted = DateFormat('hh:mm a').format(e.time);
                      
                      String confidenceFormatted;
                      if (e.confidence is num) {
                        confidenceFormatted = '${((e.confidence as num) * 100).toStringAsFixed(0)}%';
                      } else {
                        confidenceFormatted = e.confidence.toString();
                      }

                      return buildLogCard(
                        title: e.label,
                        subtitle: 'Confidence: $confidenceFormatted',
                        time: timeFormatted,
                        icon: Icons.graphic_eq,
                        iconColor: Colors.blueAccent, latitude: null, longitude: null,
                      );
                    },
                  ),
          ),
        ],
      ),
    ); // <-- Added closing parenthesis and semicolon for Scaffold/build
  }
}

// Synchronous card widget builder
Widget buildLogCard({
  required String title,
  required String subtitle,
  required String time,
  required IconData icon,
  required Color iconColor,
  required double? latitude,
  required double? longitude,
}) {
  // Format coordinates cleanly if they exist
  String locationText = '';
  if (latitude != null && longitude != null) {
    locationText = ' • ${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}';
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$subtitle$locationText',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    ),
  );
}
// --- GPS MAP PAGE ---

class GPSPage extends StatefulWidget {
  const GPSPage({super.key});

  @override
  State<GPSPage> createState() => _GPSPageState();
}

class _GPSPageState extends State<GPSPage> {
  GoogleMapController? _mapController;
  Position? _position;
  String _status = 'Fetching location...';
  Set<Marker> _markers = <Marker>{};
  final AudioPlayer _player = AudioPlayer();
  DateTime? _lastPlayed;
  bool showAlert = false;
  String alertMessage = 'Scanning surroundings';
  Timer? _alertTimer;
  bool _isMicOn = true;

  final JunctionAlertService _junctionAlertService = JunctionAlertService();
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initMapLocation();
    _junctionAlertService.startMonitoring(_onJunctionAlert);
  }

  Future<void> _onJunctionAlert(String message) async {
    if (!mounted || !_isMicOn) return;

    _alertTimer?.cancel();
    setState(() {
      showAlert = true;
      alertMessage = message;
    });

    _alertTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        showAlert = false;
        alertMessage = 'Scanning surroundings';
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        backgroundColor: message.contains('Nearby road detected') ? Colors.red : Colors.orange,
      ),
    );

    final now = DateTime.now();
    final playedRecently = _lastPlayed != null && now.difference(_lastPlayed!) < const Duration(milliseconds: 1500);
    if (!playedRecently) {
      try {
        await _player.play(AssetSource('assets/bell-chime-alert.mp3.flac'));
      } catch (_) {
        SystemSound.play(SystemSoundType.alert);
      }
      _lastPlayed = now;
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _player.dispose();
    _alertTimer?.cancel();
    super.dispose();
  }

  void _handleSnappedPoints(List<dynamic> snappedPoints, void Function(String) onAlert) {
    if (snappedPoints.isNotEmpty) {
      for (final point in snappedPoints) {
        final placeId = point['placeId'];
        final location = point['location'] as Map<String, dynamic>?;
        final lat = location?['latitude'];
        final lng = location?['longitude'];
        onAlert('Nearby road detected (Place ID: $placeId) at lat: $lat, lng: $lng');
      }
    } else {
      onAlert('Off-road or unmapped area detected.');
    }
  }

  Future<void> _initMapLocation() async {
    final pos = await LocationService.getCurrentPosition();

    if (pos == null) {
      if (!mounted) return;
      setState(() => _status = 'Permission denied or unavailable');
      return;
    }

    final currentLatLng = LatLng(pos.latitude, pos.longitude);

    if (!mounted) return;
    setState(() {
      _position = pos;
      _status = 'Location loaded';
      _markers = <Marker>{
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLatLng,
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
      };
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: currentLatLng, zoom: 16.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng defaultCenter = _position != null
        ? LatLng(_position!.latitude, _position!.longitude)
        : const LatLng(41.8781, -87.6298);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live GPS Map'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: defaultCenter,
                zoom: 14.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                if (_position != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(_position!.latitude, _position!.longitude),
                        zoom: 16.0,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              onPressed: _initMapLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Center on My Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}