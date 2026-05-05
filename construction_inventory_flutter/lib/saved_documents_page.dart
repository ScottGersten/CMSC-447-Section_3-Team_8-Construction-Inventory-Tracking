import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'models/packing_slip_item.dart';
import 'models/purchase_order.dart';
import 'repositories/firestore_repository.dart';

class SavedDocumentsPage extends StatefulWidget {
  const SavedDocumentsPage({super.key, required this.currentUser});

  final AppUser? currentUser;

  @override
  State<SavedDocumentsPage> createState() => _SavedDocumentsPageState();
}

class _SavedDocumentsPageState extends State<SavedDocumentsPage> {
  final _repository = FirestoreRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved Documents'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.description), text: 'Purchase Orders'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Packing Slips'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPurchaseOrderTab(),
            _buildPackingSlipTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderTab() {
    return StreamBuilder<List<PurchaseOrder>>(
      stream: _repository.streamPurchaseOrders(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading purchase orders: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(child: Text('No saved purchase orders yet.'));
        }

        return ListView.separated(
          itemCount: orders.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final order = orders[index];
            return ListTile(
              title: Text(order.poNumber),
              subtitle: Text(
                'Ordered: ${_formatDate(order.orderDate)}\nExpected: ${_formatDate(order.expectedDeliveryDate)}',
              ),
              isThreeLine: true,
              trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchaseOrderDetailPage(purchaseOrder: order),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPackingSlipTab() {
    return StreamBuilder<List<PackingSlipItem>>(
      stream: _repository.streamPackingSlipItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading packing slip items: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No parsed packing slip items yet.'));
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item.rawDescription),
              subtitle: Text(
                'Qty: ${item.quantityListed} ${item.unitOfMeasure} • Delivery ${item.deliveryId}',
              ),
              trailing: item.isManuallyVerified
                  ? const Chip(label: Text('Verified'), avatar: Icon(Icons.check, size: 18))
                  : item.requiresReview
                      ? TextButton(
                          child: const Text('Verify'),
                          onPressed: () => _verifyPackingSlipItem(item.packingSlipItemId),
                        )
                      : const Chip(label: Text('Auto OK')),
              isThreeLine: false,
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _verifyPackingSlipItem(String itemId) async {
    try {
      await _repository.markPackingSlipItemVerified(itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Packing slip item marked verified.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not verify item: $e')),
      );
    }
  }
}

class PurchaseOrderDetailPage extends StatelessWidget {
  const PurchaseOrderDetailPage({super.key, required this.purchaseOrder});

  final PurchaseOrder purchaseOrder;

  @override
  Widget build(BuildContext context) {
    final repository = FirestoreRepository();
    return Scaffold(
      appBar: AppBar(
        title: Text('Order ${purchaseOrder.poNumber}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${purchaseOrder.poId}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('Status: ${_statusDisplay(purchaseOrder.status)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Order date: ${_formatDate(purchaseOrder.orderDate)}'),
            Text('Expected delivery: ${_formatDate(purchaseOrder.expectedDeliveryDate)}'),
            if (purchaseOrder.pdfStoragePath != null) ...[
              const SizedBox(height: 8),
              Text('PDF: ${purchaseOrder.pdfStoragePath}'),
            ],
            const SizedBox(height: 16),
            const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<PurchaseOrderItem>>(
                future: repository.getPurchaseOrderItems(purchaseOrder.poId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading items: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('No items found for this order.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item.materialId),
                        subtitle: Text('Qty: ${item.quantityOrdered} • Unit cost: \$${item.unitCost.toStringAsFixed(2)}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusDisplay(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.fulfilled:
        return 'Fulfilled';
      case PurchaseOrderStatus.partiallyFulfilled:
        return 'Partially Fulfilled';
      default:
        return 'Pending';
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}
