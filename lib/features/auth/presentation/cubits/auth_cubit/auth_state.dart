part of 'auth_cubit.dart';

enum AuthAction { none, login, signup }

enum AuthStatus { initial, loading, success, failure }

class AuthState {
  final AuthAction action;
  final AuthStatus status;
  final String? errorMessage;
  final String? email;
  final String? name;
  final File? image;

  const AuthState({
    required this.action,
    required this.status,
    this.errorMessage,
    this.email,
    this.name,
    this.image
  });

  factory AuthState.initial() {
    return const AuthState(action: AuthAction.none, status: AuthStatus.initial);
  }

  AuthState copyWith({
    AuthAction? action,
    AuthStatus? status,
    String? errorMessage,
  }) {
    return AuthState(
      action: action ?? this.action,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
