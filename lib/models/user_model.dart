class User {
  final int id;
  final String username;
  final String fullname;
  final String email;
  final String? password;
  final String role;
  final int? countryId;
  final String? countryName;
  final String? phone;
  final String? address;
  final String is_active;
  final String token;
  final String? createdAt;
  final String? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.fullname,
    required this.email,
    this.password,
    required this.role,
    this.countryId,
    this.countryName,
    this.phone,
    this.address,
    required this.is_active,
    required this.token,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // Ensure 'id' is parsed as int. Handles both int and String inputs.
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      username: json['username']?.toString() ?? '',
      fullname: json['name']?.toString() ?? json['fullname']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString(),
      role: json['role']?.toString() ?? '',
      // Ensure 'country_id' is parsed as int?. Handles both int and String inputs.
      countryId: json['country_id'] is int
          ? json['country_id']
          : int.tryParse(json['country_id']?.toString() ?? ''),
      countryName: json['country_name']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      is_active:
          json['is_active'] != null ? json['is_active'].toString() : 'false',
      token: json['token']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ??
          json['created_datetime']?.toString(),
      updatedAt: json['updated_at']?.toString() ??
          json['updated_datetime']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullname': fullname,
      'email': email,
      'password': password,
      'role': role,
      'country_id': countryId,
      'country_name': countryName,
      'phone': phone,
      'address': address,
      'is_active': is_active,
      'token': token,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
