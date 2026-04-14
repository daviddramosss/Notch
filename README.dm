# NotchPanel

## Sobre el proyecto

He desarrollado NotchPanel como un reto técnico personal para mi portfolio. El objetivo era construir un clon funcional de utilidades como *Notch
Nook*, superando la gran limitación del framework moderno de Apple

Para lograr una experiencia fluida y 100% nativa, he diseñado una **arquitectura híbrida**. Utilizo las APIs de bajo nivel de **AppKit** (`NSPanel`,
`NSEvent`) y funciones en C para dominar la física y los permisos del sistema, mientras delego exclusivamente a **SwiftUI** el renderizado visual y
las animaciones de la interfaz.

## Características Principales

He implementado un sistema de arquitectura modular ("Plug & Play") que me ha permitido inyectar las siguientes herramientas de productividad
directamente en la ceja del Mac:

* **🎵 Control Multimedia Avanzado:** Integración directa con Spotify y Apple Music saltando las restricciones de Sandbox mediante el framework privado `MediaRemote` (C-API) y `NSAppleScript`.
* **📁 Bandeja DropZone:** Un espacio de almacenamiento temporal (`NSItemProvider`) basado en Drag & Drop para guardar archivos y enlaces.
* **📅 Calendario Nativo:** Lectura en tiempo real de los eventos del día solicitando acceso seguro a `EventKit`.
* **📸 Espejo (Cámara):** Feed de video en vivo inyectando un `AVCaptureVideoPreviewLayer` dentro del entorno de SwiftUI.
* **📊 Monitor del Sistema:** Lectura de bajo nivel del kernel (Mach/Darwin) para mostrar el uso real de CPU y RAM, junto con el estado de batería de dispositivos Bluetooth conectados.

## 🛠️ Stack Tecnológico y Retos Superados

* **Lenguaje:** Swift 5+
* **UI:** SwiftUI (Vistas, Animaciones) + AppKit (Gestión de Ventanas y Puntero).
* **Frameworks Nativos:** `AVFoundation`, `EventKit`, `IOBluetooth`.

## Arquitectura

Si quieres profundizar en cómo he estructurado el código, separado las responsabilidades (MVVM) y gestionado la inyección de los módulos, puedes leer
la documentación completa aquí:
**[Ver Arquitectura del Proyecto](Docs/Architecture.md)**

##  Instalación y Uso

Si quieres probar la aplicación en tu propio Mac (Requiere macOS 13+):

1. Ve a la pestaña de [Releases](enlace_a_tus_releases_en_github) y descarga el último archivo `NotchPanel.app.zip`.
2. Descomprímelo y arrastra la app a tu carpeta de **Aplicaciones**.
3. **Importante:** Como es un proyecto Open Source no firmado mediante el programa de pago de Apple, la primera vez que la abras debes hacer **Clic Derecho > Abrir** (y confirmar la excepción de seguridad de macOS).
4. Pasa el ratón por el Notch de tu cámara para desplegar el panel. Aparecerá un icono de un engranaje arriba a la derecha para acceder a los **Ajustes**.

---
*Desarrollado por David Ramos.*
