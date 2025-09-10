// lib/services/ai/skills.dart
import 'dart:math';
import '../../services/location_service.dart';

class CopilotContext {
  // acá podés inyectar cámara, mini-LLM, caches, etc.
  CopilotContext();
}

abstract class CopilotSkill {
  String get name;
  Future<Map<String, dynamic>> invoke(CopilotContext ctx);
  double confidence(CopilotContext ctx, Map<String, dynamic> out);
}

/// OCR rápido (MLKit) – placeholder
class OcrSkill implements CopilotSkill {
  @override String get name => 'ocr';
  @override Future<Map<String, dynamic>> invoke(CopilotContext ctx) async {
    // TODO: MLKit TextRecognizer. Placeholder:
    return {'bestLine': 'Poste 124 sin aislador', 'tags': ['poste','aislador']};
  }
  @override double confidence(_, out)=> out['bestLine']==null?0.0:0.78;
}

/// Detector objetos (TFLite/YOLO int8) – placeholder
class ObjectsSkill implements CopilotSkill {
  @override String get name => 'objects';
  @override Future<Map<String, dynamic>> invoke(CopilotContext ctx) async {
    // TODO: TFLite. Placeholder:
    return {'topClass':'Rotura leve','tags':['rotura','cable','poste']};
  }
  @override double confidence(_, __)=>0.72;
}

/// GPS robusto con tu UltraFix
class GpsSkill implements CopilotSkill {
  @override String get name => 'gps';
  @override Future<Map<String, dynamic>> invoke(CopilotContext ctx) async {
    final fix = await LocationService.instance.getUltraFix(
      maxSamples: 8, perSampleTimeout: const Duration(seconds: 3),
      overallTimeout: const Duration(seconds: 10),
    );
    return {'lat':fix.latitude,'lng':fix.longitude,'acc':fix.accuracyMeters??30.0};
  }
  @override double confidence(_, out){
    final acc = (out['acc'] as num?)?.toDouble() ?? 99;
    return (1.0 - min(acc, 60)/60).clamp(0,1);
  }
}

/// Memoria (aprendizajes/correcciones de usuario)
class MemorySkill implements CopilotSkill {
  final Future<Map<String,dynamic>> Function() loader;
  MemorySkill(this.loader);
  @override String get name => 'memory';
  @override Future<Map<String, dynamic>> invoke(CopilotContext ctx) => loader();
  @override double confidence(_, __)=>0.6;
}
