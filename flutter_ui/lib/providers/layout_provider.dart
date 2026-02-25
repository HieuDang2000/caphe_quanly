import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/layout_repository.dart';

class LayoutState {
  final List<Map<String, dynamic>> floors;
  final List<Map<String, dynamic>> objects;
  final int? selectedFloorId;
  final bool isLoading;
  final String? error;

  const LayoutState({
    this.floors = const [],
    this.objects = const [],
    this.selectedFloorId,
    this.isLoading = false,
    this.error,
  });

  LayoutState copyWith({
    List<Map<String, dynamic>>? floors,
    List<Map<String, dynamic>>? objects,
    int? selectedFloorId,
    bool? isLoading,
    String? error,
  }) {
    return LayoutState(
      floors: floors ?? this.floors,
      objects: objects ?? this.objects,
      selectedFloorId: selectedFloorId ?? this.selectedFloorId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LayoutNotifier extends StateNotifier<LayoutState> {
  final LayoutRepository _repo;
  LayoutNotifier(this._repo) : super(const LayoutState());

  Future<void> loadFloors() async {
    state = state.copyWith(isLoading: true);
    try {
      final floors = await _repo.getFloors();
      state = state.copyWith(floors: floors, isLoading: false);
      if (floors.isNotEmpty && state.selectedFloorId == null) {
        await selectFloor(floors.first['id']);
      }
      // Background refresh
      _repo.getFloors(forceRefresh: true).then((fresh) {
        if (mounted) state = state.copyWith(floors: fresh);
      }).catchError((_) {});
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectFloor(int floorId) async {
    state = state.copyWith(selectedFloorId: floorId, isLoading: true);
    try {
      final objects = await _repo.getFloorObjects(floorId);
      state = state.copyWith(objects: objects, isLoading: false);
      // Background refresh
      _repo.getFloorObjects(floorId, forceRefresh: true).then((fresh) {
        if (mounted && state.selectedFloorId == floorId) {
          state = state.copyWith(objects: fresh);
        }
      }).catchError((_) {});
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addObject(Map<String, dynamic> data) async {
    try {
      await _repo.addObject(data);
      if (state.selectedFloorId != null) await selectFloor(state.selectedFloorId!);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateObject(int id, Map<String, dynamic> data) async {
    try {
      await _repo.updateObject(id, data);
      state = state.copyWith(
        objects: state.objects.map((o) => o['id'] == id ? {...o, ...data} : o).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> batchUpdate(List<Map<String, dynamic>> objects) async {
    try {
      await _repo.batchUpdate(objects);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteObject(int id) async {
    try {
      await _repo.deleteObject(id);
      state = state.copyWith(objects: state.objects.where((o) => o['id'] != id).toList());
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void updateLocalPosition(int id, double x, double y) {
    state = state.copyWith(
      objects: state.objects.map((o) {
        if (o['id'] == id) return {...o, 'position_x': x, 'position_y': y};
        return o;
      }).toList(),
    );
  }

  void updateLocalRotation(int id, double rotation) {
    state = state.copyWith(
      objects: state.objects.map((o) {
        if (o['id'] == id) return {...o, 'rotation': rotation};
        return o;
      }).toList(),
    );
  }
}

final layoutProvider = StateNotifierProvider<LayoutNotifier, LayoutState>((ref) {
  return LayoutNotifier(ref.watch(layoutRepositoryProvider));
});
