import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/reservation_repository.dart';

class ReservationState {
  final List<Map<String, dynamic>> reservations;
  final bool isLoading;
  final String? error;

  const ReservationState({this.reservations = const [], this.isLoading = false, this.error});

  ReservationState copyWith({List<Map<String, dynamic>>? reservations, bool? isLoading, String? error}) {
    return ReservationState(
      reservations: reservations ?? this.reservations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ReservationNotifier extends StateNotifier<ReservationState> {
  final ReservationRepository _repo;

  ReservationNotifier(this._repo) : super(const ReservationState());

  Future<void> load({String? date, String? status, int? tableId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.getReservations(date: date, status: status, tableId: tableId);
      state = state.copyWith(reservations: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      await _repo.createReservation(data);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateStatus(int id, String status) async {
    try {
      await _repo.updateStatus(id, status);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repo.deleteReservation(id);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final reservationProvider = StateNotifierProvider<ReservationNotifier, ReservationState>((ref) {
  return ReservationNotifier(ref.watch(reservationRepositoryProvider));
});
