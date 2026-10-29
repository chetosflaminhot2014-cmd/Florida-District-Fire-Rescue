# F.D.F.R. — Florida District Fire & Rescue

**Versión de desarrollo:** 0.1.2 Alpha  
**Motor:** Godot 4.7.2  
**Plataformas objetivo:** Windows PC y Android

F.D.F.R. es un prototipo jugable de simulación de bomberos y rescate ambientado en una ciudad ficticia inspirada en Florida. El proyecto está en desarrollo; esta versión no representa un simulador terminado.

## Lo que incluye el prototipo

- Menú principal de F.D.F.R. con vista 3D de fondo.
- Ciudad generada por procedimientos y trabajo de importación de edificios, carreteras y vehículos.
- Movimiento en tercera persona y controles táctiles para dispositivos móviles.
- Vehículo de emergencia conducible y cambio entre cámara exterior e interior.
- Sistema inicial de llamadas 911, panel de radio y opciones de respuesta.
- Marcador de ubicación de incidente y mensajes de despacho.
- Base de multijugador para crear o unirse a una sesión, con sincronización inicial de jugadores.
- Ajustes de calidad gráfica según la plataforma.

## Controles de referencia

- **PC:** WASD o flechas para moverse; Shift para correr; E para entrar o salir del vehículo; ratón para mirar; Esc para liberar o capturar el ratón; V para cambiar la cámara.
- **Android:** usa los controles en pantalla. La disposición puede cambiar mientras se ajusta la interfaz.

## Descargar y ejecutar en Windows

1. Abre la pestaña **Actions** del repositorio.
2. Entra en la ejecución más reciente de **Build F.D.F.R. (Windows + Android)** que haya terminado correctamente.
3. Descarga el artefacto **FDFR-Windows-PC-Alpha** y extrae el ZIP si el navegador lo descarga comprimido.
4. Ejecuta `FDFR-Windows-Alpha.exe`.

Para Android, descarga el artefacto **FDFR-Android-Alpha-APK** e instala el APK en un dispositivo compatible.

## Estado y limitaciones conocidas

Esta es una **Alpha temprana**. Las llamadas 911, la radio, la conducción, el mapa y el multijugador siguen necesitando pruebas completas en juego y entre varios dispositivos. Algunos personajes y elementos del mundo todavía son provisionales; no todas las animaciones, sonidos, físicas de vehículos ni comportamientos de emergencia están implementados. No se debe asumir que una función está terminada solo porque aparece en la interfaz.

## Desarrollo

Los cambios se mantienen en la rama `main`. GitHub Actions importa recursos, comprueba la carga del proyecto con Godot y genera artefactos de Windows y Android. Una ejecución correcta confirma que el proyecto pasó las comprobaciones automatizadas de esa compilación; no sustituye todas las pruebas manuales dentro del juego.
