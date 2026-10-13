# QA — Notificaciones de Chamba

final result: passed

## Referencia y evidencia

- Referencia original: `docs/notifications-design/reference.png` (263 × 711 px,
  incluye teléfono y leyenda externa).
- Implementación: `docs/notifications-design/implementation.png` (390 × 844 px,
  renderizado de la pantalla real de Flutter, densidad 1).
- Comparación conjunta: `docs/notifications-design/comparison.png`.
- Estado: Todas, cuatro avisos de ejemplo (llegada, oferta, finalización, mensaje).
- Normalización: región del teléfono de la referencia recortada a 251 × 622 px,
  escalada manteniendo la proporción a 341 × 844 px. No se considera una captura
  de densidad nativa conocida; el objetivo es reproducir la composición y el
  lenguaje visual, manteniendo la navegación de la app existente.

## Superficies revisadas

- Tipografía: Plus Jakarta Sans, título de 24 px, títulos de tarjeta de 14 px,
  cuerpo de 12 px y fecha de 11 px. Filtros y botones heredan la misma familia.
  No se recortan títulos ni descripciones. Prueba adicional a escala 2 en 320 px.
- Espaciado: tarjetas de radio 20 px, margen externo 16 px, separación 12 px,
  relleno interno 14 px. Botones de 40 px de alto dentro de tarjetas también
  pulsables. La lista permite desplazar avisos y cargar más.
- Colores: violeta para llegada, ámbar para oferta/pago, verde para finalización,
  azul para mensajes. Texto oscuro legible y acento oscuro en botones de color.
- Imágenes: cuatro PNG con transparencia real generados con ImageGen. Mapa,
  monedas, casa y chat, ilustraciones 3D suaves. Escala 96 px, proporción
  conservada, ocultas cuando el texto ampliado necesita más espacio.
- Contenido: texto dinámico del servidor, hora local, etiquetas que describen
  la acción. Sin imágenes que contengan textos o botones falsos. Los avisos sin
  destino suficiente muestran un detalle legible.

## Historial de comparación

1. La primera captura de pruebas usaba la fuente Ahem y aún no había terminado
   de decodificar todas las imágenes. No era evidencia visual válida. Se cargó
   la fuente oficial, el set Material Icons y las imágenes antes de capturar.
2. Se detectaron ilustraciones pequeñas y título poco destacado. Se ampliaron
   las ilustraciones a 96 px, se ajustó el relleno y se alineó el título de 24 px.
3. La captura mostró filtros y botones con la fuente de pruebas. Se hizo
   explícita la herencia de tipografía del tema en ambos controles y se repitió
   el renderizado. La comparación conjunta final muestra letras e imágenes
   completas y no conserva hallazgos P0/P1/P2.

## Diferencias intencionales

- Se conserva el centro de notificaciones como ruta existente: no se inventa
  una barra inferior de Inicio/Notificaciones/Perfil ni se cambia el shell.
- Hay una categoría Mensajes independiente y desplazamiento horizontal de
  filtros. Evita esconder mensajes dentro de Sistema.
- El mapa es una ilustración decorativa, no una ubicación real ni un retrato
  inventado. El botón abre el flujo real del trabajo/seguimiento.
- El icono de opciones abre Actualizar y Marcar visibles como leídas, acciones
  reales. No simula una pantalla de ajustes inexistente.

## Funcionamiento y límites

17 pruebas pasan: filtrado, payload original, apertura, lectura individual,
lectura en cola con pulsaciones rápidas, lectura por categoría, detalle de
avisos sin destino, reintento, paginación, deduplicación, texto ampliado y
política existente de alertas. Analizador Dart: sin problemas en los archivos
nuevos y modificados de presentación y pruebas.

La compilación web de la app está bloqueada por la incompatibilidad previa
entre record_web 1.3.0 y el override record_platform_interface 1.1.0
(`streamBufferSize`). Se verificó el renderizado nativo mediante Flutter tests;
no se afirma una vista web interactiva ni una prueba contra una cuenta real.
El routing de producción sigue usando NotificationRouter y los identificadores
que devuelve el servidor. Los pagos asociados a un trabajo abren su resumen.

## Checklist final

- [x] Ilustraciones generadas incluidas en el bundle de Flutter.
- [x] Comparación visual conjunta revisada.
- [x] Filtros y botones conectados a la pantalla real.
- [x] Errores y estados vacíos accesibles.
- [x] Pruebas de comportamiento y analizador correctos.
- [ ] Prueba manual en dispositivo conectado con sesión y trabajo reales.

## Revisión de cliente y trabajador — 12 de octubre de 2026

1. **Cliente** — captura `docs/notifications-design/implementation.png`:
   Ver ofertas, Ver mapa, Ver resumen y Ver mensaje. Se conserva el cuerpo
   recibido del servidor y la fecha. Destinos activos: seguimiento; destinos
   terminados/cancelados: resumen del trabajo.
2. **Trabajador** — captura `docs/notifications-design/worker.png`:
   Ver solicitud, Ver trabajo, Ver propuesta y Ver mensaje. Se corrigió la
   etiqueta de contrapropuestas del cliente y el destino de `in_progress`:
   ahora abre el trabajo activo directamente. La oferta aceptada tiene una
   ilustración de acuerdo económico, diferenciada del trabajo finalizado.
3. **Compartido** — filtros por tipo, acciones de lectura, recarga, detalle
   para eventos sin destino, soporte, perfil y texto ampliado. Comparación
   conjunta: `docs/notifications-design/client-worker.png`.

33 pruebas pasan (15 de roles/destinos, 11 de pantalla y 7 de política de
alertas). Capturas inspeccionadas a 390 × 844, fuente de marca e imágenes reales
cargadas. Texto legible y botones sin etiquetas de rol incorrectas. La lista
permite deslizar avisos largos; no se recortan contenidos para forzar cuatro
tarjetas visibles. Los colores se acompañan de icono, título y acción, por lo
que el significado no depende solo del color. Sigue pendiente una prueba con
sesión real en dispositivo; no se afirma una auditoría de una cuenta real.

Resultado de esta revisión: passed.

## Verificación de todos los filtros y botones

39 pruebas pasan: se pulsa Todas, Trabajos, Pagos, Mensajes y Sistema en ambos
roles y se comprueba la selección y el contenido. Se verifican también los
botones de pago, mensaje, perfil, soporte, actualizar, marcar visibles como
leídas y reintento de paginación conservando avisos previos. No hubo cambios
visuales adicionales en esta verificación.

Limitación detectada al revisar el backend: NotificationsService no emite aún
`payment` ni `payment_received`, ni hay una confirmación de pago separada del
cierre de un trabajo. El filtro Pagos clasifica correctamente estos eventos
cuando llegan, pero no se afirma que el backend los genere. No se clasifica
una oferta ni un trabajo terminado como pago recibido: un monto final o una
oferta no demuestra que se haya cobrado. Las pruebas de Pagos usan eventos
ficticios explícitos y validan el estado vacío cuando no existen avisos de pago.

## Estado final — nuevas/leídas y eliminación de Pagos

Esta revisión sustituye las notas anteriores relativas al filtro Pagos.

- Ya no existe la categoría Pagos para ninguno de los roles. Los eventos
  payment/payment_received también se excluyen de la lista y del contador del
  icono en el servidor; no se borran los registros históricos.
- Cada tarjeta identifica explícitamente Nueva o Leída. Abrir un aviso lo marca
  como leído y las opciones permiten marcar los avisos visibles; si la red
  falla, conservan su estado y contador anterior.
- La fila Todas / Nuevas / Leídas muestra contadores y filtra por estado. Se
  combina con Todas / Trabajos / Mensajes / Sistema. Los contadores del servidor
  abarcan todas las páginas y se ajustan a la categoría elegida.
- La nueva ruta GET /api/mobile/notifications/counts está protegida por el guard
  móvil existente y devuelve los totales por tipo y estado del usuario
  autenticado. Publicar el backend antes de la app. Si ese resumen no está
  disponible, la lista funciona y avisa cuando muestra solo el conteo cargado.
- Marcar más de 100 avisos se hace en lotes; solo los lotes confirmados pasan a
  Leída. Los avisos nuevos de páginas posteriores no se anuncian como ausentes
  por haber leído la página visible.

Evidencia actual: implementation.png (cliente), worker.png (trabajador) y
client-worker.png, dentro de docs/notifications-design. El espacio adicional
para contadores desplaza la cuarta tarjeta; la lista conserva el scroll y no
recorta ni oculta las acciones dentro de cada tarjeta.

Validación: 46 pruebas de Flutter y 10 del servicio de notificaciones del
backend, compilación NestJS correcta y analizador Dart sin problemas. Pruebas
con datos aislados; sigue pendiente la comprobación manual con sesión real en
un dispositivo. No se desplegaron los cambios durante esta tarea.

final result: passed

## 2026-10-13 — Barra inferior con onda por rol

Referencia: docs/bottom-nav-design/reference.png, imagen seleccionada por el usuario.
Implementación: ChambaWaveBottomNav, consumida por las dos clases públicas de navegación existentes. No se modificaron las rutas del shell ni la carga de sus pantallas.

Evidencia: docs/bottom-nav-design/comparison.png reúne la referencia y las capturas reales de Flutter, además de los estados Billetera seleccionada y Notificaciones seleccionada con contadores. client-worker.png es la vista compacta final.

Captura: viewport lógico 390 px; superficies de 366 × 84 px; PNG de componente a densidad 3, normalizado a 390 × 94 px para comparar. Se recortó solo la región de navegación de la referencia y se normalizó a 366 × 84 px. El teléfono, el indicador de inicio y el texto editorial no pertenecen al componente. Se verificó la barra nativa de forma aislada; no se afirma una prueba de sesión real en teléfono.

Hallazgos y correcciones:
- P1, accesibilidad: el nodo de navegación ocultaba la acción del hijo al excluir semántica. Se añadió la acción de pulsación al nodo que anuncia la pestaña, su estado seleccionado y el total exacto sin leer. Las pruebas validan la acción y cada callback.
- P2, iconos: se redujeron los tamaños a 32 px en el botón activo y 28 px en los inactivos para acercarse a la referencia.
- P2, legibilidad: el texto amarillo activo y las etiquetas inactivas usan tonos algo más oscuros que la referencia para facilitar la lectura. El círculo activo conserva el amarillo vivo.
- Artefacto de captura: Flutter Test desactivaba el desenfoque de sombras y la captura tenía exterior transparente. Se habilitaron sombras reales y el fondo de la app antes de comparar. No se confundió ese artefacto con un borde real.

Superficies de fidelidad:
- Tipografía: se conserva Plus Jakarta Sans del producto; 11 px, pesos 500/600, etiquetas completas. El área crece con el tamaño de texto y admite varias líneas.
- Espaciado: tres pestañas para clientes y cuatro para trabajadores; círculos de 56 px, radios de 28 px y área segura inferior. Targets mayores de 48 px incluso a 320 px y escala de texto 2.
- Color: cliente morado; trabajador amarillo/ámbar; iconos secundarios lavanda, contador rojo. La pequeña diferencia de tono en etiquetas es intencional por legibilidad.
- Imágenes y onda: cinco iconos PNG independientes con alfa y dos fondos generados con ImageGen. Una curva amplia en el tercio superior, valle central y subida a la derecha; se verificó la curva en la comparación. BoxFit.fill conserva ambos extremos. La referencia representa una onda decorativa estática; no se añadió desplazamiento repetido.
- Contenido: Inicio, Billetera, Notificaciones y Perfil mantienen sus nombres y orden. Billetera solo aparece para trabajadores. El contador se conserva y muestra 99+ sin perder el total accesible.

Validación: 41 pruebas pasaron (barra, callbacks por rol, estados, contadores, mensajes y política de notificaciones); tras el ajuste final de color se repitieron las 7 pruebas de la barra y se recapturó la comparación. Análisis estático de los tres archivos modificados sin incidencias. git diff --check correcto.
La compilación del APK fue cancelada a petición del usuario. No se entrega ni se publica un APK en esta iteración.

Sin P0/P1/P2 pendientes dentro del componente revisado. Diferencias aceptadas: tipografía existente del producto, tono accesible de etiquetas, proporciones discretamente ajustadas a 390 px y separación adicional de área segura.
final result: passed

## 2026-10-13 — Transición de selección de la barra

El círculo destacado se desliza durante 260 ms con easeInOutCubic. El icono viaja dentro del círculo y cambia con un fundido y escala de 130 ms; las etiquetas cambian suavemente de color. La acción de navegación se ejecuta de inmediato. No hay temporizadores, reproducción continua ni espera para aceptar otro toque. La preferencia del sistema de reducir movimiento pone las duraciones a cero.

Primera revisión visual: P2, los iconos blancos estacionarios perdían legibilidad cuando el círculo pasaba por debajo. Se corrigió colocando el icono activo dentro del círculo que se mueve. Se recapturaron los estados inicial, 80 ms, 160 ms y final para ambos roles. El contador se pinta por encima del círculo y la capa animada ignora eventos de puntero.

Evidencia final: docs/bottom-nav-design/motion-comparison.png, comparison.png y selection-animation.gif. Fotogramas capturados del componente Flutter real a densidad 2, normalizados a 390 × 94 px para la vista de movimiento. El GIF repite esos fotogramas como demostración; la app anima una sola vez por cambio de selección.

Fidelidad:
- Tipografía y contenido: mismas etiquetas, Plus Jakarta Sans y tamaños; solo transiciona el color.
- Espaciado: mismos radios, círculo, orden, área segura y targets.
- Colores: mismos morados y amarillos, fondo con onda intacto.
- Imágenes: mismos PNG generados; sin nuevos recortes, dibujos o imágenes sustitutas. Icono activo legible dentro del círculo durante toda la trayectoria.
- Estados: selección final y contadores correctos, también al tocar varias pestañas en 30 ms y recibir un cambio del badge durante el movimiento.

Validación final: 46 pruebas pasaron. Incluyen movimiento intermedio y posición final en ambos roles, navegación inmediata, toques rápidos, actualización del contador, eliminación del widget, movimiento reducido y ausencia de fotogramas programados al terminar. El selector alcanza el destino dentro de 260 ms; la respuesta visual nativa de InkWell puede durar algo más y también se detiene. Análisis estático de los dos archivos editados sin incidencias.

Esta verificación usa el componente nativo aislado, no una medición de rendimiento de un teléfono real. Se conserva la instrucción del usuario de no generar APK.
Sin P0/P1/P2 pendientes en la transición revisada.
final result: passed
