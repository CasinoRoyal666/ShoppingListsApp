import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shopping_app/services/secure_storage_service.dart';
import '../../models/models.dart';
import '../screens/spending_analysis_screen.dart';
import '../models/budget_limit.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  CollectionReference get _shoppingListsCollection => _firestore.collection('shopping_lists');
  CollectionReference get _categoriesCollection => _firestore.collection('categories');
  CollectionReference get _shoppingItemsCollection => _firestore.collection('shopping_items');

  // Методы для работы со списками покупок
  Stream<List<ShoppingList>> getShoppingLists() {
    return _shoppingListsCollection
        .where('userId', isEqualTo: currentUser?.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShoppingList.fromSnapshot(doc))
          .toList();
    });
  }

  Future<ShoppingList?> getShoppingListByIdOnce(String listId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shopping_lists')
          .doc(listId)
          .get();

      if (doc.exists) {
        return ShoppingList.fromSnapshot(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching shopping list: $e');
      return null;
    }
  }

  Future<ShoppingList> createShoppingList(ShoppingList list) async {
    final docRef = await _shoppingListsCollection.add(list.toMap());
    return list.copyWith(id: docRef.id);
  }

  Future<void> updateShoppingList(ShoppingList list) async {
    if (list.id == null) return;

    await _shoppingListsCollection.doc(list.id).update({
      'title': list.title,
      'description': list.description,
      'isCompleted': list.isCompleted,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteShoppingList(String listId) async {
    try {
      final items = await _shoppingItemsCollection
          .where('shoppingListId', isEqualTo: listId)
          .get();
      for (var doc in items.docs) {
        await doc.reference.delete();
      }
      await _shoppingListsCollection.doc(listId).delete();
    } catch (e) {
      print('Error deleting shopping list: $e');
      rethrow;
    }
  }

  Stream<ShoppingList> getShoppingListById(String listId) {
    return _shoppingListsCollection
        .doc(listId)
        .snapshots()
        .map((snapshot) => ShoppingList.fromSnapshot(snapshot));
  }
  Future<void> updateShoppingListTotalPrice(String listId, double totalPrice) async {
    await _shoppingListsCollection.doc(listId).update({
      'totalPrice': totalPrice,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> recalculateShoppingListTotalPrice(String listId) async {
    final itemsSnapshot = await _shoppingItemsCollection
        .where('shoppingListId', isEqualTo: listId)
        .get();

    double totalPrice = 0.0;
    for (var doc in itemsSnapshot.docs) {
      final item = ShoppingItem.fromSnapshot(doc);
      totalPrice += item.price * item.quantity;
    }

    await updateShoppingListTotalPrice(listId, totalPrice);
  }

  Stream<List<Category>> getCategories() {
    return _categoriesCollection
        .where('userId', isEqualTo: currentUser?.uid)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Category.fromSnapshot(doc))
          .toList();
    });
  }

  Future<Category> createCategory(Category category) async {
    final docRef = await _categoriesCollection.add(category.toMap());
    return category;
  }

  Future<void> updateCategory(Category category) async {
    if (category.id == null) return;
    await _categoriesCollection.doc(category.id).update({
      'name': category.name,
      'color': category.color,
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    await _categoriesCollection.doc(categoryId).delete();

    final items = await _shoppingItemsCollection
        .where('categoryId', isEqualTo: categoryId)
        .get();

    for (var doc in items.docs) {
      await doc.reference.update({'categoryId': null});
    }
  }
  Future<void> fixItemsWithInvalidCategories(String listId) async {
    final items = await getShoppingItemsOnce(listId);
    final categoriesSnapshot = await _categoriesCollection
        .where('userId', isEqualTo: currentUser?.uid)
        .get();

    final validCategoryIds = Set<String>.from(
        categoriesSnapshot.docs.map((doc) => doc.id));

    final itemsToFix = items.where((item) =>
    item.categoryId != null && !validCategoryIds.contains(item.categoryId));

    for (var item in itemsToFix) {
      await updateShoppingItem(item.copyWith(categoryId: null));
    }
  }

  Future<List<ShoppingItem>> searchItemsByName(String query) async {
    if (query.trim().isEmpty || query.trim().length < 2) {
      return [];
    }
    try {
      final queryLower = query.toLowerCase();
      final snapshot = await _shoppingItemsCollection
          .where('userId', isEqualTo: currentUser?.uid)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => ShoppingItem.fromSnapshot(doc))
          .where((item) => item.name.toLowerCase().contains(queryLower))
          .toList();
    } catch (e) {
      print('Error searching items: $e');
      return [];
    }
  }

  Stream<List<ShoppingItem>> getShoppingItems(String listId) {
    return _shoppingItemsCollection
        .where('shoppingListId', isEqualTo: listId)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShoppingItem.fromSnapshot(doc))
          .toList();
    });
  }

  Future<List<ShoppingItem>> getShoppingItemsOnce(String listId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shopping_items')
          .where('shoppingListId', isEqualTo: listId)
          .get();

      return snapshot.docs
          .map((doc) => ShoppingItem.fromSnapshot(doc))
          .toList();
    } catch (e) {
      print('Error fetching shopping items: $e');
      return [];
    }
  }

  Future<ShoppingItem> createShoppingItem(ShoppingItem item) async {
    final itemData = item.toMap();
    itemData['userId'] = currentUser?.uid;
    final docRef = await _shoppingItemsCollection.add(itemData);
    return item.copyWith(id: docRef.id);
  }

  Future<void> updateShoppingItem(ShoppingItem item) async {
    if (item.id == null) return;

    await _shoppingItemsCollection.doc(item.id).update({
      'name': item.name,
      'quantity': item.quantity,
      'unit': item.unit,
      'isCompleted': item.isCompleted,
      'categoryId': item.categoryId,
      'price': item.price,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'userId': currentUser?.uid,
    });
  }

  Future<void> toggleItemCompletion(String itemId, bool isCompleted) async {
    await _shoppingItemsCollection.doc(itemId).update({
      'isCompleted': isCompleted,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteShoppingItem(String itemId) async {
    try {
      // Получаем информацию о товаре перед удалением
      final itemDoc = await _shoppingItemsCollection.doc(itemId).get();
      if (!itemDoc.exists) return;

      final item = ShoppingItem.fromSnapshot(itemDoc);
      final listId = item.shoppingListId;

      // Удаляем товар
      await _shoppingItemsCollection.doc(itemId).delete();

      // Обновляем общую стоимость списка
      if (listId != null) {
        await recalculateShoppingListTotalPrice(listId);
      }
    } catch (e) {
      print('Error deleting shopping item: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserStatistics() async {
    final listsSnapshot = await _shoppingListsCollection
        .where('userId', isEqualTo: currentUser?.uid)
        .get();

    final completedLists = listsSnapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['isCompleted'] == true)
        .length;

    final itemsSnapshot = await _firestore
        .collectionGroup('shopping_items')
        .where('userId', isEqualTo: currentUser?.uid)
        .get();

    final completedItems = itemsSnapshot.docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['isCompleted'] == true)
        .length;

    return {
      'totalLists': listsSnapshot.docs.length,
      'completedLists': completedLists,
      'totalItems': itemsSnapshot.docs.length,
      'completedItems': completedItems,
    };
  }

  Future<List<ShoppingList>> getCompletedShoppingListsByPeriod(
      DateTime startDate, DateTime endDate) async {
    final snapshot = await _shoppingListsCollection
        .where('userId', isEqualTo: currentUser?.uid)
        .where('isCompleted', isEqualTo: true)
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('updatedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    return snapshot.docs
        .map((doc) => ShoppingList.fromSnapshot(doc))
        .toList();
  }

  Future<Map<String, dynamic>> getSpendingStatisticsByPeriod(
      DateTime startDate, DateTime endDate) async {
    final lists = await getCompletedShoppingListsByPeriod(startDate, endDate);

    double totalSpending = 0;
    Map<String, double> spendingByList = {};
    Map<String, String> listTitles = {};

    for (var list in lists) {
      if (list.id != null && list.totalPrice > 0) {
        totalSpending += list.totalPrice;
        spendingByList[list.id!] = list.totalPrice;
        listTitles[list.id!] = list.title;
      }
    }

    return {
      'totalSpending': totalSpending,
      'spendingByList': spendingByList,
      'listTitles': listTitles,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  Future<Map<String, dynamic>> getPopularItemsAndCategories() async {
    try {
      // Получаем все завершенные списки
      final listsSnapshot = await _shoppingListsCollection
          .where('userId', isEqualTo: currentUser?.uid)
          .where('isCompleted', isEqualTo: true)
          .get();

      final Map<String, int> categoryCount = {};
      final Map<String, int> itemCount = {};

      // Для каждого списка получаем его элементы
      for (var listDoc in listsSnapshot.docs) {
        final itemsSnapshot = await _shoppingItemsCollection
            .where('shoppingListId', isEqualTo: listDoc.id)
            .get();

        for (var itemDoc in itemsSnapshot.docs) {
          final item = ShoppingItem.fromSnapshot(itemDoc);
          
          // Подсчет категорий
          if (item.categoryId != null) {
            try {
              final categoryDoc = await _categoriesCollection.doc(item.categoryId).get();
              if (categoryDoc.exists) {
                final categoryName = (categoryDoc.data() as Map<String, dynamic>)['name'] as String;
                categoryCount[categoryName] = (categoryCount[categoryName] ?? 0) + 1;
              }
            } catch (e) {
              print('Error fetching category: $e');
              // Пропускаем категорию, если она не существует
              continue;
            }
          }

          // Подсчет товаров
          itemCount[item.name] = (itemCount[item.name] ?? 0) + 1;
        }
      }

      return {
        'categories': categoryCount,
        'items': itemCount,
      };
    } catch (e) {
      print('Error getting popular items and categories: $e');
      return {
        'categories': {},
        'items': {},
      };
    }
  }

  // Методы для работы с ограничениями бюджета
  Future<void> setBudgetLimit(String period, double limit) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Сохраняем в Firebase
      final oldLimit = await _firestore
          .collection('users')
          .doc(userId)
          .collection('budget_limits')
          .where('period', isEqualTo: period)
          .get();

      for (var doc in oldLimit.docs) {
        await doc.reference.delete();
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('budget_limits')
          .add({
        'period': period,
        'limit': limit,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      await SecureStorageService.saveBudgetLimit(period, limit);
    } catch (e) {
      print('Ошибка при установке лимита бюджета: $e');
      rethrow;
    }
  }

  Stream<BudgetLimit?> getBudgetLimit(String period) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('budget_limits')
        .where('period', isEqualTo: period)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return BudgetLimit.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
    });
  }
  Future<int> getTotalItemsCountForUser(String userId) async {
    try {
      // Получаем все списки пользователя
      final lists = await _shoppingListsCollection
          .where('userId', isEqualTo: userId)
          .get();

      if (lists.docs.isEmpty) return 0;

      int totalCount = 0;

      // Для каждого списка получаем количество товаров
      for (final list in lists.docs) {
        final items = await _shoppingItemsCollection
            .where('shoppingListId', isEqualTo: list.id)
            .count()
            .get();
        totalCount += items.count!;
      }

      return totalCount;
    } catch (e) {
      print('Error getting items count: $e');
      return 0;
    }
  }
}
