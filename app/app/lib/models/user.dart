/// Neo-Stream user model.
class User {
  final int id;
  final String username;
  final String email;
  final bool isPremium;
  final bool premiumActive;
  final String? premiumUntil;
  final String? premiumType;
  final String? subscriptionStatus;
  final bool isBanned;
  final String? banReason;
  final String? referralCode;
  final String? createdAt;
  final String? lastLogin;
  final int? parentUserId;
  final bool isSubAccount;
  final int maxSubAccounts;
  final String? affiliateCode;
  final bool isAffiliatePartner;
  final bool isAdmin;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.isPremium = false,
    this.premiumActive = false,
    this.premiumUntil,
    this.premiumType,
    this.subscriptionStatus,
    this.isBanned = false,
    this.banReason,
    this.referralCode,
    this.createdAt,
    this.lastLogin,
    this.parentUserId,
    this.isSubAccount = false,
    this.maxSubAccounts = 4,
    this.affiliateCode,
    this.isAffiliatePartner = false,
    this.isAdmin = false,
  });

  String get premiumLabel {
    if (!premiumActive) {
      return 'Gratuit';
    }
    switch (premiumType) {
      case 'normal':
        return 'Premium';
      case 'referral_free':
        return 'Premium (Parrainage)';
      case 'giveaway':
        return 'Premium (Giveaway)';
      case 'lifetime':
        return 'Premium Lifetime';
      default:
        return 'Premium';
    }
  }

  String get premiumExpiry {
    if (premiumUntil == null || premiumUntil!.isEmpty) {
      return '';
    }
    if (premiumUntil!.contains('2099')) {
      return 'Illimite';
    }
    return premiumUntil!.split(' ').first;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isPremium: json['is_premium'] == 1 || json['is_premium'] == true,
      premiumActive: json['premium_active'] == true,
      premiumUntil: json['premium_until']?.toString(),
      premiumType: json['premium_type']?.toString(),
      subscriptionStatus: json['subscription_status']?.toString(),
      isBanned: json['is_banned'] == 1 || json['is_banned'] == true,
      banReason: json['ban_reason']?.toString(),
      referralCode: json['referral_code']?.toString(),
      createdAt: json['created_at']?.toString(),
      lastLogin: json['last_login']?.toString(),
      parentUserId: json['parent_user_id'] is int
          ? json['parent_user_id']
          : int.tryParse(json['parent_user_id']?.toString() ?? ''),
      isSubAccount:
          json['is_sub_account'] == 1 || json['is_sub_account'] == true,
      maxSubAccounts: json['max_sub_accounts'] is int
          ? json['max_sub_accounts']
          : int.tryParse(json['max_sub_accounts']?.toString() ?? '') ?? 4,
      affiliateCode: json['affiliate_code']?.toString(),
      isAffiliatePartner:
          json['is_affiliate_partner'] == 1 ||
          json['is_affiliate_partner'] == true,
      isAdmin: json['is_admin'] == 1 || json['is_admin'] == true,
    );
  }
}
