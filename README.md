
# 🌿 Agroasistente
Aplicación móvil multiplataforma para el sector agrícola (AgroTech) desarrollada bajo la metodología Vibe Coding. El sistema captura imágenes en tiempo real mediante visión computacional, procesa los datos de forma segura a través de la API de Gemini, utiliza este modelo para identificar la  patologías vegetales y sugerir tratamientos específicos.
## 🔗 Demo en Vivo: 
Nota: Requiere permisos de cámara simulados o carga de la galeria de imágenes).

🎥 Demostración en Video: https://drive.google.com/file/d/1lILm8J0SXwBZXNzlCYb1MjP-dxuAmR-A/view?usp=sharing
## 🛠️ Stack Tecnológico & Arquitectura*   
*  Frontend Mobile: Flutter (Dart)
*  Hardware Integration: image_picker / Acceso nativo a Cámara y Galería de fotos.
*  Generative AI: Google AI Studio y Gemini-2.5 flash para el análisis.
*  Seguridad de API keys: oculta de forma absoluta la API Key en el servidor para el entorno web, e inyección dinámica con Dart-Define en tiempo de compilación para la aplicación móvil nativa en Flutter.
## ⚙️ Funcionalidades Clave
*   Captura Híbrida de Medios: Integración nativa con los módulos de hardware del dispositivo para captura fotográfica directa o importación desde la galería del sistema.
*   Diagnóstico de Cultivos por Visión Artificial: Utiliza el modelo de última generación de Google, Gemini 2.5 Flash, para escanear y procesar de forma inmediata imágenes de las plantas.
*   Detección Precisa: Identifica patologías comunes (como infecciones fúngicas de mildiú), plagas succionadoras (como arañuela roja o áfidos) y deficiencias nutricionales severas (como clorosis por falta de nitrógeno), genera recomendaciones farmacológicas detalladas.
*   Optimización de Producción: Módulo reactivo que, en caso de diagnosticar una planta sana, genera recomendaciones personalizadas de fertilización para maximizar el rendimiento del cultivo.


