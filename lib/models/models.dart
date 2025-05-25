import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingList {
  final String? id;
  String title;
  String? description;
  bool isCompleted;
  final String userId;
  DateTime createdAt;
  DateTime updatedAt;
  double totalPrice;

  ShoppingList({
    this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    required this.userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.totalPrice = 0.0,
  }) :
        this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'totalPrice': totalPrice,
    };
  }

  factory ShoppingList.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return ShoppingList(
      id: snapshot.id,
      title: data['title'] ?? '',
      description: data['description'],
      isCompleted: data['isCompleted'] ?? false,
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
    );
  }

  ShoppingList copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? totalPrice,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

class Category {
  final String? id;
  String name;
  String color;
  String userId;
  DateTime createdAt;

  Category({
    this.id,
    required this.name,
    required this.color,
    required this.userId,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Category.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Category(
      id: snapshot.id,
      name: data['name'] ?? '',
      color: data['color'] ?? '#FF9800',
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

class ShoppingItem {
  final String? id;
  String name;
  double quantity;
  String unit;
  bool isCompleted;
  String? categoryId;
  String shoppingListId;
  DateTime createdAt;
  DateTime updatedAt;
  double price;

  ShoppingItem({
    this.id,
    required this.name,
    this.quantity = 1,
    this.unit = 'шт',
    this.isCompleted = false,
    this.categoryId,
    required this.shoppingListId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.price = 0.0,
  }) :
        this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isCompleted': isCompleted,
      'categoryId': categoryId,
      'shoppingListId': shoppingListId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'price': price, // Добавление цены в Map
    };
  }

  factory ShoppingItem.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return ShoppingItem(
      id: snapshot.id,
      name: data['name'] ?? '',
      quantity: (data['quantity'] ?? 1).toDouble(),
      unit: data['unit'] ?? 'шт',
      isCompleted: data['isCompleted'] ?? false,
      categoryId: data['categoryId'],
      shoppingListId: data['shoppingListId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      price: (data['price'] ?? 0.0).toDouble(), // Парсинг цены
    );
  }

  ShoppingItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    bool? isCompleted,
    String? categoryId,
    String? shoppingListId,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? price,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isCompleted: isCompleted ?? this.isCompleted,
      categoryId: categoryId ?? this.categoryId,
      shoppingListId: shoppingListId ?? this.shoppingListId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      price: price ?? this.price,
    );
  }
}