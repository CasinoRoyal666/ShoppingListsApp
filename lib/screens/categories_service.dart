// categories_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'dart:math';
import 'package:flutter_slidable/flutter_slidable.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _nameController = TextEditingController();
  String _selectedColor = '#FF9800'; // Default color (Orange)

  // Предопределенные цвета для выбора
  final List<ColorOption> _colorOptions = [
    ColorOption('#FF9800', 'Оранжевый'),
    ColorOption('#F44336', 'Красный'),
    ColorOption('#4CAF50', 'Зеленый'),
    ColorOption('#2196F3', 'Синий'),
    ColorOption('#9C27B0', 'Фиолетовый'),
    ColorOption('#FFEB3B', 'Желтый'),
    ColorOption('#795548', 'Коричневый'),
    ColorOption('#607D8B', 'Серый'),
    ColorOption('#000000', 'Черный'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Future<void> _createOrEditCategory(BuildContext context, [Category? existingCategory]) async {
    if (existingCategory != null) {
      _nameController.text = existingCategory.name;
      _selectedColor = existingCategory.color;
    } else {
      _nameController.clear();
      _selectedColor = _colorOptions[Random().nextInt(_colorOptions.length)].value;
    }

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existingCategory == null ? 'Новая категория' : 'Редактировать категорию'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Название категории',
                        hintText: 'Например: Овощи',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Выберите цвет категории:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _colorOptions.map((colorOption) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = colorOption.value;
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: _hexToColor(colorOption.value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == colorOption.value
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.trim().isNotEmpty) {
                      if (existingCategory == null) {
                        // Создаем новую категорию
                        final newCategory = Category(
                          name: _nameController.text.trim(),
                          color: _selectedColor,
                          userId: _firebaseService.currentUser!.uid,
                        );
                        await _firebaseService.createCategory(newCategory);
                      } else {
                        // Обновляем существующую категорию
                        final updatedCategory = Category(
                          id: existingCategory.id,
                          name: _nameController.text.trim(),
                          color: _selectedColor,
                          userId: existingCategory.userId,
                          createdAt: existingCategory.createdAt,
                        );
                        await _firebaseService.updateCategory(updatedCategory);
                      }
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existingCategory == null
                                ? 'Категория создана'
                                : 'Категория обновлена',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Введите название категории'),
                        ),
                      );
                    }
                  },
                  child: Text(existingCategory == null ? 'Создать' : 'Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategory(Category category) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Удалить категорию'),
          content: Text(
            'Вы уверены, что хотите удалить категорию "${category.name}"? '
                'Это действие не удалит товары, но они будут отображаться без категории.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _firebaseService.deleteCategory(category.id!);
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Категория удалена')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории товаров'),
      ),
      body: StreamBuilder<List<Category>>(
        stream: _firebaseService.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка: ${snapshot.error}'),
            );
          }

          final categories = snapshot.data ?? [];

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'У вас пока нет категорий',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Категории помогут вам организовать ваши покупки',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _createOrEditCategory(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать категорию'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Slidable(
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) => _createOrEditCategory(context, category),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                        label: 'Изменить',
                      ),
                      SlidableAction(
                        onPressed: (_) => _deleteCategory(category),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Удалить',
                      ),
                    ],
                  ),
                  child: Card(
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _hexToColor(category.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(category.name),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createOrEditCategory(context),
        tooltip: 'Добавить категорию',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ColorOption {
  final String value;
  final String name;

  ColorOption(this.value, this.name);
}