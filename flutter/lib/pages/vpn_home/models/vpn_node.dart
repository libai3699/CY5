class VpnNode {
  const VpnNode({
    required this.id,
    required this.name,
    required this.region,
    required this.protocol,
    required this.address,
    required this.rawUri,
  });

  final String id;
  final String name;
  final String region;
  final String protocol;
  final String address;
  final String rawUri;
}
