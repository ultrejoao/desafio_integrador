import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/captura.dart';

class CapturaService {
  static const String _key = 'capturas';
  final _uuid = const Uuid();

  Future<List<Captura>> getCapturas() async {
    final prefs = await SharedPreferences.getInstance();
    final capturasJson = prefs.getStringList(_key) ?? [];
    return capturasJson
        .map((json) => Captura.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));
  }

  Future<void> salvarCaptura(String imagemBase64, int numeroPessoas) async {
    final prefs = await SharedPreferences.getInstance();
    final capturas = await getCapturas();

    final novaCaptura = Captura(
      id: _uuid.v4(),
      data: DateTime.now(),
      imagemBase64: imagemBase64,
      numeroPessoas: numeroPessoas,
    );

    capturas.add(novaCaptura);
    await prefs.setStringList(
      _key,
      capturas.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<void> deletarCaptura(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final capturas = await getCapturas();
    capturas.removeWhere((c) => c.id == id);
    await prefs.setStringList(
      _key,
      capturas.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }
} 