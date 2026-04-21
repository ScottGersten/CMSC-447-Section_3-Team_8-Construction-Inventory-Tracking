import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'models/material.dart' as material_model;
import 'repositories/firestore_repository.dart';

class MaterialsPage extends StatefulWidget {
  final AppUser? currentUser;

  const MaterialsPage({super.key, this.currentUser});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  late FirestoreRepository _repository;
  
  // Material creation form controllers
  final TextEditingController _materialNameController = TextEditingController();
  final TextEditingController _materialDescriptionController = TextEditingController();
  final TextEditingController _materialPartNumberController = TextEditingController();
  final TextEditingController _materialManufacturerController = TextEditingController();
  final TextEditingController _materialUnitCostController = TextEditingController();
  material_model.MaterialCategory _materialCategory = material_model.MaterialCategory.materials;
  String _materialUnitOfMeasure = 'unit';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = FirestoreRepository();
  }

  @override
  void dispose() {
    _materialNameController.dispose();
    _materialDescriptionController.dispose();
    _materialPartNumberController.dispose();
    _materialManufacturerController.dispose();
    _materialUnitCostController.dispose();
    super.dispose();
  }

  Future<void> _createNewMaterial() async {
    final name = _materialNameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter a material name', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final unitCostText = _materialUnitCostController.text.trim();
      final unitCost = unitCostText.isEmpty ? 0.0 : double.parse(unitCostText);

      final newMaterial = material_model.Material(
        materialId: '',
        name: name,
        description: _materialDescriptionController.text.trim().isEmpty
            ? null
            : _materialDescriptionController.text.trim(),
        category: _materialCategory,
        partNumber: _materialPartNumberController.text.trim().isEmpty
            ? null
            : _materialPartNumberController.text.trim(),
        manufacturer: _materialManufacturerController.text.trim().isEmpty
            ? null
            : _materialManufacturerController.text.trim(),
        unitOfMeasure: _materialUnitOfMeasure,
        unitCost: unitCost,
      );

      await _repository.createMaterial(newMaterial);

      // Clear form
      _materialNameController.clear();
      _materialDescriptionController.clear();
      _materialPartNumberController.clear();
      _materialManufacturerController.clear();
      _materialUnitCostController.clear();
      _materialCategory = material_model.MaterialCategory.materials;
      _materialUnitOfMeasure = 'unit';

      if (mounted) {
        _showMessage('Material "$name" created successfully!');
      }
    } catch (e) {
      _showMessage('Error creating material: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteMaterial(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text(
            'Are you sure you want to delete "$name"? This action cannot be undone.'),
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
      await _repository.deleteMaterial(id);
      if (mounted) {
        _showMessage('Material deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error deleting material: $e', isError: true);
      }
    }
  }

  Future<void> _editMaterial(material_model.Material material) async {
    final nameEditController = TextEditingController(text: material.name);
    final descriptionEditController =
        TextEditingController(text: material.description ?? '');
    final partNumberEditController =
        TextEditingController(text: material.partNumber ?? '');
    final manufacturerEditController =
        TextEditingController(text: material.manufacturer ?? '');
    final unitCostEditController =
        TextEditingController(text: material.unitCost.toStringAsFixed(2));
    var selectedCategory = material.category;
    var selectedUnitOfMeasure = material.unitOfMeasure;
    bool isEditing = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Material'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameEditController,
                      enabled: !isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Material Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionEditController,
                      enabled: !isEditing,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<material_model.MaterialCategory>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: material_model.MaterialCategory.values
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category == material_model.MaterialCategory.equipment
                                      ? 'Equipment'
                                      : 'Materials',
                                ),
                              ))
                          .toList(),
                      onChanged: isEditing
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => selectedCategory = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: partNumberEditController,
                      enabled: !isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Part Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: manufacturerEditController,
                      enabled: !isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.factory),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedUnitOfMeasure,
                      decoration: const InputDecoration(
                        labelText: 'Unit of Measure',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'unit', child: Text('Unit')),
                        DropdownMenuItem(value: 'box', child: Text('Box')),
                        DropdownMenuItem(value: 'case', child: Text('Case')),
                        DropdownMenuItem(value: 'pallet', child: Text('Pallet')),
                        DropdownMenuItem(value: 'kg', child: Text('Kilogram')),
                        DropdownMenuItem(value: 'lb', child: Text('Pound')),
                        DropdownMenuItem(value: 'm', child: Text('Meter')),
                        DropdownMenuItem(value: 'ft', child: Text('Foot')),
                      ],
                      onChanged: isEditing
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(
                                    () => selectedUnitOfMeasure = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitCostEditController,
                      enabled: !isEditing,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Unit Cost',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isEditing
                      ? null
                      : () {
                          nameEditController.dispose();
                          descriptionEditController.dispose();
                          partNumberEditController.dispose();
                          manufacturerEditController.dispose();
                          unitCostEditController.dispose();
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isEditing
                      ? null
                      : () async {
                          try {
                            setDialogState(() => isEditing = true);
                            final name = nameEditController.text.trim();
                            if (name.isEmpty) {
                              _showMessage('Please enter a material name',
                                  isError: true);
                              setDialogState(() => isEditing = false);
                              return;
                            }

                            final unitCostText =
                                unitCostEditController.text.trim();
                            final unitCost = unitCostText.isEmpty
                                ? 0.0
                                : double.parse(unitCostText);

                            final updatedMaterial = material_model.Material(
                              materialId: material.materialId,
                              name: name,
                              description: descriptionEditController.text
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : descriptionEditController.text.trim(),
                              category: selectedCategory,
                              partNumber:
                                  partNumberEditController.text.trim().isEmpty
                                      ? null
                                      : partNumberEditController.text.trim(),
                              manufacturer: manufacturerEditController.text
                                      .trim()
                                      .isEmpty
                                  ? null
                                  : manufacturerEditController.text.trim(),
                              unitOfMeasure: selectedUnitOfMeasure,
                              unitCost: unitCost,
                            );

                            await _repository.updateMaterial(
                                material.materialId, updatedMaterial);

                            if (mounted) {
                              _showMessage('Material updated successfully');
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            _showMessage('Error: $e', isError: true);
                            setDialogState(() => isEditing = false);
                          }
                        },
                  child: isEditing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
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
        title: const Text("Materials Management"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
      body: DefaultTabController(
        length: 2,
        initialIndex: 1,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Add Material'),
                Tab(text: 'All Materials'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Add Material Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        TextField(
                          controller: _materialNameController,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Material Name *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.label),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _materialDescriptionController,
                          enabled: !_isLoading,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<material_model.MaterialCategory>(
                          value: _materialCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: material_model.MaterialCategory.values
                              .map((category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(
                                      category == material_model.MaterialCategory.equipment
                                          ? 'Equipment'
                                          : 'Materials',
                                    ),
                                  ))
                              .toList(),
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _materialCategory = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _materialPartNumberController,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Part Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _materialManufacturerController,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Manufacturer',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.factory),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _materialUnitOfMeasure,
                          decoration: const InputDecoration(
                            labelText: 'Unit of Measure',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'unit', child: Text('Unit')),
                            DropdownMenuItem(value: 'box', child: Text('Box')),
                            DropdownMenuItem(value: 'case', child: Text('Case')),
                            DropdownMenuItem(value: 'pallet', child: Text('Pallet')),
                            DropdownMenuItem(value: 'kg', child: Text('Kilogram')),
                            DropdownMenuItem(value: 'lb', child: Text('Pound')),
                            DropdownMenuItem(value: 'm', child: Text('Meter')),
                            DropdownMenuItem(value: 'ft', child: Text('Foot')),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _materialUnitOfMeasure = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _materialUnitCostController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Unit Cost',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isLoading ? null : _createNewMaterial,
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
                              : const Text('Add Material'),
                        ),
                      ],
                    ),
                  ),

                  // All Materials Tab
                  StreamBuilder<List<material_model.Material>>(
                    stream: _repository.streamAllMaterials(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final materials = snapshot.data ?? [];
                      if (materials.isEmpty) {
                        return const Center(
                          child: Text('No materials found'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: materials.length,
                        itemBuilder: (context, index) {
                          final material = materials[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: material.category ==
                                        material_model.MaterialCategory.equipment
                                    ? Colors.blue
                                    : Colors.green,
                                child: Icon(
                                  material.category ==
                                          material_model.MaterialCategory.equipment
                                      ? Icons.build
                                      : Icons.shopping_bag,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(material.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (material.description != null)
                                    Text(
                                      material.description!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  Text(
                                    'Category: ${material.category == material_model.MaterialCategory.equipment ? 'Equipment' : 'Materials'}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  if (material.partNumber != null)
                                    Text(
                                      'Part #: ${material.partNumber}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  if (material.manufacturer != null)
                                    Text(
                                      'Mfg: ${material.manufacturer}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  Text(
                                    'Unit: ${material.unitOfMeasure} | Cost: \$${material.unitCost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: GestureDetector(
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
                                        child: const Text('Edit'),
                                        onTap: () =>
                                            Future.delayed(
                                              const Duration(milliseconds: 100),
                                              () => _editMaterial(material),
                                            ),
                                      ),
                                      PopupMenuItem(
                                        child: const Text('Delete'),
                                        onTap: () =>
                                            Future.delayed(
                                              const Duration(milliseconds: 100),
                                              () => _deleteMaterial(
                                                  material.materialId, material.name),
                                            ),
                                      ),
                                    ],
                                  );
                                },
                                child: const Icon(Icons.more_vert),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
