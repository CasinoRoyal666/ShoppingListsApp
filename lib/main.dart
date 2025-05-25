import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shopping_app/screens/account_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/list_details_screen.dart';
import 'screens/shoppping_lists_screen.dart';
import 'screens/categories_service.dart';
import 'screens/spending_analysis_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Список покупок',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => AuthScreen(),
        '/shopping_lists': (context) => ShoppingListsScreen(),
        '/account': (context) => const AccountScreen(),
        '/list_details':(context) {
          final listId = ModalRoute.of(context)!.settings.arguments as String;
          return ListDetailsScreen(listId: listId);
        },
        '/categories': (context) => const CategoriesScreen(),
        '/spending_analysis': (context) => const SpendingAnalysisScreen(),
      },
    );
  }
}