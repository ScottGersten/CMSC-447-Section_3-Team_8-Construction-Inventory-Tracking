import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'models/inventory_item.dart';
import 'models/location.dart';
import 'models/material.dart' as material_model;
import 'repositories/firestore_repository.dart';

class InventoryPage extends StatefulWidget {
  final AppUser? currentUser;

  const InventoryPage({super.key, this.currentUser});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late FirestoreRepository _repository;
  
  // Inventory item form controllers
  String? _selectedMaterialId;
  String? _selectedLocationId;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reservedQuantityController = TextEditingController();
  final TextEditingController _lowStockThresholdController = TextEditingController();
  InventoryStatus _selectedStatus = InventoryStatus.inStock;
  bool _isLoading = false;

  // Material creation form controllers
  final TextEditingController _materialNameController = TextEditingController();
  final TextEditingController _materialDescriptionController = TextEditingController();
  final TextEditingController _materialPartNumberController = TextEditingController();
  final TextEditingController _materialManufacturerController = TextEditingController();
  final TextEditingController _materialUnitCostController = TextEditingController();
  material_model.MaterialCategory _materialCategory = material_model.MaterialCategory.materials;
  String _materialUnitOfMeasure = 'unit';
  bool _creatingMaterial = false;

  @override
  void initState() {
    super.initState();
    _repository = FirestoreRepository();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reservedQuantityController.dispose();
    _lowStockThresholdController.dispose();
    _materialNameController.dispose();
    _materialDescriptionController.dispose();
    _materialPartNumberController.dispose();
    _materialManufacturerController.dispose();
    _materialUnitCostController.dispose();
    super.dispose();
  }

  // Function to add inventory item
  Future<void> _addInventoryItem() async {
    if (_selectedMaterialId == null || _selectedLocationId == null) {
      _showMessage('Please select a material and location', isError: true);
      return;
    }

    final quantityText = _quantityController.text.trim();
    final reservedText = _reservedQuantityController.text.trim();
    final thresholdText = _lowStockThresholdController.text.trim();

    if (quantityText.isEmpty || reservedText.isEmpty || thresholdText.isEmpty) {
      _showMessage('Please fill in all quantity fields', isError: true);
      return;
    }

    try {
      final quantity = double.parse(quantityText);
      final reservedQuantity = double.parse(reservedText);
      final lowStockThreshold = double.parse(thresholdText);

      if (quantity < 0 || reservedQuantity < 0 || lowStockThreshold < 0) {
        _showMessage('Quantities cannot be negative', isError: true);
        return;
      }

      setState(() => _isLoading = true);

      final inventoryItem = InventoryItem(
        inventoryItemId: '',
        materialId: _selectedMaterialId!,
        locationId: _selectedLocationId!,
        quantity: quantity,
        reservedQuantity: reservedQuantity,
        lowStockThreshold: lowStockThreshold,
        status: _selectedStatus,
        lastUpdatedAt: DateTime.now(),
      );

      await _repository.createInventoryItem(inventoryItem);

      // Clear form
      _selectedMaterialId = null;
      _selectedLocationId = null;
      _quantityController.clear();
      _reservedQuantityController.clear();
      _lowStockThresholdController.clear();
      _selectedStatus = InventoryStatus.inStock;

      if (mounted) {
        _showMessage('Inventory item added successfully!');
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Function to delete an item
  Future<void> _deleteInventoryItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Inventory Item'),
        content: const Text(
            'Are you sure you want to delete this inventory item? This action cannot be undone.'),
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
      await _repository.deleteInventoryItem(id);
      if (mounted) {
        _showMessage('Inventory item deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error deleting item: $e', isError: true);
      }
    }
  }

  // Function to edit an existing inventory item
  Future<void> _editInventoryItem(InventoryItem item) async {
    final quantityEditController = TextEditingController(
      text: item.quantity.toStringAsFixed(2),
    );
    final reservedEditController = TextEditingController(
      text: item.reservedQuantity.toStringAsFixed(2),
    );
    final thresholdEditController = TextEditingController(
      text: item.lowStockThreshold.toStringAsFixed(2),
    );
    final availableQuantityController = TextEditingController(
      text: item.availableQuantity.toStringAsFixed(2),
    );
    bool isEditing = false;

    // Function to update available quantity display
    void updateAvailableQuantity() {
      try {
        final quantity = double.tryParse(quantityEditController.text) ?? 0;
        final reserved = double.tryParse(reservedEditController.text) ?? 0;
        final available = quantity - reserved;
        availableQuantityController.text = available.toStringAsFixed(2);
      } catch (e) {
        availableQuantityController.text = '0.00';
      }
    }

    // Add listeners to update available quantity
    quantityEditController.addListener(updateAvailableQuantity);
    reservedEditController.addListener(updateAvailableQuantity);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Inventory Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: quantityEditController,
                      enabled: !isEditing,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reservedEditController,
                      enabled: !isEditing,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reserved Quantity',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: thresholdEditController,
                      enabled: !isEditing,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Low Stock Threshold',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.warning),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: availableQuantityController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Available Quantity (Read-only)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.check_circle),
                        filled: true,
                        fillColor: Color(0xFFF5F5F5),
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
                          quantityEditController.dispose();
                          reservedEditController.dispose();
                          thresholdEditController.dispose();
                          availableQuantityController.dispose();
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
                            final quantity =
                                double.parse(quantityEditController.text);
                            final reserved =
                                double.parse(reservedEditController.text);
                            final threshold =
                                double.parse(thresholdEditController.text);

                            if (quantity < 0 ||
                                reserved < 0 ||
                                threshold < 0) {
                              _showMessage('Quantities cannot be negative',
                                  isError: true);
                              setDialogState(() => isEditing = false);
                              return;
                            }

                            // Calculate status automatically based on available quantity
                            final availableQty = quantity - reserved;
                            final calculatedStatus = availableQty == 0
                                ? InventoryStatus.outOfStock
                                : availableQty <= threshold
                                    ? InventoryStatus.lowStock
                                    : InventoryStatus.inStock;

                            await _repository.updateInventoryItem(
                              inventoryItemId: item.inventoryItemId,
                              quantity: quantity,
                              reservedQuantity: reserved,
                              lowStockThreshold: threshold,
                              status: calculatedStatus,
                            );

                            if (mounted) {
                              _showMessage('Inventory item updated successfully');
                              quantityEditController.dispose();
                              reservedEditController.dispose();
                              thresholdEditController.dispose();
                              availableQuantityController.dispose();
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

  // Function to increment quantity by 1
  Future<void> _incrementQuantity(InventoryItem item) async {
    try {
      final newQuantity = item.quantity + 1;
      final availableQty = newQuantity - item.reservedQuantity;
      final calculatedStatus = availableQty == 0
          ? InventoryStatus.outOfStock
          : availableQty <= item.lowStockThreshold
              ? InventoryStatus.lowStock
              : InventoryStatus.inStock;
      await _repository.updateInventoryItem(
        inventoryItemId: item.inventoryItemId,
        quantity: newQuantity,
        reservedQuantity: item.reservedQuantity,
        lowStockThreshold: item.lowStockThreshold,
        status: calculatedStatus,
      );
      if (mounted) {
        _showMessage('Quantity incremented to ${newQuantity.toStringAsFixed(2)}');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error incrementing quantity: $e', isError: true);
      }
    }
  }

  // Function to decrement quantity by 1
  Future<void> _decrementQuantity(InventoryItem item) async {
    try {
      if (item.quantity <= 0) {
        _showMessage('Quantity cannot go below 0', isError: true);
        return;
      }
      final newQuantity = item.quantity - 1;
      final availableQty = newQuantity - item.reservedQuantity;
      final calculatedStatus = availableQty == 0
          ? InventoryStatus.outOfStock
          : availableQty <= item.lowStockThreshold
              ? InventoryStatus.lowStock
              : InventoryStatus.inStock;
      await _repository.updateInventoryItem(
        inventoryItemId: item.inventoryItemId,
        quantity: newQuantity,
        reservedQuantity: item.reservedQuantity,
        lowStockThreshold: item.lowStockThreshold,
        status: calculatedStatus,
      );
      if (mounted) {
        _showMessage('Quantity decremented to ${newQuantity.toStringAsFixed(2)}');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error decrementing quantity: $e', isError: true);
      }
    }
  }

  // Function to create a new material
  Future<void> _createNewMaterial() async {
    final name = _materialNameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter a material name', isError: true);
      return;
    }

    setState(() => _creatingMaterial = true);

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
        Navigator.pop(context);
      }
    } catch (e) {
      _showMessage('Error creating material: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _creatingMaterial = false);
      }
    }
  }

  // Group inventory items by status
  Map<InventoryStatus, List<InventoryItem>> _groupItemsByStatus(
      List<InventoryItem> items) {
    final grouped = <InventoryStatus, List<InventoryItem>>{};

    for (final item in items) {
      if (!grouped.containsKey(item.status)) {
        grouped[item.status] = [];
      }
      grouped[item.status]!.add(item);
    }

    return grouped;
  }

  // Build a list with headers and grouped items
  List<dynamic> _buildGroupedList(
      Map<InventoryStatus, List<InventoryItem>> grouped) {
    final result = <dynamic>[];

    // Order: outOfStock, lowStock, inStock
    final order = [
      InventoryStatus.outOfStock,
      InventoryStatus.lowStock,
      InventoryStatus.inStock,
    ];

    for (final status in order) {
      if (grouped.containsKey(status) && grouped[status]!.isNotEmpty) {
        // Add header
        final headerText = _getStatusHeaderText(status);
        result.add(headerText);

        // Add items for this status
        result.addAll(grouped[status]!);
      }
    }

    return result;
  }

  // Get header text for status
  String _getStatusHeaderText(InventoryStatus status) {
    switch (status) {
      case InventoryStatus.outOfStock:
        return '🔴 Out of Stock';
      case InventoryStatus.lowStock:
        return '🟡 Low Stock';
      case InventoryStatus.inStock:
        return '🟢 In Stock';
    }
  }

  // Show dialog to create new material
  void _showCreateMaterialDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Material'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _materialNameController,
                      enabled: !_creatingMaterial,
                      decoration: const InputDecoration(
                        labelText: 'Material Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _materialDescriptionController,
                      enabled: !_creatingMaterial,
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
                      onChanged: _creatingMaterial
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(
                                    () => _materialCategory = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _materialPartNumberController,
                      enabled: !_creatingMaterial,
                      decoration: const InputDecoration(
                        labelText: 'Part Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _materialManufacturerController,
                      enabled: !_creatingMaterial,
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
                      onChanged: _creatingMaterial
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(
                                    () => _materialUnitOfMeasure = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _materialUnitCostController,
                      enabled: !_creatingMaterial,
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
                  onPressed: _creatingMaterial
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _creatingMaterial ? null : _createNewMaterial,
                  child: _creatingMaterial
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create Material'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _statusDisplayName(InventoryStatus status) {
    switch (status) {
      case InventoryStatus.inStock:
        return 'In Stock';
      case InventoryStatus.lowStock:
        return 'Low Stock';
      case InventoryStatus.outOfStock:
        return 'Out of Stock';
    }
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

  void _openMaterialsManagement() {
    Navigator.pushNamed(
      context,
      '/materials',
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
              } else if (value == 'materials') {
                _openMaterialsManagement();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'materials',
                child: ListTile(
                  leading: Icon(Icons.shopping_bag),
                  title: Text('Manage Materials'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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
          // Create Inventory Item Form
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Add Inventory Item'),
                      Tab(text: 'View Items'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Add Inventory Item Tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              // Material dropdown with add button
                              Row(
                                children: [
                                  Expanded(
                                    child: StreamBuilder<List<material_model.Material>>(
                                      stream: _repository.streamAllMaterials(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return DropdownButtonFormField<String>(
                                            decoration: const InputDecoration(
                                              labelText: 'Material',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: const [],
                                            onChanged: null,
                                          );
                                        }

                                        final materials = snapshot.data ?? [];
                                        return DropdownButtonFormField<String>(
                                          value: _selectedMaterialId,
                                          decoration: const InputDecoration(
                                            labelText: 'Material',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.shopping_bag),
                                          ),
                                          items: materials
                                              .map((material) =>
                                                  DropdownMenuItem<String>(
                                                    value: material.materialId,
                                                    child: Text(material.name),
                                                  ))
                                              .toList(),
                                          onChanged: _isLoading
                                              ? null
                                              : (value) {
                                                  setState(() =>
                                                      _selectedMaterialId = value);
                                                },
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _isLoading ? null : _showCreateMaterialDialog,
                                    icon: const Icon(Icons.add_circle),
                                    tooltip: 'Add New Material',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Location dropdown
                              StreamBuilder<List<Location>>(
                                stream: _repository.streamAllLocations(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Location',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [],
                                      onChanged: null,
                                    );
                                  }

                                  final locations = snapshot.data ?? [];
                                  return DropdownButtonFormField<String>(
                                    value: _selectedLocationId,
                                    decoration: const InputDecoration(
                                      labelText: 'Location',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.location_on),
                                    ),
                                    items: locations
                                        .map((location) =>
                                            DropdownMenuItem<String>(
                                              value: location.locationId,
                                              child: Text(location.name),
                                            ))
                                        .toList(),
                                    onChanged: _isLoading
                                        ? null
                                        : (value) {
                                            setState(() =>
                                                _selectedLocationId = value);
                                          },
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              // Quantity input
                              TextField(
                                controller: _quantityController,
                                enabled: !_isLoading,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.inventory_2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Reserved Quantity input
                              TextField(
                                controller: _reservedQuantityController,
                                enabled: !_isLoading,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Reserved Quantity',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Low Stock Threshold input
                              TextField(
                                controller: _lowStockThresholdController,
                                enabled: !_isLoading,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Low Stock Threshold',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.warning),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Status dropdown
                              AbsorbPointer(
                                absorbing: _isLoading,
                                child: DropdownButtonFormField<InventoryStatus>(
                                  initialValue: _selectedStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.check_circle),
                                  ),
                                  items: InventoryStatus.values
                                      .map((status) => DropdownMenuItem(
                                            value: status,
                                            child: Text(
                                                _statusDisplayName(status)),
                                          ))
                                      .toList(),
                                  onChanged: (status) {
                                    if (status != null) {
                                      setState(() => _selectedStatus = status);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Create button
                              FilledButton(
                                onPressed:
                                    _isLoading ? null : _addInventoryItem,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text('Add Inventory Item'),
                              ),
                            ],
                          ),
                        ),

                        // View Items Tab
                        StreamBuilder<List<InventoryItem>>(
                          stream: _repository.streamInventoryItems(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            final items = snapshot.data ?? [];
                            if (items.isEmpty) {
                              return const Center(
                                child: Text('No inventory items found'),
                              );
                            }

                            // Group items by status
                            final groupedItems = _groupItemsByStatus(items);
                            final displayItems = _buildGroupedList(groupedItems);

                            return ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: displayItems.length,
                              itemBuilder: (context, index) {
                                final item = displayItems[index];
                                
                                if (item is String) {
                                  // This is a header
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                    child: Text(
                                      item,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  );
                                }
                                
                                // This is an inventory item
                                final inventoryItem = item as InventoryItem;
                                return FutureBuilder<
                                    Map<String, String?>>(
                                  future: Future.wait([
                                    _repository
                                        .getMaterial(inventoryItem.materialId)
                                        .then((m) => m?.name ?? 'Unknown'),
                                    _repository
                                        .getLocation(inventoryItem.locationId)
                                        .then((l) => l?.name ?? 'Unknown'),
                                  ]).then((results) => {
                                    'material': results[0],
                                    'location': results[1],
                                  }),
                                  builder: (context, nameSnapshot) {
                                    final materialName =
                                        nameSnapshot.data?['material'] ??
                                            'Loading...';
                                    final locationName =
                                        nameSnapshot.data?['location'] ??
                                            'Loading...';

                                    return Card(
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              inventoryItem.availableQuantity == 0
                                                  ? Colors.red
                                                  : inventoryItem.availableQuantity <=
                                                          inventoryItem.lowStockThreshold
                                                      ? Colors.yellow[700]
                                                      : Colors.green,
                                          child: Icon(
                                            inventoryItem.availableQuantity == 0
                                                ? Icons.close
                                                : inventoryItem.availableQuantity <=
                                                        inventoryItem.lowStockThreshold
                                                    ? Icons.warning
                                                    : Icons.check_circle,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(materialName),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Location: $locationName',
                                              style: const TextStyle(
                                                  fontSize: 12),
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Qty: ${inventoryItem.quantity.toStringAsFixed(2)} | Reserved: ${inventoryItem.reservedQuantity.toStringAsFixed(2)} | Available: ${inventoryItem.availableQuantity.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        fontSize: 11),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 100,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.remove),
                                                        iconSize: 28,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        onPressed: () =>
                                                            _decrementQuantity(
                                                                inventoryItem),
                                                      ),
                                                      IconButton(
                                                        icon:
                                                            const Icon(Icons.add),
                                                        iconSize: 28,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        onPressed: () =>
                                                            _incrementQuantity(
                                                                inventoryItem),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              'Threshold: ${inventoryItem.lowStockThreshold.toStringAsFixed(2)} | Status: ${_statusDisplayName(inventoryItem.status)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
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
                                                        () => _editInventoryItem(inventoryItem),
                                                      ),
                                                ),
                                                PopupMenuItem(
                                                  child: const Text('Delete'),
                                                  onTap: () =>
                                                      Future.delayed(
                                                        const Duration(milliseconds: 100),
                                                        () => _deleteInventoryItem(
                                                            inventoryItem.inventoryItemId),
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}