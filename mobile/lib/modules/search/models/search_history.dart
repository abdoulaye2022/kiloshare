import 'search_params.dart';

class SearchHistory {
  final int? id;
  final int? userId;
  final SearchParams searchParams;
  final DateTime searchedAt;

  const SearchHistory({
    this.id,
    this.userId,
    required this.searchParams,
    required this.searchedAt,
  });

  factory SearchHistory.fromJson(Map<String, dynamic> json) => SearchHistory(
    id: json['id'] as int?,
    userId: json['user_id'] as int?,
    searchParams: SearchParams.fromJson(json['search_params'] as Map<String, dynamic>? ?? {}),
    searchedAt: DateTime.parse(json['searched_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id!,
    if (userId != null) 'user_id': userId!,
    'search_params': searchParams.toJson(),
    'searched_at': searchedAt.toIso8601String(),
  };

  String get searchSummary => searchParams.searchSummary;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(searchedAt);

    if (difference.inDays > 7) {
      return _formatDate(searchedAt);
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
      'juil', 'août', 'sept', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool isSimilarTo(SearchHistory other) {
    final params1 = searchParams;
    final params2 = other.searchParams;

    return params1.departureCity == params2.departureCity &&
        params1.arrivalCity == params2.arrivalCity &&
        params1.departureDate == params2.departureDate &&
        params1.transportType == params2.transportType;
  }

  SearchHistory copyWith({
    int? id,
    int? userId,
    SearchParams? searchParams,
    DateTime? searchedAt,
  }) {
    return SearchHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      searchParams: searchParams ?? this.searchParams,
      searchedAt: searchedAt ?? this.searchedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchHistory &&
        other.id == id &&
        other.userId == userId &&
        other.searchParams == searchParams &&
        other.searchedAt == searchedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, userId, searchParams, searchedAt);
  }

  @override
  String toString() {
    return 'SearchHistory(id: $id, searchSummary: $searchSummary, searchedAt: $searchedAt)';
  }
}