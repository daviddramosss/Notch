# Arquitectura y Hoja de Ruta: Notch Panel (macOS)

## 1. Justificación de la Arquitectura

Para construir un clon de Notch Nook nativo para macOS, me enfrenté a un reto fundamental: **SwiftUI no está diseñado para crear ventanas flotantes complejas, sin bordes y dinámicas**. 

Si dependiera únicamente de SwiftUI para gestionar la ventana, la aplicación sufriría tirones en las animaciones, desajustes visuales y una grave falta de control sobre los permisos del sistema operativo. Por ello, he optado por una **arquitectura híbrida (AppKit + SwiftUI)** basada en el patrón de diseño **MVVM (Model-View-ViewModel)** y una estricta separación de responsabilidades:

* **AppKit (`NSPanel`, `NSWindowController`):** Se encarga exclusivamente del trabajo "sucio" de bajo nivel. Controla la física de la ventana (que no tenga bordes, que flote sobre otras apps, que se oculte del Dock) y lee el hardware del Mac (tamaño físico del notch).
* **SwiftUI:** Lo utilizo única y exclusivamente como un motor de renderizado visual (la interfaz). Dibuja los fondos negros, los textos, las animaciones de los botones y los widgets.
* **Patrón Manager + View + ViewModel:** Para asegurar que la app escale sin convertirse en código espagueti. He diseñado cada futuro módulo (Cámara, Spotify, Calendario) para que tenga un `Manager` que hable con el sistema, un `ViewModel` que traduzca los datos, y una `View` tonta que solo los muestre.

---

## 2. Plan de Desarrollo (Roadmap de 6 Fases)

1.  **Fase 1: Núcleo y Hover (Completada):** Cimientos de la app. Eliminación de ventanas por defecto, cálculo matemático del hardware del notch físico, y un sistema global de rastreo del ratón para expandir/contraer el panel.
2.  **Fase 2: Arquitectura Modular:** Creación de un sistema "Plug & Play" (WidgetRegistry). Esto me permitirá inyectar nuevas funcionalidades sin romper el núcleo. Implementación de la ventana gráfica de Ajustes.
3.  **Fase 3: Multimedia y Calendario:** Conexión con `MRMediaRemote` para controlar Spotify/Apple Music, y `EventKit` para leer los próximos eventos del día.
4.  **Fase 4: Espejo (Cámara) y Dropzone:** Integración con `AVFoundation` para un feed de video en vivo y un sistema de Drag & Drop para guardar archivos temporalmente en memoria.
5.  **Fase 5: Atajos y Sistema:** Monitorización de recursos del Mac (CPU, RAM, Batería) y conexión con Bluetooth para AirPods.
6.  **Fase 6: Pulido y Distribución:** Refinamiento de animaciones y empaquetado final de la aplicación para su uso independiente.

---

## Estructura de Carpetas

```text
NotchPanel/
├── NotchPanelApp.swift          ← Entry point, NSApplicationDelegateAdaptor
├── NotchPanelView.swift         ← La carcasa visual de SwiftUI (Raíz)
├── Assets.xcassets              ← Contiene el logo de Spotify y recursos visuales
├── Info.plist                   ← Declaración de permisos del sistema (AppleEvents)
│
├── Core/
│   ├── AppDelegate.swift        ← Ciclo de vida, elimina ventana inicial y pide permisos
│   ├── AutomationPermissionManager.swift ← Fuerza popups nativos de macOS (Carbon API)
│   ├── PanelWindowController.swift ← Controla posición, física del notch y animación
│   ├── PanelViewModel.swift     ← Estado (@Published isExpanded) y dimensiones
│   └── HoverDetector.swift      ← Rastreo de puntero (NSEvent) e histéresis
│
├── Docs/
│   └── Architecture.md          ← Documentación viva del proyecto
│
├── Infrastructure/
│   ├── AppSettings.swift        ← @AppStorage / UserDefaults para memoria persistente
│   └── WidgetRegistry.swift     ← Lista centralizada que dice qué widgets dibujar y su orden
│
├── Modules/                     ← Arquitectura Plug & Play
│   ├── Calendar/
│   │   ├── CalendarView.swift   ← Interfaz gráfica de los eventos
│   │   └── CalendarWidgetManager.swift ← Lógica de EventKit para leer el calendario
│   ├── Camera/
│   │   ├── CameraManager.swift  ← Interfaz con AVFoundation para captura de video
│   │   └── CameraView.swift     ← NSViewRepresentable para renderizar el feed de video
│   ├── DropZone/
│   │   ├── DropzoneManager.swift ← Almacenamiento temporal en memoria de archivos arrastrados
│   │   └── DropzoneView.swift   ← Interfaz responsiva para onDrop y previsualización
│   ├── NowPlaying/
│   │   ├── MRMediaRemoteBridge.swift ← Puente C puro para saltar el sandbox multimedia
│   │   ├── NowPlayingManager.swift   ← Cerebro musical (Radio pública, AppleScript, Seeking)
│   │   └── NowPlayingView.swift      ← Interfaz gráfica (Carátula, Slider protegido, controles)
│   ├── SystemMonitor/
│   │   ├── AirPodsInfo.swift         ← Modelo de datos de batería
│   │   ├── BluetoothManager.swift    ← Conexión con IOBluetooth para rastrear periféricos
│   │   ├── SystemHeaderView.swift    ← Cabecera de estadísticas dibujada en el panel
│   │   ├── SystemMonitorManager.swift ← Gestor central de lecturas del sistema
│   │   └── SystemStats.swift         ← Interfaz de bajo nivel (API Mach/Darwin) para CPU/RAM
│   └── WidgetProtocol.swift     ← Reglas de los widgets (protocol Widget { id, isEnabled })
│
├── Permissions/
│   └── PermissionsManager.swift ← Orquestador global de permisos (Cámara, Calendario, etc.)
│
└── Settings/
    └── SettingsView.swift       ← Interfaz gráfica para activar/desactivar widgets
