import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../providers/menu_provider.dart';

class MenuFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? item;
  const MenuFormScreen({super.key, this.item});

  @override
  ConsumerState<MenuFormScreen> createState() => _MenuFormScreenState();
}

class _MenuFormScreenState extends ConsumerState<MenuFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descController;
  int? _categoryId;
  bool _isAvailable = true;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?['name'] ?? '');
    _priceController = TextEditingController(text: widget.item?['price']?.toString() ?? '');
    _descController = TextEditingController(text: widget.item?['description'] ?? '');
    _categoryId = widget.item?['category_id'];
    _isAvailable = widget.item?['is_available'] ?? true;

    Future.microtask(() => ref.read(menuProvider.notifier).loadCategories());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn danh mục')));
      return;
    }

    final data = {
      'name': _nameController.text,
      'price': double.parse(_priceController.text),
      'description': _descController.text,
      'category_id': _categoryId,
      'is_available': _isAvailable,
    };

    final success = await ref.read(menuProvider.notifier).saveItem(data, id: widget.item?['id']);
    if (success && mounted) context.pop();
  }

  Future<void> _pickImage() async {
    if (!isEditing) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (file != null) {
      await ref.read(menuProvider.notifier).uploadImage(widget.item!['id'], file.path);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hình ảnh')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Sửa món' : 'Thêm món')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isEditing)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 40, color: AppTheme.primaryColor),
                        SizedBox(height: 8),
                        Text('Nhấn để chọn ảnh', style: TextStyle(color: AppTheme.primaryColor)),
                      ],
                    ),
                  ),
                ),
              if (isEditing) const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Danh mục'),
                items: menuState.categories.map((cat) => DropdownMenuItem(value: cat['id'] as int, child: Text(cat['name']))).toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Chọn danh mục' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Tên món'), validator: (v) => Validators.required(v, 'Tên món')),
              const SizedBox(height: 16),
              TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'Giá (VNĐ)', prefixText: '₫ '), keyboardType: TextInputType.number, validator: (v) => Validators.positiveNumber(v, 'Giá')),
              const SizedBox(height: 16),
              TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Mô tả'), maxLines: 3),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Còn hàng'),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                activeThumbColor: AppTheme.successColor,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _save, child: Text(isEditing ? 'Cập nhật' : 'Thêm món')),
            ],
          ),
        ),
      ),
    );
  }
}
