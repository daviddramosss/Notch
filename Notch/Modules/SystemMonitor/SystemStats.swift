import Foundation

// Un "molde" limpio para guardar la salud de nuestro Mac
struct SystemStats {
    var cpuUsage: Double = 0.0      // De 0.0 a 1.0 (0% a 100%)
    var ramUsed: Double = 0.0       // En Gigabytes (GB)
    var ramTotal: Double = 0.0      // En Gigabytes (GB)
    
    // Calculamos el porcentaje de RAM usada automáticamente
    var ramPercent: Double {
        guard ramTotal > 0 else { return 0.0 }
        return ramUsed / ramTotal
    }
}
