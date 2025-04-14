module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Ganache default host
      port: 7545,            // Ganache default port
      network_id: "*",       // Match any network ID
    },
  },
  compilers: {
    solc: {
      version: "0.8.0",    // Matches SocialMedia.sol
    },
  },
};