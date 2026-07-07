part of 'auto_login_cubit.dart';

sealed class AutoLoginState extends Equatable {
  const AutoLoginState();

  @override
  List<Object> get props => [];
}

final class AutoLoginInitial extends AutoLoginState {}

final class AutoLoginLoading extends AutoLoginState {}

final class AutoLoginSuccess extends AutoLoginState {}

final class AutoLoginFailure extends AutoLoginState {}
