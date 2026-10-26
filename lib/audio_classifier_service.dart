import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:record/record.dart';

typedef SoundDetectedCallback = void Function(String, double);

class AudioClassifierService {
  late Interpreter _interpreter;
  List<String> _labels = [];
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isListening = false;
  bool _isReady = false;

  // Single-row multi-column model prediction matrix
  final List<List<double>> _persistentOutputMatrix = [
    List<double>.filled(521, 0.0),
  ];

  final List<double> list_buffer = <double>[];
  static const int bufferSize = 15600; // 0.975s @ 16kHz
  
  // --- DEBOUNCE / COOLDOWN STATE ---
  DateTime? _lastTriggerTime;
  String? _lastReportedSound;
  static const Duration _cooldownDuration = Duration(milliseconds: 100); 
  
  // ---------------------------------
  
  SoundDetectedCallback? onSoundDetected;

  Future<void> init() async {
    if (_isReady) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mode/yamnet.tflite');

      final labelData = await rootBundle.loadString('assets/models/mode/yamnet_labels.txt');
      _labels = labelData
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      _isReady = true;
      print('YAMNet AI engine initialized successfully with ${_labels.length} labels.');
    } catch (e) {
      _isReady = false;
      print('Error initializing interpreter: $e');
    }
  }

  Future<void> startTracking({int bufferLength = 1024}) async {
    if (!_isReady) {
      print('Cannot start tracking: YAMNet interpreter is not ready yet.');
      return;
    }

    if (!await _audioRecorder.hasPermission()) {
      print('Permission denied for audio recording');
      return;
    }

    _isListening = true;
    list_buffer.clear();

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    );

    final stream = await _audioRecorder.startStream(config);
    print('Started audio stream for classification');

    stream.listen((Uint8List chunk) {
      if (!_isListening) return;

      final ByteData byteData = ByteData.sublistView(chunk);
      final int sampleCount = chunk.length ~/ 2;
      final Float32List float32Buffer = Float32List(sampleCount);

      for (int i = 0; i < sampleCount; i++) {
        int pcm16 = byteData.getInt16(i * 2, Endian.little);
        float32Buffer[i] = pcm16 / 32768.0;
      }

      list_buffer.addAll(float32Buffer);

      while (list_buffer.length >= bufferSize) {
        final List<double> inputFrame = list_buffer.sublist(0, bufferSize);
        list_buffer.removeRange(0, 7800); 
        
        _runModelInference(Float32List.fromList(inputFrame));
      }
    });
  }

  void _runModelInference(Float32List inputBuffer) {
    try {
      // 💡 100% FIXED: Clear inner list zero explicitly to satisfy compiler layout
      _persistentOutputMatrix[0].fillRange(0, 521, 0.0);
      
      _interpreter.run([inputBuffer], _persistentOutputMatrix);

      // 💡 100% FIXED: Read explicitly out of row zero [0][i] to fix runtime range crash
      List<MapEntry<int, double>> scores = [];
      for (int i = 0; i < 521; i++) {
        scores.add(MapEntry(i, _persistentOutputMatrix[0][i])); 
      }
      scores.sort((a, b) => b.value.compareTo(a.value));

      int bestMatchIndex = scores[0].key;
      double highestScore = scores[0].value;

      String rawTopSound = bestMatchIndex < _labels.length ? _labels[bestMatchIndex] : "Unknown";
      print('🎤 Listening... Top guess: [$bestMatchIndex] $rawTopSound (${(highestScore * 100).toStringAsFixed(1)}%)');

      // vehicle sound categories based on YAMNet label indices
      bool isVehicleCategory(int index) {
        return (index >= 290 && index <= 345) || 
               (index >= 397 && index <= 405) || 
               index == 382;                     
      }

      if (!isVehicleCategory(bestMatchIndex)) {
        for (int i = 1; i < 5; i++) {
          if (isVehicleCategory(scores[i].key) && scores[i].value > 0.25) {
            bestMatchIndex = scores[i].key;
            highestScore = scores[i].value;
            break;
          }
        }
      }

      // If it's not a vehicle sound, let the UI reset cleanly so it doesn't freeze
      if (!isVehicleCategory(bestMatchIndex)) {
        if (_lastReportedSound != "Scanning Surroundings...") {
          _lastReportedSound = "Scanning Surroundings...";
          if (onSoundDetected != null) {
            onSoundDetected!("Scanning Surroundings...", 0.0);
            Future.delayed(const Duration(milliseconds: 6000000), () {
              if (onSoundDetected != null) {
                onSoundDetected!("Scanning Surroundings...", 0.0);
              }
            });
          }
        }
        return;
      }

      if (highestScore > 0.40) {
        String soundName = "🚨 WATCH OUT! Vehicle DETECTED. STRIDE SAFE!! 🚨";
        TextStyle soundStyle = TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 248, 234, 234));

        if (bestMatchIndex >= 333 && bestMatchIndex <= 341) {
          soundName = "🚨 WATCH OUT! Vehicle DETECTED. STRIDE SAFE!! 🚨";
        } else if (bestMatchIndex >= 397 && bestMatchIndex <= 405) {
          soundName = "🚨 WATCH OUT! Vehicle DETECTED. STRIDE SAFE!! 🚨";
        }

        final now = DateTime.now();
        bool isCooldownExpired = _lastTriggerTime == null || now.difference(_lastTriggerTime!) > _cooldownDuration;

        if (isCooldownExpired || _lastReportedSound != soundName) {
          _lastTriggerTime = now;
          _lastReportedSound = soundName;
          print('🔍 Detected Instantly: $soundName (${(highestScore * 100).toStringAsFixed(1)}%)');
          
          if (onSoundDetected != null) {
            onSoundDetected!(soundName, highestScore);
          }
        }
      }
    } catch (e, stackTrace) {
      print("Inference iteration error: $e\n$stackTrace");
    }
  }

  Future<void> stopTracking() async {
    _isListening = false;
    list_buffer.clear();
    await _audioRecorder.stop();
    print('🛑 AI Stream Closed.');
  }

  void dispose() {
    _isListening = false;
    _interpreter.close();
    _audioRecorder.dispose();
  }
}

