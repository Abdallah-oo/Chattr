part of 'signup_verification_cubit.dart';

enum SignupVerificationStatus {
  initial,
  verifying,
  verified,
  verifyFailure,
  resending,
  resent,
  resendFailure,
}

class SignupVerificationState extends Equatable {
  final SignupVerificationStatus status;
  final String? errorMessage;
  final String email;
  final String name;
  final File image;
  final int remainingSeconds; 

  const SignupVerificationState({
    this.status = SignupVerificationStatus.initial,
    this.errorMessage,
    required this.email,
    required this.name,
    required this.image,
    this.remainingSeconds = 0,
  });

  SignupVerificationState copyWith({
    SignupVerificationStatus? status,
    String? errorMessage,
    int? remainingSeconds,
  }) {
    return SignupVerificationState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      email: email,
      name: name,
      image: image,
       remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, email, remainingSeconds];
}
