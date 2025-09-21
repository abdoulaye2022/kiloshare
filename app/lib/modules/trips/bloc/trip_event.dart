part of 'trip_bloc.dart';

@immutable
abstract class TripEvent extends Equatable {
  const TripEvent();

  @override
  List<Object?> get props => [];
}

class LoadTrips extends TripEvent {
  const LoadTrips();
}

class LoadTripById extends TripEvent {
  final String tripId;
  
  const LoadTripById(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class RefreshTrips extends TripEvent {
  const RefreshTrips();
}

class CreateTrip extends TripEvent {
  final Map<String, dynamic> tripData;
  
  const CreateTrip(this.tripData);
  
  @override
  List<Object?> get props => [tripData];
}

class UpdateTrip extends TripEvent {
  final String tripId;
  final Map<String, dynamic> updates;
  
  const UpdateTrip(this.tripId, this.updates);
  
  @override
  List<Object?> get props => [tripId, updates];
}

class DeleteTrip extends TripEvent {
  final String tripId;
  
  const DeleteTrip(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class DuplicateTrip extends TripEvent {
  final String tripId;
  
  const DuplicateTrip(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class PublishTrip extends TripEvent {
  final String tripId;
  
  const PublishTrip(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class PauseTrip extends TripEvent {
  final String tripId;
  final String? reason;
  
  const PauseTrip(this.tripId, {this.reason});
  
  @override
  List<Object?> get props => [tripId, reason];
}

class ResumeTrip extends TripEvent {
  final String tripId;
  
  const ResumeTrip(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class CancelTrip extends TripEvent {
  final String tripId;
  final String? reason;
  final String? details;
  
  const CancelTrip(this.tripId, {this.reason, this.details});
  
  @override
  List<Object?> get props => [tripId, reason, details];
}

class CompleteTrip extends TripEvent {
  final String tripId;
  
  const CompleteTrip(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class AddToFavorites extends TripEvent {
  final String tripId;
  
  const AddToFavorites(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class RemoveFromFavorites extends TripEvent {
  final String tripId;
  
  const RemoveFromFavorites(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class ShareTrip extends TripEvent {
  final String tripId;
  
  const ShareTrip(this.tripId);
  
  @override
  List<Object?> get props => [tripId];
}

class ReportTrip extends TripEvent {
  final String tripId;
  final String reportType;
  final String? description;
  
  const ReportTrip(this.tripId, this.reportType, {this.description});
  
  @override
  List<Object?> get props => [tripId, reportType, description];
}

class LoadDrafts extends TripEvent {
  const LoadDrafts();
}

class LoadFavorites extends TripEvent {
  const LoadFavorites();
}

class SearchTrips extends TripEvent {
  final Map<String, dynamic> filters;
  
  const SearchTrips(this.filters);
  
  @override
  List<Object?> get props => [filters];
}

class LoadPublicTrips extends TripEvent {
  final int limit;
  
  const LoadPublicTrips({this.limit = 10});
  
  @override
  List<Object?> get props => [limit];
}

// Filter events for user's trips
class FilterUserTrips extends TripEvent {
  final Map<String, dynamic> filters;
  
  const FilterUserTrips(this.filters);
  
  @override
  List<Object?> get props => [filters];
}

class FilterDrafts extends TripEvent {
  final Map<String, dynamic> filters;
  
  const FilterDrafts(this.filters);
  
  @override
  List<Object?> get props => [filters];
}

class FilterFavorites extends TripEvent {
  final Map<String, dynamic> filters;
  
  const FilterFavorites(this.filters);
  
  @override
  List<Object?> get props => [filters];
}