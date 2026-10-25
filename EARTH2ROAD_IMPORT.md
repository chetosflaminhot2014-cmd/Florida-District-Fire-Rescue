# Integración de mapas Earth2Road

F.D.F.R. ahora busca primero una escena de ciudad exportada desde Earth2Road. Esto es un punto de integración: **no incluye por sí solo los archivos de mapa generados**.

## Dónde colocar el mapa

1. En Earth2Road, genera un área urbana pequeña de Tampa, Florida. Para el primer intento usa un área de aproximadamente 0.6–1 km; los mapas grandes consumen bastante memoria.
2. Exporta el mundo para Godot siguiendo la documentación oficial de Earth2Road.
3. Copia la escena Godot exportada y todos sus recursos/dependencias a:
   `assets/earth2road/tampa/`
4. Usa uno de estos nombres para la escena principal: `map.tscn`, `world.tscn` o `main.tscn`.
5. Conserva la estructura relativa de los archivos exportados. No copies únicamente el `.tscn` si usa mallas, materiales, texturas o recursos externos.
6. Abre el proyecto en Godot 4.7.2, importa los recursos y ejecuta la escena principal. Comprueba primero en PC y después en Android.

## Qué hace el código

Al iniciar el mundo, `main.gd` busca esas tres rutas en ese orden e instancia la primera escena válida con raíz `Node3D`. Si no encuentra un mapa Earth2Road válido, conserva las alternativas anteriores (modelo Tampa GLB y mapa OSM/procedural).

La escena debe estar centrada cerca del origen del mundo jugable y usar una escala compatible con Godot (idealmente 1 unidad = 1 metro). Si el mapa exportado usa otro origen o escala, habrá que ajustar su transformación y la posición de las instalaciones.

## Limitaciones pendientes

- El export de Earth2Road **todavía debe generarse y añadirse manualmente**; no se puede generar el mapa real desde este repositorio sin ejecutar Earth2Road y descargar sus datos.
- Earth2Road se documenta como un proyecto Godot 4.6 validado principalmente en Windows. La compatibilidad con Godot 4.7.2 y Android debe probarse; no está garantizada.
- Las calles y edificios de Earth2Road no garantizan que el camión pueda circular sin ajustes. Hay que revisar colisiones, origen, escala, zonas de aparición, estación de bomberos y llamadas de emergencia.
- Los datos cartográficos procedentes de OpenStreetMap conservan sus propios términos y requieren atribución.

## Referencias

- Earth2Road: https://github.com/Alezx311/earth2road
- Guía del juego/exportación Godot: https://github.com/Alezx311/earth2road/blob/main/docs/GAME.md
