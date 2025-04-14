import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3;

import 'config.dart';

class MessagesPage extends StatefulWidget {
  final String currentUsername;
  final String currentAddress;
  final String currentPrivateKey;
  const MessagesPage({
    Key? key,
    required this.currentUsername,
    required this.currentAddress,
    required this.currentPrivateKey,
  }) : super(key: key);

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late web3.Web3Client web3client;
  final String contractAddress = "0x94d27754C8C8290aA2C88E8C7F34270fDc7da2CB";
  final String abi =
      '[{"inputs":[{"internalType":"string","name":"_username","type":"string"},{"internalType":"string","name":"_userDataHash","type":"string"}],"name":"registerUser","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"_username","type":"string"}],"name":"getUser","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_userAddress","type":"address"}],"name":"getUserByAddress","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"string","name":"_contentHash","type":"string"}],"name":"createPost","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_postId","type":"uint256"}],"name":"getPost","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_receiver","type":"address"},{"internalType":"string","name":"_contentHash","type":"string"}],"name":"sendMessage","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_messageId","type":"uint256"}],"name":"getMessage","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"postCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"messageCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]';

  final TextEditingController _searchController = TextEditingController();
  String? errorMessage;
  Map<String, List<Map<String, dynamic>>> conversations = {};
  Map<String, List<Map<String, dynamic>>> filteredConversations = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    web3client = web3.Web3Client(Config.rpcUrl, http.Client());
    _fetchMessages();
    _searchController.addListener(_filterConversations);
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      _fetchMessages();
    });
  }

  Future<void> _fetchMessages() async {
    try {
      final contract = web3.DeployedContract(
          web3.ContractAbi.fromJson(abi, "SocialMedia"),
          web3.EthereumAddress.fromHex(contractAddress));
      final messageCountResult = await web3client.call(
          contract: contract,
          function: contract.function('messageCount'),
          params: []).timeout(Duration(seconds: 10));
      final messageCount = (messageCountResult[0] as BigInt).toInt();

      Map<String, List<Map<String, dynamic>>> tempConversations = {};
      for (int i = 1; i <= messageCount; i++) {
        final messageData = await web3client.call(
            contract: contract,
            function: contract.function('getMessage'),
            params: [BigInt.from(i)]).timeout(Duration(seconds: 10));
        final senderAddress = (messageData[0] as web3.EthereumAddress).hex;
        final receiverAddress = (messageData[1] as web3.EthereumAddress).hex;
        final contentHash = messageData[2] as String;
        final timestamp = (messageData[3] as BigInt).toInt();

        if (senderAddress.toLowerCase() !=
                widget.currentAddress.toLowerCase() &&
            receiverAddress.toLowerCase() !=
                widget.currentAddress.toLowerCase()) {
          continue;
        }

        final senderUsername = await web3client.call(
            contract: contract,
            function: contract.function('getUserByAddress'),
            params: [
              web3.EthereumAddress.fromHex(senderAddress)
            ]).timeout(Duration(seconds: 10));
        final receiverUsername = await web3client.call(
            contract: contract,
            function: contract.function('getUserByAddress'),
            params: [
              web3.EthereumAddress.fromHex(receiverAddress)
            ]).timeout(Duration(seconds: 10));

        final response = await http
            .get(Uri.parse('${Config.ipfsGatewayUrl}/ipfs/$contentHash'))
            .timeout(Duration(seconds: 10));
        if (response.statusCode != 200)
          throw Exception("Failed to fetch message content from IPFS");

        final messageJson = jsonDecode(response.body);
        final content = messageJson['content'];

        String otherUser =
            senderAddress.toLowerCase() == widget.currentAddress.toLowerCase()
                ? receiverUsername[0] as String
                : senderUsername[0] as String;
        if (!tempConversations.containsKey(otherUser)) {
          tempConversations[otherUser] = [];
        }

        tempConversations[otherUser]!.add({
          'sender': senderUsername[0] as String,
          'receiver': receiverUsername[0] as String,
          'content': content,
          'timestamp': timestamp,
          'senderAddress': senderAddress,
          'receiverAddress': receiverAddress,
        });
      }

      setState(() {
        conversations = tempConversations;
        filteredConversations = tempConversations;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Failed to fetch messages: $e";
      });
      print("Error in _fetchMessages: $e");
    }
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredConversations = conversations;
      } else {
        filteredConversations = {};
        conversations.forEach((user, messages) {
          if (user.toLowerCase().contains(query)) {
            filteredConversations[user] = messages;
          }
        });
      }
    });
  }

  void _showStartChatDialog() {
    showDialog(
      context: context,
      builder: (context) => StartChatDialog(
        web3client: web3client,
        contractAddress: contractAddress,
        abi: abi,
        currentUsername: widget.currentUsername,
        currentAddress: widget.currentAddress,
        currentPrivateKey: widget.currentPrivateKey,
      ),
    ).then(
        (_) => _fetchMessages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Messages",
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
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
                    controller: _searchController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search Conversations",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 15.0, horizontal: 16.0),
                    ),
                  ),
                ),
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorMessage!,
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Expanded(
                child: filteredConversations.isEmpty
                    ? Center(
                        child: Text(
                          "No conversations yet",
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 8.0),
                        itemCount: filteredConversations.keys.length,
                        itemBuilder: (context, index) {
                          final otherUser =
                              filteredConversations.keys.elementAt(index);
                          final messages = filteredConversations[otherUser]!;
                          final lastMessage = messages.last;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    currentUsername: widget.currentUsername,
                                    currentAddress: widget.currentAddress,
                                    currentPrivateKey: widget.currentPrivateKey,
                                    otherUsername: otherUser,
                                    otherAddress: lastMessage['senderAddress']
                                                .toLowerCase() ==
                                            widget.currentAddress.toLowerCase()
                                        ? lastMessage['receiverAddress']
                                        : lastMessage['senderAddress'],
                                    conversation: messages,
                                  ),
                                ),
                              ).then((_) => _fetchMessages());
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 8.0),
                              padding: EdgeInsets.all(16.0),
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
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.blue.shade400.withOpacity(0.2),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.transparent,
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
                                          otherUser[0].toUpperCase(),
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          otherUser,
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "${lastMessage['sender']}: ${lastMessage['content']}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color:
                                                Colors.white.withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateTime.fromMillisecondsSinceEpoch(
                                            lastMessage['timestamp'] * 1000)
                                        .toString()
                                        .substring(11, 16),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showStartChatDialog,
        backgroundColor: Colors.blue.shade400,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: "Start New Chat",
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 6,
      ),
    );
  }
}

class StartChatDialog extends StatefulWidget {
  final web3.Web3Client web3client;
  final String contractAddress;
  final String abi;
  final String currentUsername;
  final String currentAddress;
  final String currentPrivateKey;

  const StartChatDialog({
    Key? key,
    required this.web3client,
    required this.contractAddress,
    required this.abi,
    required this.currentUsername,
    required this.currentAddress,
    required this.currentPrivateKey,
  }) : super(key: key);

  @override
  _StartChatDialogState createState() => _StartChatDialogState();
}

class _StartChatDialogState extends State<StartChatDialog> {
  final TextEditingController _usernameController = TextEditingController();
  String? errorMessage;

  Future<void> _startChat() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        errorMessage = "Please enter a username";
      });
      return;
    }

    if (username.toLowerCase() == widget.currentUsername.toLowerCase()) {
      setState(() {
        errorMessage = "You cannot message yourself";
      });
      return;
    }

    try {
      final contract = web3.DeployedContract(
          web3.ContractAbi.fromJson(widget.abi, "SocialMedia"),
          web3.EthereumAddress.fromHex(widget.contractAddress));
      final userData = await widget.web3client.call(
          contract: contract,
          function: contract.function('getUser'),
          params: [username]).timeout(Duration(seconds: 10));
      final userAddress = userData[0] as web3.EthereumAddress;

      if (userAddress.hex == "0x0000000000000000000000000000000000000000") {
        setState(() {
          errorMessage = "User not found";
        });
        return;
      }

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            currentUsername: widget.currentUsername,
            currentAddress: widget.currentAddress,
            currentPrivateKey: widget.currentPrivateKey,
            otherUsername: username,
            otherAddress: userAddress.hex,
            conversation: [],
          ),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
      });
      print("Error in _startChat: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "Start New Chat",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.7),
                  Colors.black.withOpacity(0.7),
                ],
              ),
              border: Border.all(
                color: Colors.blue.shade400.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _usernameController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Enter Username",
                labelStyle: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                errorMessage!,
                style: GoogleFonts.poppins(
                  color: Colors.redAccent,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: GoogleFonts.poppins(
              color: Colors.purple.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _startChat,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade400,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shadowColor: Colors.blue.shade400.withOpacity(0.5),
            elevation: 4,
          ),
          child: Text(
            "Start Chat",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class ChatPage extends StatefulWidget {
  final String currentUsername;
  final String currentAddress;
  final String currentPrivateKey;
  final String otherUsername;
  final String otherAddress;
  final List<Map<String, dynamic>> conversation;

  const ChatPage({
    Key? key,
    required this.currentUsername,
    required this.currentAddress,
    required this.currentPrivateKey,
    required this.otherUsername,
    required this.otherAddress,
    required this.conversation,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late web3.Web3Client web3client;
  final String contractAddress = "0x94d27754C8C8290aA2C88E8C7F34270fDc7da2CB";
  final String abi =
      '[{"inputs":[{"internalType":"string","name":"_username","type":"string"},{"internalType":"string","name":"_userDataHash","type":"string"}],"name":"registerUser","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"_username","type":"string"}],"name":"getUser","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_userAddress","type":"address"}],"name":"getUserByAddress","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"string","name":"_contentHash","type":"string"}],"name":"createPost","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_postId","type":"uint256"}],"name":"getPost","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_receiver","type":"address"},{"internalType":"string","name":"_contentHash","type":"string"}],"name":"sendMessage","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_messageId","type":"uint256"}],"name":"getMessage","outputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"},{"internalType":"string","name":"","type":"string"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"postCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"messageCount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}]';

  final TextEditingController _messageController = TextEditingController();
  String? errorMessage;
  bool isSending = false;
  List<Map<String, dynamic>> messages = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    web3client = web3.Web3Client(Config.rpcUrl, http.Client());
    messages = widget.conversation;
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      setState(() {}); // Trigger rebuild to refresh
    });
  }

  Future<String> _uploadToIPFS(String data) async {
    final uri = Uri.parse('${Config.ipfsApiUrl}/add');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromString('data', data,
          filename: 'message.json'));
    final response = await request.send().timeout(Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200)
      throw Exception("IPFS upload failed: $responseBody");
    return jsonDecode(responseBody)['Hash'];
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      setState(() {
        errorMessage = "Message cannot be empty";
      });
      return;
    }

    setState(() {
      isSending = true;
      errorMessage = null;
    });

    try {
      final contract = web3.DeployedContract(
          web3.ContractAbi.fromJson(abi, "SocialMedia"),
          web3.EthereumAddress.fromHex(contractAddress));

      final messageData =
          jsonEncode({'content': content, 'sender': widget.currentUsername});
      final contentHash = await _uploadToIPFS(messageData);
      print("Message IPFS Hash: $contentHash");

      final txHash = await web3client
          .sendTransaction(
            web3.EthPrivateKey.fromHex(widget.currentPrivateKey),
            web3.Transaction.callContract(
              contract: contract,
              function: contract.function('sendMessage'),
              parameters: [
                web3.EthereumAddress.fromHex(widget.otherAddress),
                contentHash
              ],
            ),
            chainId: 1337,
          )
          .timeout(Duration(seconds: 30));

      print("Transaction hash: $txHash");

      setState(() {
        messages.add({
          'sender': widget.currentUsername,
          'receiver': widget.otherUsername,
          'content': content,
          'timestamp': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
          'senderAddress': widget.currentAddress,
          'receiverAddress': widget.otherAddress,
        });
        _messageController.clear();
        isSending = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Failed to send message: $e";
        isSending = false;
      });
      print("Error in _sendMessage: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      widget.otherUsername,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.blue.shade400.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Text(
                          "No messages yet",
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 8.0),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isSentByCurrentUser =
                              msg['sender'] == widget.currentUsername;
                          return Align(
                            alignment: isSentByCurrentUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 12),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSentByCurrentUser
                                      ? [
                                          Colors.blue.shade400,
                                          Colors.blue.shade600,
                                        ]
                                      : [
                                          Colors.grey.shade800,
                                          Colors.grey.shade900,
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSentByCurrentUser
                                        ? Colors.blue.shade400.withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isSentByCurrentUser
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['content'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    DateTime.fromMillisecondsSinceEpoch(
                                            msg['timestamp'] * 1000)
                                        .toString()
                                        .substring(11, 16),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorMessage!,
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.blue.shade900.withOpacity(0.9),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade400.withOpacity(0.2),
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
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
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Type a message...",
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.purple.shade400,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade400.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: isSending
                            ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                strokeWidth: 2,
                              )
                            : Icon(Icons.send, color: Colors.white),
                        onPressed: isSending ? null : _sendMessage,
                        padding: EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}