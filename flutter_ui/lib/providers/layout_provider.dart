import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../config/api_config.dart';

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
  final ApiClient _api;
  LayoutNotifier(this._api) : super(const LayoutState());

  Future<void> loadFloors() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get(ApiConfig.floors);
      final floors = List<Map<String, dynamic>>.from(res.data);
      state = state.copyWith(floors: floors, isLoading: false);
      if (floors.isNotEmpty && state.selectedFloorId == null) {
        await selectFloor(floors.first['id']);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectFloor(int floorId) async {
    state = state.copyWith(selectedFloorId: floorId, isLoading: true);
    try {
      final res = await _api.get('${ApiConfig.floors}/$floorId/objects');
      final objects = List<Map<String, dynamic>>.from(res.data);
      state = state.copyWith(objects: objects, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addObject(Map<String, dynamic> data) async {
    try {
      await _api.post(ApiConfig.layoutObjects, data: data);
      if (state.selectedFloorId != null) await selectFloor(state.selectedFloorId!);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateObject(int id, Map<String, dynamic> data) async {
    try {
      await _api.put('${ApiConfig.layoutObjects}/$id', data: data);
      state = state.copyWith(
        objects: state.objects.map((o) => o['id'] == id ? {...o, ...data} : o).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> batchUpdate(List<Map<String, dynamic>> objects) async {
    try {
      await _api.put(ApiConfig.layoutObjectsBatch, data: {'objects': objects});
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteObject(int id) async {
    try {
      await _api.delete('${ApiConfig.layoutObjects}/$id');
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
  return LayoutNotifier(ref.watch(apiClientProvider));
});
