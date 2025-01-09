class ServiceInfo {
  final String? name;
  final String? type;
  final String id;
  String? address;
  final Map<String, dynamic>? attributes;

  /// Tracks when this service was last seen on the network
  DateTime lastSeen;

  ServiceInfo({
    required this.name,
    required this.type,
    String? id,
    this.address,
    this.attributes,
    DateTime? lastSeen,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'id': id,
        'address': address,
        'attributes': attributes,
      };

  factory ServiceInfo.fromJson(Map<String, dynamic> json) {
    final service = ServiceInfo(
      name: json['name'] as String?,
      type: json['type'] as String?,
      id: json['id'] as String?,
      address: json['address'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
    // Set lastSeen to "now" whenever we parse a discovered service
    service.lastSeen = DateTime.now();
    return service;
  }
}
