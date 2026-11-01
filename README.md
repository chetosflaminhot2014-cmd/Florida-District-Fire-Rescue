# F.D.F.R. — Florida District Fire & Rescue

**Versión:** 0.2.0 Alpha  
**Motor:** Godot 4.7.2  
**Plataformas:** Windows PC y Android

F.D.F.R. es un simulador de bomberos y rescate en desarrollo, ambientado en una ciudad inspirada en Florida. Esta versión es una Alpha: las comprobaciones automáticas no sustituyen las pruebas manuales en dispositivos reales.

## Sistemas incluidos

- Ciudad 3D con edificios, carreteras y datos urbanos de Tampa basados en OpenStreetMap.
- Despacho 911 con distintos tipos de incidentes, panel de radio y marcador de destino.
- Conducción del camión de bomberos, cámara exterior/interior, sirena y luces de emergencia.
- Sistema de incendio con llamas, humo, brasas, propagación y extinción mediante agua.
- Rescate de personas y objetivos de misión.
- Tráfico, semáforos y peatones.
- Combustible, depósito de agua, daños y reparación del vehículo.
- Carrera persistente con rangos, experiencia, créditos, estadísticas y 50 logros.
- Base de multijugador con sincronización inicial de jugadores.

## Cambios técnicos de 0.2.0

- Corregida una redeclaración de variable que impedía analizar el script principal.
- Corregidas las rutas de texturas compartidas por los modelos de carreteras y vehículos.
- Corregida la configuración de partículas CPU para fuego, humo y brasas.
- La carrera cuenta tiempo únicamente durante turnos activos y guarda el progreso al cerrar o pausar la aplicación.
- Añadida una consulta de progreso para los 50 logros.
- Añadida una prueba automática de integración que comprueba el mundo, jugador, camión, HUD, despacho, carrera, logros y creación/limpieza del incendio.
- El flujo de compilación reutiliza el mapa urbano verificado, serializa las compilaciones y detecta referencias a archivos de recursos ausentes.

## Controles

- **Windows:** WASD o flechas para moverse; Shift para correr; E para entrar o salir del vehículo; ratón para mirar; Esc para liberar o capturar el ratón; V para cambiar la cámara.
- **Android:** controles táctiles en pantalla. Las acciones secundarias se mantienen agrupadas para reducir la saturación del HUD.

## Descargas

Los artefactos de Windows y Android se generan en cada ejecución correcta de **Build F.D.F.R. (Windows + Android)**:

- Windows: artefacto `FDFR-Windows-PC-Alpha`.
- Android: artefacto `FDFR-Android-Alpha-APK`.

Consulta las ejecuciones en la pestaña **Actions** del repositorio y descarga los dos artefactos de la misma ejecución.

## Limitaciones conocidas

- Se necesita probar el juego manualmente en distintos equipos Windows y dispositivos Android.
- Los modelos detallados de bombero, policía y paramédico son mallas estáticas; no tienen todas las animaciones necesarias.
- El multijugador es una base inicial, no un sistema en línea completo.
- Física, tráfico, misiones y rendimiento en ciudades grandes siguen en desarrollo.

Una compilación correcta confirma que Godot pudo importar, iniciar y exportar el proyecto; no significa que cada sistema esté terminado ni que se haya probado en todos los dispositivos.
