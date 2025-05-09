import 'package:flutter/material.dart';
import 'package:monit/backend/product.dart';
import 'package:monit/models/product.dart';
import 'package:monit/models/user.dart';
import 'package:monit/providers/product_provider.dart';
import 'package:monit/widgets/appbar.dart';
import 'package:monit/widgets/card.dart';
import 'package:monit/widgets/purchase_product.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  final bool keepAlive;

  const DashboardScreen({
    super.key,
    this.keepAlive = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, List<Product>> _categorizedProducts = {};
  List<String> _categories = [];

  // Override wantKeepAlive getter to maintain state
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    // print('DashboardScreen: initState called - fetching products');
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final productDb = ProductDatabase();
      final products = await productDb.getProducts();
      if (!mounted) return;
      productDb.getUserSelectedProducts(context);

      // Group products by category
      final categorizedProducts = <String, List<Product>>{};
      for (var product in products) {
        if (!categorizedProducts.containsKey(product.category)) {
          categorizedProducts[product.category] = [];
        }
        categorizedProducts[product.category]!.add(product);
      }

      // Sort categories alphabetically
      final categories = categorizedProducts.keys.toList()..sort();

      if (mounted) {
        setState(() {
          _categorizedProducts = categorizedProducts;
          _categories = categories;
          _isLoading = false;
          // Initialize tab controller after we know how many categories we have
          _tabController = TabController(length: categories.length, vsync: this);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_categories.isNotEmpty) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make sure to call super.build for AutomaticKeepAliveClientMixin
    super.build(context);

    // Get the child model from the provider
    final childModel = Provider.of<ChildModel>(context);

    // If categories are empty, show loading or empty state
    if (_categories.isEmpty && _isLoading) {
      return Scaffold(
        appBar: customAppBar(context, 'Monit', childModel),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: customAppBar(context, 'Monit', childModel),
      body: _categories.isEmpty
          ? const Center(child: Text('No products available'))
          : Column(
              children: [
                // Tab Bar for Categories
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.blue.shade700,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue.shade700,
                  tabs: _categories.map((category) => Tab(text: category)).toList(),
                ),

                // Tab Bar View with Products
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _categories.map((category) {
                      final categoryProducts = _categorizedProducts[category] ?? [];
                      return _buildProductGrid(categoryProducts);
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    return products.isEmpty
        ? const Center(child: Text('No products in this category'))
        : Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Center(
                child: Wrap(
                  spacing: 16, // horizontal spacing between cards
                  runSpacing: 16, // vertical spacing between rows
                  alignment: WrapAlignment.center, // Center items horizontally
                  children: products.map((product) {
                    // No SizedBox wrapper - let the ProductCard control its own size
                    return ProductCard(
                      product: product,
                      onTap: () {
                        // Get the ProductProvider without modifying it yet
                        final productProvider = Provider.of<ProductProvider>(context, listen: false);
                        showProductDetailsDialog(product, productProvider, context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          );
  }
}
