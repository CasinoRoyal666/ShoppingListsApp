import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/budget_limit.dart';
import 'popular_items_screen.dart';
import '../services/secure_storage_service.dart';

class SpendingAnalysisScreen extends StatefulWidget {
  const SpendingAnalysisScreen({Key? key}) : super(key: key);

  @override
  _SpendingAnalysisScreenState createState() => _SpendingAnalysisScreenState();
}

class _SpendingAnalysisScreenState extends State<SpendingAnalysisScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late AnimationController _animationController;
  late Animation<double> _animation;
  final TextEditingController _budgetLimitController = TextEditingController();

  // Периоды анализа
  String _selectedPeriod = 'week';
  late DateTime _startDate;
  late DateTime _endDate;

  // Данные для диаграммы
  double _totalSpending = 0;
  Map<String, double> _spendingByList = {};
  Map<String, String> _listTitles = {};
  bool _isLoading = true;

  // Форматтер для денежных значений
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ru_RU',
    symbol: '₽',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _updateDateRange();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _budgetLimitController.dispose();
    super.dispose();
  }

  void _updateDateRange() {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'week':
        _endDate = now;
        _startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        _endDate = now;
        _startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        _endDate = now;
        _startDate = DateTime(now.year - 1, now.month, now.day);
        break;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final stats = await _firebaseService.getSpendingStatisticsByPeriod(
      _startDate,
      _endDate,
    );

    setState(() {
      _totalSpending = stats['totalSpending'];
      _spendingByList = stats['spendingByList'];
      _listTitles = stats['listTitles'];
      _isLoading = false;
    });

    _animationController.reset();
    _animationController.forward();
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _updateDateRange();
    _loadData();
  }

  Future<void> _showBudgetLimitDialog() async {
    try {
      final currentLimit = await _firebaseService.getBudgetLimit(_selectedPeriod).first;
      _budgetLimitController.text = currentLimit?.limit.toString() ?? '';

      if (!mounted) return;

      return showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Установить лимит бюджета'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _budgetLimitController,
                decoration: const InputDecoration(
                  labelText: 'Лимит бюджета',
                  prefixText: '₽ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Text(
                'Текущий период: ${_getPeriodName(_selectedPeriod)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final limit = double.tryParse(_budgetLimitController.text);
                if (limit != null && limit > 0) {
                  try {
                    await _firebaseService.setBudgetLimit(_selectedPeriod, limit);
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ошибка при сохранении лимита: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Пожалуйста, введите корректную сумму'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке данных: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getPeriodName(String period) {
    switch (period) {
      case 'week':
        return 'Неделя';
      case 'month':
        return 'Месяц';
      case 'year':
        return 'Год';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Анализ расходов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.trending_up),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PopularItemsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: _showBudgetLimitDialog,
            tooltip: 'Установить лимит бюджета',
          ),
        ],
      ),
      body: SafeArea(
        child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPeriodSelector(),
          _buildDateRange(),
          _buildSpendingCard(),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_totalSpending > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.width * 0.8,
                    child: _buildPieChart(),
                  ),
                  const SizedBox(height: 16),
                  ..._buildSpendingListItems(),
                ],
              ),
            )
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPeriodSelector(),
                    _buildDateRange(),
                    _buildSpendingCard(),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_totalSpending > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _buildPieChart(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        children: _buildSpendingListItems(),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'week', label: Text('Неделя')),
          ButtonSegment(value: 'month', label: Text('Месяц')),
          ButtonSegment(value: 'year', label: Text('Год')),
        ],
        selected: {_selectedPeriod},
        onSelectionChanged: (Set<String> selection) {
          _changePeriod(selection.first);
        },
      ),
    );
  }

  Widget _buildDateRange() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        'Период: ${DateFormat('dd.MM.yyyy').format(_startDate)} - ${DateFormat('dd.MM.yyyy').format(_endDate)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSpendingCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<BudgetLimit?>(
        stream: _firebaseService.getBudgetLimit(_selectedPeriod),
        builder: (context, snapshot) {
          // Получаем лимит из Firebase
          final budgetLimit = snapshot.data;
          
          // Если нет данных в Firebase, пробуем получить из локального хранилища
          if (budgetLimit == null) {
            return FutureBuilder<double?>(
              future: SecureStorageService.getBudgetLimit(_selectedPeriod),
              builder: (context, localLimitSnapshot) {
                final localLimit = localLimitSnapshot.data;
                return _buildSpendingCardContent(_totalSpending, localLimit);
              },
            );
          }

          return _buildSpendingCardContent(_totalSpending, budgetLimit.limit);
        },
      ),
    );
  }

  Widget _buildSpendingCardContent(double totalSpending, double? limit) {
    final isOverBudget = limit != null && totalSpending > limit;
    final percentage = limit != null ? (totalSpending / limit * 100) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Общие расходы:',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  _currencyFormat.format(totalSpending),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isOverBudget ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            if (limit != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Лимит бюджета:'),
                  Text(
                    _currencyFormat.format(limit),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage! > 1 ? 1 : percentage,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${percentage.toStringAsFixed(1)}% от лимита',
                style: TextStyle(
                  color: isOverBudget ? Colors.red : Colors.green,
                  fontSize: 12,
                ),
                textAlign: TextAlign.end,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: _buildPieChart(),
        ),
        const SizedBox(height: 16),
        ..._buildSpendingListItems(),
      ],
    );
  }

  Widget _buildPieChart() {
    return FadeTransition(
      opacity: _animation,
      child: ScaleTransition(
        scale: _animation,
        child: PieChart(
          PieChartData(
            sections: _buildPieChartSections(),
            centerSpaceRadius: 40,
            sectionsSpace: 2,
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                // Можно добавить обработку касаний
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Нет данных о расходах за выбранный период',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    // Массив цветов для секций диаграммы
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

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    _spendingByList.forEach((listId, amount) {
      final title = _listTitles[listId] ?? 'Без названия';
      final percentage = (amount / _totalSpending * 100);
      final color = colors[colorIndex % colors.length];

      sections.add(
        PieChartSectionData(
          color: color,
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      colorIndex++;
    });

    return sections;
  }

  List<Widget> _buildSpendingListItems() {
    final items = <Widget>[];
    int colorIndex = 0;
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

    _spendingByList.forEach((listId, amount) {
      final title = _listTitles[listId] ?? 'Без названия';
      final percentage = (amount / _totalSpending * 100);
      final color = colors[colorIndex % colors.length];

      items.add(
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text(
                '${colorIndex + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(title),
            subtitle: Text('${percentage.toStringAsFixed(1)}% от общих расходов'),
            trailing: Text(
              _currencyFormat.format(amount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );

      colorIndex++;
    });

    return items;
  }
}