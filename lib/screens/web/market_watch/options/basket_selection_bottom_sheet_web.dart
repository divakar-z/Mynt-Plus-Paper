import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/marketwatch_model/opt_chain_model.dart';
import '../../../../provider/order_provider.dart';
import '../../../../provider/thems.dart';
import '../../../../res/res.dart';
import '../../../../sharedWidget/custom_drag_handler.dart';

class BasketSelectionBottomSheet extends ConsumerStatefulWidget {
  final OptionValues selectedOptions;
  final Function(String) onBasketSelected;

  const BasketSelectionBottomSheet({
    super.key,
    required this.selectedOptions,
    required this.onBasketSelected,
  });

  @override
  ConsumerState<BasketSelectionBottomSheet> createState() =>
      _BasketSelectionBottomSheetState();
}

class _BasketSelectionBottomSheetState
    extends ConsumerState<BasketSelectionBottomSheet> {
  List<String> availableBaskets = [];
  bool isLoading = true;
  final TextEditingController _basketNameController = TextEditingController();
  bool showCreateForm = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableBaskets();
  }

  @override
  void dispose() {
    _basketNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableBaskets() async {
    try {
      final orderProv = ref.read(orderProvider);
      
      // Ensure basket data is loaded
      await orderProv.getBasketName();
      
      // Get basket names from the order provider
      final baskets = orderProv.bsktList.map<String>((basket) => basket['bsketName'].toString()).toList();
      
      setState(() {
        availableBaskets = baskets;
        isLoading = false;
        
        // Show create form if no baskets exist
        if (baskets.isEmpty) {
          showCreateForm = true;
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        showCreateForm = true;
      });
    }
  }

  Future<void> _createNewBasket() async {
    if (_basketNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a basket name'),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    final basketName = _basketNameController.text.trim();
    
    // Check if basket already exists
    if (availableBaskets.contains(basketName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Basket "$basketName" already exists'),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    try {
      final orderProv = ref.read(orderProvider);
      
      // Create basket using existing method
      await orderProv.createBasketOrder(basketName, context);
      
      // Refresh the baskets list
      await _loadAvailableBaskets();
      
      setState(() {
        showCreateForm = false;
        _basketNameController.clear();
      });
      
      // Automatically select the newly created basket
      widget.onBasketSelected(basketName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create basket: $e'),
          backgroundColor: colors.error,
        ),
      );
    }
  }

  /// Gets the appropriate color for basket status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placing':
        return colors.primaryLight;
      case 'placed':
      case 'completed':
        return colors.ltpgreen;
      case 'failed':
      case 'error':
        return colors.darkred;
      case 'partial':
      case 'partially_placed':
      case 'partially_filled':
      case 'partially_completed':
        return Colors.orange;
      default:
        return colors.colorGrey;
    }
  }

  /// Shows basket management options
  void _showBasketManagementOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Manage All Baskets'),
              onTap: () {
                Navigator.pop(context); // Close options
                Navigator.pop(context); // Close basket selection
                // Navigate to basket management screen
                Navigator.pushNamed(context, '/basket-management');
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Refresh Baskets'),
              onTap: () {
                Navigator.pop(context);
                _loadAvailableBaskets();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Basket Help'),
              onTap: () {
                Navigator.pop(context);
                _showBasketHelp();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows detailed basket status information
  void _showBasketStatusDetails(String basketName, String status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Basket Status: $basketName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_getStatusDescription(status)),
            const SizedBox(height: 8),
            if (status.toLowerCase() != 'completed' && status.toLowerCase() != 'failed')
              Text(
                'You can reset this basket to place orders again.',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondaryLight,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (status.toLowerCase() != 'placing')
            TextButton(
              onPressed: () {
                final orderProv = ref.read(orderProvider);
                orderProv.resetBasketOrderTracking(basketName);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Basket "$basketName" has been reset'),
                    backgroundColor: colors.ltpgreen,
                  ),
                );
              },
              child: const Text('Reset Basket'),
            ),
        ],
      ),
    );
  }

  /// Gets description for basket status
  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'placing':
        return 'Orders are currently being placed...';
      case 'placed':
        return 'All orders have been successfully placed.';
      case 'completed':
        return 'All orders have been executed successfully.';
      case 'failed':
        return 'Order placement failed. You can reset and try again.';
      case 'partially_placed':
        return 'Some orders were placed successfully, others failed.';
      case 'partially_filled':
        return 'Some orders have been filled, others are still pending.';
      case 'partially_completed':
        return 'Some orders completed, others were rejected.';
      default:
        return 'Basket is ready for order placement.';
    }
  }

  /// Shows basket help information
  void _showBasketHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Basket Help'),
        content: const Text(
          'Baskets allow you to group multiple options and place orders together.\n\n'
          '• Create baskets to organize your trades\n'
          '• Add up to 20 options per basket\n'
          '• Place all orders at once\n'
          '• Track order status for each basket\n'
          '• Reset baskets to place orders again',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.read(themeProvider);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: theme.isDarkMode ? colors.colorBlack : colors.colorWhite,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CustomDragHandler(),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Basket',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                    ),
                  ),
                ),
                // Quick Actions
                if (availableBaskets.isNotEmpty) ...[
                  IconButton(
                    onPressed: () => _showBasketManagementOptions(context),
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                    ),
                    tooltip: 'Basket Options',
                  ),
                ],
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                  ),
                ),
              ],
            ),
          ),
          
          // Selected options info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.isDarkMode ? colors.colorGrey.withOpacity(0.1) : colors.colorGrey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                ),
                const SizedBox(width: 8),
                Text(
                  'option selected',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                  ),
                ),
              ],
            ),
          ),
          
          // Loading state
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          
          // Create basket form
          else if (showCreateForm) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    availableBaskets.isEmpty ? 'No baskets found. Create your first basket:' : 'Create new basket:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _basketNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter basket name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _createNewBasket(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              showCreateForm = false;
                              _basketNameController.clear();
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _createNewBasket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                          ),
                          child: const Text(
                            'Create',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]
          
          // Basket list
          else ...[
            // Create new basket button
            if (availableBaskets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        showCreateForm = true;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Basket'),
                  ),
                ),
              ),
            
            // Available baskets
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: availableBaskets.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final basketName = availableBaskets[index];
                  final orderProv = ref.read(orderProvider);
                  final basketStatus = orderProv.getBasketStatus(basketName);
                  final basketData = orderProv.bsktList.firstWhere(
                    (basket) => basket['bsketName'] == basketName,
                    orElse: () => {'curLength': '0', 'max': '20'},
                  );
                  
                  return ListTile(
                    leading: Stack(
                      children: [
                        Icon(
                          Icons.folder,
                          color: colors.primary,
                          size: 24,
                        ),
                        if (basketStatus != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getStatusColor(basketStatus),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            basketName,
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                            ),
                          ),
                        ),
                        if (basketStatus != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(basketStatus).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              basketStatus.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getStatusColor(basketStatus),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      'Items: ${basketData['curLength']}/${ref.read(orderProvider).basketMaxOrders}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.isDarkMode ? colors.textSecondaryDark : colors.textSecondaryLight,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (basketStatus != null && basketStatus != 'ready')
                          IconButton(
                            onPressed: () => _showBasketStatusDetails(basketName, basketStatus),
                            icon: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                            ),
                          ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.isDarkMode ? colors.colorWhite : colors.colorBlack,
                        ),
                      ],
                    ),
                    onTap: () {
                      widget.onBasketSelected(basketName);
                    },
                  );
                },
              ),
            ),
          ],
          
          // Bottom padding for safe area
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}