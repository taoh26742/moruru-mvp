// モルル Flutter MVP サンプル（単一ファイル版）
// ------------------------------------------------------------
// ✅ やること（pubspec.yaml に追加）
// dependencies:
//   flutter:
//     sdk: flutter
//   provider: ^6.0.5
//   shared_preferences: ^2.2.2
//
// その後：
//   flutter pub get
//   flutter run
// ------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repo = LocalRepo(prefs);
  final state = GameState(repo);
  await state.restore();

  runApp(
    ChangeNotifierProvider(
      create: (_) => state,
      child: const DreamCreaturesApp(),
    ),
  );
}

class DreamCreaturesApp extends StatelessWidget {
  const DreamCreaturesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dream Creatures – モルル',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB3E5C5)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/morning': (_) => const MorningResultScreen(),
        '/map': (_) => const MapScreen(),
      },
    );
  }
}

// ------------------------------------------------------------
// データ保存（端末ローカル）
// ------------------------------------------------------------
class LocalRepo {
  LocalRepo(this.prefs);
  final SharedPreferences prefs;

  Future<void> save(GameSnapshot s) async {
    await prefs.setString('date', s.date);
    await prefs.setInt('sleepMinutes', s.sleepMinutes);
    await prefs.setInt('stepCount', s.stepCount);
    await prefs.setInt('xp', s.xp);
    await prefs.setInt('stage', s.stage);
    await prefs.setInt('streak', s.streak);
  }

  GameSnapshot loadOrDefault() {
    final today = DateUtils.dateOnly(DateTime.now());
    return GameSnapshot(
      date: _getString('date') ?? _fmtDate(today),
      sleepMinutes: _getInt('sleepMinutes') ?? 0,
      stepCount: _getInt('stepCount') ?? 0,
      xp: _getInt('xp') ?? 0,
      stage: _getInt('stage') ?? 1,
      streak: _getInt('streak') ?? 0,
    );
  }

  String? _getString(String k) => prefs.getString(k);
  int? _getInt(String k) => prefs.getInt(k);
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
        .toString();

// ------------------------------------------------------------
// ゲーム状態
// ------------------------------------------------------------
class GameState extends ChangeNotifier {
  GameState(this.repo);
  final LocalRepo repo;
  late GameSnapshot _snap;

  GameSnapshot get snap => _snap;
  String get date => _snap.date;
  int get sleepMinutes => _snap.sleepMinutes;
  int get stepCount => _snap.stepCount;
  int get xp => _snap.xp;
  int get stage => _snap.stage;
  int get streak => _snap.streak;

  Future<void> restore() async {
    _snap = repo.loadOrDefault();
  }

  Future<void> save() async => repo.save(_snap);

  // 寝る前：フラグだけ立てる（MVPでは手入力中心）
  DateTime? _sleepStart;
  void tapGoodNight() {
    _sleepStart = DateTime.now();
    notifyListeners();
  }

  // 朝：睡眠分を適用（手入力でもOK）
  Future<void> applyMorning({required int sleepMin}) async {
    _ensureToday();
    _snap = _snap.copyWith(sleepMinutes: sleepMin);

    final energy = _dreamEnergy(sleepMin);
    final stepBonus = (stepCount / 1000).floor() * 2;
    final newXp = _snap.xp + energy + stepBonus;

    // 連続ログイン（朝結果閲覧）
    final newStreak = _snap.streak + 1;

    int newStage = _snap.stage;
    if (_snap.stage == 1 && _meetsStage2()) newStage = 2;
    if (_snap.stage == 2 && _meetsStage3()) newStage = 3;

    _snap = _snap.copyWith(xp: newXp, stage: newStage, streak: newStreak);
    await save();
    notifyListeners();
  }

  // 歩数を加算（本番はHealth連携で置換）
  Future<void> addSteps(int delta) async {
    _ensureToday();
    _snap = _snap.copyWith(stepCount: (_snap.stepCount + delta).clamp(0, 100000));
    await save();
    notifyListeners();
  }

  // 日付が変わったら今日のスロットにリセット
  void _ensureToday() {
    final today = _fmtDate(DateTime.now());
    if (_snap.date != today) {
      _snap = GameSnapshot(date: today, sleepMinutes: 0, stepCount: 0, xp: _snap.xp, stage: _snap.stage, streak: _snap.streak);
    }
  }

  // 進化条件（シンプル版）
  bool _meetsStage2() => sleepMinutes >= 360 && stepCount >= 5000; // 6h & 5,000歩
  bool _meetsStage3() => sleepMinutes >= 480 && stepCount >= 8000; // 8h & 8,000歩

  int _dreamEnergy(int sleepMin) => (sleepMin / 10).round().clamp(0, 60);
}

class GameSnapshot {
  const GameSnapshot({
    required this.date,
    required this.sleepMinutes,
    required this.stepCount,
    required this.xp,
    required this.stage,
    required this.streak,
  });

  final String date;
  final int sleepMinutes;
  final int stepCount;
  final int xp;
  final int stage;
  final int streak;

  GameSnapshot copyWith({
    String? date,
    int? sleepMinutes,
    int? stepCount,
    int? xp,
    int? stage,
    int? streak,
  }) => GameSnapshot(
        date: date ?? this.date,
        sleepMinutes: sleepMinutes ?? this.sleepMinutes,
        stepCount: stepCount ?? this.stepCount,
        xp: xp ?? this.xp,
        stage: stage ?? this.stage,
        streak: streak ?? this.streak,
      );
}

// ------------------------------------------------------------
// UI
// ------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(title: const Text('モルル – ホーム')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _MoruruCard(stage: gs.stage),
            const SizedBox(height: 16),
            _StatRow(label: '今日の睡眠', value: '${gs.sleepMinutes} 分'),
            _StatRow(label: '今日の歩数', value: '${gs.stepCount} 歩'),
            _StatRow(label: 'XP', value: '${gs.xp}'),
            _StatRow(label: 'ステージ', value: 'Stage ${gs.stage}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                gs.tapGoodNight();
                _showSleepInputSheet(context);
              },
              child: const Text('おやすみ（睡眠を入力）'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/map'),
              child: const Text('マップへ'),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.read<GameState>().addSteps(1000),
                    child: const Text('+1,000歩（デモ）'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/morning'),
                    child: const Text('朝の結果を見る'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showSleepInputSheet(BuildContext context) {
    final controller = TextEditingController(text: '420');
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('睡眠時間（分）を入力', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final v = int.tryParse(controller.text.trim()) ?? 0;
                await context.read<GameState>().applyMorning(sleepMin: v);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('決定'),
            )
          ],
        ),
      ),
    );
  }
}

class MorningResultScreen extends StatelessWidget {
  const MorningResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final energy = (gs.sleepMinutes / 10).round().clamp(0, 60);
    final stepBonus = (gs.stepCount / 1000).floor() * 2;

    return Scaffold(
      appBar: AppBar(title: const Text('朝のごほうび')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('今朝の結果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ResultTile(label: '夢エネルギー', value: '+$energy'),
            _ResultTile(label: '歩数ボーナス', value: '+$stepBonus'),
            _ResultTile(label: 'ステージ', value: 'Stage ${gs.stage}'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ホームへ'),
            )
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();

    final distanceKm = (gs.stepCount * 0.0007);
    final forestUnlocked = gs.sleepMinutes >= 480; // 8時間睡眠で解放

    return Scaffold(
      appBar: AppBar(title: const Text('マップ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MapCard(
              title: 'ひだまり草原',
              subtitle: '歩くほど探索が進むよ',
              progress: (distanceKm / 5).clamp(0, 1).toDouble(),
              detail: '今日の到達距離: ${distanceKm.toStringAsFixed(1)} km / 5.0 km',
            ),
            const SizedBox(height: 12),
            _MapCard(
              title: 'ねむりの森',
              subtitle: '8時間以上寝ると解放',
              progress: forestUnlocked ? 1 : (gs.sleepMinutes / 480).clamp(0, 1).toDouble(),
              detail: forestUnlocked ? '解放中！' : 'あと ${(480 - gs.sleepMinutes).clamp(0, 480)} 分',
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ホームへ'),
            )
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// パーツUI
// ------------------------------------------------------------
class _MoruruCard extends StatelessWidget {
  const _MoruruCard({required this.stage});
  final int stage;

  @override
  Widget build(BuildContext context) {
    final size = 140.0 + (stage - 1) * 16;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF7),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // 体
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEAF2),
                    shape: BoxShape.circle,
                  ),
                ),
                // 耳（丸）
                Positioned(
                  left: 24,
                  top: 16,
                  child: _dot(28 + (stage - 1) * 2),
                ),
                Positioned(
                  right: 24,
                  top: 16,
                  child: _dot(28 + (stage - 1) * 2),
                ),
                // しっぽ（丸）
                Positioned(
                  bottom: 8,
                  right: 24,
                  child: _dot(18 + (stage - 1) * 2),
                ),
                // 顔
                Column(
                  children: const [
                    SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FaceDot(),
                        SizedBox(width: 32),
                        _FaceDot(),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('ω', style: TextStyle(fontSize: 24)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Text('モルル  Stage $stage'),
          ],
        ),
      ),
    );
  }

  Widget _dot(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(color: const Color(0xFFFFD2E1), shape: BoxShape.circle),
      );
}

class _FaceDot extends StatelessWidget {
  const _FaceDot();
  @override
  Widget build(BuildContext context) {
    return Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle));
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE6EEE8))),
      child: ListTile(title: Text(label), trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.title, required this.subtitle, required this.progress, required this.detail});
  final String title;
  final String subtitle;
  final double progress;
  final String detail;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE6EEE8))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text(detail),
        ]),
      ),
    );
  }
}
