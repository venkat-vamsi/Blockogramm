import { create } from 'ipfs-http-client';
import crypto from 'crypto';

// Generate sample RSA key pair
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
});

// Connect to the running jsipfs daemon
const ipfs = create({
  host: '127.0.0.1',
  port: 5002,
  protocol: 'http',
});

async function main() {
  // Sample message
  const message = "This is a secret message!";
  
  // Encrypt with public key
  const encrypted = crypto.publicEncrypt(publicKey, Buffer.from(message));
  const encryptedString = encrypted.toString('base64');
  
  // Upload to IPFS via daemon
  const { cid } = await ipfs.add(encryptedString);
  console.log("Encrypted message uploaded to IPFS with CID:", cid.toString());

  // Retrieve from IPFS
  const stream = ipfs.cat(cid);
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  const data = Buffer.concat(chunks).toString('utf8'); // Convert binary to string
  const decrypted = crypto.privateDecrypt(privateKey, Buffer.from(data, 'base64'));
  console.log("Decrypted message from IPFS:", decrypted.toString());
}

main().catch(console.error);