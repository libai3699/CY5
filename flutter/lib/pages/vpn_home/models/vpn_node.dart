class VpnNode {
  const VpnNode({
    required this.id,
    required this.name,
    required this.region,
    required this.protocol,
    required this.address,
    required this.rawUri,
    this.latency,
  });

  final String id;
  final String name;
  final String region;
  final String protocol;
  final String address;
  final String rawUri;
  final int? latency; // 延迟（毫秒），null 表示未测速

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region,
      'protocol': protocol,
      'address': address,
      'rawUri': rawUri,
      'latency': latency,
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
      latency: json['latency'] as int?,
    );
  }

  VpnNode copyWith({
    String? id,
    String? name,
    String? region,
    String? protocol,
    String? address,
    String? rawUri,
    int? latency,
  }) {
    return VpnNode(
      id: id ?? this.id,
      name: name ?? this.name,
      region: region ?? this.region,
      protocol: protocol ?? this.protocol,
      address: address ?? this.address,
      rawUri: rawUri ?? this.rawUri,
      latency: latency ?? this.latency,
    );
  }
}
