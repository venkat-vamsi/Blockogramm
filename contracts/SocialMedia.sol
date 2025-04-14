pragma solidity ^0.8.0;

contract SocialMedia {
    struct User {
        address userAddress;
        string username;
        string userDataHash;
        bool exists;
    }
    struct Post {
        address sender;
        string contentHash;
        uint256 timestamp;
    }
    struct Message {
        address sender;
        address receiver;
        string contentHash;
        uint256 timestamp;
    }
    mapping(string => User) public users;
    mapping(address => string) public addressToUsername;
    mapping(uint256 => Post) public posts;
    uint256 public postCount;
    mapping(uint256 => Message) public messages;
    uint256 public messageCount;

    function registerUser(string memory _username, string memory _userDataHash) public {
        require(!users[_username].exists, "Username taken");
        users[_username] = User(msg.sender, _username, _userDataHash, true);
        addressToUsername[msg.sender] = _username;
    }

    function getUser(string memory _username) public view returns (address, string memory, string memory) {
        require(users[_username].exists, "User not found");
        User memory user = users[_username];
        return (user.userAddress, user.username, user.userDataHash);
    }

    function getUserByAddress(address _userAddress) public view returns (string memory) {
        string memory username = addressToUsername[_userAddress];
        require(bytes(username).length > 0, "User not found");
        return username;
    }

    function createPost(string memory _contentHash) public {
        postCount++;
        posts[postCount] = Post(msg.sender, _contentHash, block.timestamp);
    }

    function getPost(uint256 _postId) public view returns (address, string memory, uint256) {
        Post memory post = posts[_postId];
        return (post.sender, post.contentHash, post.timestamp);
    }

    function sendMessage(address _receiver, string memory _contentHash) public {
        messageCount++;
        messages[messageCount] = Message(msg.sender, _receiver, _contentHash, block.timestamp);
    }

    function getMessage(uint256 _messageId) public view returns (address, address, string memory, uint256) {
        Message memory message = messages[_messageId];
        return (message.sender, message.receiver, message.contentHash, message.timestamp);
    }
}