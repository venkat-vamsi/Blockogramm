import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3;

import 'config.dart';

class ExplorePage extends StatefulWidget {
  @override
  _ExplorePageState createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  late web3.Web3Client web3client;
  final String contractAddress = "0x3Eb11333C089746703258f500e7EEDB414e85812";
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
  List<Map<String, dynamic>> posts = [];
  String? errorMessage;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    web3client = web3.Web3Client(Config.rpcUrl, http.Client());
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _fetchPosts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    try {
      print("Fetching posts...");
      final contract = web3.DeployedContract(
          web3.ContractAbi.fromJson(abi, "SocialMedia"),
          web3.EthereumAddress.fromHex(contractAddress));

      final postCountResult = await web3client.call(
          contract: contract,
          function: contract.function('postCount'),
          params: []).timeout(Duration(seconds: 10));
      final postCount = (postCountResult[0] as BigInt).toInt();
      print("Post count: $postCount");

      if (postCount == 0) {
        setState(() {
          posts = [];
          errorMessage = "No posts found";
        });
        print("No posts found in contract");
        return;
      }

      List<Map<String, dynamic>> fetchedPosts = [];
      for (int i = 1; i <= postCount; i++) {
        print("Fetching post $i...");
        try {
          final postData = await web3client.call(
              contract: contract,
              function: contract.function('getPost'),
              params: [BigInt.from(i)]).timeout(Duration(seconds: 10));
          final sender = postData[0] as web3.EthereumAddress;
          final contentHash = postData[1] as String;
          final timestamp = (postData[2] as BigInt).toInt();
          print(
              "Post $i: sender=$sender, contentHash=$contentHash, timestamp=$timestamp");

          print("Fetching IPFS content for hash: $contentHash");
          final response = await http
              .get(Uri.parse('${Config.ipfsGatewayUrl}/ipfs/$contentHash'))
              .timeout(Duration(seconds: 10));
          if (response.statusCode == 200) {
            final content = response.body;
            print("IPFS content for $contentHash: $content");
            try {
              final postJson = jsonDecode(content);
              fetchedPosts.add({
                'username': postJson['username'] ?? 'Unknown',
                'caption': postJson['caption'] ?? '',
                'image': postJson['image'],
                'timestamp': timestamp,
              });
            } catch (e) {
              print("Not a JSON post, treating as text: $e");
              fetchedPosts.add({
                'username': 'Unknown',
                'caption': content,
                'image': null,
                'timestamp': timestamp,
              });
            }
          } else {
            print(
                "Failed to fetch IPFS content for hash $contentHash: ${response.statusCode} - ${response.body}");
          }
        } catch (e) {
          print("Error fetching post $i: $e");
        }
      }

      print("Fetched ${fetchedPosts.length} posts");
      setState(() {
        posts = fetchedPosts.reversed
            .toList(); // Reverse to show latest posts first
        errorMessage =
            fetchedPosts.isEmpty ? "No posts loaded successfully" : null;
      });
      _animationController.forward(from: 0);
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load posts: $e";
      });
      print("Error in _fetchPosts: $e");
    }
  }

  void _showFullImage(BuildContext context, String imageData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                base64Decode(imageData.split(',')[1]),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: EdgeInsets.all(20),
                  color: Colors.black87,
                  child: Text(
                    "Failed to load image",
                    style: GoogleFonts.poppins(
                      color: Colors.red.shade400,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade900, Colors.purple.shade900],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Explore",
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.blue.shade400.withOpacity(0.5),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white, size: 28),
                      onPressed: () {
                        setState(() {
                          posts = [];
                          errorMessage = null;
                        });
                        _fetchPosts();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade700.withOpacity(0.3),
                        padding: EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchPosts,
                  color: Colors.white,
                  backgroundColor: Colors.blue.shade700,
                  child: errorMessage != null
                      ? Center(
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.poppins(
                              color: Colors.red.shade400,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : posts.isEmpty
                          ? Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue.shade400),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 8.0),
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                return FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: _animationController,
                                    curve: Interval(
                                      (index / posts.length) * 0.5,
                                      1.0,
                                      curve: Curves.easeInOut,
                                    ),
                                  ),
                                  child: Card(
                                    elevation: 10,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    color: Colors.transparent,
                                    margin:
                                        EdgeInsets.symmetric(vertical: 10.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.black.withOpacity(0.7),
                                            Colors.blue.shade900
                                                .withOpacity(0.7),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.blue.shade400
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.shade400
                                                .withOpacity(0.2),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      padding: EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundColor:
                                                    Colors.transparent,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.blue.shade400,
                                                        Colors.purple.shade400,
                                                      ],
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      post['username'][0]
                                                          .toUpperCase(),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                post['username'],
                                                style: GoogleFonts.poppins(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          if (post['caption'] != null &&
                                              post['caption'].isNotEmpty)
                                            Text(
                                              post['caption'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                height: 1.4,
                                              ),
                                            ),
                                          SizedBox(height: 12),
                                          if (post['image'] != null)
                                            GestureDetector(
                                              onTap: () => _showFullImage(
                                                  context, post['image']),
                                              child: Hero(
                                                tag: 'post_image_$index',
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.memory(
                                                    base64Decode(post['image']
                                                        .split(',')[1]),
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: 220,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Container(
                                                        height: 220,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.black87,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            "Failed to load image",
                                                            style: GoogleFonts
                                                                .poppins(
                                                              color: Colors
                                                                  .red.shade400,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          SizedBox(height: 12),
                                          Text(
                                            "Posted on: ${DateTime.fromMillisecondsSinceEpoch(post['timestamp'] * 1000).toString()}",
                                            style: GoogleFonts.poppins(
                                              color:
                                                  Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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
