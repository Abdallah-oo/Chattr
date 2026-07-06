import 'dart:async';
import 'dart:io';

import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'signup_verification_state.dart';

class SignupVerificationCubit extends Cubit<SignupVerificationState> {
  final AuthRepo authRepo;
  Timer? _cooldownTimer;
  static const int _cooldownDuration = 60;

  SignupVerificationCubit(
    this.authRepo, {
    required String email,
    required String name,
    required File image,
  }) : super(SignupVerificationState(email: email, image: image, name: name)) {
    _startCooldown();
  }

  Future<void> verifyOtp(String otp) async {
    emit(state.copyWith(status: SignupVerificationStatus.verifying));
    final result = await authRepo.verifySignupOtp(
      email: state.email,
      otp: otp,
      name: state.name,
      image: state.image,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SignupVerificationStatus.verifyFailure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: SignupVerificationStatus.verified)),
    );
  }

  Future<void> resendOtp() async {
    emit(state.copyWith(status: SignupVerificationStatus.resending));
    final result = await authRepo.resendSignupOtp(email: state.email);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SignupVerificationStatus.resendFailure,
          errorMessage: failure.message,
        ),
      ),
      (_) {
        emit(state.copyWith(status: SignupVerificationStatus.resent));
        _startCooldown();
      },
    );
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    emit(state.copyWith(remainingSeconds: _cooldownDuration));

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.remainingSeconds - 1;
      if (next <= 0) {
        timer.cancel();
        emit(state.copyWith(remainingSeconds: 0));
      } else {
        emit(state.copyWith(remainingSeconds: next));
      }
    });
  }

  @override
  Future<void> close() {
    _cooldownTimer
        ?.cancel(); // مهم جدًا — لو الشاشة اتقفلت والـ Timer لسه شغال هيحاول يعمل emit على Cubit متقفل
    return super.close();
  }
}
