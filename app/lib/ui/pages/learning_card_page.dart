import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/learning_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../database/local_database.dart';
import '../../models/vocabulary_list.dart';
import '../../models/word.dart';
import '../../managers/learning_manager.dart';

/// 题型
enum QuizType {
  enToCn,       // 英选中：显示英文，选中文释义
  cnToEn,       // 中选英：显示中文释义，选英文单词
  fillLetters,  // 填字母：显示中文释义+部分字母，选缺失部分
}

/// 学习卡片页面 - 背单词模式
///
/// 流程：直接出题 → 答对下一个 → 答错显示完整释义/发音卡片
class LearningCardPage extends StatefulWidget {
  final VocabularyList vocabularyList;
  final LearningMode mode;
  final int dailyLimit;
  final int todayLearned;

  const LearningCardPage({
    super.key,
    required this.vocabularyList,
    required this.mode,
    this.dailyLimit = 20,
    this.todayLearned = 0,
  });

  @override
  State<LearningCardPage> createState() => _LearningCardPageState();
}

class _LearningCardPageState extends State<LearningCardPage> {
  LearningSession? _session;
  Word? _currentWord;
  bool _isLoading = true;
  int _currentIndex = 0;
  int _totalWords = 0;

  // 今日计划
  int _correctCount = 0;
  int _wrongCount = 0;
  int _dailyLimit = 20;
  int _todayLearnedBefore = 0;

  // 出题
  QuizType _quizType = QuizType.enToCn;
  List<String> _choices = [];
  int _correctChoiceIndex = 0;
  int? _selectedChoiceIndex;
  bool? _isAnswerCorrect;

  // 填字母题
  String _fillDisplay = '';
  String _fillMissing = '';
  List<String> _fillChoices = [];
  int _fillCorrectIndex = 0;

  // 阶段: quiz -> result(仅答错) 
  String _phase = 'quiz';

  final Random _random = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// 将释义中包含当前单词的部分替换为 ***（不区分大小写，含变形如复数等）
  String _maskWordInText(String text, String word) {
    if (word.isEmpty) return text;
    final lower = word.toLowerCase();
    // 匹配单词本身及常见变形（复数s/es, ing, ed, er, est, ly, tion, ment等）
    final escaped = RegExp.escape(lower);
    final pattern = RegExp(
      '$escaped(?:s|es|ed|ing|er|est|ly|tion|ment|ness|ful|less|able|ible|ous|ive|al|ial)?',
      caseSensitive: false,
    );
    return text.replaceAll(pattern, '***');
  }

  @override
  void initState() {
    super.initState();
    _dailyLimit = widget.dailyLimit;
    _todayLearnedBefore = widget.todayLearned;
    _startLearningSession();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    if (_session != null) {
      try {
        context.read<LearningProvider>().learningManager.endLearningSession(_session!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _playPronunciation({int type = 1}) async {
    if (_currentWord == null) return;
    try {
      final url = 'https://dict.youdao.com/dictvoice?type=$type&audio=${Uri.encodeComponent(_currentWord!.word)}';
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {}
  }

  Future<void> _startLearningSession() async {
    setState(() => _isLoading = true);
    try {
      final lm = context.read<LearningProvider>().learningManager;
      final session = await lm.startLearningSession(widget.vocabularyList.id, widget.mode);
      final count = await lm.getUnlearnedWordCount(widget.vocabularyList.id);
      if (mounted) {
        // 本次会话最多学习 dailyLimit - todayLearnedBefore 个
        final remaining = (_dailyLimit - _todayLearnedBefore).clamp(0, count);
        setState(() { _session = session; _totalWords = remaining > 0 ? remaining : count; });
        await _loadNextWord();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('启动学习失败: ${_getErrorMessage(e)}');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadNextWord() async {
    if (_session == null) return;
    // 达到今日计划上限
    if (_currentIndex >= _totalWords) {
      await _showCompletionStats();
      return;
    }
    setState(() {
      _isLoading = true;
      _phase = 'quiz';
      _selectedChoiceIndex = null;
      _isAnswerCorrect = null;
    });
    try {
      final lm = context.read<LearningProvider>().learningManager;
      final word = await lm.getNextWord(_session!);
      if (mounted) {
        if (word == null) {
          await _showCompletionStats();
        } else {
          _currentWord = word;
          _currentIndex++;
          await _prepareQuiz();
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('加载单词失败: ${_getErrorMessage(e)}');
      }
    }
  }

  Future<void> _prepareQuiz() async {
    if (_currentWord == null) return;
    // 随机选题型
    final types = QuizType.values;
    _quizType = types[_random.nextInt(types.length)];

    final localDb = context.read<LocalDatabase>();
    final wrongWords = await localDb.getSimilarWordsForQuiz(
      widget.vocabularyList.id, _currentWord!.id, _currentWord!.word, 3,
    );

    switch (_quizType) {
      case QuizType.enToCn:
        // 英文 → 选中文释义
        final options = wrongWords.map((w) => w.definition).toList();
        options.add(_currentWord!.definition);
        options.shuffle(_random);
        _choices = options;
        _correctChoiceIndex = _choices.indexOf(_currentWord!.definition);
        break;
      case QuizType.cnToEn:
        // 中文释义 → 选英文单词
        final options = wrongWords.map((w) => w.word).toList();
        options.add(_currentWord!.word);
        options.shuffle(_random);
        _choices = options;
        _correctChoiceIndex = _choices.indexOf(_currentWord!.word);
        break;
      case QuizType.fillLetters:
        _prepareFillLetters(wrongWords);
        break;
    }
  }

  void _prepareFillLetters(List<Word> wrongWords) {
    final word = _currentWord!.word;
    if (word.length < 3) {
      _quizType = QuizType.enToCn;
      final options = wrongWords.map((w) => w.definition).toList();
      options.add(_currentWord!.definition);
      options.shuffle(_random);
      _choices = options;
      _correctChoiceIndex = _choices.indexOf(_currentWord!.definition);
      return;
    }
    // 随机隐藏一段连续字母(2-3个)
    final hideLen = word.length <= 4 ? 2 : (_random.nextInt(2) + 2);
    final maxStart = word.length - hideLen;
    final start = _random.nextInt(maxStart + 1);
    _fillMissing = word.substring(start, start + hideLen);
    _fillDisplay = '${word.substring(0, start)}${'_' * hideLen}${word.substring(start + hideLen)}';

    // 生成高迷惑性干扰项
    final wrongOptions = <String>{};
    
    // 策略1：字母交换（把正确片段的相邻字母互换）
    if (_fillMissing.length >= 2) {
      for (int i = 0; i < _fillMissing.length - 1 && wrongOptions.length < 3; i++) {
        final chars = _fillMissing.split('');
        final tmp = chars[i];
        chars[i] = chars[i + 1];
        chars[i + 1] = tmp;
        final swapped = chars.join();
        if (swapped != _fillMissing) wrongOptions.add(swapped);
      }
    }
    
    // 策略2：常见易混淆字母替换
    const confusables = {
      'a': ['e', 'o', 'u'],
      'e': ['a', 'i', 'o'],
      'i': ['e', 'y', 'a'],
      'o': ['u', 'a', 'e'],
      'u': ['o', 'a', 'i'],
      'b': ['d', 'p'],
      'd': ['b', 't'],
      'p': ['b', 'q'],
      'q': ['p', 'g'],
      'g': ['q', 'j'],
      'c': ['k', 's'],
      'k': ['c', 'g'],
      's': ['c', 'z'],
      'z': ['s', 'x'],
      'n': ['m', 'u'],
      'm': ['n', 'w'],
      't': ['d', 'f'],
      'f': ['v', 't'],
      'v': ['f', 'w'],
      'w': ['v', 'm'],
      'l': ['r', 'i'],
      'r': ['l', 'n'],
    };
    for (int i = 0; i < _fillMissing.length && wrongOptions.length < 3; i++) {
      final ch = _fillMissing[i].toLowerCase();
      if (confusables.containsKey(ch)) {
        for (final replacement in confusables[ch]!) {
          if (wrongOptions.length >= 3) break;
          final chars = _fillMissing.split('');
          chars[i] = _fillMissing[i] == _fillMissing[i].toUpperCase()
              ? replacement.toUpperCase()
              : replacement;
          final variant = chars.join();
          if (variant != _fillMissing) wrongOptions.add(variant);
        }
      }
    }
    
    // 策略3：反转片段
    if (wrongOptions.length < 3) {
      final reversed = _fillMissing.split('').reversed.join();
      if (reversed != _fillMissing) wrongOptions.add(reversed);
    }
    
    // 策略4：从相似单词中截取同位置片段
    for (final w in wrongWords) {
      if (wrongOptions.length >= 3) break;
      if (w.word.length >= start + hideLen) {
        final fragment = w.word.substring(start, start + hideLen);
        if (fragment != _fillMissing) wrongOptions.add(fragment);
      } else if (w.word.length >= hideLen) {
        final s = _random.nextInt(w.word.length - hideLen + 1);
        final fragment = w.word.substring(s, s + hideLen);
        if (fragment != _fillMissing) wrongOptions.add(fragment);
      }
    }
    
    // 补足：随机字母
    while (wrongOptions.length < 3) {
      final chars = List.generate(hideLen, (_) => String.fromCharCode(97 + _random.nextInt(26)));
      final fake = chars.join();
      if (fake != _fillMissing && !wrongOptions.contains(fake)) wrongOptions.add(fake);
    }

    final options = wrongOptions.take(3).toList();
    options.add(_fillMissing);
    options.shuffle(_random);
    _fillChoices = options;
    _fillCorrectIndex = _fillChoices.indexOf(_fillMissing);
  }

  void _onSelectChoice(int index) {
    if (_selectedChoiceIndex != null) return;
    final correct = index == _correctChoiceIndex;
    setState(() {
      _selectedChoiceIndex = index;
      _isAnswerCorrect = correct;
    });
    _recordAnswer(correct);
    if (correct) {
      // 答对：短暂显示绿色后自动下一个
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _loadNextWord();
      });
    } else {
      // 答错：进入结果页，显示完整释义和发音
      setState(() => _phase = 'result');
    }
  }

  void _onSelectFill(int index) {
    if (_selectedChoiceIndex != null) return;
    final correct = index == _fillCorrectIndex;
    setState(() {
      _selectedChoiceIndex = index;
      _isAnswerCorrect = correct;
    });
    _recordAnswer(correct);
    if (correct) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _loadNextWord();
      });
    } else {
      setState(() => _phase = 'result');
    }
  }

  Future<void> _recordAnswer(bool correct) async {
    if (_currentWord == null || _session == null) return;
    setState(() {
      if (correct) { _correctCount++; } else { _wrongCount++; }
    });
    try {
      final lm = context.read<LearningProvider>().learningManager;
      if (correct) {
        await lm.markWordAsKnown(_currentWord!.id, widget.vocabularyList.id);
      } else {
        await lm.markWordAsUnknown(_currentWord!.id, widget.vocabularyList.id);
      }
    } catch (_) {}
  }

  Future<void> _showCompletionStats() async {
    if (_session == null) return;
    try {
      final lm = context.read<LearningProvider>().learningManager;
      final stats = await lm.endLearningSession(_session!);
      _session = null;

      // 更新统计数据
      try {
        final sp = context.read<StatisticsProvider>();
        await sp.statisticsManager.incrementTodayNewWords(stats.totalWordsLearned);
        await sp.statisticsManager.updateStatistics();
      } catch (_) {}

      if (mounted) {
        final minutes = stats.duration.inMinutes;
        final seconds = stats.duration.inSeconds % 60;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Icon(Icons.celebration, color: Colors.amber.shade600, size: 32),
              const SizedBox(width: 12),
              const Text('学习完成！', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              _statRow(Icons.library_books, Colors.blue, '学习单词', '${stats.totalWordsLearned}'),
              const SizedBox(height: 10),
              _statRow(Icons.check_circle, Colors.green, '答对', '${stats.knownWordsCount}'),
              const SizedBox(height: 10),
              _statRow(Icons.error, Colors.orange, '答错', '${stats.unknownWordsCount}'),
              const SizedBox(height: 10),
              _statRow(Icons.timer, Colors.purple, '用时', '$minutes分$seconds秒'),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))],
          ),
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) { _showError('结束会话失败'); Navigator.pop(context); }
    }
  }

  Widget _statRow(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认退出'),
            content: const Text('确定要退出学习吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
            ],
          ),
        );
        if (shouldPop == true && mounted) {
          if (_session != null) {
            try { context.read<LearningProvider>().learningManager.endLearningSession(_session!); _session = null; } catch (_) {}
          }
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.mode == LearningMode.random ? '随机学习' : '顺序学习'),
          backgroundColor: Colors.blue, foregroundColor: Colors.white,
          actions: [
            if (_totalWords > 0) Center(child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$_currentIndex/$_totalWords', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentWord == null
                ? const Center(child: Text('没有可学习的单词'))
                : Column(children: [
                    LinearProgressIndicator(
                      value: _totalWords > 0 ? _currentIndex / _totalWords : 0,
                      minHeight: 4, backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                    Expanded(child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        _phase == 'quiz' ? _buildQuiz() : _buildWrongResult(),
                        const SizedBox(height: 16),
                        _buildSessionStats(),
                      ]),
                    )),
                  ]),
      ),
    );
  }

  /// 本次学习进度统计
  Widget _buildSessionStats() {
    final todayTotal = _todayLearnedBefore + _currentIndex;
    final pct = _dailyLimit > 0 ? (todayTotal / _dailyLimit).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.trending_up, color: Colors.blue.shade600, size: 18),
          const SizedBox(width: 6),
          Text('今日进度 $todayTotal/$_dailyLimit', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
            child: Text('✓ $_correctCount', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
            child: Text('✗ $_wrongCount', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400)),
        ),
      ]),
    );
  }

  /// 出题界面
  Widget _buildQuiz() {
    switch (_quizType) {
      case QuizType.enToCn:
        return _buildEnToCnQuiz();
      case QuizType.cnToEn:
        return _buildCnToEnQuiz();
      case QuizType.fillLetters:
        return _buildFillLettersQuiz();
    }
  }

  /// 英选中：显示英文单词，选中文释义
  Widget _buildEnToCnQuiz() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _quizHeader('请选择正确的中文释义'),
      const SizedBox(height: 24),
      // 英文单词
      Card(
        elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24), child: Column(children: [
          Text(_currentWord!.word, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
          if (_currentWord!.phonetic != null && _currentWord!.phonetic!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_currentWord!.phonetic!, style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontFamilyFallback: const ['Noto Sans', 'Arial Unicode MS', 'Lucida Grande'])),
          ],
        ])),
      ),
      const SizedBox(height: 24),
      ..._buildChoiceButtons(_choices, _correctChoiceIndex, _onSelectChoice),
    ]);
  }

  /// 中选英：显示中文释义，选英文单词
  Widget _buildCnToEnQuiz() {
    final maskedDef = _maskWordInText(_currentWord!.definition, _currentWord!.word);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _quizHeader('请选择对应的英文单词'),
      const SizedBox(height: 24),
      Card(
        elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24), child: Column(children: [
          Text(maskedDef, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.4), textAlign: TextAlign.center),
          if (_currentWord!.partOfSpeech != null && _currentWord!.partOfSpeech!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_currentWord!.partOfSpeech!, style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
            ),
          ],
        ])),
      ),
      const SizedBox(height: 24),
      ..._buildChoiceButtons(_choices, _correctChoiceIndex, _onSelectChoice),
    ]);
  }

  /// 填字母：显示中文释义+部分字母，选缺失部分
  Widget _buildFillLettersQuiz() {
    final maskedDef = _maskWordInText(_currentWord!.definition, _currentWord!.word);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _quizHeader('请选择缺失的字母'),
      const SizedBox(height: 24),
      Card(
        elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24), child: Column(children: [
          Text(maskedDef, style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.4), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Text(_fillDisplay, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, fontFamily: 'monospace'), textAlign: TextAlign.center),
        ])),
      ),
      const SizedBox(height: 24),
      ..._buildChoiceButtons(_fillChoices, _fillCorrectIndex, _onSelectFill),
    ]);
  }

  Widget _quizHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 15, color: Colors.blue.shade800, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
    );
  }

  List<Widget> _buildChoiceButtons(List<String> choices, int correctIndex, void Function(int) onSelect) {
    return List.generate(choices.length, (i) {
      final letter = String.fromCharCode(65 + i);
      Color bgColor = Colors.white;
      Color borderColor = Colors.grey.shade300;
      Color textColor = Colors.black87;

      if (_selectedChoiceIndex != null) {
        if (i == correctIndex) {
          bgColor = Colors.green.shade50;
          borderColor = Colors.green;
          textColor = Colors.green.shade800;
        } else if (i == _selectedChoiceIndex && i != correctIndex) {
          bgColor = Colors.red.shade50;
          borderColor = Colors.red;
          textColor = Colors.red.shade800;
        }
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _selectedChoiceIndex == null ? () => onSelect(i) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(letter, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade700))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(choices[i], style: TextStyle(fontSize: 16, color: textColor), maxLines: 3, overflow: TextOverflow.ellipsis)),
                if (_selectedChoiceIndex != null && i == correctIndex)
                  const Icon(Icons.check_circle, color: Colors.green, size: 22),
                if (_selectedChoiceIndex != null && i == _selectedChoiceIndex && i != correctIndex)
                  const Icon(Icons.cancel, color: Colors.red, size: 22),
              ]),
            ),
          ),
        ),
      );
    });
  }

  /// 答错后的结果页：显示完整释义、发音、例句
  Widget _buildWrongResult() {
    return Column(children: [
      const Icon(Icons.cancel, color: Colors.red, size: 64),
      const SizedBox(height: 8),
      const Text('回答错误', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
      const SizedBox(height: 20),
      Card(
        elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          Text(_currentWord!.word, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // 发音按钮
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () => _playPronunciation(type: 1), icon: Icon(Icons.volume_up, color: Colors.blue.shade600), tooltip: '美音'),
            Text('美音', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(width: 16),
            IconButton(onPressed: () => _playPronunciation(type: 2), icon: Icon(Icons.volume_up, color: Colors.orange.shade600), tooltip: '英音'),
            Text('英音', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
          if (_currentWord!.phonetic != null && _currentWord!.phonetic!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_currentWord!.phonetic!, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontFamilyFallback: const ['Noto Sans', 'Arial Unicode MS', 'Lucida Grande'])),
          ],
          const SizedBox(height: 16),
          // 释义
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('正确释义', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              const SizedBox(height: 6),
              Text(_currentWord!.definition, style: const TextStyle(fontSize: 17, color: Colors.black87, height: 1.4)),
            ]),
          ),
          if (_currentWord!.partOfSpeech != null && _currentWord!.partOfSpeech!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
              child: Text(_currentWord!.partOfSpeech!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            )),
          ],
          if (_currentWord!.example != null && _currentWord!.example!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.format_quote, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 4),
                  Text('例句', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                Text(_currentWord!.example!, style: TextStyle(fontSize: 14, color: Colors.green.shade900, height: 1.4, fontStyle: FontStyle.italic)),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text('这个单词会在1天后再次出现', style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
            ]),
          ),
        ])),
      ),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () => _loadNextWord(),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('下一个', style: TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      )),
    ]);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  String _getErrorMessage(dynamic e) {
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return e.toString();
  }
}
