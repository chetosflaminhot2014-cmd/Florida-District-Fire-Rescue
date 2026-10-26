# Importar el mapa de gen-map a F.D.F.R.

Esta carpeta está preparada para recibir una exportación GLB de [gen-map](https://gen-map.tarapata.net/es/). El juego prioriza los GLB de esta carpeta antes de usar los mapas de respaldo.

## Exportación recomendada

1. Abre https://gen-map.tarapata.net/es/ en un navegador de escritorio si es posible.
2. Busca **Tampa, Florida, USA**.
3. Selecciona una zona compacta de aproximadamente **0.8 × 0.8 km** centrada en el centro urbano. No empieces con 16 × 16 km: sería demasiado pesado para el objetivo Android.
4. Activa edificios, carreteras, terreno y agua si están disponibles. Las texturas generadas pueden activarse si el rendimiento del equipo lo permite.
5. Exporta el ZIP en formato GLB.
6. Extrae los GLB de la exportación dentro de esta carpeta. Mantén las texturas/archivos auxiliares junto a ellos si la exportación los incluye.

## Nombres que reconoce el juego

**Escena GLB única:** renombra el archivo combinado a uno de estos nombres:
- `city.glb`
- `map.glb`
- `combined.glb`
- `scene.glb`

**Exportación por componentes:** si no existe un GLB combinado, usa estos nombres para los componentes:
- `terrain.glb`
- `roads.glb`
- `buildings.glb`
- `water.glb`
- `vegetation.glb`
- `street_furniture.glb`

El cargador de `main.gd` intenta primero una escena combinada y, si no la encuentra, carga los componentes conocidos. No pongas a la vez el mapa combinado y sus componentes, porque se superpondrían.

## Validación antes de usarlo

- Comprueba que el mapa aparece con orientación y escala correctas.
- Prueba las colisiones y que el camión pueda recorrer las calles.
- Verifica que la estación, el hospital, el aeropuerto y las gasolineras no queden enterrados ni encima de edificios del mapa.
- Prueba el rendimiento en Android antes de ampliar el área.

## Créditos

El mapa se genera a partir de datos de OpenStreetMap. Al distribuir el juego con datos derivados de OSM, incluye la atribución **© OpenStreetMap contributors** y respeta la licencia ODbL. gen-map no garantiza que todos los edificios o calles estén completos.

**Estado:** el cargador de GLB está preparado en el repositorio, pero esta carpeta aún no contiene una exportación de ciudad. No afirmes que el mapa se ha integrado hasta que los archivos GLB estén presentes y se haya probado una compilación.
