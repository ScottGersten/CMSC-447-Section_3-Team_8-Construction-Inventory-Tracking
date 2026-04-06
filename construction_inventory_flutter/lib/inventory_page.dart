import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/app_user.dart';

class InventoryPage extends StatefulWidget {
  final AppUser? currentUser;

  const InventoryPage({super.key, this.currentUser});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController _itemController = TextEditingController();
  final CollectionReference _materials = FirebaseFirestore.instance.collection('materials');

  // Function to add an item
  Future<void> _addItem() async {
    if (_itemController.text.isNotEmpty) {
      await _materials.add({
        "name": _itemController.text,
        "timestamp": FieldValue.serverTimestamp(),
      });
      _itemController.clear();
    }
  }

  // Function to delete an item
  Future<void> _deleteItem(String id) async {
    await _materials.doc(id).delete();
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _openUserManagement() {
    Navigator.pushNamed(
      context,
      '/user-management',
      arguments: widget.currentUser,
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
    final user = widget.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'management') {
                _openUserManagement();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (user != null && user.role == UserRole.systemAdmin)
                const PopupMenuItem<String>(
                  value: 'management',
                  child: ListTile(
                    leading: Icon(Icons.people),
                    title: Text('Manage Users'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (user != null)
                      Tooltip(
                        message:
                            '${user.name}\n${user.email}\n${_roleDisplayName(user.role)}',
                        child: CircleAvatar(
                          radius: 16,
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (user != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logged in as: ${user.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Role: ${_roleDisplayName(user.role)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(labelText: 'Material Name'),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addItem),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _materials.orderBy('timestamp', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    return ListTile(
                      title: Text(doc['name']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteItem(doc.id),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}