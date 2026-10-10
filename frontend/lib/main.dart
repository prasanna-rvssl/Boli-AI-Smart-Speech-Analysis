import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

void main() => runApp(const BoliApp());

class BoliApp extends StatelessWidget {
  const BoliApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Boli — AI Smart Speech Analysis',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6C4CF1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        ),
        home: const BoliHome(),
      );
}

class BoliHome extends StatefulWidget {
  const BoliHome({super.key});

  @override
  State<BoliHome> createState() => _BoliHomeState();
}

class _BoliHomeState extends State<BoliHome> {
  final _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  bool _busy = false;
  String _transcript = '';
  String _message = 'Tap the microphone and say a few words.';
  List<String> _keywords = [];
  Timer? _restartTimer;
  static const _fillers = {
    'um', 'uh', 'hmm', 'like', 'you', 'know', 'ok', 'okay', 'the', 'and',
  };

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          if (!mounted) return;
          _listening = false;
          _restartTimer?.cancel();
          setState(() => _message = 'Microphone error: ${error.errorMsg}');
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted || !_listening || status != 'notListening') return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _listening) _listenAgain();
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
          setState(() {
            _transcript = result.recognizedWords;
            _keywords = _extractKeywords(_transcript);
            _message = _transcript.isEmpty
                ? 'Listening… speak naturally.'
                : 'Listening… keywords update as you speak.';
          });
        },
      );
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not start microphone recognition.');
    }
  }

  List<String> _extractKeywords(String text) {
    final seen = <String>{};
    for (final word in text.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (word.length > 2 && !_fillers.contains(word)) seen.add(word);
      if (seen.length == 10) break;
    }
    return seen.toList();
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) await _initializeSpeech();
    if (!_speechAvailable) {
      setState(() => _message = 'Microphone speech recognition is unavailable in this browser. Try Chrome or Edge.');
      return;
    }
    setState(() {
      _listening = true;
      _transcript = '';
      _keywords = [];
      _message = 'Requesting microphone access…';
    });
    await _listenAgain();
  }

  Future<void> _stopListening() async {
    _restartTimer?.cancel();
    _listening = false;
    await _speech.stop();
    if (mounted) setState(() => _message = 'Listening stopped.');
  }

  Future<void> _uploadVideo() async {
    if (_apiBaseUrl.isEmpty) {
      setState(() => _message = 'Video analysis is not configured yet. Live microphone analysis is ready.');
      return;
    }
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (selection == null) return;
    final file = selection.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _message = 'This browser could not read the selected video. Try another file.');
      return;
    }

    setState(() {
      _busy = true;
      _message = 'Uploading and analyzing ${file.name}…';
      _keywords = [];
      _transcript = '';
    });
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_apiBaseUrl/upload'))
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
      final response = await request.send().timeout(const Duration(minutes: 5));
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw Exception(data['error'] ?? 'Video analysis failed');
      }
      if (!mounted) return;
      setState(() {
        _keywords = List<String>.from(data['keywords'] ?? const []);
        _transcript = data['transcript'] as String? ?? '';
        _message = _keywords.isEmpty ? 'No speech detected.' : 'Video analysis complete.';
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Upload failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.graphic_eq, color: Color(0xFF6C4CF1), size: 36),
                      SizedBox(width: 10),
                      Text('Boli', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('AI Smart Speech Analysis', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: EdgeInsets.all(width < 500 ? 20 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Turn speech into key ideas', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Speak into your microphone for live keywords, or choose a video to analyze.',
                              style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
                          const SizedBox(height: 26),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _listening ? _stopListening : _startListening,
                                icon: Icon(_listening ? Icons.stop : Icons.mic),
                                label: Text(_listening ? 'Stop listening' : 'Start listening'),
                                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _uploadVideo,
                                icon: const Icon(Icons.video_file_outlined),
                                label: const Text('Analyze a video'),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFFF2EFFD), borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              else Icon(_listening ? Icons.hearing : Icons.info_outline, color: const Color(0xFF6C4CF1)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_message, style: const TextStyle(height: 1.4))),
                            ]),
                          ),
                          if (_transcript.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            const Text('What Boli heard', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(_transcript, style: TextStyle(color: Colors.grey.shade800, height: 1.5)),
                          ],
                          const SizedBox(height: 22),
                          const Text('KEYWORDS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Color(0xFF6C4CF1))),
                          const SizedBox(height: 12),
                          if (_keywords.isEmpty)
                            Text('Your key words will show up here.', style: TextStyle(color: Colors.grey.shade600))
                          else
                            Wrap(spacing: 8, runSpacing: 8, children: _keywords.map((word) => Chip(label: Text(word))).toList()),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Microphone access is requested only when you start listening. Browser speech recognition availability varies.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
