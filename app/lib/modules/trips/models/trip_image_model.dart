class TripImage {
  final String id;
  final String url;
  final String? thumbnail;
  final String? medium;
  final bool isPrimary;
  final int order;
  final int? fileSize;
  final int? width;
  final int? height;
  final String? altText;

  const TripImage({
    required this.id,
    required this.url,
    this.thumbnail,
    this.medium,
    this.isPrimary = false,
    this.order = 0,
    this.fileSize,
    this.width,
    this.height,
    this.altText,
  });

  factory TripImage.fromJson(Map<String, dynamic> json) {
    return TripImage(
      id: json['id']?.toString() ?? '',
      url: json['url'] ?? '',
      thumbnail: json['thumbnail'],
      medium: json['medium'],
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
      order: json['order'] is int ? json['order'] : int.tryParse(json['order']?.toString() ?? '0') ?? 0,
      fileSize: json['file_size'] is int ? json['file_size'] : int.tryParse(json['file_size']?.toString() ?? '0'),
      width: json['width'] is int ? json['width'] : int.tryParse(json['width']?.toString() ?? '0'),
      height: json['height'] is int ? json['height'] : int.tryParse(json['height']?.toString() ?? '0'),
      altText: json['alt_text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'thumbnail': thumbnail,
      'medium': medium,
      'is_primary': isPrimary,
      'order': order,
      'file_size': fileSize,
      'width': width,
      'height': height,
      'alt_text': altText,
    };
  }

  TripImage copyWith({
    String? id,
    String? url,
    String? thumbnail,
    String? medium,
    bool? isPrimary,
    int? order,
    int? fileSize,
    int? width,
    int? height,
    String? altText,
  }) {
    return TripImage(
      id: id ?? this.id,
      url: url ?? this.url,
      thumbnail: thumbnail ?? this.thumbnail,
      medium: medium ?? this.medium,
      isPrimary: isPrimary ?? this.isPrimary,
      order: order ?? this.order,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      altText: altText ?? this.altText,
    );
  }

  @override
  String toString() {
    return 'TripImage(id: $id, url: $url, isPrimary: $isPrimary, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripImage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}