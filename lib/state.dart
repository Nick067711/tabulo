import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';

enum Op { add, sub, mul, div }

Op opFromName(String s) {
  for (final o in Op.values) {
    if (o.name == s) return o;
  }
  return Op.add;
}

int _int(dynamic v, [int def = 0]) => v is num ? v.toInt() : def;

/// One arithmetic task. For division [a] is the dividend and [b] the divisor.
/// When [missing] is true the child has to find [b] instead of the result.
class Task {
  final Op op;
  final int a;
  final int b;
  final bool missing;
  const Task(this.op, this.a, this.b, {this.missing = false});

  int get result => switch (op) {
        Op.add => a + b,
        Op.sub => a - b,
        Op.mul => a * b,
        Op.div => b == 0 ? 0 : a ~/ b,
      };

  int get answer => missing ? b : result;

  bool same(Task o) => o.op == op && o.a == a && o.b == b;

  Map<String, dynamic> toJson() => {'op': op.name, 'a': a, 'b': b, 'm': missing};

  static Task fromJson(Map<String, dynamic> j) =>
      Task(opFromName('${j['op']}'), _int(j['a']), _int(j['b']), missing: j['m'] == true);
}

class Mistake {
  final Task task;
  final String given;
  Mistake(this.task, this.given);
  Map<String, dynamic> toJson() => {'t': task.toJson(), 'g': given};
  static Mistake fromJson(Map<String, dynamic> j) =>
      Mistake(Task.fromJson(Map<String, dynamic>.from(j['t'] as Map)), '${j['g'] ?? ''}');
}

class Profile {
  final String id;
  String name;
  int color;
  int stars;
  Profile({required this.id, required this.name, this.color = 0, this.stars = 0});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color, 'stars': stars};
  static Profile fromJson(Map<String, dynamic> j) =>
      Profile(id: '${j['id']}', name: '${j['name']}', color: _int(j['color']), stars: _int(j['stars']));
}

/// kind: add, sub, mul, div, table, column, quiz0, quiz1
class Session {
  final String id;
  final String profileId;
  final String kind;
  final int date;
  final int ms;
  final int total;
  final int correct;
  final List<Mistake> mistakes;
  final String desc;
  final bool choice;
  Session({
    required this.id,
    required this.profileId,
    required this.kind,
    required this.date,
    required this.ms,
    required this.total,
    required this.correct,
    required this.mistakes,
    this.desc = '',
    this.choice = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'p': profileId,
        'k': kind,
        'd': date,
        'ms': ms,
        'n': total,
        'c': correct,
        'x': mistakes.map((m) => m.toJson()).toList(),
        'desc': desc,
        'ch': choice,
      };
  static Session fromJson(Map<String, dynamic> j) => Session(
        id: '${j['id']}',
        profileId: '${j['p']}',
        kind: '${j['k']}',
        date: _int(j['d']),
        ms: _int(j['ms']),
        total: _int(j['n']),
        correct: _int(j['c']),
        mistakes: ((j['x'] as List?) ?? [])
            .map((e) => Mistake.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        desc: '${j['desc'] ?? ''}',
        choice: j['ch'] == true,
      );
}

class LbEntry {
  final String id;
  final String profileId;
  final String name;
  final int group;
  final int correct;
  final int total;
  final int ms;
  final int date;
  LbEntry({
    required this.id,
    required this.profileId,
    required this.name,
    required this.group,
    required this.correct,
    required this.total,
    required this.ms,
    required this.date,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'p': profileId,
        'n': name,
        'g': group,
        'c': correct,
        't': total,
        'ms': ms,
        'd': date,
      };
  static LbEntry fromJson(Map<String, dynamic> j) => LbEntry(
        id: '${j['id']}',
        profileId: '${j['p']}',
        name: '${j['n']}',
        group: _int(j['g']),
        correct: _int(j['c']),
        total: _int(j['t']),
        ms: _int(j['ms']),
        date: _int(j['d']),
      );
}

class LbArchive {
  final int count;
  final int from;
  final int to;
  final List<LbEntry> entries;
  LbArchive({required this.count, required this.from, required this.to, required this.entries});
  Map<String, dynamic> toJson() =>
      {'count': count, 'from': from, 'to': to, 'e': entries.map((e) => e.toJson()).toList()};
  static LbArchive fromJson(Map<String, dynamic> j) => LbArchive(
        count: _int(j['count']),
        from: _int(j['from']),
        to: _int(j['to']),
        entries: ((j['e'] as List?) ?? [])
            .map((e) => LbEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Best entry is better when it has more correct answers, then less time.
int cmpEntries(LbEntry a, LbEntry b) {
  final c = b.correct.compareTo(a.correct);
  if (c != 0) return c;
  return a.ms.compareTo(b.ms);
}

class BoardView {
  final List<LbEntry> podium;
  final List<LbEntry> rest;
  BoardView(this.podium, this.rest);
}

BoardView buildBoardView(List<LbEntry> entries) {
  final all = List<LbEntry>.from(entries)..sort(cmpEntries);
  final best = <String, LbEntry>{};
  for (final e in all) {
    best.putIfAbsent(e.profileId, () => e);
  }
  final bests = best.values.toList()..sort(cmpEntries);
  final podium = bests.take(3).toList();
  final rest = all.where((e) => !podium.contains(e)).toList();
  return BoardView(podium, rest);
}

class QuizOutcome {
  final int place;
  final bool onPodium;
  final bool isRecord;
  final int recordPlace; // 0 = record not on podium
  final LbEntry? record;
  QuizOutcome(this.place, this.onPodium, this.isRecord, this.recordPlace, this.record);
}

class ModuleConfig {
  int count;
  List<int> numbers; // for multiplication / division
  int range; // index into AppState.ranges, for addition / subtraction
  bool carry; // allow crossing ten
  ModuleConfig({this.count = 20, List<int>? numbers, this.range = 1, this.carry = true})
      : numbers = numbers ?? [2, 3, 4, 5, 6, 7, 8, 9];
  Map<String, dynamic> toJson() => {'count': count, 'nums': numbers, 'range': range, 'carry': carry};
  static ModuleConfig fromJson(Map<String, dynamic> j) => ModuleConfig(
        count: _int(j['count'], 20),
        numbers: ((j['nums'] as List?) ?? [2, 3, 4, 5, 6, 7, 8, 9]).map((e) => _int(e)).toList(),
        range: _int(j['range'], 1),
        carry: j['carry'] != false,
      );
}

/// A multiplication-table game in progress. marks: "r-c" -> h (hidden), ok, bad.
class TableGame {
  final Map<String, String> marks;
  final List<String> firstBad;
  final int start;
  TableGame({required this.marks, required this.firstBad, required this.start});
  Map<String, dynamic> toJson() => {'m': marks, 'fb': firstBad, 's': start};
  static TableGame fromJson(Map<String, dynamic> j) => TableGame(
        marks: Map<String, dynamic>.from((j['m'] as Map?) ?? {}).map((k, v) => MapEntry(k, '$v')),
        firstBad: ((j['fb'] as List?) ?? []).map((e) => '$e').toList(),
        start: _int(j['s']),
      );
}

class AppState extends ChangeNotifier {
  static const trialMs = 24 * 3600 * 1000;
  static const ranges = [10, 20, 100, 1000];
  static const langs = ['pl', 'en', 'de', 'es', 'fr', 'uk'];
  static const maxSessions = 300;

  SharedPreferences? _prefs;
  final Random _rnd = Random();

  bool onboarded = false;
  String lang = 'pl';
  String mulSign = '×';
  String divSign = '÷';
  List<Profile> profiles = [];
  String? activeId;
  List<ModuleConfig> modules = [
    ModuleConfig(range: 1),
    ModuleConfig(range: 1),
    ModuleConfig(),
    ModuleConfig(),
  ];
  int quizCount = 100;
  int quizSince = DateTime.now().millisecondsSinceEpoch;
  int? trialStart;
  bool purchased = false;
  List<Session> sessions = [];
  List<LbEntry> board = [];
  List<LbArchive> archives = [];
  Map<String, TableGame> tableGames = {};

  String t(String key) => tr(lang, key);

  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';

  // ---------- persistence ----------

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString('tabulo_v1');
      if (raw == null) {
        final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        lang = langs.contains(sys) ? sys : 'en';
        applyDefaultSigns();
        return;
      }
      _fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('Tabulo: load failed: $e');
    }
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString('tabulo_v1', jsonEncode(_toJson()));
    } catch (e) {
      debugPrint('Tabulo: save failed: $e');
    }
  }

  Map<String, dynamic> _toJson() => {
        'onb': onboarded,
        'lang': lang,
        'mul': mulSign,
        'div': divSign,
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'active': activeId,
        'modules': modules.map((m) => m.toJson()).toList(),
        'qc': quizCount,
        'qs': quizSince,
        'trial': trialStart,
        'sv': 2,
        'paid': purchased,
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'board': board.map((e) => e.toJson()).toList(),
        'arch': archives.map((a) => a.toJson()).toList(),
        'tables': tableGames.map((k, v) => MapEntry(k, v.toJson())),
      };

  void _fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) =>
        ((j[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    onboarded = j['onb'] == true;
    lang = langs.contains(j['lang']) ? '${j['lang']}' : 'en';
    mulSign = '${j['mul'] ?? '×'}';
    divSign = '${j['div'] ?? ':'}';
    if (j['sv'] != 2) applyDefaultSigns(); // older test builds used other defaults
    profiles = list('profiles').map(Profile.fromJson).toList();
    activeId = j['active'] as String?;
    final mods = list('modules').map(ModuleConfig.fromJson).toList();
    if (mods.length == 4) modules = mods;
    quizCount = _int(j['qc'], 100);
    quizSince = _int(j['qs'], DateTime.now().millisecondsSinceEpoch);
    trialStart = j['trial'] is num ? (j['trial'] as num).toInt() : null;
    purchased = j['paid'] == true;
    sessions = list('sessions').map(Session.fromJson).toList();
    board = list('board').map(LbEntry.fromJson).toList();
    archives = list('arch').map(LbArchive.fromJson).toList();
    final tg = Map<String, dynamic>.from((j['tables'] as Map?) ?? {});
    tableGames = tg.map((k, v) => MapEntry(k, TableGame.fromJson(Map<String, dynamic>.from(v as Map))));
  }

  Future<void> resetAll() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove('tabulo_v1');
    onboarded = false;
    profiles = [];
    activeId = null;
    modules = [ModuleConfig(range: 1), ModuleConfig(range: 1), ModuleConfig(), ModuleConfig()];
    quizCount = 100;
    quizSince = DateTime.now().millisecondsSinceEpoch;
    trialStart = null;
    purchased = false;
    sessions = [];
    board = [];
    archives = [];
    tableGames = {};
    notifyListeners();
  }

  // ---------- language and signs ----------

  /// Standard signs for everyone; they can be changed in Settings.
  void applyDefaultSigns() {
    mulSign = '×';
    divSign = '÷';
  }

  void setLang(String l, {bool withSigns = false}) {
    lang = l;
    if (withSigns) applyDefaultSigns();
    _changed();
  }

  void setMulSign(String s) {
    mulSign = s;
    _changed();
  }

  void setDivSign(String s) {
    divSign = s;
    _changed();
  }

  String sign(Op op) => switch (op) {
        Op.add => '+',
        Op.sub => '−',
        Op.mul => mulSign,
        Op.div => divSign,
      };

  String opName(Op op) => t('op_${op.name}');

  String fullText(Task task) => '${task.a} ${sign(task.op)} ${task.b} = ${task.result}';

  // ---------- trial and purchase ----------

  int get now => DateTime.now().millisecondsSinceEpoch;

  bool get trialUsed => trialStart != null;

  bool get trialActive {
    final s = trialStart;
    if (s == null) return false;
    final n = now;
    if (n < s) return false; // clock moved back: treat as expired
    return n - s < trialMs;
  }

  bool get locked => !purchased && !trialActive;

  int get trialHoursLeft {
    final s = trialStart;
    if (s == null) return 0;
    final left = trialMs - (now - s);
    if (left <= 0) return 0;
    return (left / 3600000).ceil();
  }

  void startTrial() {
    trialStart ??= now;
    _changed();
  }

  void purchase() {
    purchased = true;
    _changed();
  }

  void endTrialNow() {
    trialStart = now - trialMs - 1000;
    _changed();
  }

  void undoPurchase() {
    purchased = false;
    _changed();
  }

  void completeOnboarding() {
    onboarded = true;
    _changed();
  }

  // ---------- profiles ----------

  Profile get me {
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    if (profiles.isEmpty) {
      final p = Profile(id: newId(), name: t('player'), color: 0);
      profiles.add(p);
    }
    activeId = profiles.first.id;
    return profiles.first;
  }

  Profile addProfile(String name) {
    final used = profiles.map((p) => p.color).toSet();
    var color = 0;
    for (var i = 0; i < 6; i++) {
      if (!used.contains(i)) {
        color = i;
        break;
      }
      color = profiles.length % 6;
    }
    final p = Profile(id: newId(), name: name.trim(), color: color);
    profiles.add(p);
    activeId ??= p.id;
    _changed();
    return p;
  }

  void ensureFirstProfile(String name) {
    if (profiles.isEmpty) {
      final p = addProfile(name);
      activeId = p.id;
      _changed();
    } else {
      me.name = name.trim();
      _changed();
    }
  }

  void removeProfile(String id) {
    profiles.removeWhere((p) => p.id == id);
    sessions.removeWhere((s) => s.profileId == id);
    board.removeWhere((e) => e.profileId == id);
    tableGames.remove(id);
    if (activeId == id) activeId = profiles.isEmpty ? null : profiles.first.id;
    _changed();
  }

  void setActive(String id) {
    activeId = id;
    _changed();
  }

  // ---------- module settings ----------

  ModuleConfig module(Op op) => modules[op.index];

  void updateModule(Op op, void Function(ModuleConfig m) change) {
    change(modules[op.index]);
    _changed();
  }

  // ---------- sessions ----------

  List<Session> sessionsOf(String profileId) => sessions.where((s) => s.profileId == profileId).toList();

  void addSession(Session s, {int stars = 0}) {
    sessions.insert(0, s);
    if (sessions.length > maxSessions) sessions.removeRange(maxSessions, sessions.length);
    if (stars > 0) {
      for (final p in profiles) {
        if (p.id == s.profileId) p.stars += stars;
      }
    }
    _changed();
  }

  // ---------- quiz and leaderboard ----------

  List<LbEntry> boardOf(int group) => board.where((e) => e.group == group).toList();

  LbEntry? bestOf(String profileId, int group) {
    final mine = board.where((e) => e.profileId == profileId && e.group == group).toList()..sort(cmpEntries);
    return mine.isEmpty ? null : mine.first;
  }

  QuizOutcome addQuizResult(int group, int correct, int ms) {
    final p = me;
    final prev = bestOf(p.id, group);
    final e = LbEntry(
      id: newId(),
      profileId: p.id,
      name: p.name,
      group: group,
      correct: correct,
      total: quizCount,
      ms: ms,
      date: now,
    );
    board.add(e);
    _trim(p.id, group);
    final view = buildBoardView(boardOf(group));
    var place = 0;
    var onPodium = false;
    final pi = view.podium.indexOf(e);
    if (pi >= 0) {
      place = pi + 1;
      onPodium = true;
    } else {
      final ri = view.rest.indexOf(e);
      place = ri >= 0 ? ri + 4 : 0;
    }
    final isRecord = prev == null || cmpEntries(e, prev) < 0;
    final record = bestOf(p.id, group);
    final recordPlace = record == null ? 0 : view.podium.indexOf(record) + 1;
    _changed();
    return QuizOutcome(place, onPodium, isRecord, recordPlace, record);
  }

  /// Keeps at most 5 results per person and group: the record + 4 newest.
  void _trim(String profileId, int group) {
    final mine = board.where((e) => e.profileId == profileId && e.group == group).toList();
    if (mine.length <= 5) return;
    mine.sort(cmpEntries);
    final best = mine.first;
    final others = mine.skip(1).toList()..sort((a, b) => b.date.compareTo(a.date));
    final keep = <LbEntry>{best, ...others.take(4)};
    board.removeWhere((e) => mine.contains(e) && !keep.contains(e));
  }

  void setQuizCount(int n) {
    if (n == quizCount) return;
    if (board.isNotEmpty) {
      archives.insert(0, LbArchive(count: quizCount, from: quizSince, to: now, entries: List.of(board)));
    }
    board = [];
    quizCount = n;
    quizSince = now;
    _changed();
  }

  // ---------- multiplication table game ----------

  TableGame? tableGame(String profileId) => tableGames[profileId];

  void saveTableGame(String profileId, TableGame? g) {
    if (g == null) {
      tableGames.remove(profileId);
    } else {
      tableGames[profileId] = g;
    }
    _changed();
  }
}
