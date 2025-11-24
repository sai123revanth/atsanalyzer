import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

// --- CONSTANTS & THEME ---
const String _apiKey = "AIzaSyByOii7M0kU2B3DoABRGOeBYAtNpmvkt98";
const Color kBgColor = Color(0xFF0B0F19); // Deep dark navy/black
const Color kCardBgColor = Color(0xFF151B2E); // Slightly lighter blue-grey
const Color kPrimaryColor = Color(0xFF38BDF8); // Cyan/Light Blue
const Color kAccentPurple = Color(0xFFA855F7); // Purple
const Color kTextMain = Colors.white;
const Color kTextMuted = Color(0xFF94A3B8); // Slate 400

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Opaque ATS Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kBgColor,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryColor,
          surface: kCardBgColor,
          onSurface: kTextMain,
        ),
      ),
      home: const AnalyzerScreen(),
    );
  }
}

class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({super.key});

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  // Navigation State
  String _activeTab = 'home'; // 'home', 'input', 'results'

  // Data State
  final TextEditingController _resumeController = TextEditingController();
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _error;

  // File State
  String? _fileName;
  bool _isFileUploaded = false;

  // --- FILE HANDLING ---
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;

        setState(() {
          _fileName = file.name;
          // _fileExtension = file.extension; // Removed unused variable to fix warning
          _isFileUploaded = true;
          _error = null;
        });

        // Simulating text extraction for demo purposes:
        String extractedText = "Parsed content from ${_fileName}...\n\n[Full Resume Content Would Appear Here]\n\nJohn Doe\nSoftware Engineer...";

        // If it's a plain text file (and bytes are available), we can actually read it
        if (file.extension == 'txt' && file.bytes != null) {
          extractedText = utf8.decode(file.bytes!);
        }

        _resumeController.text = extractedText;
      }
    } catch (e) {
      setState(() => _error = "Error picking file: $e");
    }
  }

  void _clearFile() {
    setState(() {
      _fileName = null;
      _isFileUploaded = false;
      _resumeController.clear();
    });
  }

  // --- API LOGIC ---
  Future<void> _analyzeResume() async {
    final text = _resumeController.text.trim();

    // Validation
    if (!_isFileUploaded && text.isEmpty) {
      setState(() => _error = "Please upload a resume file first.");
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _analysisResult = null;
    });

    const systemPrompt = """
    You are an advanced Applicant Tracking System (ATS) and Career Coach. 
    Analyze the provided resume text rigorously. 
    Return a strict JSON object (no markdown formatting, just raw JSON) with the following structure:
    {
      "score": <integer_0_to_100>,
      "summary": "<short_executive_summary>",
      "pros": ["<point_1>", "<point_2>", ...],
      "cons": ["<point_1>", "<point_2>", ...]
    }
    Focus on keywords, formatting impact (implied), clarity, and impact metrics.
    """;

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$_apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "Resume Content from File ($_fileName):\n$text"}
              ]
            }
          ],
          "systemInstruction": {
            "parts": [
              {"text": systemPrompt}
            ]
          },
          "generationConfig": {"responseMimeType": "application/json"}
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("API Error: ${response.statusCode} - ${response.body}");
      }

      final data = jsonDecode(response.body);
      final aiText = data['candidates']?[0]['content']?['parts']?[0]['text'];

      if (aiText != null) {
        final parsed = jsonDecode(aiText);
        setState(() {
          _analysisResult = parsed;
          _activeTab = 'results';
        });
      } else {
        throw Exception("No analysis received from AI.");
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_activeTab) {
      case 'input':
        return _buildInputView();
      case 'results':
        return _buildResultsView();
      case 'home':
      default:
        return _buildHomeView();
    }
  }

  // --- HEADER ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: kBgColor.withValues(alpha: 0.8), // UPDATED
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))), // UPDATED
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.redAccent, Colors.orangeAccent],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
                child: const Icon(Icons.show_chart, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Opaque ATS",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.settings, color: Colors.grey[400]),
          )
        ],
      ),
    );
  }

  // --- HOME VIEW ---
  Widget _buildHomeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: [
                BoxShadow(color: kAccentPurple.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)), // UPDATED
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rocket_launch, size: 14, color: kAccentPurple),
                const SizedBox(width: 8),
                Text(
                  "New: AI-Powered Analytics 2.0",
                  style: TextStyle(color: kAccentPurple, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1.1, fontFamily: 'Roboto'),
              children: [
                const TextSpan(text: "Future-Proof\n"),
                TextSpan(text: "Your\n", style: TextStyle(color: Colors.grey[400])),
                const TextSpan(text: "Career Path"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "We transform complex resumes into ATS-optimized, job-winning profiles. Secure, scalable insights built for the recruitment of tomorrow.",
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextMuted, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _activeTab = 'input'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: kPrimaryColor.withValues(alpha: 0.4), // UPDATED
                ),
                child: const Text("Analyze Resume", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 60),
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)), // UPDATED
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.2), // UPDATED
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusChip(Icons.security, "Encrypted", Colors.greenAccent),
                    _buildStatusChip(Icons.show_chart, "99.9% Uptime", Colors.purpleAccent),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // UPDATED
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)), // UPDATED
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // --- INPUT VIEW ---
  Widget _buildInputView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _activeTab = 'home'),
            icon: const Icon(Icons.arrow_back, color: kTextMuted, size: 16),
            label: const Text("Back", style: TextStyle(color: kTextMuted)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          ),
          const SizedBox(height: 16),
          const Text("Upload Resume", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Supports .docx, .ppt, .pdf formats. Our AI will extract and analyze.", style: TextStyle(color: kTextMuted)),
          const SizedBox(height: 24),

          // --- FILE UPLOAD AREA ---
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: kCardBgColor.withValues(alpha: 0.5), // UPDATED
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _isFileUploaded ? kPrimaryColor : Colors.white.withValues(alpha: 0.1), // UPDATED
                    style: BorderStyle.solid,
                    width: _isFileUploaded ? 2 : 1
                ),
              ),
              child: CustomPaint(
                painter: _isFileUploaded ? null : DashedBorderPainter(color: Colors.white.withValues(alpha: 0.2)), // UPDATED
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isFileUploaded) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withValues(alpha: 0.1), // UPDATED
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.description, size: 40, color: kPrimaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _fileName ?? "Unknown File",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearFile,
                        child: const Text("Remove File", style: TextStyle(color: Colors.redAccent)),
                      )
                    ] else ...[
                      const Icon(Icons.cloud_upload_outlined, size: 48, color: kTextMuted),
                      const SizedBox(height: 16),
                      const Text(
                        "Tap to Browse Files",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "DOCX, PPTX, PDF, or TXT",
                        style: TextStyle(color: kTextMuted.withValues(alpha: 0.7), fontSize: 12), // UPDATED
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- EXTRACTED TEXT PREVIEW (Required for analysis context) ---
          if (_isFileUploaded) ...[
            Row(
              children: [
                const Icon(Icons.visibility_outlined, size: 16, color: kTextMuted),
                const SizedBox(width: 8),
                Text("Parsed Content Preview (Editable)", style: TextStyle(color: kTextMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)), // UPDATED
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _resumeController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5, color: Color(0xFFE2E8F0)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Extracted text will appear here...",
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),

          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1), // UPDATED
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)), // UPDATED
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAnalyzing || !_isFileUploaded ? null : _analyzeResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                disabledBackgroundColor: kCardBgColor,
                disabledForegroundColor: Colors.grey,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isAnalyzing
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
              )
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined),
                  SizedBox(width: 12),
                  Text("Analyze File", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- RESULTS VIEW ---
  Widget _buildResultsView() {
    if (_analysisResult == null) return const SizedBox.shrink();

    final score = _analysisResult!['score'] as int;
    final summary = _analysisResult!['summary'] as String;
    final pros = List<String>.from(_analysisResult!['pros']);
    final cons = List<String>.from(_analysisResult!['cons']);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                _clearFile();
                setState(() => _activeTab = 'input');
              },
              icon: const Icon(Icons.refresh, color: kTextMuted, size: 16),
              label: const Text("New Scan", style: TextStyle(color: kTextMuted)),
            ),
            Text("ID: ${math.Random().nextInt(999999)}", style: TextStyle(fontFamily: 'monospace', color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          height: 200,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: kCardBgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)), // UPDATED
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 100,
                        width: 100,
                        child: CustomPaint(
                          painter: ScorePainter(score: score),
                          child: Center(
                            child: Text(
                              "$score",
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("SCORE", style: TextStyle(color: Colors.grey[500], fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCardBgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)), // UPDATED
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: kAccentPurple),
                          SizedBox(width: 8),
                          Text("AI SUMMARY", style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            summary,
                            style: const TextStyle(height: 1.4, fontSize: 13, color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildListCard("Strong Points", pros, Colors.greenAccent, Icons.check_circle_outline),
        const SizedBox(height: 16),
        _buildListCard("Improvements", cons, Colors.redAccent, Icons.highlight_off),
        const SizedBox(height: 32),
        Center(
          child: TextButton(
            onPressed: () {},
            child: const Text("Download Detailed PDF Report", style: TextStyle(color: kPrimaryColor)),
          ),
        )
      ],
    );
  }

  Widget _buildListCard(String title, List<String> items, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBgColor.withValues(alpha: 0.6), // UPDATED
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)), // UPDATED
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFCBD5E1)))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// --- CUSTOM PAINTERS ---
class ScorePainter extends CustomPainter {
  final int score;
  ScorePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (score > 90) fgPaint.color = Colors.greenAccent;
    else if (score > 75) fgPaint.color = kPrimaryColor;
    else if (score > 50) fgPaint.color = Colors.orangeAccent;
    else fgPaint.color = Colors.redAccent;

    double arcAngle = 2 * math.pi * (score / 100);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, arcAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant ScorePainter oldDelegate) => oldDelegate.score != score;
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 8.0;

    // Top
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
    // Bottom
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height), Offset(startX + dashWidth, size.height), paint);
      startX += dashWidth + dashSpace;
    }
    // Left
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
    // Right
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(size.width, startY), Offset(size.width, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}