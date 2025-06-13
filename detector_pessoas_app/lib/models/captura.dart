class Captura {
  final String id;
  final DateTime data;
  final String imagemBase64;
  final int numeroPessoas;

  Captura({
    required this.id,
    required this.data,
    required this.imagemBase64,
    required this.numeroPessoas,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'data': data.toIso8601String(),
      'imagemBase64': imagemBase64,
      'numeroPessoas': numeroPessoas,
    };
  }

  factory Captura.fromJson(Map<String, dynamic> json) {
    return Captura(
      id: json['id'],
      data: DateTime.parse(json['data']),
      imagemBase64: json['imagemBase64'],
      numeroPessoas: json['numeroPessoas'],
    );
  }
} 