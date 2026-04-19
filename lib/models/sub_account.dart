/// Neo-Stream Sub-Account Model
class SubAccount {
  final int id;
  final String username;
  final String email;
  final bool isPremium;
  final bool requirePassword;
  final String? createdAt;
  final String? lastLogin;

  SubAccount({
    required this.id,
    required this.username,
    required this.email,
    this.isPremium = false,
    this.requirePassword = true,
    this.createdAt,
    this.lastLogin,
  });

  factory SubAccount.fromJson(Map<String, dynamic> json) {
    return SubAccount(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isPremium: json['is_premium'] == 1 || json['is_premium'] == true,
      requirePassword:
          json['require_password'] == 1 ||
          json['require_password'] == true ||
          json['require_password'] == '1',
      createdAt: json['created_at']?.toString(),
      lastLogin: json['last_login']?.toString(),
    );
  }
}
