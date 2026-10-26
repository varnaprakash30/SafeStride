import 'package:safe_stride/main.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_stride/audio_classifier_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_page.dart';

final AudioPlayer _player = AudioPlayer();

// Define LogEntry if not already exported by your service file
class LogEntry {
  final String label;
  final DateTime time;
  final String confidence;
  LogEntry({required this.label, required this.time, required this.confidence});

  get placeId => null;

  get latitude => null;

  get longitude => null;
}

final List<LogEntry> logEntries = [];
final globalClassifierService = AudioClassifierService();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isMicOn = false;
  String _detectedLabel = "Ready to Stride";
  DateTime? _lastPlayed;
  bool _showAlert = false;
  Timer? _alertTimer;
  DateTime? _lockUntil;
  
  final TextStyle _statusTextStyle = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.red,
  );

  @override
  void initState() {
    super.initState();

    globalClassifierService.onSoundDetected = (String sound, double accuracy) {
      if (!mounted) return;

      final now = DateTime.now();
      final isVehicleAlert = sound.toLowerCase().contains('vehicle') || sound.toLowerCase().contains('watch out') || sound.contains('🚨');

      // If we're in a lock period (recent vehicle), ignore non-vehicle updates
      if (!isVehicleAlert && _lockUntil != null && now.isBefore(_lockUntil!)) {
        // still record the non-vehicle event but do not change visible label
        logEntries.add(LogEntry(label: sound, time: now, confidence: isVehicleAlert ? "${(accuracy * 100).toStringAsFixed(1)}%" : "N/A"));
        return;
      }

      // Play alert sound for vehicle events (debounced)
      if (isVehicleAlert) {
        final playedRecently = _lastPlayed != null && now.difference(_lastPlayed!) < const Duration(milliseconds: 1500);
        if (!playedRecently) {
          try {
            _player.play(AssetSource('freesound_community-soft-alert-81627.mp3'));
          } catch (_) {
            SystemSound.play(SystemSoundType.alert);
          }
          _lastPlayed = now;
        }

        // Lock visible state for 5 seconds
        _lockUntil = now.add(const Duration(seconds: 5));

        // Ensure red alert stays visible for 5 seconds
        _alertTimer?.cancel();
        _alertTimer = Timer(const Duration(seconds: 5), () {
          if (!mounted) return;
          setState(() {
            _showAlert = false;
            _detectedLabel = 'Scanning surroundings...';
            _lockUntil = null;
          });
        });
      }

      setState(() {
        _detectedLabel = sound;
        _showAlert = isVehicleAlert ? true : _showAlert;
        logEntries.add(LogEntry(label: sound, time: now, confidence: isVehicleAlert ? "${(accuracy * 100).toStringAsFixed(1)}%" : "N/A"));
      });
    };

    _initializeClassifier();
  }

  Future _initializeClassifier() async {
    await globalClassifierService.init();
    if (mounted) {
      setState(() {
        _detectedLabel = "Ready to Stride";
      });
    }
  }

  @override
  void dispose() {
    globalClassifierService.onSoundDetected = null;
    _alertTimer?.cancel();
    super.dispose();
  }

  Future _toggleListening() async {
    try {
      if (!_isMicOn) {
        await globalClassifierService.startTracking(bufferLength: 1024);
        setState(() {
          _isMicOn = true;
          _detectedLabel = 'Listening for traffic...';
        });
      } else {
        await globalClassifierService.stopTracking();
        // stop alerts immediately when microphone is muted
        _alertTimer?.cancel();
        setState(() {
          _isMicOn = false;
          _detectedLabel = 'Ready to Stride Safely.';
          _showAlert = false;
        });
      }
    } catch (e) {
      debugPrint('Error toggling microphone: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isVehicleAlert = 
        _detectedLabel.toLowerCase().contains('car') ||
        _detectedLabel.toLowerCase().contains('truck') ||
        _detectedLabel.toLowerCase().contains('vehicle') ||
        _detectedLabel.toLowerCase().contains('engine') ||
        _detectedLabel.toLowerCase().contains('bicycle') ||
        _detectedLabel.contains('AUTO_MASS') ||
        _detectedLabel.contains('KINETIC_UNIT') ||
        _detectedLabel.contains('TRANSIT_VECTOR');

      // Final display decision: keep alert visible while `_showAlert` is true
      final bool showAlert = _showAlert || isVehicleAlert;

    return Scaffold(
      backgroundColor: showAlert ? const Color.fromARGB(255, 203, 29, 29) : const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text(
          'SafeStride',
          style: TextStyle(
            color: Color.fromARGB(255, 255, 254, 254),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Brand Logo / Icon
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color.fromARGB(255, 19, 19, 19).withOpacity(0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    height: 120,
                    width: 120,
                    child: Image.asset('assets/app_logo.png', fit: BoxFit.contain),
                  ),
                ),
              ),

              // Glowing Status / Alert Badge
              // Shows 3 items if true, 1 item if false
            AnimatedContainer(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.only(bottom: 8.0), 
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,// Optional: adds space between the repeated containers
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: showAlert
            ? [Colors.red.withOpacity(0.85), Colors.red.withOpacity(0.6)]
            : [Colors.amber.withOpacity(0.2), Colors.orange.withOpacity(0.1)],
             
            
      ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
            color: showAlert ? Colors.redAccent : Colors.amber,
              width: 1.5,
              
        
          ),
        ),
        
        
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVehicleAlert ? Icons.warning_amber_rounded : Icons.radar,
                      color: const Color.fromARGB(255, 243, 239, 239),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ACTIVE: MONITORING SURROUNDINGS...',
                      style: TextStyle(
                        color: Color.fromARGB(255, 243, 239, 239),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
  

                // Live Acoustic Feed Readout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _detectedLabel,
                  textAlign: TextAlign.center,
                  style: isVehicleAlert
                      ? const TextStyle(
                          color: Color.fromARGB(255, 8, 8, 8),
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        )
                      : const TextStyle(
                          color: Color.fromARGB(179, 255, 255, 253),
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                ),
              ),
              
              

              // Central Microphone Hub
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  height: 220,
                  width: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        isVehicleAlert
                            ? Colors.redAccent.withOpacity(0.5)
                            : const Color(0xFF0D47A1).withOpacity(0.8),
                        const Color(0xFF121212),
                      ],
                    ),
                    border: Border.all(
                      color: isVehicleAlert
                          ? Colors.redAccent
                          : (_isMicOn ? Colors.cyanAccent.withOpacity(0.6) : Colors.grey.withOpacity(0.3)),
                      width: 2,
                    ),
                    boxShadow: _isMicOn
                        ? [
                            BoxShadow(
                              color: (isVehicleAlert ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isMicOn ? 'Listening for\nTraffic...' : 'Paused\nTap to Resume',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Icon(
                        _isMicOn ? Icons.mic : Icons.mic_off,
                        color: _isMicOn ? Colors.greenAccent : Colors.grey,
                        size: 38,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LogsPage()),
                      );
                    },
                    icon: const Icon(Icons.list_alt, size: 16, color: Colors.white70),
                    label: const Text('View Logs', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GPSPage()),
                      );
                    },
                    icon: const Icon(Icons.map, size: 16, color: Colors.white70),
                    label: const Text('View GPS', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


}

// Temporary placeholder classes if they aren't created yet in separate files




  