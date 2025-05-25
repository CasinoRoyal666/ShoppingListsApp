// lib/screens/account_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart'; // Убедитесь, что путь корректен
// import '../screens/auth_screen.dart'; // Предполагаемое имя экрана авторизации

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  int _listsCount = 0;
  int _itemsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    try {

      final lists = await _firebaseService.getShoppingLists().first;
      _listsCount = lists.length;

     // _itemsCount = await _firebaseService.getTotalItemsCountForUser(currentUser!.uid);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных пользователя: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (Route<dynamic> route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка выхода: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (currentUser == null) {
      return const Center(child: Text('Пользователь не авторизован.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой аккаунт'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                     backgroundImage: currentUser?.photoURL != null
                        ? NetworkImage(currentUser!.photoURL!)
                        : null,
                    child: currentUser?.photoURL == null
                        ? Icon(Icons.person, size: 50)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentUser?.displayName ?? currentUser?.email ?? 'Имя не указано',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (currentUser?.email != null)
                    Text(
                      currentUser!.email!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.list_alt,
                      label: 'Создано списков:',
                      value: _listsCount.toString(),
                    ),
                 //   Divider(),
                 //   _buildInfoRow(
                 //     icon: Icons.shopping_cart_checkout,
                  //    label: 'Всего товаров в списках:',
                  //    value: _itemsCount.toString(),
                 //   ),
                  ],
                ),
              ),
            ),
            const Spacer(), // Занимает все доступное пространство
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Выйти из аккаунта'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: _signOut,
              ),
            ),
            const SizedBox(height: 20), // Немного отступа снизу
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}