import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _boliTitle = 'Boli — AI Smart Speech Analysis';

void main() => runApp(const BoliApp());

class BoliApp extends StatelessWidget {
  const BoliApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: _boliTitle,
        debugShowCheckedModeBanner: false,
        home: const LandingPage(),
      );
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 750,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.record_voice_over, size: 70, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  _boliTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                Text(
                  'Detect speech and extract important keywords from live video or uploaded videos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: Colors.grey[700]),
                ),
                const SizedBox(height: 35),
                SizedBox(
                  width: 250,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.videocam),
                    label: const Text('Live Detection'),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const HomeScreen())),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: 250,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Video'),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const UploadScreen())),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  CameraController? _cameraController;
  bool _speechAvailable = false;
  bool isListening = false;
  bool isSpeechDetected = false;
  bool _cameraReady = false;
  String _cameraMessage = 'Starting camera…';
  String keywords = '';
  Timer? _restartTimer;
  static const _fillers = {
    'um', 'uh', 'hmm', 'like', 'you', 'know', 'ok', 'okay', 'the', 'and',
  };

  @override
  void initState() {
    super.initState();
    _startCamera();
    _initializeSpeech();
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraMessage = 'No camera found');
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(camera, ResolutionPreset.medium,
          enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _cameraMessage = 'Camera unavailable');
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (_) {
          if (!mounted) return;
          _restartTimer?.cancel();
          setState(() {
            isListening = false;
            isSpeechDetected = false;
          });
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted || !isListening || status != 'notListening') return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && isListening) _listenAgain();
    });
  }

  Future<void> _listenAgain() async {
    try {
      await _speech.listen(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        onResult: (result) {
          if (!mounted) return;
          final words = <String>{};
          for (final word
              in result.recognizedWords.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
            if (word.length > 2 && !_fillers.contains(word)) words.add(word);
            if (words.length == 10) break;
          }
          setState(() {
            keywords = words.join(', ');
            isSpeechDetected = keywords.isNotEmpty;
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          isListening = false;
          isSpeechDetected = false;
        });
      }
    }
  }

  Future<void> getLiveKeywords() async {
    if (!_speechAvailable) await _initializeSpeech();
    if (!_speechAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Microphone recognition is unavailable. Try Chrome or Edge.'),
        ));
      }
      return;
    }
    setState(() {
      isListening = true;
      isSpeechDetected = false;
      keywords = '';
    });
    await _listenAgain();
  }

  Future<void> stopListening() async {
    _restartTimer?.cancel();
    setState(() => isListening = false);
    await _speech.stop();
  }

  void goHome() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );

  @override
  void dispose() {
    _restartTimer?.cancel();
    _speech.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 900,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(_boliTitle,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  height: 400,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _cameraReady && _cameraController != null
                        ? CameraPreview(_cameraController!)
                        : Center(
                            child: _cameraMessage == 'Starting camera…'
                                ? const CircularProgressIndicator()
                                : Text(_cameraMessage,
                                    style: const TextStyle(color: Colors.white)),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isListening
                        ? Colors.orange
                        : isSpeechDetected
                            ? Colors.green
                            : Colors.red,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isListening
                            ? Icons.mic
                            : isSpeechDetected
                                ? Icons.volume_up
                                : Icons.volume_off,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isListening
                            ? 'Listening...'
                            : isSpeechDetected
                                ? 'Speech Detected'
                                : 'No Speech',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isListening ? null : getLiveKeywords,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Detection'),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton.icon(
                      onPressed: isListening ? stopListening : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    keywords.isEmpty ? 'Keywords: ...' : 'Keywords: $keywords',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                    onPressed: goHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String status = 'No file selected';
  String keywords = '';
  bool _busy = false;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => status = 'Could not read the selected video');
      return;
    }
    if (_apiBaseUrl.isEmpty) {
      setState(() => status = 'Video analysis service is not configured');
      return;
    }

    setState(() {
      _busy = true;
      status = 'Uploading...';
      keywords = '';
    });
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$_apiBaseUrl/upload'))
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: file.name));
      final response = await request.send().timeout(const Duration(minutes: 5));
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw Exception(data['error'] ?? 'Video analysis failed');
      }
      setState(() {
        keywords = (data['keywords'] as List? ?? const []).join(', ');
        status = 'Done';
      });
    } catch (error) {
      setState(() => status = 'Upload failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void goHome() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (route) => false,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Upload Video',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ElevatedButton(
                    onPressed: _busy ? null : pickFile,
                    child: const Text('Select Video')),
                const SizedBox(height: 15),
                if (_busy) const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text(status),
                const SizedBox(height: 20),
                if (keywords.isNotEmpty) Text(keywords),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                    onPressed: goHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
