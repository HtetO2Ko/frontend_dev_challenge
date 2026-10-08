import 'dart:async';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  Timer? _searchDebounce;
  int _searchRequestId = 0;

  void onQueryChanged(String query) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    final requestId = ++_searchRequestId;

    if (query.trim().isEmpty) {
      results.clear();
      hasSearched.value = false;
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    hasSearched.value = true;

    try {
      final found = await dealRepo.search(query);
      if (requestId != _searchRequestId) return;
      results.assignAll(found);
    } catch (e) {
      if (requestId == _searchRequestId) {
        LogService.error('search failed', e);
      }
    } finally {
      if (requestId == _searchRequestId) {
        isLoading.value = false;
      }
    }
  }
}
