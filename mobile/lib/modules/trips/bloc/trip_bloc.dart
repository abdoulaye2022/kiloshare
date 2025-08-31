import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';
import '../../../services/auth_token_service.dart';

part 'trip_event.dart';
part 'trip_state.dart';

class TripBloc extends Bloc<TripEvent, TripState> {
  late final TripService _tripService;

  TripBloc() : super(const TripInitial()) {
    print('=== DEBUG: TripBloc constructor called ===');
    _tripService = AuthTokenService.instance.tripService;
    print('DEBUG: TripService instance from AuthTokenService: $_tripService');
    
    on<LoadTrips>((event, emit) async {
      print('=== DEBUG: LoadTrips event received ===');
      await _onLoadTrips(event, emit);
    });
    on<LoadTripById>(_onLoadTripById);
    on<RefreshTrips>(_onRefreshTrips);
    on<CreateTrip>(_onCreateTrip);
    on<UpdateTrip>(_onUpdateTrip);
    on<DeleteTrip>(_onDeleteTrip);
    on<DuplicateTrip>(_onDuplicateTrip);
    on<PublishTrip>(_onPublishTrip);
    on<PauseTrip>(_onPauseTrip);
    on<ResumeTrip>(_onResumeTrip);
    on<CancelTrip>(_onCancelTrip);
    on<CompleteTrip>(_onCompleteTrip);
    on<AddToFavorites>(_onAddToFavorites);
    on<RemoveFromFavorites>(_onRemoveFromFavorites);
    on<ShareTrip>(_onShareTrip);
    on<ReportTrip>(_onReportTrip);
    on<LoadDrafts>(_onLoadDrafts);
    on<LoadFavorites>(_onLoadFavorites);
    on<SearchTrips>(_onSearchTrips);
    on<LoadPublicTrips>(_onLoadPublicTrips);
    on<FilterUserTrips>(_onFilterUserTrips);
    on<FilterDrafts>(_onFilterDrafts);
    on<FilterFavorites>(_onFilterFavorites);
  }

  Future<void> _onLoadTrips(LoadTrips event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final trips = await _tripService.getUserTrips();
      emit(TripsLoaded(trips: trips));
    } catch (error) {
      emit(TripError('Failed to load trips: ${error.toString()}', error: error));
    }
  }

  Future<void> _onLoadTripById(LoadTripById event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final trip = await _tripService.getTripById(event.tripId);
      // TODO: Check if current user owns this trip
      final isOwner = true; // Placeholder
      final isFavorite = false; // TODO: Check if trip is favorited
      
      emit(TripDetailsLoaded(
        trip: trip,
        isOwner: isOwner,
        isFavorite: isFavorite,
      ));
    } catch (error) {
      emit(TripError('Failed to load trip details: ${error.toString()}', error: error));
    }
  }

  Future<void> _onRefreshTrips(RefreshTrips event, Emitter<TripState> emit) async {
    try {
      final trips = await _tripService.getUserTrips();
      emit(TripsLoaded(trips: trips));
    } catch (error) {
      emit(TripError('Failed to refresh trips: ${error.toString()}', error: error));
    }
  }

  Future<void> _onCreateTrip(CreateTrip event, Emitter<TripState> emit) async {
    try {
      final data = event.tripData;
      final newTrip = await _tripService.createTrip(
        transportType: data['transportType'] ?? '',
        departureCity: data['departureCity'] ?? '',
        departureCountry: data['departureCountry'] ?? '',
        departureAirportCode: data['departureAirportCode'],
        departureDate: DateTime.parse(data['departureDate'] ?? DateTime.now().toIso8601String()),
        arrivalCity: data['arrivalCity'] ?? '',
        arrivalCountry: data['arrivalCountry'] ?? '',
        arrivalAirportCode: data['arrivalAirportCode'],
        arrivalDate: DateTime.parse(data['arrivalDate'] ?? DateTime.now().toIso8601String()),
        availableWeightKg: (data['availableWeightKg'] ?? 0.0).toDouble(),
        pricePerKg: (data['pricePerKg'] ?? 0.0).toDouble(),
        currency: data['currency'] ?? 'CAD',
        description: data['description'],
        flightNumber: data['flightNumber'],
        airline: data['airline'],
        specialNotes: data['specialNotes'],
        restrictedCategories: data['restrictedCategories'] != null 
          ? List<String>.from(data['restrictedCategories'])
          : null,
        restrictedItems: data['restrictedItems'] != null 
          ? List<String>.from(data['restrictedItems'])
          : null,
        restrictionNotes: data['restrictionNotes'],
      );
      emit(TripCreated(newTrip));
      
      // Automatically reload trips list
      add(const LoadTrips());
    } catch (error) {
      emit(TripError('Failed to create trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onUpdateTrip(UpdateTrip event, Emitter<TripState> emit) async {
    try {
      final updatedTrip = await _tripService.updateTrip(event.tripId, event.updates);
      emit(TripUpdated(updatedTrip));
      
      // If we're currently viewing this trip's details, update the state
      if (state is TripDetailsLoaded) {
        final currentState = state as TripDetailsLoaded;
        if (currentState.trip.id == updatedTrip.id) {
          emit(currentState.copyWith(trip: updatedTrip));
        }
      }
      
      // Refresh trips list
      add(const RefreshTrips());
    } catch (error) {
      emit(TripError('Failed to update trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onDeleteTrip(DeleteTrip event, Emitter<TripState> emit) async {
    try {
      await _tripService.deleteTrip(event.tripId);
      emit(const TripActionSuccess(
        message: 'Voyage supprimé avec succès',
        action: TripAction.delete,
      ));
      emit(TripDeleted(event.tripId));
      
      // Refresh trips list
      add(const RefreshTrips());
    } catch (error) {
      emit(TripError('Failed to delete trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onDuplicateTrip(DuplicateTrip event, Emitter<TripState> emit) async {
    try {
      final newTrip = await _tripService.duplicateTrip(event.tripId);
      
      // Get the original trip for context
      Trip? originalTrip;
      try {
        originalTrip = await _tripService.getTripById(event.tripId);
      } catch (_) {
        // Original trip might not be accessible anymore
      }
      
      emit(const TripActionSuccess(
        message: 'Voyage dupliqué avec succès',
        action: TripAction.duplicate,
      ));
      emit(TripDuplicated(
        newTrip: newTrip,
        originalTrip: originalTrip ?? newTrip, // Fallback to new trip
      ));
      
      // Refresh trips list
      add(const RefreshTrips());
    } catch (error) {
      emit(TripError('Failed to duplicate trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onPublishTrip(PublishTrip event, Emitter<TripState> emit) async {
    try {
      final updatedTrip = await _tripService.publishTrip(event.tripId);
      emit(TripActionSuccess(
        message: 'Trip published successfully',
        action: TripAction.publish,
        updatedTrip: updatedTrip,
      ));
      
      _updateCurrentTripState(emit, updatedTrip);
      add(const RefreshTrips());
    } catch (error) {
      emit(TripError('Failed to publish trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onPauseTrip(PauseTrip event, Emitter<TripState> emit) async {
    try {
      final updatedTrip = await _tripService.pauseTrip(event.tripId, reason: event.reason);
      emit(TripActionSuccess(
        message: 'Trip paused successfully',
        action: TripAction.pause,
        updatedTrip: updatedTrip,
      ));
      
      _updateCurrentTripState(emit, updatedTrip);
      add(const RefreshTrips());
    } catch (error) {
      emit(TripError('Failed to pause trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onResumeTrip(ResumeTrip event, Emitter<TripState> emit) async {
    try {
      final updatedTrip = await _tripService.resumeTrip(event.tripId);
      emit(TripActionSuccess(
        message: 'Trip resumed successfully',
        action: TripAction.resume,
        updatedTrip: updatedTrip,
      ));
      
      _updateCurrentTripState(emit, updatedTrip);
      add(const RefreshTrips());
    } catch (error) {
      emit(TripError('Failed to resume trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onCancelTrip(CancelTrip event, Emitter<TripState> emit) async {
    try {
      final updatedTrip = await _tripService.cancelTrip(
        event.tripId, 
        reason: event.reason,
        details: event.details,
      );
      emit(TripActionSuccess(
        message: 'Trip cancelled successfully',
        action: TripAction.cancel,
        updatedTrip: updatedTrip,
      ));
      
      _updateCurrentTripState(emit, updatedTrip);
      add(const RefreshTrips());
    } catch (error) {
      emit(TripError('Failed to cancel trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onCompleteTrip(CompleteTrip event, Emitter<TripState> emit) async {
    try {
      final updatedTrip = await _tripService.completeTrip(event.tripId);
      emit(TripActionSuccess(
        message: 'Trip completed successfully',
        action: TripAction.complete,
        updatedTrip: updatedTrip,
      ));
      
      _updateCurrentTripState(emit, updatedTrip);
      add(const RefreshTrips());
    } catch (error) {
      emit(TripError('Failed to complete trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onAddToFavorites(AddToFavorites event, Emitter<TripState> emit) async {
    try {
      await _tripService.addToFavorites(event.tripId);
      emit(const TripActionSuccess(
        message: 'Trip added to favorites',
        action: TripAction.addToFavorites,
      ));
      
      // Update current trip details if viewing this trip
      if (state is TripDetailsLoaded) {
        final currentState = state as TripDetailsLoaded;
        if (currentState.trip.id == event.tripId) {
          emit(currentState.copyWith(isFavorite: true));
        }
      }
    } catch (error) {
      emit(TripError('Failed to add trip to favorites: ${error.toString()}', error: error));
    }
  }

  Future<void> _onRemoveFromFavorites(RemoveFromFavorites event, Emitter<TripState> emit) async {
    try {
      await _tripService.removeFromFavorites(event.tripId);
      emit(const TripActionSuccess(
        message: 'Trip removed from favorites',
        action: TripAction.removeFromFavorites,
      ));
      
      // Update current trip details if viewing this trip
      if (state is TripDetailsLoaded) {
        final currentState = state as TripDetailsLoaded;
        if (currentState.trip.id == event.tripId) {
          emit(currentState.copyWith(isFavorite: false));
        }
      }
    } catch (error) {
      emit(TripError('Failed to remove trip from favorites: ${error.toString()}', error: error));
    }
  }

  Future<void> _onShareTrip(ShareTrip event, Emitter<TripState> emit) async {
    try {
      await _tripService.shareTrip(event.tripId);
      emit(const TripActionSuccess(
        message: 'Trip shared successfully',
        action: TripAction.share,
      ));
    } catch (error) {
      emit(TripError('Failed to share trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onReportTrip(ReportTrip event, Emitter<TripState> emit) async {
    try {
      await _tripService.reportTrip(event.tripId, reportType: event.reportType, description: event.description);
      emit(const TripActionSuccess(
        message: 'Trip reported successfully',
        action: TripAction.report,
      ));
    } catch (error) {
      emit(TripError('Failed to report trip: ${error.toString()}', error: error));
    }
  }

  Future<void> _onLoadDrafts(LoadDrafts event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final drafts = await _tripService.getDrafts();
      emit(DraftsLoaded(drafts));
    } catch (error) {
      emit(TripError('Failed to load drafts: ${error.toString()}', error: error));
    }
  }

  Future<void> _onLoadFavorites(LoadFavorites event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final favorites = await _tripService.getFavorites();
      emit(FavoritesLoaded(favorites));
    } catch (error) {
      emit(TripError('Failed to load favorites: ${error.toString()}', error: error));
    }
  }

  Future<void> _onSearchTrips(SearchTrips event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final results = await _tripService.searchTrips(
        departureCity: event.filters['departureCity'],
        arrivalCity: event.filters['arrivalCity'],
        departureCountry: event.filters['departureCountry'],
        arrivalCountry: event.filters['arrivalCountry'],
        departureDateFrom: event.filters['departureDateFrom'],
        departureDateTo: event.filters['departureDateTo'],
        minWeight: event.filters['minWeight'],
        maxPricePerKg: event.filters['maxPricePerKg'],
        currency: event.filters['currency'],
        verifiedOnly: event.filters['verifiedOnly'],
      );
      emit(SearchResultsLoaded(
        results: results,
        filters: event.filters,
      ));
    } catch (error) {
      emit(TripError('Failed to search trips: ${error.toString()}', error: error));
    }
  }

  Future<void> _onLoadPublicTrips(LoadPublicTrips event, Emitter<TripState> emit) async {
    print('=== DEBUG: _onLoadPublicTrips START ===');
    print('DEBUG: Loading public trips with limit: ${event.limit}');
    emit(const TripLoading());
    try {
      // Create a separate TripService instance for public operations (no auth required)
      print('DEBUG: Creating TripService instance for public operations');
      final publicTripService = TripService();
      print('DEBUG: Calling getPublicTrips...');
      final trips = await publicTripService.getPublicTrips(limit: event.limit);
      print('DEBUG: getPublicTrips completed successfully - ${trips.length} trips loaded');
      emit(PublicTripsLoaded(trips: trips));
      print('DEBUG: PublicTripsLoaded state emitted');
    } catch (error) {
      print('=== DEBUG: Error in _onLoadPublicTrips ===');
      print('DEBUG: Error type: ${error.runtimeType}');
      print('DEBUG: Error message: $error');
      print('DEBUG: Error string: ${error.toString()}');
      emit(TripError('Failed to load public trips: ${error.toString()}', error: error));
    }
    print('=== DEBUG: _onLoadPublicTrips END ===');
  }

  // Filter handlers for user trips
  Future<void> _onFilterUserTrips(FilterUserTrips event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      // For now, load all trips and filter client-side
      // TODO: Implement server-side filtering
      final allTrips = await _tripService.getUserTrips();
      final filteredTrips = _applyClientSideFilters(allTrips, event.filters);
      emit(TripsLoaded(trips: filteredTrips));
    } catch (error) {
      emit(TripError('Failed to filter user trips: ${error.toString()}', error: error));
    }
  }

  Future<void> _onFilterDrafts(FilterDrafts event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final allDrafts = await _tripService.getDrafts();
      final filteredDrafts = _applyClientSideFilters(allDrafts, event.filters);
      emit(DraftsLoaded(filteredDrafts));
    } catch (error) {
      emit(TripError('Failed to filter drafts: ${error.toString()}', error: error));
    }
  }

  Future<void> _onFilterFavorites(FilterFavorites event, Emitter<TripState> emit) async {
    emit(const TripLoading());
    try {
      final allFavorites = await _tripService.getFavorites();
      final filteredFavorites = _applyClientSideFilters(allFavorites, event.filters);
      emit(FavoritesLoaded(filteredFavorites));
    } catch (error) {
      emit(TripError('Failed to filter favorites: ${error.toString()}', error: error));
    }
  }

  List<Trip> _applyClientSideFilters(List<Trip> trips, Map<String, dynamic> filters) {
    return trips.where((trip) {
      // Status filter
      if (filters['status'] != null && filters['status'] != 'all') {
        final statusFilter = filters['status'] as String;
        switch (statusFilter) {
          case 'active':
            if (trip.status != TripStatus.active) return false;
            break;
          case 'paused':
            if (trip.status != TripStatus.paused) return false;
            break;
          case 'pending':
            if (trip.status != TripStatus.pendingApproval && 
                trip.status != TripStatus.pendingReview) return false;
            break;
          case 'completed':
            if (trip.status != TripStatus.completed) return false;
            break;
          case 'cancelled':
            if (trip.status != TripStatus.cancelled) return false;
            break;
        }
      }

      // Transport type filter
      if (filters['transport_type'] != null && filters['transport_type'] != 'all') {
        final transportFilter = filters['transport_type'] as String;
        // Determine transport type based on flight info
        final isFlightTransport = trip.flightNumber != null && trip.flightNumber!.isNotEmpty;
        
        switch (transportFilter) {
          case 'flight':
            if (!isFlightTransport) return false;
            break;
          case 'car':
          case 'train':
          case 'bus':
            if (isFlightTransport) return false;
            // For now, we can't distinguish between car/train/bus without additional data
            break;
        }
      }

      // Date range filter
      if (filters['departure_date_from'] != null) {
        final fromDate = DateTime.parse(filters['departure_date_from'] as String);
        if (trip.departureDate.isBefore(fromDate)) return false;
      }
      
      if (filters['departure_date_to'] != null) {
        final toDate = DateTime.parse(filters['departure_date_to'] as String);
        if (trip.departureDate.isAfter(toDate.add(const Duration(days: 1)))) return false;
      }

      // Price range filter
      if (filters['min_price_per_kg'] != null) {
        final minPrice = filters['min_price_per_kg'] as double;
        if (trip.pricePerKg < minPrice) return false;
      }
      
      if (filters['max_price_per_kg'] != null) {
        final maxPrice = filters['max_price_per_kg'] as double;
        if (trip.pricePerKg > maxPrice) return false;
      }

      return true;
    }).toList();
  }

  void _updateCurrentTripState(Emitter<TripState> emit, Trip updatedTrip) {
    if (state is TripDetailsLoaded) {
      final currentState = state as TripDetailsLoaded;
      if (currentState.trip.id == updatedTrip.id) {
        emit(currentState.copyWith(trip: updatedTrip));
      }
    }
  }
}