import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:frontend/home.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3;

import 'config.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late web3.Web3Client web3client;
  final String contractAddress =
      "0x94d27754C8C8290aA2C88E8C7F34270fDc7da2CB";
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

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLogin = true;
  String? errorMessage;
  bool _obscurePassword = true;

  final List<String> privateKeys = [
    "0xe02bb16d6c3c84f25639bd133f610810d855c7b2afa773acd9820d0563e4964b",
    "0xb480ed09cec8c2a85dcc90c8dcba947a88a2c1123a9a2a5a6796817e33c14d7f",
    "0x9aad1af879aa26bc48df11deec7cabfc729d3bb58c8535fd2988f7fe55b61725",
    "0x26693e7cdac6b7dbf4d2bb83ae1635e2636b05714bdff1b9dc3db675f1ac6afa",
    "0xda271c4e8cac7be6371f38cf51cf1a368b6ea02ba752111a6a1eb9671a20df34",
    "0x58f0b6499aa3ac19934d9c788d96a51c05589482dcfa8fba240e4701ecf1ee56",
    "0xa265cb15f139e80e88afee455b30ca1fb63d1bf89e7088bd5bb45c1588188d8f",
    "0xd614cb5e69b7858032c6f7680c40ed0fa73cb6cacf79f4c231223b2fbb97b466",
    "0x4233891eb697605e904355130ef67dedfb1fcc1ce8d3f38a59f0d1d480fc521c",
    "0xf9413d3e3ab61ca6212ec4cebe3bcc637e30ae7d19bfa2c67255b31bcc25101e",
  ];

  Map<String, String> assignedPrivateKeys = {};

  @override
  void initState() {
    super.initState();
    web3client = web3.Web3Client(Config.rpcUrl, http.Client());
    _loadAssignedPrivateKeys();
  }

  Future<void> _loadAssignedPrivateKeys() async {
    try {
      final response = await http
          .get(Uri.parse(Config.keysServerUrl))
          .timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final assignedList = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          assignedPrivateKeys = Map.fromEntries(assignedList
              .map((e) => MapEntry(e['username'], e['privateKey'])));
        });
        print("Loaded assigned private keys: $assignedPrivateKeys");
      } else {
        setState(() {
          assignedPrivateKeys = {};
        });
        print("No assigned keys found, starting fresh");
      }
    } catch (e) {
      setState(() {
        assignedPrivateKeys = {};
      });
      print("Error loading assigned keys: $e");
    }
  }

  Future<void> _saveAssignedPrivateKeys(
      String username, String privateKey) async {
    setState(() {
      assignedPrivateKeys[username] = privateKey;
    });
    final assignedList = assignedPrivateKeys.entries
        .map((e) => {'username': e.key, 'privateKey': e.value})
        .toList();
    print("Saving assigned private keys: $assignedList");
    final response = await http
        .put(
          Uri.parse(Config.keysServerUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(assignedList),
        )
        .timeout(Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception("Failed to update assigned keys: ${response.body}");
    }
    print("Successfully updated assigned keys");
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = crypto.sha256.convert(bytes);
    return hash.toString();
  }

  Future<String> _uploadToIPFS(String data) async {
    final uri = Uri.parse('${Config.ipfsApiUrl}/add');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
          http.MultipartFile.fromString('data', data, filename: 'user.json'));
    final response = await request.send().timeout(Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200)
      throw Exception("IPFS upload failed: $responseBody");
    return jsonDecode(responseBody)['Hash'];
  }

  Future<void> _registerOrLogin() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty || (!isLogin && email.isEmpty)) {
      setState(() {
        errorMessage = "Please fill in all fields";
      });
      return;
    }

    try {
      final contract = web3.DeployedContract(
          web3.ContractAbi.fromJson(abi, "SocialMedia"),
          web3.EthereumAddress.fromHex(contractAddress));

      if (isLogin) {
        final userData = await web3client.call(
            contract: contract,
            function: contract.function('getUser'),
            params: [username]).timeout(Duration(seconds: 10));
        final userAddress = userData[0] as web3.EthereumAddress;
        final userDataHash = userData[2] as String;

        if (userAddress.hex == "0x0000000000000000000000000000000000000000") {
          setState(() {
            errorMessage = "User not found. Please register.";
          });
          return;
        }

        final response = await http
            .get(Uri.parse('${Config.ipfsGatewayUrl}/ipfs/$userDataHash'))
            .timeout(Duration(seconds: 10));
        if (response.statusCode != 200)
          throw Exception("Failed to fetch user data from IPFS");

        final userJson = jsonDecode(response.body);
        final storedPasswordHash = userJson['passwordHash'];

        final enteredPasswordHash = _hashPassword(password);
        if (storedPasswordHash != enteredPasswordHash) {
          setState(() {
            errorMessage = "Incorrect password.";
          });
          return;
        }

        String privateKey = '';
        bool found = false;
        for (var pk in privateKeys) {
          final ethPrivateKey = web3.EthPrivateKey.fromHex(pk);
          if (ethPrivateKey.address.hex.toLowerCase() ==
              userAddress.hex.toLowerCase()) {
            privateKey = pk;
            found = true;
            break;
          }
        }

        if (!found) {
          setState(() {
            errorMessage = "No private key found for this user.";
          });
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(
              username: username,
              privateKey: privateKey,
              address: userAddress.hex,
            ),
          ),
        );
      } else {
        bool userExists = false;
        try {
          final userData = await web3client.call(
              contract: contract,
              function: contract.function('getUser'),
              params: [username]).timeout(Duration(seconds: 10));
          final userAddress = userData[0] as web3.EthereumAddress;
          if (userAddress.hex != "0x0000000000000000000000000000000000000000") {
            userExists = true;
          }
        } catch (e) {
          if (e.toString().contains("User not found")) {
            userExists = false;
          } else {
            throw e;
          }
        }

        if (userExists) {
          setState(() {
            errorMessage = "Username already taken.";
          });
          return;
        }

        String selectedPrivateKey = '';
        bool found = false;
        for (var pk in privateKeys) {
          if (!assignedPrivateKeys.values.contains(pk)) {
            selectedPrivateKey = pk;
            found = true;
            break;
          }
        }

        if (!found) {
          setState(() {
            errorMessage =
                "No more available accounts. Please add more private keys to the list.";
          });
          return;
        }

        final ethPrivateKey = web3.EthPrivateKey.fromHex(selectedPrivateKey);
        final address = ethPrivateKey.address.hex;
        print(
            "Assigned private key $selectedPrivateKey (address: $address) to user $username");

        final key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1');
        final iv = encrypt.IV.fromLength(16);
        final encrypter = encrypt.Encrypter(encrypt.AES(key));
        final encryptedEmail = encrypter.encrypt(email, iv: iv);

        final passwordHash = _hashPassword(password);

        final userDataJson = jsonEncode({
          'email': encryptedEmail.base64,
          'iv': iv.base64,
          'passwordHash': passwordHash,
        });

        final userDataHash = await _uploadToIPFS(userDataJson);
        print("User IPFS Hash: $userDataHash");

        await web3client
            .sendTransaction(
              ethPrivateKey,
              web3.Transaction.callContract(
                contract: contract,
                function: contract.function('registerUser'),
                parameters: [username, userDataHash],
              ),
              chainId: 1337,
            )
            .timeout(Duration(seconds: 30));

        await _saveAssignedPrivateKeys(username, selectedPrivateKey);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(
              username: username,
              privateKey: selectedPrivateKey,
              address: address,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
      });
      print("Error in _registerOrLogin: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.purple.shade300],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLogin ? 'Welcome Back!' : 'Join Us!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black26,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    style: TextStyle(color: Colors.black),
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(Icons.person, color: Colors.blue.shade700),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    style: TextStyle(color: Colors.black),
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock, color: Colors.blue.shade700),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.blue.shade700,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 20),
                    ),
                    obscureText: _obscurePassword,
                  ),
                ),
                if (!isLogin) ...[
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: TextStyle(color: Colors.black),
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon:
                            Icon(Icons.email, color: Colors.blue.shade700),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 20),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 24),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _registerOrLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black26,
                  ),
                  child: Text(
                    isLogin ? "Login" : "Register",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                      errorMessage = null;
                      _usernameController.clear();
                      _passwordController.clear();
                      _emailController.clear();
                    });
                  },
                  child: Text(
                    isLogin
                        ? "Need to register? Sign up"
                        : "Already have an account? Log in",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          blurRadius: 5.0,
                          color: Colors.black26,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
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