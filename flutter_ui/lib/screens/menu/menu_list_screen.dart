import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/menu_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/responsive_layout.dart';

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
    final mobile = isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Quản lý danh mục',
            onPressed: () => _showCategoryManagement(),
          ),
        ],
      ),
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
                    labelStyle: TextStyle(
                      color: menuState.selectedCategoryId == null
                          ? Colors.white
                          : null,
                    ),
                    onSelected: (_) =>
                        ref.read(menuProvider.notifier).loadItems(),
                  ),
                ),
                ...menuState.categories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat['name']),
                      selected: menuState.selectedCategoryId == cat['id'],
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: menuState.selectedCategoryId == cat['id']
                            ? Colors.white
                            : null,
                      ),
                      onSelected: (_) => ref
                          .read(menuProvider.notifier)
                          .loadItems(categoryId: cat['id']),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: menuState.isLoading
                ? const LoadingWidget()
                : menuState.items.isEmpty
                ? const Center(child: Text('Chưa có món nào'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final crossAxisCount = w < kMobileMaxWidth
                          ? 2
                          : (w / 200).floor().clamp(3, 6);

                      return GridView.builder(
                        padding: EdgeInsets.all(mobile ? 8 : 12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 200 / 150,
                        ),
                        itemCount: menuState.items.length,
                        itemBuilder: (_, index) {
                          final item = menuState.items[index];
                          final name = item['name']?.toString() ?? '';
                          final categoryName =
                              item['category']?['name']?.toString() ?? '';
                          final isAvailable = item['is_available'] != false;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                context.push('/menu/form', extra: item),
                            onLongPress: () => _confirmDelete(item),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          child: const Icon(
                                            Icons.restaurant,
                                            color: AppTheme.primaryColor,
                                            size: 18,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (!isAvailable)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.errorColor
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Hết hàng',
                                              style: TextStyle(
                                                color: AppTheme.errorColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      categoryName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.payments_outlined,
                                          size: 16,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          Formatters.currency(
                                            item['price'] ?? 0,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                            fontSize: 15,
                                          ),
                                        ),
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
                  ),
          ),
        ],
      ),
    );
  }

  void _showCategoryManagement() {
    final menuState = ref.read(menuProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quản lý danh mục',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCategoryDialog();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm danh mục'),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: menuState.categories.length,
                itemBuilder: (_, index) {
                  final cat = menuState.categories[index];
                  final count = cat['menu_items_count'] as int?;
                  return ListTile(
                    title: Text(cat['name'] ?? ''),
                    subtitle: count != null ? Text('$count món') : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            Navigator.pop(context);
                            _showCategoryDialog(category: cat);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: AppTheme.errorColor,
                          ),
                          onPressed: () {
                            _confirmDeleteCategory(cat);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final nameController = TextEditingController(text: category?['name'] ?? '');
    final descController = TextEditingController(
      text: category?['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(category == null ? 'Thêm danh mục' : 'Sửa danh mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ref
                  .read(menuProvider.notifier)
                  .saveCategory({
                    'name': nameController.text,
                    'description': descController.text,
                  }, id: category?['id']);
              if (success && mounted) Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Map<String, dynamic> category) {
    final count = category['menu_items_count'] as int? ?? 0;
    final nav = Navigator.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa danh mục'),
        content: Text(
          count > 0
              ? 'Danh mục "${category['name']}" có $count món. Xóa danh mục sẽ xóa luôn tất cả món trong đó. Bạn có chắc muốn xóa?'
              : 'Bạn có chắc muốn xóa danh mục "${category['name']}"?',
        ),
        actions: [
          TextButton(onPressed: () => nav.pop(), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              nav.pop();
              final success = await ref
                  .read(menuProvider.notifier)
                  .deleteCategory(Formatters.toNum(category['id']).toInt());
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa danh mục')),
                );
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa món'),
        content: Text('Bạn có chắc muốn xóa "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () async {
              final success = await ref
                  .read(menuProvider.notifier)
                  .deleteItem(Formatters.toNum(item['id']).toInt());
              if (mounted) {
                Navigator.pop(dialogContext);
                if (success) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Đã xóa món')));
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
