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
├── Modules/                     ← Arquitectura Plug & Play
│   ├── WidgetProtocol.swift     ← Reglas de los widgets (protocol Widget { id, isEnabled })
│   └── NowPlaying/
│       ├── MRMediaRemoteBridge.swift ← Puente C puro para saltar el sandbox multimedia
│       ├── NowPlayingManager.swift   ← Cerebro musical (Radio pública, AppleScript, Seeking)
│       └── NowPlayingView.swift      ← Interfaz gráfica (Carátula, Slider protegido, controles)
│
├── Settings/
│   └── SettingsView.swift       ← Interfaz gráfica para activar/desactivar widgets
│
├── Infrastructure/
│   ├── AppSettings.swift        ← @AppStorage / UserDefaults para memoria persistente
│   └── WidgetRegistry.swift     ← Lista centralizada que dice qué widgets dibujar y su orden
│
└── Docs/
    └── Architecture.md          ← Documentación viva del proyecto
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


## 4. Detalle de la Fase 2: Arquitectura Modular (Widget Registry y Ajustes)

El objetivo de esta fase fue evitar el "código espagueti". En lugar de meter todas las funciones en la ventana principal, creamos un sistema modular donde cada función (Música, Cámara, etc.) es un bloque independiente que se "enchufa" a la aplicación.

### Carpeta `Infrastructure`
* **`WidgetProtocol.swift`:** Define las reglas estrictas de lo que es un widget en nuestra app. Todo widget debe tener un `id`, un booleano `isEnabled`, y una función `makeView()` que devuelve su interfaz gráfica.
* **`WidgetRegistry.swift`:** Actúa como el centro comercial de los widgets. Es una lista ordenada que mantiene constancia de qué widgets existen y si el usuario los ha activado o desactivado. La vista principal (`NotchPanelView`) solo itera sobre este registro dibujando lo que esté encendido.
* **`AppSettings.swift`:** Un archivo centralizado usando `@AppStorage` para guardar en la memoria persistente (UserDefaults) del Mac preferencias globales, como por ejemplo si un widget específico está activado o no.

### Carpeta `Settings`
* **Sistema de Ventanas Independientes:** Se creó una ventana estándar de macOS (AppKit) totalmente desvinculada del panel físico del notch. Se invoca a través del icono de la barra de menús. Contiene el `SettingsViewModel` para interactuar con la infraestructura y permitir al usuario apagar o encender widgets mediante "toggles".

---

## 5. Detalle de la Fase 3 (Parte A): Módulo Multimedia (Now Playing)

Implementar el widget musical nativo en macOS 14+ requiere esquivar restricciones de "Sandbox" y permisos de "Automatización". No usamos `AVPlayer`, 
sino que controlamos las aplicaciones de música oficiales (Spotify y Apple Music) del usuario.

### Estructura del Módulo `NowPlaying`
* **`NowPlayingView.swift` (La Interfaz):** Dibuja la carátula, textos y botones. Implementa una lógica defensiva en SwiftUI (usando `max(0, ...)`) para la barra de progreso, evitando "crasheos" silenciosos si el reproductor envía tiempos matemáticamente negativos o desajustados.
* **`MRMediaRemoteBridge.swift` (El Puente de Comandos):** macOS bloquea el acceso público a sus controles multimedia. Usamos la API de C `dlopen` para forzar la carga de una librería privada de Apple (`MediaRemote.framework`). Esto nos permite enviar las órdenes puras del sistema (Play, Pause, Next Track) saltándonos las restricciones de las APIs de alto nivel.

### `NowPlayingManager.swift` (El Cerebro Multinúcleo)
Este archivo orquesta un sistema híbrido complejo para obtener información en tiempo real sin gastar batería:
1. **Radio Pública (`DistributedNotificationCenter`):** Escucha "gritos" silenciosos del sistema. Cuando Spotify o Music cambian de canción, mandan un aviso. Esto es instantáneo y consume 0 recursos, dándonos el Título y Artista.
2. **Descarga de Carátulas:** Si es Spotify, baja la imagen asíncronamente desde su CDN. Si es Apple Music (o el CDN de Spotify falla), hace una petición a la API pública de `iTunes Search` en alta definición (600x600).
3. **El Reloj Matemático:** En lugar de preguntar al Mac por el segundo exacto cada segundo (lo que fundiría la CPU), preguntamos *una vez* usando `NSAppleScript`. Guardamos la hora exacta en un `Date()` y calculamos visualmente el progreso con una resta matemática (`Timer.scheduledTimer` a 0.5s), logrando una animación fluida a coste 0 de rendimiento.
4. **Seeking (Control del Slider):** Al arrastrar el Slider en la interfaz, frenamos la matemática, y al soltar, enviamos una orden `NSAppleScript` ("tell application Spotify to set player position...") para que la canción salte al milisegundo deseado.

### Carpeta `Core`: Permisos de Automatización
* **`AutomationPermissionManager.swift`:** Para que el "Seeking" vía AppleScript funcione, macOS exige el permiso de *Automatización*. Como `NSAppleScript` falla en silencio y no muestra popups nativos, implementamos la API pura de C `Carbon` (`AEDeterminePermissionToAutomateTarget`). Esto fuerza a macOS a mostrar la alerta de seguridad nativa la primera vez que se abre la app, guardando el permiso permanentemente en los Ajustes del Sistema.
