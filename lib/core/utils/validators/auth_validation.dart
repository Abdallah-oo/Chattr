
class AuthValidation {
  ///Field validator
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required field';
    return null;
  }

  ///email validator
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required field';
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  ///password validator

  static String? password(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required field';
    if (value.length < 9) return 'At least 9 characters';
    return null;
  }

 

  ///phone validator

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required field';
    final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
    if (!phoneRegex.hasMatch(value.trim())) return 'Enter a valid phone number';
    return null;
  }
}
