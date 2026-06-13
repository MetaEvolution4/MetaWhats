class User {
  final String id;
  final String phone;
  final String? name;
  final String? avatarUrl;
  final String? publicKey;
  final DateTime createdAt;

  User({
    required this.id,
    required this.phone,
    this.name,
    this.avatarUrl,
    this.publicKey,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      publicKey: json['publicKey'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'avatarUrl': avatarUrl,
      'publicKey': publicKey,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
