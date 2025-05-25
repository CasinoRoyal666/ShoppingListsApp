// shopping_lists_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../screens/account_screen.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({Key? key}) : super(key: key);

  @override
  _ShoppingListsScreenState createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createNewList(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isCreating = false; // Флаг для отслеживания состояния создания

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Создать новый список'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Название списка',
                        hintText: 'Например: Продукты на неделю',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Описание (необязательно)',
                        hintText: 'Например: Покупки на выходные',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null // Блокируем кнопку во время создания
                      : () {
                    Navigator.of(context).pop();
                    _titleController.clear();
                    _descriptionController.clear();
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null // Блокируем кнопку во время создания
                      : () async {
                    if (_titleController.text.trim().isNotEmpty) {
                      // Устанавливаем флаг, что начали создание
                      setState(() {
                        isCreating = true;
                      });

                      try {
                        final newList = ShoppingList(
                          title: _titleController.text.trim(),
                          description: _descriptionController.text.trim().isNotEmpty
                              ? _descriptionController.text.trim()
                              : null,
                          userId: currentUser!.uid,
                        );

                        await _firebaseService.createShoppingList(newList);

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          _titleController.clear();
                          _descriptionController.clear();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Список создан')),
                          );
                        }
                      } catch (e) {
                        // Если произошла ошибка, снимаем блокировку
                        if (context.mounted) {
                          setState(() {
                            isCreating = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка при создании списка: $e')),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Введите название списка')),
                      );
                    }
                  },
                  child: isCreating
                      ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Создание...'),
                    ],
                  )
                      : const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои списки покупок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/account');
            },
            tooltip: 'Мой аккаунт',
          ),
          IconButton(
            icon: const Icon(Icons.pie_chart),
            onPressed: () {
              Navigator.pushNamed(context, '/spending_analysis');
            },
            tooltip: 'Анализ расходов',
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              Navigator.pushNamed(context, '/categories');
            },
            tooltip: 'Категории',
          ),
        ],
      ),
      body: StreamBuilder<List<ShoppingList>>(
        stream: _firebaseService.getShoppingLists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка: ${snapshot.error}'),
            );
          }

          final lists = snapshot.data ?? [];

          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_basket, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'У вас пока нет списков покупок',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _createNewList(context),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Создать список'),
                  ),
                ],
              ),
            );
          }

          // Определяем ориентацию экрана
          final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

          // Адаптивная сетка для отображения списков
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: isLandscape
                ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: lists.length,
              itemBuilder: (context, index) {
                return _buildShoppingListCard(context, lists[index]);
              },
            )
                : ListView.builder(
              itemCount: lists.length,
              itemBuilder: (context, index) {
                return _buildShoppingListCard(context, lists[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewList(context),
        tooltip: 'Создать новый список',
        icon: const Icon(Icons.add),
        label: const Text('Новый список'),
      ),
    );
  }

  Widget _buildShoppingListCard(BuildContext context, ShoppingList list) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Определяем цвет и иконку в зависимости от статуса списка
    final Color statusColor = list.isCompleted
        ? Colors.green.shade400
        : colorScheme.primary;

    final Icon statusIcon = Icon(
      list.isCompleted ? Icons.task_alt : Icons.shopping_cart_outlined,
      color: Colors.white,
      size: 24,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: list.isCompleted
            ? BorderSide(color: Colors.green.shade200, width: 1)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/list_details',
            arguments: list.id,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Верхняя полоса с иконкой статуса
            Container(
              height: 8,
              color: statusColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Иконка списка
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: statusIcon),
                  ),
                  const SizedBox(width: 16),

                  // Основная информация
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                list.title,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  decoration: list.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildIconButton(
                                  Icons.edit_outlined,
                                  colorScheme.primary,
                                      () => _editList(context, list),
                                ),
                                _buildIconButton(
                                  Icons.delete_outline,
                                  Colors.red.shade400,
                                      () => _deleteList(context, list),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (list.description != null && list.description!.isNotEmpty)
                          Text(
                            list.description!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Дата создания
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(list.createdAt),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),

                            // Статус или метка
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: list.isCompleted
                                    ? Colors.green.shade100
                                    : colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                list.isCompleted ? 'Завершен' : 'Активен',
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: list.isCompleted
                                      ? Colors.green.shade700
                                      : colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(left: 4),
      child: IconButton(
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        color: color,
        onPressed: onPressed,
        tooltip: icon == Icons.edit_outlined ? 'Редактировать' : 'Удалить',
      ),
    );
  }

  void _editList(BuildContext context, ShoppingList list) {
    _titleController.text = list.title;
    _descriptionController.text = list.description ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isCompleted = list.isCompleted;

        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Редактировать список'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Название списка',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Описание (необязательно)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Список завершен'),
                        value: isCompleted,
                        onChanged: (value) {
                          setState(() {
                            isCompleted = value;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _titleController.clear();
                      _descriptionController.clear();
                    },
                    child: const Text('Отмена'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_titleController.text.trim().isNotEmpty) {
                        final updatedList = list.copyWith(
                          title: _titleController.text.trim(),
                          description: _descriptionController.text.trim().isNotEmpty
                              ? _descriptionController.text.trim()
                              : null,
                          isCompleted: isCompleted,
                        );

                        await _firebaseService.updateShoppingList(updatedList);

                        Navigator.of(context).pop();
                        _titleController.clear();
                        _descriptionController.clear();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Список обновлен')),
                        );
                      }
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  void _deleteList(BuildContext context, ShoppingList list) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isDeleting = false; // Флаг, указывающий на процесс удаления

        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Удалить список'),
                content: Text(
                  'Вы уверены, что хотите удалить список "${list.title}"? '
                      'Это действие нельзя отменить.',
                ),
                actions: [
                  TextButton(
                    onPressed: isDeleting
                        ? null // Блокируем кнопку во время удаления
                        : () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Отмена'),
                  ),
                  ElevatedButton(
                    onPressed: isDeleting
                        ? null // Блокируем кнопку во время удаления
                        : () async {
                      // Устанавливаем флаг, что начали удаление
                      setState(() {
                        isDeleting = true;
                      });

                      try {
                        await _firebaseService.deleteShoppingList(list.id!);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Список удален')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          // Если произошла ошибка, снимаем блокировку
                          setState(() {
                            isDeleting = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка при удалении: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: isDeleting
                        ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Удаление...'),
                      ],
                    )
                        : const Text('Удалить'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}