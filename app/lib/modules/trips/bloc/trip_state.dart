part of 'trip_bloc.dart';

@immutable
abstract class TripState extends Equatable {
  const TripState();

  @override
  List<Object?> get props => [];
}

class TripInitial extends TripState {
  const TripInitial();
}

class TripLoading extends TripState {
  const TripLoading();
}

class TripsLoaded extends TripState {
  final List<Trip> trips;
  final bool hasReachedMax;
  
  const TripsLoaded({
    this.trips = const <Trip>[],
    this.hasReachedMax = false,
  });
  
  TripsLoaded copyWith({
    List<Trip>? trips,
    bool? hasReachedMax,
  }) {
    return TripsLoaded(
      trips: trips ?? this.trips,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }
  
  @override
  List<Object?> get props => [trips, hasReachedMax];
}

class TripDetailsLoaded extends TripState {
  final Trip trip;
  final bool isOwner;
  final bool isFavorite;
  
  const TripDetailsLoaded({
    required this.trip,
    this.isOwner = false,
    this.isFavorite = false,
  });
  
  TripDetailsLoaded copyWith({
    Trip? trip,
    bool? isOwner,
    bool? isFavorite,
  }) {
    return TripDetailsLoaded(
      trip: trip ?? this.trip,
      isOwner: isOwner ?? this.isOwner,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
  
  @override
  List<Object?> get props => [trip, isOwner, isFavorite];
}

class TripActionSuccess extends TripState {
  final String message;
  final Trip? updatedTrip;
  final TripAction action;
  
  const TripActionSuccess({
    required this.message,
    required this.action,
    this.updatedTrip,
  });
  
  @override
  List<Object?> get props => [message, updatedTrip, action];
}

class TripCreated extends TripState {
  final Trip trip;
  
  const TripCreated(this.trip);
  
  @override
  List<Object?> get props => [trip];
}

class TripUpdated extends TripState {
  final Trip trip;
  
  const TripUpdated(this.trip);
  
  @override
  List<Object?> get props => [trip];
}

class TripDeleted extends TripState {
  final String tripId;
  
  const TripDeleted(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class TripDuplicated extends TripState {
  final Trip newTrip;
  final Trip originalTrip;
  
  const TripDuplicated({
    required this.newTrip,
    required this.originalTrip,
  });
  
  @override
  List<Object?> get props => [newTrip, originalTrip];
}

class TripError extends TripState {
  final String message;
  final dynamic error;
  
  const TripError(this.message, {this.error});
  
  @override
  List<Object?> get props => [message, error];
}

class DraftsLoaded extends TripState {
  final List<Trip> drafts;

  const DraftsLoaded(this.drafts);

  DraftsLoaded copyWith({
    List<Trip>? drafts,
  }) {
    return DraftsLoaded(drafts ?? this.drafts);
  }

  @override
  List<Object?> get props => [drafts];
}

class FavoritesLoaded extends TripState {
  final List<Trip> favorites;

  const FavoritesLoaded(this.favorites);

  FavoritesLoaded copyWith({
    List<Trip>? favorites,
  }) {
    return FavoritesLoaded(favorites ?? this.favorites);
  }

  @override
  List<Object?> get props => [favorites];
}

class SearchResultsLoaded extends TripState {
  final List<Trip> results;
  final Map<String, dynamic> filters;
  final bool hasReachedMax;
  
  const SearchResultsLoaded({
    required this.results,
    required this.filters,
    this.hasReachedMax = false,
  });
  
  SearchResultsLoaded copyWith({
    List<Trip>? results,
    Map<String, dynamic>? filters,
    bool? hasReachedMax,
  }) {
    return SearchResultsLoaded(
      results: results ?? this.results,
      filters: filters ?? this.filters,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }
  
  @override
  List<Object?> get props => [results, filters, hasReachedMax];
}

class PublicTripsLoaded extends TripState {
  final List<Trip> trips;
  final bool hasReachedMax;

  const PublicTripsLoaded({
    required this.trips,
    this.hasReachedMax = false,
  });

  PublicTripsLoaded copyWith({
    List<Trip>? trips,
    bool? hasReachedMax,
  }) {
    return PublicTripsLoaded(
      trips: trips ?? this.trips,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [trips, hasReachedMax];
}

enum TripAction {
  create,
  update,
  delete,
  duplicate,
  publish,
  pause,
  resume,
  cancel,
  complete,
  addToFavorites,
  removeFromFavorites,
  share,
  report,
}