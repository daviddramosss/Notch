# Arquitectura y Hoja de Ruta: Notch Panel (macOS)

## 1. Justificación de la Arquitectura

Notch Panel está diseñado como una utilidad nativa para macOS que emula y amplía el concepto de "Dynamic Island" en la pantalla de los Mac con muesca (notch).

Para lograr una integración fluida con el sistema operativo sin penalizar el rendimiento ni introducir artefactos visuales, se implementa una **arquitectura híbrida (AppKit + SwiftUI)** estructurada bajo el patrón **MVVM (Model-View-ViewModel)** y un sistema modular desacoplado:

* **AppKit (`NSPanel`, `NSWindowController`, `HoverDetector`):** Gestiona los aspectos de bajo nivel del sistema de ventanas.
  * Configuración de ventana sin bordes (`borderless`), no activable (`nonactivatingPanel`) y flotante a nivel de barra de estado (`.statusBar`).
  * Cálculo geométrico del marco físico del notch a través de las APIs de hardware de `NSScreen` (`auxiliaryTopLeftArea`, `auxiliaryTopRightArea`).
  * Monitorización global y local de eventos del cursor mediante `NSEvent` para controlar expansiones, colapsos y protección de ventanas emergentes (popovers).
  * Control de ciclo de vida de instancia única mediante `NSRunningApplication`.
* **SwiftUI:** Actúa como motor declarativo de renderizado visual de la interfaz. Dibuja el panel, las pestañas de navegación (Nook, Tray), los contenedores elásticos y los widgets.
* **Capa Modular (Registry + Managers):** Cada funcionalidad opera de forma aislada a través de un `Manager` especializado (lógica de negocio e integración con APIs del sistema), un estado observable y vistas de presentación.

---

## 2. Estado del Plan de Desarrollo

### Fases Completadas

* **Fase 1: Núcleo, Geometría y Detección de Hover:**
  * Supresión de ventanas estándar y configuración de `NSPanel` flotante sin marco.
  * Detección geométrica del notch físico con fallback para monitores externos o Macs sin muesca.
  * Detección de hover y clics mediante `NSEvent.addGlobalMonitorForEvents` y `addLocalMonitorForEvents`.
  * Animación fluida con interpolación continua de esquinas (`cornerCurve = .continuous`).

* **Fase 2: Arquitectura Modular y Ajustes:**
  * Implementación de `WidgetRegistry` para el registro dinámico de widgets.
  * Panel nativo de ajustes (`SettingsView`) con persistencia en `UserDefaults` vía `@AppStorage`.
  * Personalización de altura, radio de curvatura, modo de activación y orden de widgets.

* **Fase 3: Multimedia y Calendario:**
  * Integración de `NowPlayingManager` mediante `MRMediaRemoteBridge` (enlace dinámico a funciones de `MediaRemote.framework`) y `DistributedNotificationCenter` para Spotify y Apple Music.
  * Descarga y caché de carátulas con control de generación para evitar condiciones de carrera.
  * Integración con `EventKit` en `CalendarWidgetManager` con visualización semanal responsiva según el ancho disponible.

* **Fase 4: Espejo (Cámara), Dropzone y Monitor del Sistema:**
  * Captura de vídeo en tiempo real mediante `AVCaptureSession` y capa de previsualización con efecto espejo en `CameraView`.
  * Zona de arrastre de archivos (`DropzoneView`) con soporte para compartir directamente mediante `NSSharingService` (AirDrop).
  * Monitorización de recursos de hardware (CPU y RAM) mediante llamadas al kernel Mach/Darwin (`host_processor_info`, `host_statistics64`, `sysctlbyname`).
  * Lectura pasiva de estado de periféricos conectados (AirPods) mediante `IOBluetooth`.

* **Fase 5: Módulo de Aplicaciones Ancladas (Pinned Apps) y Estabilización:**
  * Acceso directo a aplicaciones configurables en el ala izquierda del panel.
  * Límite estricto de hasta 2 aplicaciones visibles para preservar la simetría y evitar solapamientos con el área de la cámara.
  * Detección en tiempo real de aplicaciones en ejecución y soporte para control de procesos: cerrar (`terminate`), forzar salida (`forceTerminate`), ocultar, reiniciar y revelar en Finder.
  * Menú de acciones en doble clic y menú contextual estándar en clic secundario.

* **Fase 6: Correcciones Críticas de Sistema:**
  * Blindaje del detector de hover (`HoverDetector`) durante la apertura de ventanas secundarias y popovers para evitar colapsos inesperados.
  * Control de proceso único en `AppDelegate` para suprimir instancias redundantes al iniciar con el sistema o compilar desde Xcode.
  * Flujo de permisos unificado en `PermissionsManager` ejecutado una única vez en el primer arranque, evitando solicitudes repetitivas.

### Fases Pendientes

1. **Optimización de Recursos en Reposo y Multi-Monitor:**
   * Suspensión dinámica de temporizadores (reproducción multimedia y monitor del sistema) mientras el panel permanezca colapsado.
   * Manejo adaptativo ante cambios de resolución de pantalla o reconexión de monitores secundarios en caliente.
2. **Empaquetado y Distribución:**
   * Configuración de firma de código (*Code Signing*) para exportación independiente.
   * Limpieza de artefactos de depuración y generación del archivo `.dmg` / `.app` distribuible.

---

## 3. Estructura del Proyecto

```text
Notch/
├── NotchPanelApp.swift                    Entry point (@main), delega en AppDelegate
├── NotchPanelView.swift                   Vista raíz en SwiftUI (cabecera, pestañas y widgets)
├── Info.plist                             Permisos del sistema (Cámara, Calendario, AppleEvents)
├── Assets.xcassets                        Recursos gráficos e iconos del sistema
│
├── Core/
│   ├── AppDelegate.swift                  Ciclo de vida, control de instancia única y StatusItem
│   ├── PanelWindowController.swift        Gestión de geometría, nivel de ventana y animación de NSPanel
│   ├── PanelViewModel.swift               Estado reactivo (isExpanded, isMenuOrPopoverOpen, dimensiones)
│   └── HoverDetector.swift                Rastreo global/local de eventos de cursor y prevención de colapso
│
├── Docs/
│   └── Architecture.md                    Documentación técnica del proyecto
│
├── Infrastructure/
│   ├── AppSettings.swift                  Persistencia de configuraciones mediante @AppStorage
│   └── WidgetRegistry.swift               Registro y ciclo de vida de los módulos activos
│
├── Modules/
│   ├── WidgetProtocol.swift               Protocolo base para widgets (id, title, activate, deactivate)
│   ├── Calendar/
│   │   ├── CalendarWidgetManager.swift    Lógica de integración con EventKit
│   │   └── CalendarView.swift             Renderizado del calendario y lista de eventos
│   ├── Camera/
│   │   ├── CameraManager.swift            Control de sesión AVCaptureSession
│   │   └── CameraView.swift               Contenedor NSViewRepresentable con previsualización
│   ├── DropZone/
│   │   ├── DropzoneManager.swift          Gestión de archivos arrastrados y servicio AirDrop
│   │   └── DropzoneView.swift             Interfaz visual de recepción de archivos
│   ├── NowPlaying/
│   │   ├── MRMediaRemoteBridge.swift      Carga dinámica de funciones privadas de MediaRemote
│   │   ├── NowPlayingManager.swift        Control de estado multimedia, metadatos y carátulas
│   │   └── NowPlayingView.swift           Controles de reproducción, progreso e información de pista
│   ├── PinnedApps/
│   │   ├── PinnedApp.swift                Modelo de datos de aplicaciones ancladas
│   │   ├── PinnedAppsManager.swift        Lanzamiento, consulta de estado y terminación de procesos
│   │   └── PinnedAppsHeaderView.swift     Iconos en cabecera (máx. 2) y popover de acciones
│   └── SystemMonitor/
│       ├── SystemStats.swift              Modelo de datos de métricas de hardware
│       ├── SystemMonitorManager.swift     Llamadas de bajo nivel (Mach/Darwin) para CPU y memoria
│       ├── BluetoothManager.swift         Monitorización pasiva de dispositivos Bluetooth (AirPods)
│       ├── AirPodsInfo.swift              Estructura de datos para estado de batería
│       ├── AirPodsBatteryReader.swift     Lectura de niveles de carga
│       ├── AirPodsBatteryDropdown.swift   Vista emergente de niveles de carga
│       └── SystemHeaderView.swift         Indicadores visuales en la cabecera del panel
│
├── Permissions/
│   └── PermissionsManager.swift           Orquestación centralizada y secuencial de permisos TCC
│
└── Settings/
    └── SettingsView.swift                 Ventana de preferencias modular
```
