# F.D.F.R. — Backlog de 100 mejoras

**Base de trabajo:** v0.2.1 Alpha  
**Plataformas objetivo:** Windows y Android  
**Estado:** plan de trabajo; los puntos de esta lista NO se consideran implementados hasta que exista código y una prueba verificable.

## A. Estabilidad y calidad (1–15)
1. Añadir comprobación de recursos obligatorios al iniciar.
2. Mostrar un mensaje recuperable cuando falte un recurso.
3. Registrar errores de carga en un archivo de diagnóstico.
4. Evitar que una excepción de una misión cierre el juego.
5. Añadir pruebas unitarias para la progresión.
6. Añadir pruebas de aceptación para el despacho.
7. Probar la creación y limpieza repetida de incendios.
8. Verificar que no queden nodos huérfanos al reiniciar una misión.
9. Comprobar señales duplicadas al volver al menú.
10. Añadir una prueba de guardado y recuperación de carrera.
11. Comprobar que el juego se puede pausar y reanudar.
12. Verificar cierre limpio en Windows.
13. Verificar pausa y reanudación en Android.
14. Registrar duración de carga y uso de memoria.
15. Mantener una matriz de resultados por plataforma y dispositivo.

## B. Interfaz y controles (16–25)
16. Añadir menú de pausa funcional.
17. Añadir pantalla de ajustes.
18. Permitir ajustar sensibilidad de cámara.
19. Permitir invertir el eje vertical.
20. Añadir selector de calidad gráfica.
21. Añadir control de volumen general.
22. Separar volumen de motor, sirena, radio y ambiente.
23. Permitir reubicar controles táctiles.
24. Añadir opción de tamaño de botones táctiles.
25. Mostrar indicadores de interacción contextual.

## C. Bombero y equipamiento (26–35)
26. Añadir selección de uniforme.
27. Añadir casco y equipo visual por separado.
28. Añadir animación de caminar.
29. Añadir animación de correr.
30. Añadir animación de subir y bajar del camión.
31. Añadir animación de transportar equipo.
32. Añadir indicador de aire disponible como recurso de juego.
33. Añadir interacción con puertas.
34. Añadir interacción con hidrantes como objetivo de misión.
35. Añadir transición coherente entre primera y tercera persona.

## D. Incendios y rescate (36–50)
36. Separar intensidad visual y estado lógico del incendio.
37. Definir estados de incendio: activo, contenido y extinguido.
38. Evitar que un incendio se propague a través de paredes sólidas.
39. Limitar la propagación a superficies marcadas como combustibles.
40. Añadir distintos tamaños de incidente.
41. Añadir objetivos secundarios de misión.
42. Mostrar progreso de extinción.
43. Mostrar consumo de agua durante la operación.
44. Añadir recarga de agua en puntos designados.
45. Añadir estados de rescate para víctimas.
46. Evitar que una víctima se rescate más de una vez.
47. Añadir civiles que puedan evacuar por rutas seguras.
48. Añadir evaluación final de cada servicio.
49. Añadir bonificación por objetivos completados, no por acciones repetidas.
50. Limpiar todos los efectos y objetivos al terminar o cancelar un servicio.

## E. Despacho 911 y misiones (51–60)
51. Añadir identificador único por llamada.
52. Evitar que dos llamadas ocupen la misma unidad simultáneamente.
53. Separar estados: entrante, aceptada, en ruta, en escena y cerrada.
54. Pausar el reloj de respuesta cuando el juego está pausado.
55. Mostrar distancia al incidente.
56. Añadir filtro de llamadas por tipo.
57. Añadir historial de llamadas completadas.
58. Añadir resumen de unidades disponibles.
59. Evitar recompensas duplicadas al cerrar una llamada.
60. Añadir tutorial interactivo para la primera llamada.

## F. Ciudad y tráfico (61–70)
61. Añadir puntos de interés claramente identificados.
62. Añadir señalización vial legible.
63. Mejorar colisiones de aceras y edificios.
64. Evitar que peatones atraviesen obstáculos.
65. Evitar que vehículos de tráfico se superpongan.
66. Añadir rutas alternativas para tráfico bloqueado.
67. Añadir semáforos con fases coherentes.
68. Reducir densidad de tráfico en dispositivos modestos.
69. Añadir límites de velocidad como regla de juego.
70. Añadir zonas de baja velocidad alrededor de la estación.

## G. Vehículos y estación (71–80)
71. Añadir selección de vehículos disponibles.
72. Diferenciar aceleración y frenado por clase de vehículo.
73. Mejorar suspensión visual.
74. Añadir indicador de marcha y freno.
75. Añadir estado de puertas y compartimentos.
76. Añadir inspección previa a la salida.
77. Añadir estacionamiento en bahías de la estación.
78. Añadir puntos de reparación claramente señalados.
79. Añadir mantenimiento visual del vehículo.
80. Guardar el último vehículo seleccionado.

## H. Carrera y guardado (81–87)
81. Añadir migración de versiones del archivo de guardado.
82. Validar los datos guardados antes de cargarlos.
83. Mantener copia de seguridad del último guardado válido.
84. Añadir pantalla de estadísticas de carrera.
85. Mostrar progreso hacia el siguiente rango.
86. Evitar que estadísticas negativas entren al guardado.
87. Añadir reinicio de carrera con confirmación explícita.

## I. Multijugador y comunicaciones (88–93)
88. Añadir límite de frecuencia para actualizaciones de posición.
89. Eliminar estados remotos al desconectarse un jugador.
90. Añadir timeout visible para conexiones pendientes.
91. Validar el tamaño de todos los mensajes de red.
92. Añadir indicador de latencia y estado de conexión.
93. Mantener las misiones cooperativas desactivadas hasta contar con autoridad de servidor y pruebas de sincronización.

## J. Audio, rendimiento y publicación (94–100)
94. Añadir ambiente sonoro de estación.
95. Añadir variación de sonido de motor según velocidad.
96. Optimizar sombras y partículas en Android.
97. Añadir niveles de detalle para objetos lejanos.
98. Verificar exportación limpia de Windows desde CI.
99. Verificar instalación, inicio y pausa del APK en dispositivo Android.
100. Publicar notas de versión con resultados de pruebas y limitaciones conocidas.

## Criterio de aceptación
Cada mejora se marca como terminada únicamente cuando el código correspondiente existe, el proyecto importa sin errores, la prueba automatizada aplicable pasa y, cuando corresponda, se completa una prueba manual en Windows o Android. Una exportación correcta no sustituye la validación de jugabilidad en dispositivo real.
