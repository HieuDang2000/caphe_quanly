import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/menu_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart';

class MenuListScreen extends ConsumerStatefulWidget {
  const MenuListScreen({super.key});

  @override
  ConsumerState<MenuListScreen> createState() => _MenuListScreenState();
}

class _MenuListScreenState extends ConsumerState<MenuListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(menuProvider.notifier).loadCategories();
      ref.read(menuProvider.notifier).loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Quản lý danh mục',
            onPressed: () => _showCategoryDialog(),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/menu/form'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: menuState.selectedCategoryId == null,
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(color: menuState.selectedCategoryId == null ? Colors.white : null),
                    onSelected: (_) => ref.read(menuProvider.notifier).loadItems(),
                  ),
                ),
                ...menuState.categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat['name']),
                    selected: menuState.selectedCategoryId == cat['id'],
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(color: menuState.selectedCategoryId == cat['id'] ? Colors.white : null),
                    onSelected: (_) => ref.read(menuProvider.notifier).loadItems(categoryId: cat['id']),
                  ),
                )),
              ],
            ),
          ),
          Expanded(
            child: menuState.isLoading
                ? const LoadingWidget()
                : menuState.items.isEmpty
                    ? const Center(child: Text('Chưa có món nào'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: menuState.items.length,
                        itemBuilder: (_, index) {
                          final item = menuState.items[index];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                child: const Icon(Icons.restaurant, color: AppTheme.primaryColor),
                              ),
                              title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(item['category']?['name'] ?? ''),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(Formatters.currency(item['price'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                  if (item['is_available'] == false)
                                    const Text('Hết hàng', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
                                ],
                              ),
                              onTap: () => context.push('/menu/form', extra: item),
                              onLongPress: () => _confirmDelete(item),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final nameController = TextEditingController(text: category?['name'] ?? '');
    final descController = TextEditingController(text: category?['description'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(category == null ? 'Thêm danh mục' : 'Sửa danh mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên danh mục')),
            const SizedBox(height: 12),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Mô tả')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(menuProvider.notifier).saveCategory(
                {'name': nameController.text, 'description': descController.text},
                id: category?['id'],
              );
              if (success && mounted) Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa món'),
        content: Text('Bạn có chắc muốn xóa "${item['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              ref.read(menuProvider.notifier).deleteItem(item['id']);
              Navigator.pop(context);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
