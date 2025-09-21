import 'package:kiloshare/modules/trips/models/trip_model.dart';

class SearchResult {
  final List<Trip> trips;
  final SearchPagination pagination;

  const SearchResult({
    required this.trips,
    required this.pagination,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        trips: (json['trips'] as List<dynamic>? ?? [])
            .map((trip) => Trip.fromJson(trip as Map<String, dynamic>))
            .toList(),
        pagination: SearchPagination.fromJson(
            json['pagination'] as Map<String, dynamic>? ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'trips': trips.map((trip) => trip.toJson()).toList(),
        'pagination': pagination.toJson(),
      };

  bool get isEmpty => trips.isEmpty;
  bool get isNotEmpty => trips.isNotEmpty;
  int get totalTrips => trips.length;

  @override
  String toString() {
    return 'SearchResult(trips: ${trips.length}, page: ${pagination.currentPage})';
  }
}

class SearchPagination {
  final int currentPage;
  final int perPage;
  final int total;
  final int totalPages;

  const SearchPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  factory SearchPagination.fromJson(Map<String, dynamic> json) =>
      SearchPagination(
        currentPage: json['current_page'] as int? ?? 1,
        perPage: json['per_page'] as int? ?? 20,
        total: json['total'] as int? ?? 0,
        totalPages: json['total_pages'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'current_page': currentPage,
        'per_page': perPage,
        'total': total,
        'total_pages': totalPages,
      };

  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
  int get nextPage => hasNextPage ? currentPage + 1 : currentPage;
  int get previousPage => hasPreviousPage ? currentPage - 1 : currentPage;

  @override
  String toString() {
    return 'SearchPagination(currentPage: $currentPage, total: $total, totalPages: $totalPages)';
  }
}
