import 'dart:typed_data';

class BannerModel {
  final String id;
  final String imageUrl;
  final BannerScreenType screenName;
  final bool isActive;
  final int priority;
  final DateTime? expiryDate;
  final String? actionUrl;
  final String? title;
  final String? description;
  // Image data and dimensions
  final Uint8List? imageData;
  final double? imageWidth;
  final double? imageHeight;

  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.screenName,
    required this.isActive,
    required this.priority,
    this.expiryDate,
    this.actionUrl,
    this.title,
    this.description,
    this.imageData,
    this.imageWidth,
    this.imageHeight,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    String imageUrl = json['image_url'] ?? '';
    // Prepend base URL if it's a relative path
    if (imageUrl.isNotEmpty && imageUrl.startsWith('/')) {
      imageUrl = 'https://besim.mynt.in/banner$imageUrl'; // Remove the extra slash
    }

    return BannerModel(
      id: json['id'] ?? '',
      imageUrl: imageUrl,
      screenName: BannerScreenType.fromString(json['screen_name'] ?? ''),
      isActive: json['is_active'] ?? false,
      priority: json['priority'] ?? 0,
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'])
          : null,
      actionUrl: json['action_url'],
      title: json['title'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'screen_name': screenName.value,
      'is_active': isActive,
      'priority': priority,
      'expiry_date': expiryDate?.toIso8601String(),
      'action_url': actionUrl,
      'title': title,
      'description': description,
    };
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get shouldDisplay {
    return isActive && !isExpired;
  }

  BannerModel copyWith({
    String? id,
    String? imageUrl,
    BannerScreenType? screenName,
    bool? isActive,
    int? priority,
    DateTime? expiryDate,
    String? actionUrl,
    String? title,
    String? description,
    Uint8List? imageData,
    double? imageWidth,
    double? imageHeight,
  }) {
    return BannerModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      screenName: screenName ?? this.screenName,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      expiryDate: expiryDate ?? this.expiryDate,
      actionUrl: actionUrl ?? this.actionUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      imageData: imageData ?? this.imageData,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BannerModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum BannerScreenType {
  homescreen('homescreen'),
  holdings('holdings'),
  positions('positions'),
  watchlist('watchlist'),
  optionchain('optionchain');

  const BannerScreenType(this.value);
  final String value;

  static BannerScreenType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'homescreen':
      case 'home':
        return BannerScreenType.homescreen;
      case 'holdings':
        return BannerScreenType.holdings;
      case 'positions':
        return BannerScreenType.positions;
      case 'watchlist':
        return BannerScreenType.watchlist;
      case 'optionchain':
      case 'option_chain':
        return BannerScreenType.optionchain;
      default:
        return BannerScreenType.homescreen;
    }
  }
}

class ScreenBanners {
  final List<BannerModel> banners;
  final int count;

  ScreenBanners({
    required this.banners,
    required this.count,
  });

  factory ScreenBanners.fromJson(Map<String, dynamic> json) {
    return ScreenBanners(
      banners: (json['banners'] as List<dynamic>?)
          ?.map((banner) => BannerModel.fromJson(banner))
          .toList() ?? [],
      count: json['count'] ?? 0,
    );
  }
}

class BannerResponse {
  final Map<String, ScreenBanners> screens;
  final bool success;
  final String? message;

  BannerResponse({
    required this.screens,
    required this.success,
    this.message,
  });

  factory BannerResponse.fromJson(Map<String, dynamic> json) {
    Map<String, ScreenBanners> screensMap = {};

    if (json['screens'] != null) {
      final screens = json['screens'] as Map<String, dynamic>;
      screens.forEach((screenName, screenData) {
        screensMap[screenName] = ScreenBanners.fromJson(screenData);
      });
    }

    return BannerResponse(
      screens: screensMap,
      success: json['success'] ?? false,
      message: json['message'],
    );
  }

  // Helper method to get banners for a specific screen
  List<BannerModel> getBannersForScreen(String screenName) {
    return screens[screenName]?.banners ?? [];
  }

  // Helper method to get all banners from all screens
  List<BannerModel> get allBanners {
    List<BannerModel> all = [];
    for (final screenBanners in screens.values) {
      all.addAll(screenBanners.banners);
    }
    return all;
  }
}