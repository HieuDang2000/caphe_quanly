import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/layout_provider.dart';
import '../../providers/menu_provider.dart';
import '../../widgets/responsive_layout.dart';
import 'order_table_selector.dart';
import 'order_menu_picker.dart';
import 'order_cart_bar.dart';

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(layoutProvider.notifier).loadFloors();
      ref.read(menuProvider.notifier).loadCategories();
      ref.read(menuProvider.notifier).loadItems();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Theme.of(context).primaryColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(icon: Icon(Icons.table_restaurant), text: 'Chọn bàn'),
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Chọn món'),
              ],
            ),
          ),
          Expanded(
            child: mobile
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      OrderTableSelector(
                        onNavigateToMenu: () => _tabController.animateTo(1),
                      ),
                      const OrderMenuPicker(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            OrderTableSelector(
                              onNavigateToMenu: () => _tabController.animateTo(1),
                            ),
                            const OrderMenuPicker(),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 360,
                        child: OrderCartBar(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: mobile ? const OrderCartBar(isBottomBar: true) : null,
    );
  }
}
