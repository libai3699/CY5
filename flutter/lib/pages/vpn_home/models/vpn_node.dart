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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region,
      'protocol': protocol,
      'address': address,
      'rawUri': rawUri,
    };
  }

  factory VpnNode.fromJson(Map<String, dynamic> json) {
    return VpnNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '默认线路',
      region: json['region']?.toString() ?? 'Auto',
      protocol: json['protocol']?.toString() ?? 'VMESS',
      address: json['address']?.toString() ?? '',
      rawUri: (json['rawUri'] ?? json['raw_uri'])?.toString() ?? '',
    );
  }
}
