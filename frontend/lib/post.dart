import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env file: $e");
  }
  runApp(const PostApp());
}

class PostApp extends StatelessWidget {
  const PostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: GoogleFonts.poppinsTextTheme().apply(bodyColor: Colors.white),
      ),
      home: const PostPage(
        username: "test_user",
        privateKey: "your_private_key_here",
        address: "your_address_here",
      ),
    );
  }
}

class PostPage extends StatefulWidget {
  final String username;
  final String privateKey;
  final String address;
  const PostPage({
    Key? key,
    required this.username,
    required this.privateKey,
    required this.address,
  }) : super(key: key);

  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  late web3.Web3Client web3client;
  final String contractAddress = "0x94d27754C8C8290aA2C88E8C7F34270fDc7da2CB";
  final String abi = '''[
    {"inputs":[{"internalType":"string","name":"_username","type":"string"},{"internalType":"string","name":"_userDataHash","type":"string"}],"name":"registerUser","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"string","name":"_username","type":"string"}],"name":"getUser","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},
    {"inputs":[{"internalType":"address","name":"_userAddress","type":"address"}],"name":"getUserByAddress","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},
    {"inputs":[{"internalType":"string","name":"_contentHash","type":"string"}],"name":"createPost","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"uint256","name":"_postId","type":"uint256"}],"name":"getPost","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[{"internalType":"address","name":"_receiver","type":"address"},{"internalType":"string","name":"_contentHash","type":"string"}],"name":"sendMessage","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[{"internalType":"uint256","name":"_messageId","type":"uint256"}],"name":"getMessage","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"postCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"messageCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
  ]''';
  final TextEditingController _captionController = TextEditingController();
  File? _image;
  final picker = ImagePicker();
  bool _isPosting = false;
  bool _isInitialized = false;
  List<bool> _stageCompleted = [false, false, false, false];
  List<String> _stageLabels = [
    'AI SCAN',
    'SCAN COMPLETE',
    'UPLOADING',
    'LIVE ON IPFS'
  ];
  String geminiApiKey = '';

  @override
  void initState() {
    super.initState();
    web3client = web3.Web3Client(Config.rpcUrl, http.Client());
    _initializeEnv();
  }

  Future<void> _initializeEnv() async {
    try {
      geminiApiKey = dotenv.env['GEMINI_API_KEY'] ??
          'AIzaSyAVKSesFx5S5oXC6UJWJE76N5RDueHem98';
      setState(() => _isInitialized = true);
    } catch (e) {
      print('Env initialization error: $e');
      geminiApiKey = 'AIzaSyAVKSesFx5S5oXC6UJWJE76N5RDueHem98';
      setState(() => _isInitialized = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load API key: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<bool> _checkContentWithGemini(String content) async {
    if (!_isInitialized) {
      print('Gemini API not initialized');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API not ready—try again!', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '''
Analyze the following text for harmful content, including threats, violence, hate speech, curse words, or cybercrime indicators (e.g., phishing, hacking instructions). Return exactly one word: "SAFE" if the content is safe, or "NOT_SAFE" if it contains any harmful elements. Do not include explanations or additional text.

Text: "$content"
'''
                }
              ]
            }
          ],
          'safetySettings': [
            {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
            {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
            {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
            {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'}
          ]
        }),
      ).timeout(const Duration(seconds: 10));

      print('Gemini API response status: ${response.statusCode}');
      print('Gemini API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['candidates'][0]['content']['parts'][0]['text'].trim();
        return result == 'SAFE';
      } else {
        throw Exception('Gemini API error: ${response.body}');
      }
    } catch (e) {
      print('Gemini check error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Content check failed: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
  }

  Future<String> _uploadToIPFS(String data) async {
    final uri = Uri.parse('${Config.ipfsApiUrl}/add');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromString('data', data, filename: 'post.json'));
    final response = await request.send().timeout(const Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      throw Exception("IPFS upload failed: $responseBody");
    }
    return jsonDecode(responseBody)['Hash'];
  }

  Future<void> _createPost() async {
    if (_captionController.text.isEmpty && _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add a caption or image, neon runner!', style: GoogleFonts.poppins()),
          backgroundColor: Colors.purpleAccent,
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
      _stageCompleted = [false, false, false, false];
    });

    try {
      // Stage 1: AI Content Check
      String caption = _captionController.text;
      setState(() => _stageCompleted[0] = true);
      await Future.delayed(const Duration(milliseconds: 500));

      // Stage 2: AI Result
      bool isContentSafe = await _checkContentWithGemini(caption);
      setState(() => _stageCompleted[1] = true);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!isContentSafe) {
        setState(() => _isPosting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content flagged by AI—recalibrate and try again!',
                style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // Stage 3: Posting
      String? imageBase64;
      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        imageBase64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
      }

      final postData = jsonEncode({
        'username': widget.username,
        'caption': caption,
        'image': imageBase64,
      });

      setState(() => _stageCompleted[2] = true);
      await Future.delayed(const Duration(milliseconds: 500));

      // Stage 4: Posted to IPFS
      final contentHash = await _uploadToIPFS(postData);
      print("Post IPFS Hash: $contentHash");

      final contract = web3.DeployedContract(
          web3.ContractAbi.fromJson(abi, "SocialMedia"),
          web3.EthereumAddress.fromHex(contractAddress));
      await web3client
          .sendTransaction(
            web3.EthPrivateKey.fromHex(widget.privateKey),
            web3.Transaction.callContract(
              contract: contract,
              function: contract.function('createPost'),
              parameters: [contentHash],
            ),
            chainId: 1337,
          )
          .timeout(const Duration(seconds: 30));

      setState(() => _stageCompleted[3] = true);
      await Future.delayed(const Duration(milliseconds: 500));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post live in the BlockoGram!', style: GoogleFonts.poppins()),
          backgroundColor: Colors.blue.shade400,
        ),
      );
      _captionController.clear();
      setState(() {
        _image = null;
        _isPosting = false;
      });
    } catch (e) {
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in the matrix: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      print("Error in _createPost: $e");
    }
  }

  Widget _buildStageIndicator() {
    return Column(
      children: List.generate(_stageLabels.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _stageCompleted[index]
                        ? [Colors.blue.shade400, Colors.purple.shade400]
                        : [Colors.grey.shade900, Colors.grey.shade800],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _stageCompleted[index]
                          ? Colors.blue.shade400.withOpacity(0.5)
                          : Colors.transparent,
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Center(
                  child: _stageCompleted[index]
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _stageLabels[index],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _stageCompleted[index]
                        ? Colors.white
                        : Colors.grey.shade600,
                    shadows: [
                      Shadow(
                        color: _stageCompleted[index]
                            ? Colors.blue.shade400.withOpacity(0.3)
                            : Colors.transparent,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              if (index < _stageLabels.length - 1)
                Expanded(
                  child: CustomPaint(
                    painter: DottedLinePainter(isActive: _stageCompleted[index]),
                    size: const Size(double.infinity, 20),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.purple.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.blue),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.purple.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPLOAD TO THE BlockoGram',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            color: Colors.blue.shade400.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.blue.shade900.withOpacity(0.7),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.blue.shade400.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade400.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Caption...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: _image == null ? 120 : 260,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.blue.shade400.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade400.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _image == null
                          ? Center(
                              child: Text(
                                'Image not selected',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(_image!, fit: BoxFit.cover),
                            ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _pickImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.purple.shade400),
                            ),
                            shadowColor: Colors.purple.shade400.withOpacity(0.5),
                            elevation: 6,
                          ),
                          child: Text(
                            'LOAD IMAGE',
                            style: GoogleFonts.poppins(
                              color: Colors.purple.shade400,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isPosting ? null : _createPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            shadowColor: Colors.blue.shade400.withOpacity(0.5),
                            elevation: 6,
                          ),
                          child: Text(
                            'UPLOAD',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_isPosting)
                Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LoadingAnimationWidget.staggeredDotsWave(
                          color: Colors.blue.shade400,
                          size: 60,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 320,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.9),
                                Colors.blue.shade900.withOpacity(0.9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.blue.shade400.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade400.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: _buildStageIndicator(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  final bool isActive;
  DottedLinePainter({this.isActive = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? Colors.blue.shade400 : Colors.grey.shade700
      ..strokeWidth = 2;
    const dashWidth = 6;
    const dashSpace = 4;
    double startY = size.height / 2;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + dashWidth, startY),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}