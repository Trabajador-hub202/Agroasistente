import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class PlantDetectorScreen extends StatefulWidget {
  const PlantDetectorScreen({super.key});

  @override
  State<PlantDetectorScreen> createState() => _PlantDetectorScreenState();
}

class _PlantDetectorScreenState extends State<PlantDetectorScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  XFile? _selectedImage;
  bool _isAnalyzing = false;
  bool _isCameraInitialized = false;

  // Resultado del Análisis
  Map<String, dynamic>? _analysisResult;

  // ==========================================================
  // CONFIGURACIÓN DINÁMICA (Ideal para Portafolio)
  // ==========================================================
  // Estas variables se pueden configurar directamente desde la interfaz de la app.
  String _proxyUrl =
      "https://ais-pre-sn7pe6hjwyi53xxo27dpfh-392080516609.us-east1.run.app/api/analyze";
  String _geminiApiKey = const String.fromEnvironment(
      'GEMINI_API_KEY'); // Se puede pasar al compilar o escribir en la app

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error inicializando cámara: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // Tomar foto con la cámara
  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cámara no lista')),
      );
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      setState(() {
        _selectedImage = image;
        _analysisResult = null;
      });
    } catch (e) {
      debugPrint("Error al tomar foto: $e");
    }
  }

  // Seleccionar de Galería
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _analysisResult = null;
      });
    }
  }

  // Analizar Imagen (Soporta Servidor Proxy o API Directa de Gemini)
  Future<void> _analyzeImage(XFile file) async {
    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final String base64Image = base64Encode(bytes);

      // Si el usuario ingresó una Clave API de Gemini, preferimos la conexión directa
      if (_geminiApiKey.trim().isNotEmpty) {
        final response = await http.post(
          Uri.parse(
              "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_geminiApiKey"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {
                    "inlineData": {
                      "mimeType": "image/jpeg",
                      "data": base64Image
                    }
                  },
                  {
                    "text":
                        'Analiza esta foto de una hoja o cultivo. Determina si tiene una enfermedad, plaga o está sana.\n\nIMPORTANTE PARA CULTIVOS SALUDABLES:\nSi el cultivo está saludable ("isHealthy": true), es ABSOLUTAMENTE OBLIGATORIO que recomiendes de 2 a 3 productos (por ejemplo, bioestimulantes, fertilizantes foliares como NPK balanceado, inductores de resistencia, fitofortificantes ecológicos, ácidos húmicos o mejoradores de suelo) enfocados en POTENCIAR, dinamizar y maximizar el rendimiento de la producción de este cultivo. ¡NUNCA dejes la lista "agrochemicals" vacía!\n\nResponde estrictamente con un formato JSON con la siguiente estructura:\n{\n  "isHealthy": true/false,\n  "cropName": "Nombre del Cultivo",\n  "conditionName": "Nombre de la Enfermedad/Plaga o \'Sano y Fuerte\'",\n  "explanation": "Explicación detallada de los síntomas observados o el estado de vigor actual.",\n  "agrochemicals": [\n    {\n      "name": "Nombre de Producto Comercial o Genérico recomendado",\n      "type": "Bioestimulante / Fungicida / Insecticida / Fertilizante",\n      "purpose": "Razón de la recomendación",\n      "application": "Dosis sugerida o método de aplicación"\n    }\n  ],\n  "agroserviceTasks": [\n    "Acción preventiva o de mantenimiento 1",\n    "Acción preventiva o de mantenimiento 2"\n  ]\n}'
                  }
                ]
              }
            ],
            "generationConfig": {
              "responseMimeType": "application/json",
              "temperature": 0.2
            }
          }),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String rawText =
              responseData['candidates'][0]['content']['parts'][0]['text'];
          final String cleanJson = rawText.substring(
              rawText.indexOf('{'), rawText.lastIndexOf('}') + 1);
          final Map<String, dynamic> data = jsonDecode(cleanJson);

          if (!mounted) return;
          setState(() {
            _analysisResult = data;
            _isAnalyzing = false;
          });
        } else {
          throw Exception(
              "Error directo de Gemini API: Código ${response.statusCode}\nVerifica que tu API Key sea correcta.");
        }
      } else {
        // De lo contrario, intentamos usar el Servidor Proxy
        if (_proxyUrl.trim().isEmpty ||
            _proxyUrl.contains("tu-proyecto-codesandbox") ||
            _proxyUrl.contains("mwktk9-3000")) {
          throw Exception('Configuración pendiente:\n\n'
              'Para realizar el análisis, abre el menú de configuración de arriba (icono de engranaje) e ingresa tu Gemini API Key o una URL de Proxy válida.');
        }

        final response = await http
            .post(
          Uri.parse(_proxyUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "imageBase64": base64Image,
          }),
        )
            .timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception(
              "Tiempo de espera agotado al conectar con el servidor Proxy.");
        });

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (!mounted) return;
          setState(() {
            _analysisResult = data;
            _isAnalyzing = false;
          });
        } else {
          throw Exception(
              "El servidor respondió con código ${response.statusCode}: ${response.body}");
        }
      }
    } catch (e) {
      debugPrint("Error analizando cultivo: $e");
      if (!mounted) return;
      _showErrorBottomSheet(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  // Mostrar error detallado de forma atractiva y con pasos de solución
  void _showErrorBottomSheet(String errorMessage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Error de Conexión',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                errorMessage.contains("SocketException")
                    ? "No se pudo conectar al servidor proxy de CodeSandbox porque la URL actual no está activa o está desconectada."
                    : errorMessage,
                style: const TextStyle(
                    fontSize: 14, color: Colors.black, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Text(
                '💡 ¿Cómo solucionarlo?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Toca el icono de engranaje (⚙️) arriba a la derecha.\n'
                '• Ingresa tu propia clave de Gemini de forma segura o actualiza la URL de tu backend.\n'
                '• ¡No requiere volver a compilar el código!',
                style: TextStyle(
                    fontSize: 13, color: Colors.blueGrey, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSettingsDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Abrir Configuración ⚙️',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // Buscar en Google Imágenes
  Future<void> _searchOnGoogleImages(String query) async {
    final searchUrl = Uri.parse(
        "https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(query)}");
    if (await canLaunchUrl(searchUrl)) {
      await launchUrl(searchUrl, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("No se pudo abrir el navegador para la búsqueda");
    }
  }

  // Mostrar diálogo de configuración dinámico en caliente (Para tu Portafolio)
  void _showSettingsDialog() {
    final proxyController = TextEditingController(text: _proxyUrl);
    final keyController = TextEditingController(text: _geminiApiKey);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.green),
              SizedBox(width: 8),
              Text('Configuración de API'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Configura cómo se conectará la app al diagnóstico fitosanitario. Ideal para demostraciones en vivo.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API Key (Recomendado)',
                    border: OutlineInputBorder(),
                    hintText: 'Pega tu clave AIzaSy...',
                    helperText: 'Conexión directa, rápida y sin servidores.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: proxyController,
                  decoration: const InputDecoration(
                    labelText: 'URL del Servidor Proxy',
                    border: OutlineInputBorder(),
                    hintText: 'https://...',
                    helperText: 'Úsala si tienes tu backend activo.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _proxyUrl = proxyController.text.trim();
                  _geminiApiKey = keyController.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Configuración guardada correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agroasistente',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Configurar Conexión',
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _pickFromGallery,
            tooltip: 'Cargar de Galería',
          )
        ],
      ),
      body: _selectedImage == null ? _buildCameraView() : _buildCapturedView(),
    );
  }

  // Vista de Cámara
  Widget _buildCameraView() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tips_and_updates, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enfoca la hoja afectada con buena luz',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.photo_library,
                      color: Colors.white, size: 28),
                  onPressed: _pickFromGallery,
                  tooltip: 'Cargar de Galería',
                ),
              ),
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  height: 84,
                  width: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.green, size: 36),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon:
                      const Icon(Icons.settings, color: Colors.white, size: 28),
                  onPressed: _showSettingsDialog,
                  tooltip: 'Configurar',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Vista de la Imagen Capturada
  Widget _buildCapturedView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Image.file(
                File(_selectedImage!.path),
                height: 380,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 380,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image_not_supported,
                          size: 50, color: Colors.grey),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _analysisResult = null;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_isAnalyzing) ...[
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const CircularProgressIndicator(
                      color: Colors.green, strokeWidth: 5),
                  const SizedBox(height: 20),
                  Text(
                    'Enviando y analizando síntomas...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green[900],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _geminiApiKey.isNotEmpty
                        ? 'Consultando directamente a Google Gemini...'
                        : 'Conectando con tu servidor proxy...',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else if (_analysisResult == null) ...[
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                      SizedBox(width: 8),
                      Text(
                        '¡Foto lista para analizar!',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _geminiApiKey.isNotEmpty
                        ? 'Presiona el botón verde de abajo para enviar la imagen y obtener el diagnóstico agronómico vía conexión directa con Gemini.'
                        : 'Presiona el botón verde de abajo para enviar la imagen al servidor proxy y obtener el diagnóstico agronómico.',
                    style:
                        const TextStyle(fontSize: 14, color: Colors.blueGrey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _analyzeImage(_selectedImage!),
                    icon: const Icon(Icons.analytics_outlined, size: 24),
                    label: const Text(
                      'ENVIAR A DIAGNÓSTICO',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _analysisResult = null;
                      });
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Tomar otra foto / Descartar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[800],
                      side: BorderSide(color: Colors.green[800]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildResultsWidget(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                    _analysisResult = null;
                  });
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Analizar otra planta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[800],
                  side: BorderSide(color: Colors.green[800]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsWidget() {
    final bool isHealthy = _analysisResult!['isHealthy'] ?? true;
    final String cropName = _analysisResult!['cropName'] ?? 'Desconocido';
    final String condition = _analysisResult!['conditionName'] ?? 'Sana';
    final String explanation = _analysisResult!['explanation'] ?? '';
    final List agrochemicals = _analysisResult!['agrochemicals'] ?? [];
    final List tasks = _analysisResult!['agroserviceTasks'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: isHealthy ? Colors.green[50] : Colors.red[50],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    isHealthy ? Icons.check_circle : Icons.warning_rounded,
                    color: isHealthy ? Colors.green[700] : Colors.red[700],
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isHealthy
                        ? 'CULTIVO SALUDABLE'
                        : 'CULTIVO ENFERMO DETECTADO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isHealthy ? Colors.green[800] : Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Planta: $cropName | Estado: $condition',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(explanation, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _searchOnGoogleImages("$cropName $condition"),
                    icon: const Icon(Icons.image_search),
                    label: const Text('Buscar en Google Imágenes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isHealthy
                ? '⭐ Recomendaciones para Potenciar la Producción:'
                : '💊 Agroquímicos para Minimizar el Daño:',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green[900]),
          ),
          const SizedBox(height: 8),
          ...agrochemicals.map((agro) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agro['name'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.blueGrey),
                    ),
                    Text(
                      'Tipo: ${agro['type'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 16),
                    Text('Propósito: ${agro['purpose'] ?? ''}'),
                    const SizedBox(height: 4),
                    Text(
                      'Aplicación: ${agro['application'] ?? ''}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text(
            isHealthy
                ? '🌱 Labores de Mantenimiento y Prevención:'
                : '🚗 Acciones inmediatas sugeridas:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isHealthy ? Colors.green[800] : Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          ...tasks.map((task) {
            return ListTile(
              leading: Icon(
                isHealthy ? Icons.eco : Icons.arrow_forward_ios,
                size: 16,
                color: isHealthy ? Colors.green : Colors.orange,
              ),
              title: Text(task, style: const TextStyle(fontSize: 14)),
              dense: true,
            );
          }),
        ],
      ),
    );
  }
}
