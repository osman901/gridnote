import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class DictationState {
  final bool available;
  final bool listening;
  final double level; // 0..1
  const DictationState({required this.available, required this.listening, required this.level});

  DictationState copyWith({bool? available, bool? listening, double? level}) =>
      DictationState(
        available: available ?? this.available,
        listening: listening ?? this.listening,
        level: level ?? this.level,
      );
}

class DictationService {
  DictationService._();
  static final instance = DictationService._();

  final _stt = stt.SpeechToText();
  final _stateCtrl = StreamController<DictationState>.broadcast();
  DictationState _state = const DictationState(available: false, listening: false, level: 0);

  Stream<DictationState> get states => _stateCtrl.stream;
  bool get isListening => _state.listening;

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final req = await Permission.microphone.request();
    return req.isGranted;
  }

  Future<bool> init() async {
    final hasPerm = await _ensureMicPermission();
    if (!hasPerm) {
      _emit(_state.copyWith(available: false, listening: false, level: 0));
      return false;
    }

    final ok = await _stt.initialize(
      onStatus: (s) {
        final ls = s.toLowerCase();
        final listening = ls.contains('listening') || (!ls.contains('notlistening') && _stt.isListening);
        _emit(_state.copyWith(listening: listening));
      },
      onError: (_) => _emit(_state.copyWith(listening: false, level: 0)),
      debugLogging: false,
    );
    _emit(_state.copyWith(available: ok));
    return ok;
  }

  Future<void> start({
    String localeId = 'es_AR',
    void Function(String text)? onFinalText,
  }) async {
    if (!_state.available) {
      final ok = await init();
      if (!ok) return;
    }
    await _stt.listen(
      localeId: localeId,
      onResult: (r) {
        if (r.finalResult) {
          final text = r.recognizedWords.trim();
          if (text.isNotEmpty) onFinalText?.call(text);
        }
      },
      onSoundLevelChange: (level) {
        final norm = (level / 20.0).clamp(0.0, 1.0);
        _emit(_state.copyWith(level: norm));
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      ),
    );
    _emit(_state.copyWith(listening: true));
  }

  Future<void> stop() async {
    await _stt.stop();
    _emit(_state.copyWith(listening: false, level: 0));
  }

  Future<void> cancel() async {
    await _stt.cancel();
    _emit(_state.copyWith(listening: false, level: 0));
  }

  void _emit(DictationState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void dispose() {
    _stateCtrl.close();
  }
}
