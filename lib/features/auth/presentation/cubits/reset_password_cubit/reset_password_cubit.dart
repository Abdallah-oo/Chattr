
import 'package:chattr/features/auth/data/repos/auth_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'reset_password_state.dart';

class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final AuthRepo authRepo;
  ResetPasswordCubit(this.authRepo) : super(const ResetPasswordState());

  Future<void> sendOtp(String email) async {
    emit(state.copyWith(status: ResetPasswordStatus.sendingOtp, email: email));
    final result = await authRepo.sendPasswordResetOtp(email: email);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ResetPasswordStatus.sendOtpFailure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: ResetPasswordStatus.otpSent)),
    );
  }

  Future<void> verifyOtp(String otp) async {
    emit(state.copyWith(status: ResetPasswordStatus.verifyingOtp));
    final result = await authRepo.verifyPasswordResetOtp(
      email: state.email,
      otp: otp,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ResetPasswordStatus.verifyOtpFailure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: ResetPasswordStatus.otpVerified)),
    );
  }

  Future<void> updatePassword(String newPassword) async {
    emit(state.copyWith(status: ResetPasswordStatus.updatingPassword));
    final result = await authRepo.updatePassword(newPassword: newPassword);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ResetPasswordStatus.updatePasswordFailure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: ResetPasswordStatus.passwordUpdated)),
    );
  }
}
