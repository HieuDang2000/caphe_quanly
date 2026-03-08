import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/staff_repository.dart';

class StaffState {
  final List<Map<String, dynamic>> staff;
  final List<Map<String, dynamic>> shifts;
  final List<Map<String, dynamic>> attendances;
  final bool isLoading;
  final String? error;

  const StaffState({
    this.staff = const [],
    this.shifts = const [],
    this.attendances = const [],
    this.isLoading = false,
    this.error,
  });

  StaffState copyWith({
    List<Map<String, dynamic>>? staff,
    List<Map<String, dynamic>>? shifts,
    List<Map<String, dynamic>>? attendances,
    bool? isLoading,
    String? error,
  }) {
    return StaffState(
      staff: staff ?? this.staff,
      shifts: shifts ?? this.shifts,
      attendances: attendances ?? this.attendances,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class StaffNotifier extends StateNotifier<StaffState> {
  final StaffRepository _repo;

  StaffNotifier(this._repo) : super(const StaffState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getStaff(),
        _repo.getShifts(),
        _repo.getAttendances(),
      ]);
      state = state.copyWith(
        staff: results[0],
        shifts: results[1],
        attendances: results[2],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadStaff() async {
    try {
      final data = await _repo.getStaff();
      state = state.copyWith(staff: data);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadShifts() async {
    try {
      final data = await _repo.getShifts();
      state = state.copyWith(shifts: data);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadAttendances() async {
    try {
      final data = await _repo.getAttendances();
      state = state.copyWith(attendances: data);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> updateProfile(int userId, Map<String, dynamic> data) async {
    try {
      await _repo.updateProfile(userId, data);
      await loadStaff();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> createShift(Map<String, dynamic> data) async {
    try {
      await _repo.createShift(data);
      await loadShifts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateShift(int id, Map<String, dynamic> data) async {
    try {
      await _repo.updateShift(id, data);
      await loadShifts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteShift(int id) async {
    try {
      await _repo.deleteShift(id);
      await loadShifts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> checkIn(int userId) async {
    try {
      await _repo.checkIn(userId);
      await loadAttendances();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> checkOut(int userId) async {
    try {
      await _repo.checkOut(userId);
      await loadAttendances();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final staffProvider = StateNotifierProvider<StaffNotifier, StaffState>((ref) {
  return StaffNotifier(ref.watch(staffRepositoryProvider));
});
