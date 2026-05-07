import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'models/material.dart' as material_model;
import 'repositories/firestore_repository.dart';
import 'theme/app_theme.dart';

class MaterialsPage extends StatefulWidget {
  final AppUser? currentUser;

  const MaterialsPage({super.key, this.currentUser});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  late FirestoreRepository _repository;
  
  final TextEditingController _materialNameController = TextEditingController();
  final TextEditingController _materialDescriptionController = TextEditingController();
  final TextEditingController _materialPartNumberController = TextEditingController();
  final TextEditingController _materialManufacturerController = TextEditingController();
  final TextEditingController _materialUnitCostController = TextEditingController();
  material_model.MaterialCategory _materialCategory = material_model.MaterialCategory.materials;
  String _materialUnitOfMeasure = 'unit';
  bool _isLoading = false;

  bool get _canAdd => widget.currentUser?.role == UserRole.systemAdmin || widget.currentUser?.role == UserRole.projectManager;
  bool get _canRequest => widget.currentUser?.role == UserRole.systemAdmin || widget.currentUser?.role == UserRole.fieldCrew || widget.currentUser?.role == UserRole.warehouseStaff;
  bool get _canApprove => _canAdd;

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

  Future<void> _submitForm({required bool isRequest}) async {
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
        description: _materialDescriptionController.text.trim().isEmpty ? null : _materialDescriptionController.text.trim(),
        category: _materialCategory,
        partNumber: _materialPartNumberController.text.trim().isEmpty ? null : _materialPartNumberController.text.trim(),
        manufacturer: _materialManufacturerController.text.trim().isEmpty ? null : _materialManufacturerController.text.trim(),
        unitOfMeasure: _materialUnitOfMeasure,
        unitCost: unitCost,
        isApproved: !isRequest,
      );

      await _repository.createMaterial(newMaterial);

      _materialNameController.clear();
      _materialDescriptionController.clear();
      _materialPartNumberController.clear();
      _materialManufacturerController.clear();
      _materialUnitCostController.clear();
      _materialCategory = material_model.MaterialCategory.materials;
      _materialUnitOfMeasure = 'unit';

      if (mounted) {
        _showMessage(isRequest ? 'Material "$name" requested successfully!' : 'Material "$name" created successfully!');
      }
    } catch (e) {
      _showMessage('Error processing material: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveMaterial(material_model.Material material) async {
    try {
      await _repository.approveMaterial(material.materialId);
      if (mounted) {
        _showMessage('Material "${material.name}" approved successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error approving material: $e', isError: true);
      }
    }
  }

  Future<void> _editMaterial(material_model.Material material) async {
    final nameEditController = TextEditingController(text: material.name);
    final descriptionEditController = TextEditingController(text: material.description ?? '');
    final partNumberEditController = TextEditingController(text: material.partNumber ?? '');
    final manufacturerEditController = TextEditingController(text: material.manufacturer ?? '');
    final unitCostEditController = TextEditingController(text: material.unitCost.toStringAsFixed(2));
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
                      decoration: InputDecoration(labelText: 'Material Name *', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.label)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionEditController,
                      enabled: !isEditing,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: 'Description', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.description)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<material_model.MaterialCategory>(
                      value: selectedCategory,
                      decoration: InputDecoration(labelText: 'Category', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.category)),
                      items: material_model.MaterialCategory.values.map((category) => DropdownMenuItem(value: category, child: Text(category == material_model.MaterialCategory.equipment ? 'Equipment' : 'Materials'))).toList(),
                      onChanged: isEditing ? null : (value) { if (value != null) { setDialogState(() => selectedCategory = value); } },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: partNumberEditController,
                      enabled: !isEditing,
                      decoration: InputDecoration(labelText: 'Part Number', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.numbers)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: manufacturerEditController,
                      enabled: !isEditing,
                      decoration: InputDecoration(labelText: 'Manufacturer', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.factory)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedUnitOfMeasure,
                      decoration: InputDecoration(labelText: 'Unit of Measure', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.straighten)),
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
                      onChanged: isEditing ? null : (value) { if (value != null) { setDialogState(() => selectedUnitOfMeasure = value); } },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitCostEditController,
                      enabled: !isEditing,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Unit Cost', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.attach_money)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isEditing ? null : () {
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
                  onPressed: isEditing ? null : () async {
                    try {
                      setDialogState(() => isEditing = true);
                      final name = nameEditController.text.trim();
                      if (name.isEmpty) {
                        _showMessage('Please enter a material name', isError: true);
                        setDialogState(() => isEditing = false);
                        return;
                      }

                      final unitCostText = unitCostEditController.text.trim();
                      final unitCost = unitCostText.isEmpty ? 0.0 : double.parse(unitCostText);

                      final updatedMaterial = material_model.Material(
                        materialId: material.materialId,
                        name: name,
                        description: descriptionEditController.text.trim().isEmpty ? null : descriptionEditController.text.trim(),
                        category: selectedCategory,
                        partNumber: partNumberEditController.text.trim().isEmpty ? null : partNumberEditController.text.trim(),
                        manufacturer: manufacturerEditController.text.trim().isEmpty ? null : manufacturerEditController.text.trim(),
                        unitOfMeasure: selectedUnitOfMeasure,
                        unitCost: unitCost,
                        isApproved: material.isApproved,
                      );

                      await _repository.updateMaterial(material.materialId, updatedMaterial);

                      if (mounted) {
                        _showMessage('Material updated successfully');
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      _showMessage('Error: $e', isError: true);
                      setDialogState(() => isEditing = false);
                    }
                  },
                  child: isEditing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMaterial(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
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
    Navigator.pushNamed(context, '/user-management', arguments: widget.currentUser);
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

  Widget _buildFormTab({required bool isRequest}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isRequest ? 'Request Material' : 'Add New Material', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Fill in the details to ${isRequest ? 'request' : 'create'} a new material', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          TextField(controller: _materialNameController, enabled: !_isLoading, decoration: InputDecoration(labelText: 'Material Name *', hintText: 'Enter material name', prefixIcon: const Icon(Icons.label), helperText: 'Required field')),
          const SizedBox(height: 16),
          TextField(controller: _materialDescriptionController, enabled: !_isLoading, maxLines: 2, decoration: InputDecoration(labelText: 'Description', hintText: 'Enter material description', prefixIcon: const Icon(Icons.description), helperText: 'Optional')),
          const SizedBox(height: 16),
          DropdownButtonFormField<material_model.MaterialCategory>(
            value: _materialCategory,
            decoration: InputDecoration(labelText: 'Category', prefixIcon: const Icon(Icons.category), helperText: 'Select category'),
            items: material_model.MaterialCategory.values.map((category) => DropdownMenuItem(value: category, child: Text(category == material_model.MaterialCategory.equipment ? 'Equipment' : 'Materials'))).toList(),
            onChanged: _isLoading ? null : (value) { if (value != null) { setState(() => _materialCategory = value); } },
          ),
          const SizedBox(height: 16),
          TextField(controller: _materialPartNumberController, enabled: !_isLoading, decoration: InputDecoration(labelText: 'Part Number', hintText: 'Enter part number', prefixIcon: const Icon(Icons.numbers), helperText: 'Optional')),
          const SizedBox(height: 16),
          TextField(controller: _materialManufacturerController, enabled: !_isLoading, decoration: InputDecoration(labelText: 'Manufacturer', hintText: 'Enter manufacturer name', prefixIcon: const Icon(Icons.factory), helperText: 'Optional')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _materialUnitOfMeasure,
            decoration: InputDecoration(labelText: 'Unit of Measure', prefixIcon: const Icon(Icons.straighten), helperText: 'Select unit of measure'),
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
            onChanged: _isLoading ? null : (value) { if (value != null) { setState(() => _materialUnitOfMeasure = value); } },
          ),
          const SizedBox(height: 16),
          TextField(controller: _materialUnitCostController, enabled: !_isLoading, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Unit Cost', hintText: '0.00', prefixIcon: const Icon(Icons.attach_money), helperText: 'Optional')),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _submitForm(isRequest: isRequest),
            icon: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.add),
            label: Text(isRequest ? 'Request Material' : 'Add Material'),
          ),
        ],
      ),
    );
  }

  Widget _buildAllMaterialsTab() {
    return StreamBuilder<List<material_model.Material>>(
      stream: _repository.streamAllMaterials(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text('Error loading materials', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final materials = snapshot.data ?? [];
        if (materials.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 48, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text('No materials found', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Create or request a material to get started', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: materials.length,
          itemBuilder: (context, index) {
            final material = materials[index];
            final bool canShowApprove = !material.isApproved && _canApprove;
            final bool canShowEditDelete = _canAdd || (!material.isApproved && _canRequest);
            final bool hasMenuItems = canShowApprove || canShowEditDelete;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: material.category == material_model.MaterialCategory.equipment ? Colors.blue.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              material.category == material_model.MaterialCategory.equipment ? Icons.build : Icons.shopping_bag,
                              color: material.category == material_model.MaterialCategory.equipment ? Colors.blue : Colors.green,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(material.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (!material.isApproved)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.amber.shade300),
                                      ),
                                      child: const Text('Pending Approval', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (hasMenuItems)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'approve') {
                                  _approveMaterial(material);
                                } else if (value == 'edit') {
                                  _editMaterial(material);
                                } else if (value == 'delete') {
                                  _deleteMaterial(material.materialId, material.name);
                                }
                              },
                              itemBuilder: (context) => [
                                if (canShowApprove) const PopupMenuItem(value: 'approve', child: Row(children: [Icon(Icons.check_circle), SizedBox(width: 8), Text('Approve')])),
                                if (canShowEditDelete) const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')])),
                                if (canShowEditDelete) PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), const SizedBox(width: 8), const Text('Delete', style: TextStyle(color: Colors.red))])),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (material.description != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(material.description!, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _buildDetailChip(icon: Icons.category, label: 'Category', value: material.category == material_model.MaterialCategory.equipment ? 'Equipment' : 'Materials'),
                          if (material.partNumber != null) _buildDetailChip(icon: Icons.numbers, label: 'Part #', value: material.partNumber!),
                          if (material.manufacturer != null) _buildDetailChip(icon: Icons.factory, label: 'Manufacturer', value: material.manufacturer!),
                          _buildDetailChip(icon: Icons.straighten, label: 'Unit', value: material.unitOfMeasure),
                          _buildDetailChip(icon: Icons.attach_money, label: 'Cost', value: '\$${material.unitCost.toStringAsFixed(2)}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailChip({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final tabs = <Tab>[];
    final views = <Widget>[];

    if (_canAdd) {
      tabs.add(const Tab(text: 'Add Material'));
      views.add(_buildFormTab(isRequest: false));
    }
    if (_canRequest) {
      tabs.add(const Tab(text: 'Request Material'));
      views.add(_buildFormTab(isRequest: true));
    }
    tabs.add(const Tab(text: 'All Materials'));
    views.add(_buildAllMaterialsTab());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Materials Management"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
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
              if (user != null && user.role == UserRole.systemAdmin) const PopupMenuItem<String>(value: 'management', child: Row(children: [Icon(Icons.people), SizedBox(width: 12), Text('Manage Users')])),
              const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout), SizedBox(width: 12), Text('Logout')])),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Tooltip(
                  message: user != null ? '${user.name}\n${user.email}\n${_roleDisplayName(user.role)}' : '',
                  child: CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    radius: 18,
                    child: Text(
                      user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DefaultTabController(
        length: tabs.length,
        initialIndex: tabs.length - 1,
        child: Column(
          children: [
            Container(color: Colors.white, child: TabBar(isScrollable: tabs.length > 2, tabs: tabs)),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}
