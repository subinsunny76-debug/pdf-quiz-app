import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Quiz App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QuestionModel {
  final String questionText;
  final Map<String, String> options;
  final String correctAnswer;

  QuestionModel({
    required this.questionText,
    required this.options,
    required this.correctAnswer,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;

  Future<void> _pickAndParsePdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);

        File file = File(result.files.single.path!);
        List<int> bytes = await file.readAsBytes();

        // PDF ൽ നിന്ന് ടെക്സ്റ്റ് എക്സ്ട്രാക്റ്റ് ചെയ്യുന്നു
        PdfDocument document = PdfDocument(inputBytes: bytes);
        PdfTextExtractor extractor = PdfTextExtractor(document);
        String extractedText = extractor.extractText();
        document.dispose();

        // ചോദ്യങ്ങൾ വേർതിരിച്ചെടുക്കൽ
        List<QuestionModel> questions = parseQuestions(extractedText);

        setState(() => _isLoading = false);

        if (questions.isEmpty) {
          _showMessage("ചോദ്യങ്ങൾ വേർതിരിച്ചെടുക്കാൻ കഴിഞ്ഞില്ല. ഫോർമാറ്റ് പരിശോധിക്കുക.");
          return;
        }

        // ചോദ്യങ്ങൾ ക്രമം മാറ്റുന്നു (Shuffle)
        questions.shuffle();

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(questions: questions),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("പിഴവ് സംഭവിച്ചു: $e");
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // കേരള പി.എസ്.സി ചോദ്യപേപ്പർ രീതിയിലുള്ള ടെക്സ്റ്റ് പാഴ്സ് ചെയ്യുന്ന ലോജിക്
  List<QuestionModel> parseQuestions(String text) {
    List<QuestionModel> list = [];

    // 'Question' വെച്ച് ടെക്സ്റ്റിനെ വിഭജിക്കുന്നു
    List<String> rawQuestions = text.split(RegExp(r'Question\s*\d+:-'));

    for (int i = 1; i < rawQuestions.length; i++) {
      String chunk = rawQuestions[i].trim();

      // ചോദ്യഭാഗം, ഓപ്ഷനുകൾ, ശരിയായ ഉത്തരം എന്നിവ Regex വഴി കണ്ടെത്തുന്നു
      final optionPattern = RegExp(
        r'([\s\S]*?)'
        r'A:-(.*?)(?=B:-)'
        r'B:-(.*?)(?=C:-)'
        r'C:-(.*?)(?=D:-)'
        r'D:-(.*?)(?=Correct Answer:-)'
        r'Correct Answer:-\s*Option-?([A-D])',
        dotAll: true,
      );

      Match? match = optionPattern.firstMatch(chunk);
      if (match != null) {
        String qText = match.group(1)?.trim() ?? "";
        String optA = match.group(2)?.trim() ?? "";
        String optB = match.group(3)?.trim() ?? "";
        String optC = match.group(4)?.trim() ?? "";
        String optD = match.group(5)?.trim() ?? "";
        String ans = match.group(6)?.trim() ?? "";

        // ചോദ്യം ക്യാൻസൽ ചെയ്യപ്പെട്ടതല്ലാതെ ശരിയായ ഓപ്ഷൻ ഉണ്ടെങ്കിൽ മാത്രം ചേർക്കുക
        if (ans.isNotEmpty && ['A', 'B', 'C', 'D'].contains(ans)) {
          list.add(QuestionModel(
            questionText: qText,
            options: {
              'A': optA,
              'B': optB,
              'C': optC,
              'D': optD,
            },
            correctAnswer: ans,
          ));
        }
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF ക്വിസ് ആപ്പ്'),
        centerTitle: true,
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("പിഡിഎഫ് പ്രോസസ്സ് ചെയ്യുന്നു, ദയവായി കാത്തിരിക്കുക..."),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 80, color: Colors.indigo),
                    const SizedBox(height: 25),
                    const Text(
                      'ചോദ്യപേപ്പർ പിഡിഎഫ് ഫയൽ തിരഞ്ഞെടുക്കുക',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickAndParsePdf,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select PDF', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final List<QuestionModel> questions;

  const QuizScreen({super.key, required this.questions});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedOption;
  bool _isAnswered = false;

  void _checkAnswer(String optionKey) {
    if (_isAnswered) return;

    setState(() {
      _selectedOption = optionKey;
      _isAnswered = true;

      if (optionKey == widget.questions[_currentIndex].correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _isAnswered = false;
      });
    } else {
      // എല്ലാ ചോദ്യങ്ങളും കഴിഞ്ഞാൽ റിസൾട്ട് കാണിക്കുന്നു
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            score: _score,
            total: widget.questions.length,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('ചോദ്യം: ${_currentIndex + 1} / ${widget.questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.questions.length,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentQ.questionText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    ...currentQ.options.entries.map((entry) {
                      Color? buttonColor;
                      if (_isAnswered) {
                        if (entry.key == currentQ.correctAnswer) {
                          buttonColor = Colors.green.shade100;
                        } else if (entry.key == _selectedOption) {
                          buttonColor = Colors.red.shade100;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: buttonColor,
                            padding: const EdgeInsets.all(12),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () => _checkAnswer(entry.key),
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 15),
                    if (_isAnswered)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedOption == currentQ.correctAnswer
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedOption == currentQ.correctAnswer
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        child: Text(
                          _selectedOption == currentQ.correctAnswer
                              ? "ശരിയായ ഉത്തരം!"
                              : "തെറ്റായ ഉത്തരം!\nശരിയായ ഉത്തരം: Option-${currentQ.correctAnswer} (${currentQ.options[currentQ.correctAnswer]})",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _selectedOption == currentQ.correctAnswer
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_isAnswered)
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _currentIndex == widget.questions.length - 1 ? 'സ്കോർ കാണുക' : 'അടുത്ത ചോദ്യം',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final int score;
  final int total;

  const ResultScreen({super.key, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    double percentage = total > 0 ? (score / total) * 100 : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('പരീക്ഷാ ഫലം')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 90, color: Colors.amber),
              const SizedBox(height: 20),
              const Text(
                'നിങ്ങളുടെ പരീക്ഷ പൂർത്തിയായി!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                'മാർക്ക്: $score / $total',
                style: const TextStyle(fontSize: 28, color: Colors.indigo, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'ശതമാനം: ${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 35),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.replay),
                label: const Text('മറ്റൊരു ഫയൽ തിരഞ്ഞെടുക്കുക'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
