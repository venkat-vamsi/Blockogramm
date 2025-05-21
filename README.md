<div style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; background-color: #f9f9f9; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
  <h1 style="color: #2c3e50; text-align: center; border-bottom: 2px solid #3498db; padding-bottom: 10px;">BlockoGram: AI-Powered Decentralized Social Media Application</h1>
  
  <p style="font-size: 16px; line-height: 1.6; color: #34495e;">
    <strong>BlockoGram</strong> is a decentralized social media platform designed to empower users with privacy, data ownership, and a safe community experience. Built as a B.Tech mini-project in 2025 by a team of four (D. Balasubrahmanyam, Raja Bhaiya Rajbhar, G. Venkat Vamsi, B. Varun) under the guidance of Dr. Y. Krishna Bhargavi at Gokaraju Rangaraju Institute of Engineering and Technology, this project addresses the pitfalls of centralized platforms—data exploitation and censorship—while tackling the moderation challenges of decentralized systems.
  </p>

  <h2 style="color: #2980b9; margin-top: 20px;">Overview</h2>
  <p style="font-size: 16px; line-height: 1.6; color: #34495e;">
    BlockoGram leverages blockchain technology, decentralized storage, and AI to create a scalable social media ecosystem. Users can securely register, post publicly or privately, message others, and explore content, all while retaining full control over their data. The platform ensures safety by using AI to moderate harmful content in real-time, without relying on centralized authorities.
  </p>

  <h2 style="color: #2980b9; margin-top: 20px;">Key Features</h2>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li><strong>Secure Authentication:</strong> Users register and log in via Ethereum smart contracts, ensuring tamper-proof identity management.</li>
    <li><strong>Decentralized Storage:</strong> Posts and messages are encrypted with AES-256 and stored on IPFS, with only their hashes logged on the blockchain.</li>
    <li><strong>End-to-End Encrypted Messaging:</strong> Private messages are encrypted client-side, ensuring only the intended recipient can decrypt them.</li>
    <li><strong>AI-Driven Moderation:</strong> Gemini 1.5 Flash scans captions for harmful content (e.g., hate speech, misinformation) before posting, running on-device for privacy.</li>
    <li><strong>User-Centric Design:</strong> Built with Flutter, the app offers a seamless UI with features like Explore page, public/private posts, and secure chats.</li>
  </ul>

  <h2 style="color: #2980b9; margin-top: 20px;">Tech Stack</h2>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li><strong>Frontend:</strong> Flutter for a cross-platform mobile app with a responsive UI (login, messaging, posting, and explore screens).</li>
    <li><strong>Blockchain:</strong> Ethereum smart contracts (<code>SocialMedia.sol</code>) deployed on Ganache for local testing, with plans to scale to Polygon or mainnet.</li>
    <li><strong>Storage:</strong> IPFS for decentralized storage of encrypted user content, ensuring scalability and tamper resistance.</li>
    <li><strong>Backend:</strong> Python HTTP server for key management (<code>assigned_keys.json</code>) and API coordination.</li>
    <li><strong>AI Moderation:</strong> Gemini 1.5 Flash for real-time content moderation, integrated via a Python backend.</li>
    <li><strong>Encryption:</strong> AES-256 for end-to-end encryption, with session keys derived via Diffie-Hellman key exchange.</li>
    <li><strong>Blockchain Interaction:</strong> <code>web3dart</code> library in Flutter to interact with smart contracts for authentication and data retrieval.</li>
  </ul>

  <h2 style="color: #2980b9; margin-top: 20px;">How It Works</h2>
  <h3 style="color: #2c3e50;">User Authentication:</h3>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li>Users register via the <code>SocialMedia.sol</code> smart contract, storing their username and hashed password (SHA-256) on the Ethereum ledger.</li>
    <li>Private keys are assigned and synced via a Python HTTP server (<code>assigned_keys.json</code>).</li>
  </ul>
  <h3 style="color: #2c3e50;">Posting and Messaging:</h3>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li>Users create posts or messages, which are scanned by Gemini 1.5 Flash for harmful content.</li>
    <li>Safe content is encrypted with AES-256 client-side, uploaded to IPFS, and the resulting hash is stored on the blockchain.</li>
    <li>Messages are end-to-end encrypted, ensuring only the recipient can decrypt them.</li>
  </ul>
  <h3 style="color: #2c3e50;">Content Retrieval:</h3>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li>The app queries the smart contract for IPFS hashes, fetches encrypted content from IPFS, and decrypts it locally for display.</li>
  </ul>
  <h3 style="color: #2c3e50;">Scalability:</h3>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li>To handle millions of hashes per user, IPFS root hashes are stored on-chain, with the full hash list on IPFS, reducing gas costs.</li>
  </ul>

  <h2 style="color: #2980b9; margin-top: 20px;">Security and Privacy</h2>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li><strong>End-to-End Encryption:</strong> AES-256 ensures message content remains private, even on a public blockchain.</li>
    <li><strong>Decentralized Architecture:</strong> IPFS and Ethereum eliminate central points of failure, ensuring censorship resistance.</li>
    <li><strong>Immutable Ledger:</strong> Blockchain guarantees tamper-proof user data and metadata.</li>
    <li><strong>Privacy-First:</strong> No central database—user data stays under their control, with only hashes on the public ledger.</li>
  </ul>

  <h2 style="color: #2980b9; margin-top: 20px;">Future Scope</h2>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li>Scale to public blockchains (Polygon/mainnet) for real-world deployment.</li>
    <li>Add video moderation and group chats with forward secrecy.</li>
    <li>Implement zero-knowledge proofs to hide metadata (e.g., sender-receiver connections) on the public ledger.</li>
  </ul>

  <h2 style="color: #2980b9; margin-top: 20px;">Challenges Overcome</h2>
  <ul style="font-size: 16px; line-height: 1.6; color: #34495e; padding-left: 20px;">
    <li>Balanced decentralization with content moderation by integrating AI, addressing the misinformation issue common in blockchain platforms like Steemit.</li>
    <li>Optimized gas costs by offloading hash storage to IPFS, ensuring scalability for millions of posts per user.</li>
    <li>Maintained user privacy with end-to-end encryption, even with a public blockchain ledger.</li>
  </ul>
</div>
