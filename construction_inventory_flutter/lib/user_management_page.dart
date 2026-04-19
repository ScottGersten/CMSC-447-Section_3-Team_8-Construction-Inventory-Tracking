import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'repositories/firestore_repository.dart';
import 'services/auth_service.dart';

class UserManagementPage extends StatefulWidget {
  final AppUser currentUser;

  const UserManagementPage({super.key, required this.currentUser});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.fieldCrew;
  bool _isLoading = false;
  String? _message;

  late FirestoreRepository _repository;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _repository = FirestoreRepository();
    _authService = AuthService(_repository);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in all fields', isError: true);
      return;
    }

    if (password.length < 8) {
      _showMessage('Password must be at least 8 characters', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.createUser(
        name: name,
        email: email,
        password: password,
        role: _selectedRole,
      );

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _selectedRole = UserRole.fieldCrew;

      if (mounted) {
        _showMessage('User "$name" created successfully!');
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete "${user.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteUser(user.uid);
      if (mounted) {
        _showMessage('User deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error deleting user: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() => _message = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _roleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.fieldCrew:
        return 'Field Crew';
      case UserRole.warehouseStaff:
        return 'Warehouse Staff';
      case UserRole.projectManager:
        return 'Project Manager';
      case UserRole.systemAdmin:
        return 'System Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only admins can access this
    if (widget.currentUser.role != UserRole.systemAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Text('Only administrators can manage users'),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Create User'),
              Tab(text: 'All Users'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Create User Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (min 8 characters)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AbsorbPointer(
                    absorbing: _isLoading,
                    child: DropdownButtonFormField<UserRole>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'User Role',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security),
                      ),
                      items: UserRole.values
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(_roleDisplayName(role)),
                              ))
                          .toList(),
                      onChanged: (role) {
                        if (role != null) {
                          setState(() => _selectedRole = role);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _createUser,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Create User'),
                  ),
                ],
              ),
            ),

            // All Users Tab
            StreamBuilder<List<AppUser>>(
              stream: _repository.streamAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return const Center(
                    child: Text('No users found'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(user.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email),
                            Text(
                              _roleDisplayName(user.role),
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        trailing: user.role != UserRole.systemAdmin
                            ? GestureDetector(
                                onTapDown: (details) {
                                  final position = details.globalPosition;
                                  showMenu(
                                    context: context,
                                    position: RelativeRect.fromLTRB(
                                      position.dx,
                                      position.dy,
                                      position.dx,
                                      position.dy,
                                    ),
                                    items: [
                                      PopupMenuItem(
                                        child: const Text('Delete'),
                                        onTap: () =>
                                            Future.delayed(
                                              const Duration(milliseconds: 100),
                                              () => _deleteUser(user),
                                            ),
                                      ),
                                    ],
                                  );
                                },
                                child: const Icon(Icons.more_vert),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
