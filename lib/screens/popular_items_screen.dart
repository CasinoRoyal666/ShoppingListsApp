import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';

class PopularItemsScreen extends StatefulWidget {
  const PopularItemsScreen({Key? key}) : super(key: key);

  @override
  _PopularItemsScreenState createState() => _PopularItemsScreenState();
}

class _PopularItemsScreenState extends State<PopularItemsScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isLoading = true;
  Map<String, int> _popularCategories = {};
  Map<String, int> _popularItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final data = await _firebaseService.getPopularItemsAndCategories();
    
    setState(() {
      _popularCategories = data['categories'];
      _popularItems = data['items'];
      _isLoading = false;
    });

    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Популярные товары и категории'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Категории'),
            Tab(text: 'Товары'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoriesChart(),
                _buildItemsChart(),
              ],
            ),
    );
  }

  Widget _buildCategoriesChart() {
    final entries = _popularCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.5,
          child: FadeTransition(
            opacity: _animation,
            child: ScaleTransition(
              scale: _animation,
              child: PieChart(
                PieChartData(
                  sections: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    final percentage = (category.value / total * 100);
                    final color = _getColorForIndex(index);

                    return PieChartSectionData(
                      color: color,
                      value: category.value.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: FadeTransition(
            opacity: _animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(_animation),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final percentage = (entry.value / total * 100);
                  final color = _getColorForIndex(index);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(entry.key),
                      subtitle: Text('${percentage.toStringAsFixed(1)}% от всех покупок'),
                      trailing: Text('${entry.value} раз'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsChart() {
    final entries = _popularItems.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.5,
          child: FadeTransition(
            opacity: _animation,
            child: ScaleTransition(
              scale: _animation,
              child: PieChart(
                PieChartData(
                  sections: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final percentage = (item.value / total * 100);
                    final color = _getColorForIndex(index);

                    return PieChartSectionData(
                      color: color,
                      value: item.value.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: FadeTransition(
            opacity: _animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(_animation),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final percentage = (entry.value / total * 100);
                  final color = _getColorForIndex(index);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(entry.key),
                      subtitle: Text('${percentage.toStringAsFixed(1)}% от всех покупок'),
                      trailing: Text('${entry.value} раз'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.amber,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.orange,
      Colors.indigo,
      Colors.lime,
    ];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }
} 