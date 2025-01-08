// broadcast_service.dart

class ServiceInfo {
  final String? name;
  final String? type;
  final String id;
  final Map<String, dynamic>? attributes;

  ServiceInfo({
    required this.name,
    required this.type,
    String? id,
    this.attributes,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'id': id,
    'attributes': attributes,
  };

  factory ServiceInfo.fromJson(Map<String, dynamic> json) => ServiceInfo(
    name: json['name'] as String?,
    type: json['type'] as String?,
    id: json['id'] as String?,
    attributes: json['attributes'] as Map<String, dynamic>?,
  );
}
