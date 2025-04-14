import { create } from 'ipfs-http-client';

// Connect to the running jsipfs daemon
const ipfs = create({
  host: '127.0.0.1',
  port: 5002,
  protocol: 'http',
});

async function main() {
  const postContent = "Hello, this is my first decentralized post!";
  const { cid } = await ipfs.add(postContent);
  console.log("Post uploaded to IPFS with CID:", cid.toString());

  const stream = ipfs.cat(cid);
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  const data = Buffer.concat(chunks).toString('utf8');
  console.log("Retrieved from IPFS:", data);
}

main().catch(console.error);