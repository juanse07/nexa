import 'package:flutter/material.dart';

/// Brand customization profile for Pro managers.
class BrandProfile {
  const BrandProfile({
    this.logoOriginalUrl,
    this.logoHeaderUrl,
    this.logoWatermarkUrl,
    this.aspectRatio,
    this.shapeClassification,
    this.primaryColor,
    this.secondaryColor,
    this.accentColor,
    this.neutralColor,
    this.createdAt,
    this.updatedAt,
  });

  factory BrandProfile.fromJson(Map<String, dynamic> json) {
    return BrandProfile(
      logoOriginalUrl: json['logoOriginalUrl'] as String?,
      logoHeaderUrl: json['logoHeaderUrl'] as String?,
      logoWatermarkUrl: json['logoWatermarkUrl'] as String?,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
      shapeClassification: json['shapeClassification'] as String?,
      primaryColor: json['primaryColor'] as String?,
      secondaryColor: json['secondaryColor'] as String?,
      accentColor: json['accentColor'] as String?,
      neutralColor: json['neutralColor'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  final String? logoOriginalUrl;
  final String? logoHeaderUrl;
  final String? logoWatermarkUrl;
  final double? aspectRatio;
  final String? shapeClassification;
  final String? primaryColor;
  final String? secondaryColor;
  final String? accentColor;
  final String? neutralColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      if (logoOriginalUrl != null) 'logoOriginalUrl': logoOriginalUrl,
      if (logoHeaderUrl != null) 'logoHeaderUrl': logoHeaderUrl,
      if (logoWatermarkUrl != null) 'logoWatermarkUrl': logoWatermarkUrl,
      if (aspectRatio != null) 'aspectRatio': aspectRatio,
      if (shapeClassification != null) 'shapeClassification': shapeClassification,
      if (primaryColor != null) 'primaryColor': primaryColor,
      if (secondaryColor != null) 'secondaryColor': secondaryColor,
      if (accentColor != null) 'accentColor': accentColor,
      if (neutralColor != null) 'neutralColor': neutralColor,
    };
  }

  bool get hasLogo => logoHeaderUrl != null && logoHeaderUrl!.isNotEmpty;

  bool get hasColors => primaryColor != null && primaryColor!.isNotEmpty;

  /// Parse a hex color string into a Flutter Color.
  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) return null;
    final value = int.tryParse(h, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  Color? get primaryColorValue => _parseHex(primaryColor);
  Color? get secondaryColorValue => _parseHex(secondaryColor);
  Color? get accentColorValue => _parseHex(accentColor);
  Color? get neutralColorValue => _parseHex(neutralColor);

  BrandProfile copyWith({
    String? logoOriginalUrl,
    String? logoHeaderUrl,
    String? logoWatermarkUrl,
    double? aspectRatio,
    String? shapeClassification,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? neutralColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BrandProfile(
      logoOriginalUrl: logoOriginalUrl ?? this.logoOriginalUrl,
      logoHeaderUrl: logoHeaderUrl ?? this.logoHeaderUrl,
      logoWatermarkUrl: logoWatermarkUrl ?? this.logoWatermarkUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      shapeClassification: shapeClassification ?? this.shapeClassification,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      neutralColor: neutralColor ?? this.neutralColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
