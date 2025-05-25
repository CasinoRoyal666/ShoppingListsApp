// list_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'dart:async';
import '../services/firebase_service.dart';


class ListDetailsScreen extends StatefulWidget {
  final String listId;
  const ListDetailsScreen({Key? key, required this.listId}) : super(key: key);

  @override
  _ListDetailsScreenState createState() => _ListDetailsScreenState();
}

class _ListDetailsScreenState extends State<ListDetailsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedUnit = 'шт';
  String? _selectedCategoryId;
  final List<String> _availableUnits = ['шт', 'кг', 'г', 'л', 'мл', 'уп'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _quantityError;
  String? _priceError;
  String _sortBy = 'default'; // 'default', 'name', 'price'
  bool _sortAscending = true;

  bool get _isFormValid {
    return _itemNameController.text.trim().isNotEmpty &&
        _quantityController.text.trim().isNotEmpty &&
        _priceController.text.trim().isNotEmpty &&
        (double.tryParse(_quantityController.text) ?? 0) > 0 &&
        (double.tryParse(_priceController.text) ?? 0) > 0;
  }

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    _priceController.text = '0';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firebaseService.fixItemsWithInvalidCategories(widget.listId);
    });
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _updateListTotalPrice(String listId) async {
    await _firebaseService.recalculateShoppingListTotalPrice(listId);
  }

  List<ShoppingItem> _filterAndSortItems(List<ShoppingItem> items) {
    var filteredItems = _searchQuery.isEmpty
        ? items
        : items.where((item) =>
        item.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    switch (_sortBy) {
      case 'name':
        filteredItems.sort((a, b) =>
        _sortAscending
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
            : b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'price':
        print('Sorting by price. Ascending: $_sortAscending');
        filteredItems.sort((a, b) =>
        _sortAscending
            ? (a.price * a.quantity).compareTo(b.price * b.quantity)
            : (b.price * b.quantity).compareTo(a.price * a.quantity));
        break;
      default:
        break;
    }

    return filteredItems;
  }

  Future<void> _addNewItem(BuildContext context, String listId) async {
    _selectedCategoryId = null;
    _selectedUnit = 'шт';
    _itemNameController.clear();
    _quantityController.text = '1';
    _priceController.text = '0';

    // Для хранения найденных товаров
    List<ShoppingItem> suggestedItems = [];
    Timer? _debounce;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isAdding = false;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Добавить товар'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _itemNameController,
                      decoration: const InputDecoration(
                        labelText: 'Название товара',
                        hintText: 'Например: Молоко',
                      ),
                      maxLength: 30, // Максимальная длина названия
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zа-яА-Я0-9\s]')),
                      ],
                      autofocus: true,
                        onChanged: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 400), () async {
                            if (value.trim().length >= 2) {
                              final items = await _firebaseService.searchItemsByName(value);
                              if (dialogContext.mounted) {
                                setState(() {
                                  suggestedItems = items;
                                });
                              }
                            } else {
                              // Also check here
                              if (dialogContext.mounted) {
                                setState(() {
                                  suggestedItems = [];
                                });
                              }
                            }
                          });
                        },
                    ),

                    // Отображаем подсказки
                    if (suggestedItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: 150,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestedItems.length,
                          itemBuilder: (context, index) {
                            final item = suggestedItems[index];
                            return ListTile(
                              dense: true,
                              title: Text(item.name),
                              subtitle: Text('₽${item.price.toStringAsFixed(2)} · ${item.quantity} ${item.unit}'),
                              onTap: () {
                                setState(() {
                                  _itemNameController.text = item.name;
                                  _priceController.text = item.price.toString();
                                  _selectedUnit = item.unit;
                                  _selectedCategoryId = item.categoryId;
                                  suggestedItems = []; // Очищаем подсказки после выбора
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              labelText: 'Количество',
                              errorText: _quantityError
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 7,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                final numValue = double.tryParse(value);
                                if (numValue == null || numValue <= 0 || numValue > 9999) {
                                  setState(() {
                                    _quantityError = 'от 0.01 до 9999';
                                  });
                                } else {
                                  setState(() {
                                    _quantityError = null;
                                  });
                                }
                              } else {
                                setState(() {
                                  _quantityError = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Ед. изм.',
                            ),
                            items: _availableUnits.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUnit = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Цена за единицу',
                        prefixText: '₽ ',
                        errorText: _priceError,
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      maxLength: 7,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final numValue = double.tryParse(value);
                          if (numValue == null || numValue <= 0 || numValue > 9999) {
                            setState(() {
                              _priceError = 'Введите корректную цену (0 < цена ≤ 9999)';
                            });
                          } else {
                            setState(() {
                              _priceError = null;
                            });
                          }
                        } else {
                          setState(() {
                            _priceError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Category>>(
                      future: _firebaseService.getCategories().first,  // Заменяем StreamBuilder на FutureBuilder
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }

                        final categories = snapshot.data ?? [];
                        final categoryIds = categories.map((c) => c.id).toList();

                        if (_selectedCategoryId != null && !categoryIds.contains(_selectedCategoryId)) {
                          _selectedCategoryId = null;
                        }

                        return DropdownButtonFormField<String?>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Категория (необязательно)',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Без категории'),
                            ),
                            ...categories.map((category) {
                              return DropdownMenuItem(
                                value: category.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(
                                            category.color.replaceAll(
                                                '#', '0xFF'))),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAdding
                      ? null
                      : () {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: _isFormValid
                      ? () async {
                    // Устанавливаем состояние загрузки
                    setState(() {
                      isAdding = true;
                    });

                    // Отменяем таймер при закрытии диалога
                    if (_debounce?.isActive ?? false) _debounce!.cancel();

                    try {
                      final quantity = double.tryParse(_quantityController.text) ?? 1;
                      final price = double.tryParse(_priceController.text) ?? 0.0;

                      final newItem = ShoppingItem(
                        name: _itemNameController.text.trim(),
                        quantity: quantity,
                        unit: _selectedUnit,
                        categoryId: _selectedCategoryId,
                        shoppingListId: listId,
                        price: price,
                      );

                      await _firebaseService.createShoppingItem(newItem);
                      await _updateListTotalPrice(listId);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      // В случае ошибки снимаем блокировку
                      if (dialogContext.mounted) {
                        setState(() {
                          isAdding = false;
                        });

                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Ошибка при добавлении товара: $e')),
                        );
                      }
                    }
                  }
                      : null,
                  child: isAdding
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
                      Text('Добавление...'),
                    ],
                  )
                      : const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Дополнительная страховка: отменяем таймер при закрытии диалога
      if (_debounce?.isActive ?? false) _debounce!.cancel();
    });
  }

// Аналогичные изменения нужно внести и в метод _editItem
  Future<void> _editItem(BuildContext context, ShoppingItem item) async {
    _itemNameController.text = item.name;
    _quantityController.text = item.quantity.toString();
    _priceController.text = item.price.toString();
    _selectedUnit = item.unit;

    final categoriesSnapshot = await _firebaseService
        .getCategories()
        .first;

    final validCategoryIds = categoriesSnapshot
        .map((category) => category.id)
        .whereType<String>()
        .toSet();

    _selectedCategoryId =
    (item.categoryId != null && validCategoryIds.contains(item.categoryId))
        ? item.categoryId
        : null;

    if (!mounted) return;

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isUpdating = false;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Редактировать товар'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _itemNameController,
                      decoration: const InputDecoration(
                        labelText: 'Название товара',
                      ),
                      maxLength: 30,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(
                            r'[a-zA-Zа-яА-Я0-9\s]')),
                      ],
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                                labelText: 'Количество',
                                errorText: _quantityError
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 7,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                final numValue = double.tryParse(value);
                                if (numValue == null || numValue <= 0 ||
                                    numValue > 9999) {
                                  setState(() {
                                    _quantityError = 'от 0.01 до 9999';
                                  });
                                } else {
                                  setState(() {
                                    _quantityError = null;
                                  });
                                }
                              } else {
                                setState(() {
                                  _quantityError = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Ед. изм.',
                            ),
                            items: _availableUnits.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUnit = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Цена за единицу',
                        prefixText: '₽ ',
                        errorText: _priceError,
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                          decimal: true),
                      maxLength: 7,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(
                            r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final numValue = double.tryParse(value);
                          if (numValue == null || numValue <= 0 ||
                              numValue > 9999) {
                            setState(() {
                              _priceError =
                              'Введите корректную цену (0 < цена ≤ 9999)';
                            });
                          } else {
                            setState(() {
                              _priceError = null;
                            });
                          }
                        } else {
                          setState(() {
                            _priceError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Category>>(
                      future: _firebaseService
                          .getCategories()
                          .first, // Заменяем StreamBuilder на FutureBuilder
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }

                        final categories = snapshot.data ?? [];
                        final categoryIds = categories.map((c) => c.id)
                            .toList();

                        if (_selectedCategoryId != null && !categoryIds
                            .contains(_selectedCategoryId)) {
                          _selectedCategoryId = null;
                        }

                        return DropdownButtonFormField<String?>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Категория (необязательно)',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Без категории'),
                            ),
                            ...categories.map((category) {
                              return DropdownMenuItem(
                                value: category.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(
                                            category.color.replaceAll(
                                                '#', '0xFF'))),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating
                      ? null
                      : () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null // Блокируем кнопку во время обновления
                      : () async {
                    if (_itemNameController.text
                        .trim()
                        .isNotEmpty) {
                      // Устанавливаем флаг, что начали обновление
                      setState(() {
                        isUpdating = true;
                      });

                      try {
                        final quantity = double.tryParse(
                            _quantityController.text) ?? 1;
                        final price = double.tryParse(_priceController.text) ??
                            0.0;

                        final updatedItem = item.copyWith(
                          name: _itemNameController.text.trim(),
                          quantity: quantity,
                          unit: _selectedUnit,
                          categoryId: _selectedCategoryId,
                          price: price,
                        );

                        await _firebaseService.updateShoppingItem(updatedItem);
                        await _updateListTotalPrice(widget.listId);

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        // Если произошла ошибка, снимаем блокировку
                        if (dialogContext.mounted) {
                          setState(() {
                            isUpdating = false;
                          });

                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text(
                                'Ошибка при обновлении товара: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: isUpdating
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
                      Text('Сохранение...'),
                    ],
                  )
                      : const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildItemsList(List<ShoppingItem> items, Map<String, Category> categories) {
    // Если выбрана сортировка, не разделяем по завершенности
    if (_sortBy != 'default') {
      return ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildShoppingItemTile(items[index], categories, context);
        },
      );
    }

    // Стандартная сортировка: сначала незавершенные, потом завершенные
    final notCompletedItems = items.where((item) => !item.isCompleted).toList();
    final completedItems = items.where((item) => item.isCompleted).toList();

    return ListView(
      children: [
        // Незавершенные товары
        if (notCompletedItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Нужно купить',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          ...notCompletedItems.map((item) =>
              _buildShoppingItemTile(item, categories, context)
          ).toList(),
        ],

        // Завершенные товары
        if (completedItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Куплено',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ),
          ),
          ...completedItems.map((item) =>
              _buildShoppingItemTile(item, categories, context)
          ).toList(),
        ],
      ],
    );
  }

  Widget _buildShoppingItemTile(ShoppingItem item,
      Map<String, Category> categories, BuildContext context) {

    final category = item.categoryId != null && categories.containsKey(item.categoryId)
        ? categories[item.categoryId]
        : null;

    final totalItemPrice = item.price * item.quantity;

    return Slidable(
      key: Key(item.id!),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _editItem(context, item),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Изменить',
          ),
          SlidableAction(
            onPressed: (context) async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Удалить элемент'),
                  content: const Text('Вы уверены, что хотите удалить этот элемент?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Отмена'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  await _firebaseService.deleteShoppingItem(item.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Элемент удален')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка при удалении: $e')),
                    );
                  }
                }
              }
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Удалить',
          ),
        ],
      ),
      child: ListTile(
        leading: Checkbox(
          value: item.isCompleted,
          onChanged: (bool? value) async {
            await _firebaseService.toggleItemCompletion(item.id!, value!);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: TextStyle(
                decoration: item.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${item.quantity} ${item.unit}',
                  style: TextStyle(
                    color: item.isCompleted ? Colors.grey : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (category != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery
                          .of(context)
                          .size
                          .width * 0.4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(int.parse(
                            category.color.replaceAll('#', '0xFF')))
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Color(
                              int.parse(category.color.replaceAll('#', '0xFF')))
                              .withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color(int.parse(
                                  category.color.replaceAll('#', '0xFF'))),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              category.name,
                              style: TextStyle(
                                color: item.isCompleted ? Colors.grey : Colors
                                    .grey[800],
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: item.price > 0
            ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₽${totalItemPrice.toStringAsFixed(2)}',
              style: TextStyle(
                color: item.isCompleted ? Colors.grey : Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${item.price.toStringAsFixed(2)} × ${item.quantity}',
              style: TextStyle(
                color: item.isCompleted ? Colors.grey : Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        )
            : null,
      ),
    );
  }

  Widget _buildProgressBar(int totalItems, int completedItems) {
    final progress = totalItems > 0 ? completedItems / totalItems : 0.0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Прогресс:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              tween: Tween<double>(begin: 0, end: progress),
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                  minHeight: 20,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<ShoppingList>(
          stream: _firebaseService.getShoppingListById(widget.listId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text('Список покупок');
            }
            return Text(snapshot.data!.title);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Реализовать редактирование списка
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // общая стоимость списка
          StreamBuilder<ShoppingList>(
            stream: _firebaseService.getShoppingListById(widget.listId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox();
              }

              final list = snapshot.data!;

              return Container(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Общая стоимость:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '₽ ${list.totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<ShoppingItem>>(
                      stream: _firebaseService.getShoppingItems(widget.listId),
                      builder: (context, itemsSnapshot) {
                        if (!itemsSnapshot.hasData) {
                          return const SizedBox();
                        }
                        
                        final items = itemsSnapshot.data!;
                        final completedItems = items.where((item) => item.isCompleted).length;
                        
                        return _buildProgressBar(items.length, completedItems);
                      },
                    ),
                  ],
                ),
              );
            },
          ),

          // панель поиска
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск товара...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
          ),

          // панель сортировки
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Сортировка: '),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('По умолчанию'),
                    selected: _sortBy == 'default',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _sortBy = 'default';
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('По названию'),
                        if (_sortBy == 'name')
                          Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14,
                          ),
                      ],
                    ),
                    selected: _sortBy == 'name',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          if (_sortBy == 'name') {
                            _sortAscending = !_sortAscending;
                          } else {
                            _sortBy = 'name';
                            _sortAscending = true;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('По цене'),
                        if (_sortBy == 'price')
                          Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14,
                          ),
                      ],
                    ),
                    selected: _sortBy == 'price',
                    onSelected: (bool tappedOnThisChip) {
                      setState(() {
                        print('Price ChoiceChip onSelected. Tapped: $tappedOnThisChip. Current _sortBy: $_sortBy, _sortAscending: $_sortAscending');

                        if (_sortBy == 'price') {
                          _sortAscending = !_sortAscending;
                        } else {
                          _sortBy = 'price';
                          _sortAscending = true;
                        }
                        print('Price ChoiceChip onSelected - New _sortBy: $_sortBy, New _sortAscending: $_sortAscending');
                      });
                    },
                  )
                ],
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<ShoppingItem>>(
              stream: _firebaseService.getShoppingItems(widget.listId),
              builder: (context, itemsSnapshot) {
                if (itemsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (itemsSnapshot.hasError) {
                  return Center(child: Text('Ошибка: ${itemsSnapshot.error}'));
                }

                final items = itemsSnapshot.data ?? [];

                return StreamBuilder<List<Category>>(
                  stream: _firebaseService.getCategories(),
                  builder: (context, categoriesSnapshot) {
                    if (categoriesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final categories = Map<String, Category>.fromEntries(
                        (categoriesSnapshot.data ?? [])
                            .map((category) => MapEntry(category.id!, category))
                    );

                    if (items.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_cart_outlined, size: 80,
                                color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'Список пуст',
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .titleLarge,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _addNewItem(context, widget.listId),
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить первый товар'),
                            ),
                          ],
                        ),
                      ),
                      );
                    }

                    final filteredAndSortedItems = _filterAndSortItems(items);

                    if (filteredAndSortedItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_outlined, size: 80,
                                color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'Товары не найдены',
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Попробуйте изменить поисковый запрос',
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return _buildItemsList(filteredAndSortedItems, categories);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addNewItem(context, widget.listId),
        tooltip: 'Добавить товар',
        child: const Icon(Icons.add),
      ),
    );
  }
}