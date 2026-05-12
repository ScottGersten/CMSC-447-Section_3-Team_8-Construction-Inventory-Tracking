import 'package:crypto/crypto.dart';
import '../models/app_user.dart';
import '../repositories/firestore_repository.dart';

/// Authentication service for user login and validation.
class AuthService {
  final FirestoreRepository _repository;

  AuthService(this._repository);

  /// Hash password for storage (using SHA256).
  static String hashPassword(String password) {
    return sha256.convert(password.codeUnits).toString();
  }

  /// Authenticate user with email and password.
  /// Returns the authenticated user if credentials are valid, null otherwise.
  Future<AppUser?> authenticate({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _repository.getUserByEmail(email.toLowerCase().trim());
      if (user == null) {
        return null; // User not found
      }

      // Validate password (retrieve stored hash from Firestore)
      final storedPasswordHash = await _getStoredPasswordHash(user.uid);
      if (storedPasswordHash == null) {
        return null; // No password stored
      }

      final providedHash = hashPassword(password);
      if (providedHash != storedPasswordHash) {
        return null; // Password mismatch
      }

      return user; // Authentication successful
    } catch (e) {
      print('Authentication error: $e');
      return null;
    }
  }

  /// Get stored password hash for a user.
  Future<String?> _getStoredPasswordHash(String userId) async {
    return await _repository.getPasswordHash(userId);
  }

  /// Create a new user with credentials (admin only).
  Future<String> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      // Create user profile
      final user = AppUser(
        uid: '', // Will be set by Firestore
        name: name,
        email: email.toLowerCase().trim(),
        role: role,
        createdAt: DateTime.now(),
      );

      final userId = await _repository.createUser(user);

      // Store password hash separately
      await _repository.setPasswordHash(userId, hashPassword(password));

      return userId;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Update user password.
  Future<void> updatePassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _repository.updatePasswordHash(userId, hashPassword(newPassword));
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Initialize default admin account (should be called once during setup).
  Future<void> initializeDefaultAdmin() async {
    try {
      final existingAdmin = await _repository.getUserByEmail('admin@construction.local');
      if (existingAdmin != null) {
        print('Admin account already exists');
        return;
      }

      await createUser(
        name: 'System Admin',
        email: 'admin@construction.local',
        password: 'admin', // Default password - MUST be changed on first login
        role: UserRole.systemAdmin,
      );

      print('Default admin account created with email: admin@construction.local');
    } catch (e) {
      print('Error initializing admin account: $e');
    }
  }
}
