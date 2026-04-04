# Arquitectura y Hoja de Ruta: Notch Panel (macOS)

## 1. Justificación de la Arquitectura

Para construir un clon de Notch Nook nativo para macOS, nos enfrentamos a un reto fundamental: **SwiftUI no está diseñado para crear ventanas flotantes complejas, sin bordes y dinámicas**. 

Si dependiéramos únicamente de SwiftUI para gestionar la ventana, sufriríamos tirones en las animaciones, desajustes visuales y falta de control sobre los permisos del sistema operativo. Por ello, hemos optado por una **arquitectura híbrida (AppKit + SwiftUI)** basada en el patrón de diseño **MVVM (Model-View-ViewModel)** y una estricta separación de responsabilidades:

* **AppKit (`NSPanel`, `NSWindowController`):** Se encarga exclusivamente del trabajo "sucio" de bajo nivel. Controla la física de la ventana (que no tenga bordes, que flote sobre otras apps, que se oculte del Dock) y lee el hardware del Mac (tamaño físico del notch).
* **SwiftUI:** Se utiliza única y exclusivamente como un motor de renderizado visual (la interfaz). Dibuja los fondos negros, los textos, las animaciones de los botones y los widgets.
* **Patrón Manager + View + ViewModel:** Para asegurar que la app escale sin convertirse en código espagueti. Cada futuro módulo (Cámara, Spotify, Calendario) tendrá un `Manager` que hable con el sistema, un `ViewModel` que traduzca los datos, y una `View` tonta que solo los muestre.

---

## 2. Plan de Desarrollo (Roadmap de 6 Fases)

1.  **Fase 1: Núcleo y Hover (Completada):** Cimientos de la app. Eliminación de ventanas por defecto, cálculo matemático del hardware del notch físico, y un sistema global de rastreo del ratón para expandir/contraer el panel.
2.  **Fase 2: Arquitectura Modular:** Creación de un sistema "Plug & Play" (WidgetRegistry). Esto nos permitirá inyectar nuevas funcionalidades sin romper el núcleo. Implementación de la ventana gráfica de Ajustes.
3.  **Fase 3: Multimedia y Calendario:** Conexión con `MRMediaRemote` para controlar Spotify/Apple Music, y `EventKit` para leer los próximos eventos del día.
4.  **Fase 4: Espejo (Cámara) y Dropzone:** Integración con `AVFoundation` para un feed de video en vivo y un sistema de Drag & Drop para guardar archivos temporalmente en memoria.
5.  **Fase 5: Atajos y Sistema:** Monitorización de recursos del Mac (CPU, RAM, Batería) y ejecución nativa de Atajos de macOS.
6.  **Fase 6: Pulido y Distribución:** Refinamiento de animaciones y empaquetado final de la aplicación para su uso independiente.

**Esta es la estructura de carpetas**

```text
NotchPanel/
├── NotchPanelApp.swift          ← Entry point, NSApplicationDelegateAdaptor
│
├── Core/
│   ├── AppDelegate.swift        ← NSPanel lifecycle, primera ventana eliminada aquí
│   ├── PanelWindowController.swift  ← Controla posición, expansión física y animación
│   ├── PanelViewModel.swift     ← @Published isExpanded, dimensiones de la ventana
│   └── HoverDetector.swift      ← NSEvent global/local (mouse tracking e histéresis)
│
├── Views/
│   └── NotchPanelView.swift     ← La carcasa visual de SwiftUI
│
├── Modules/                     ← Cada widget es un módulo autocontenido
│   ├── WidgetProtocol.swift     ← protocol Widget: View { var id, isEnabled }
│   ├── NowPlaying/
│   │   ├── NowPlayingView.swift
│   │   └── NowPlayingManager.swift  
│   ├── Camera/
│   │   ├── CameraView.swift
│   │   └── CameraManager.swift      
│   └── ... (Resto de módulos)
│
├── Settings/
│   ├── SettingsWindowController.swift 
│   ├── SettingsView.swift             
│   └── SettingsViewModel.swift
│
├── Permissions/
│   └── PermissionsManager.swift  ← Orquesta todos los NSAlert de permisos
│
├── Infrastructure/
│   ├── AppSettings.swift         ← @AppStorage / UserDefaults wrapper
│   ├── WidgetRegistry.swift      ← Registro central, orden y estado de módulos
│   └── MenuBarController.swift   ← Menú contextual de salida y ajustes
│
└── Docs/
    └── Architecture.md           ← Documentación del proyecto

---

## 3. Detalle de la Fase 1: El Núcleo

En esta fase hemos establecido la base estructural. Cada archivo tiene una responsabilidad única y aislada:

### Archivos de Entrada y UI (Raíz)
* **`NotchPanelApp.swift` (El Entry Point): Es el primer código que se ejecuta. Utiliza NSApplicationDelegateAdaptor para delegar el control al AppDelegate. Su misión crítica es usar Settings { EmptyView() } para evitar que macOS genere una ventana en blanco por defecto.
* **`NotchPanelView.swift` (La Interfaz):** * *Función:* Es la "carcasa" visual de SwiftUI. Dibuja el fondo negro, redondea las esquinas inferiores e incluye una animación `.transition(.opacity)` para mostrar el contenido cuando el panel se expande.

### Carpeta `Core` (Lógica del Sistema)
* **`AppDelegate.swift` (El Gestor del Ciclo de Vida):** * *Función:* Arranca el motor. Inicializa el controlador de la ventana y el detector del ratón. Además, crea el `NSStatusItem`, que es el icono que reside en la barra de menú superior de macOS, permitiendo al usuario cerrar la aplicación limpiamente.
* **`PanelWindowController.swift` (El Conductor Físico):** * *Función:* Es el puente entre el sistema operativo y la app. Crea el `NSPanel` (la ventana invisible), calcula matemáticamente las dimensiones del notch físico leyendo la propiedad `NSScreen.main?.auxiliaryTopLeftArea` de la pantalla del M5, y ejecuta la animación de expansión nativa de AppKit (`NSAnimationContext`).
* **`PanelViewModel.swift` (El Cerebro / Estado):** * *Función:* Actúa como la única fuente de la verdad. Mantiene el estado reactivo (`@Published var isExpanded`). Cuando esta variable cambia, avisa automáticamente a `NotchPanelView` para que dibuje el contenido y a `PanelWindowController` para que cambie el tamaño de la ventana física.
* **`HoverDetector.swift` (El Sensor):** * *Función:* Utiliza `NSEvent.addGlobalMonitorForEvents` para rastrear la posición del puntero a nivel del sistema, incluso cuando el usuario está usando otras aplicaciones (como Safari o WhatsApp). Si el puntero entra en las coordenadas de la ventana, cambia el estado del `PanelViewModel` a expandido. Utiliza variables de estado (`wasInside`) para no saturar el uso de CPU.


