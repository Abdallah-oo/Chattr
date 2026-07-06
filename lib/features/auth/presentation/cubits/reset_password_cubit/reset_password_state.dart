part of 'reset_password_cubit.dart';

enum ResetPasswordStatus {
  initial,
  sendingOtp,
  otpSent,
  sendOtpFailure,
  verifyingOtp,
  otpVerified,
  verifyOtpFailure,
  updatingPassword,
  passwordUpdated,
  updatePasswordFailure,
}

class ResetPasswordState extends Equatable {
  final ResetPasswordStatus status;
  final String? errorMessage;
  final String email;

  const ResetPasswordState({
    this.status = ResetPasswordStatus.initial,
    this.errorMessage,
    this.email = '',
  });

  ResetPasswordState copyWith({
    ResetPasswordStatus? status,
    String? errorMessage,
    String? email,
  }) {
    return ResetPasswordState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, email];
}
