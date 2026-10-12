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
