class Config {
  static const String ipAddress = "192.168.29.252";
  static const String rpcUrl = "http://$ipAddress:7545";
  static const String ipfsApiUrl = "http://$ipAddress:5001/api/v0";
  static const String ipfsGatewayUrl = "http://$ipAddress:8080";
  static const String keysServerUrl =
      "http://$ipAddress:8000/assigned_keys.json";
}
