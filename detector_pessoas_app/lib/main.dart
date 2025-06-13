import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/historico_screen.dart';
import 'services/captura_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Detector de Pessoas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: HomePage(cameras: cameras),
    );
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({super.key, required this.cameras});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late CameraController _controller;
  bool _cameraInicializada = false;
  Uint8List? _imagemProcessada;
  int _contadorPessoas = 0;
  bool _processando = false;
  bool _capturando = false;
  int _indiceAtual = 0;
  late TabController _tabController;
  final _capturaService = CapturaService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _inicializarCamera();
  }

  Future<void> _inicializarCamera() async {
    if (widget.cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma câmera encontrada'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller.initialize();
      setState(() {
        _cameraInicializada = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao inicializar câmera: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _capturarEProcessar() async {
    if (!_cameraInicializada) return;

    setState(() {
      _capturando = true;
    });

    try {
      final imagem = await _controller.takePicture();
      final bytes = await imagem.readAsBytes();
      _processarImagem(bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao capturar imagem: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _capturando = false;
      });
    }
  }

  Future<void> _processarImagem(Uint8List imagem) async {
    setState(() {
      _processando = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/detectar'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'imagem',
          imagem,
          filename: 'imagem.jpg',
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      setState(() {
        _imagemProcessada = base64Decode(jsonData['imagem']);
        _contadorPessoas = jsonData['contador_pessoas'];
        _processando = false;
      });

      // Salvar a captura
      await _capturaService.salvarCaptura(
        jsonData['imagem'],
        _contadorPessoas,
      );
    } catch (e) {
      setState(() {
        _processando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar imagem: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector de Pessoas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt), text: 'Câmera'),
            Tab(icon: Icon(Icons.photo_library), text: 'Histórico'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Câmera
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_cameraInicializada) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text('Inicializando câmera...'),
                  ] else ...[
                    const SizedBox(height: 20),
                    Text(
                      'Câmera',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Hero(
                      tag: 'camera_preview',
                      child: SizedBox(
                        height: 300,
                        child: CameraPreview(_controller),
                      ),
                    ),
                  ],
                  if (_imagemProcessada != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Imagem Processada',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Hero(
                      tag: 'processed_image',
                      child: Image.memory(
                        _imagemProcessada!,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                  if (_processando) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    const Text('Processando imagem...'),
                  ],
                ],
              ),
            ),
          ),
          // Tab Histórico
          const HistoricoScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _cameraInicializada && !_processando && !_capturando
                  ? _capturarEProcessar
                  : null,
              label: Text(_capturando ? 'Capturando...' : 'Capturar e Processar'),
              icon: const Icon(Icons.camera_alt),
            )
          : null,
    );
  }
}
