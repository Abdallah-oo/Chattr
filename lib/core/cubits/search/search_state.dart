part of 'search_cubit.dart';

sealed class SearchState {}

final class SearchInitial extends SearchState {}

final class SearchActive extends SearchState {
  final List<dynamic> filteredList;
  SearchActive({required this.filteredList});
}

final class SearchClosed extends SearchState {}
