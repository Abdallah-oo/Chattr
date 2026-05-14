import 'package:flutter_bloc/flutter_bloc.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(SearchInitial());

  void search({
    required List<dynamic> list,
    required String query,
    required String Function(dynamic item) searchBy,
  }) {
    if (query.isEmpty) {
      emit(SearchClosed());
      return;
    }

    final filtered = list
        .where(
          (item) => searchBy(item).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    emit(SearchActive(filteredList: filtered));
  }

  void closeSearch() => emit(SearchClosed());
}
