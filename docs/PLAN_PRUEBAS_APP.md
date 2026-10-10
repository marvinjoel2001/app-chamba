# Plan de pruebas — App Chamba (Flutter)

| Campo | Valor |
|---|---|
| Versión del plan | 1.0 — 2026-10-09 |
| Autor | Claude Code (borrador para revisión de Codex) |
| Alcance | `app-chamba/lib` — 35 pantallas, 13 módulos, roles **cliente** y **trabajador** |
| Base de código analizada | commit `378c6d7` |
| Referencias | `DESIGN_SPEC.md`, `lib/core/theme/app_theme.dart`, `lib/core/widgets/chamba_widgets.dart` |
| Estado | **Pendiente de revisión por Codex** (ver sección 10) |

> **Cómo leer este documento.** La sección 2 define las reglas de diseño que aplican a *todas* las pantallas
> (tipografía, botones, color, textos, estados, accesibilidad). La sección 4 recorre módulo por módulo y
> pantalla por pantalla, con casos de prueba numerados. Los puntos marcados **[HALLAZGO]** salieron del
> análisis estático del código y deben confirmarse en dispositivo antes de abrir un bug.

---

## Índice

1. Entorno, datos y precondiciones
2. Criterios transversales (aplican a todas las pantallas)
3. Mapa de navegación
4. Pruebas por módulo y pantalla
   - M1 Arranque y onboarding
   - M2 Autenticación
   - M3 Shell, navegación inferior y elementos globales
   - M4 Cliente — Explorar y crear solicitud
   - M5 Cliente — Estado de la solicitud y ofertas
   - M6 Trabajador — Solicitudes entrantes, ofertas y verificación
   - M7 Trabajo en curso (trabajador y cliente)
   - M8 Calificación
   - M9 Mensajería y notificaciones
   - M10 Trabajador — Perfil profesional y billetera
   - M11 Perfil, historial y soporte
   - M12 Push, segundo plano y alertas
   - M13 Pantallas sin ruta (código huérfano)
5. Flujos de extremo a extremo (E2E)
6. Matriz de dispositivos y configuraciones
7. Pruebas automatizadas existentes y a crear
8. Resumen de hallazgos del análisis estático
9. Registro de defectos y criterios de salida
10. Instrucciones para la revisión de Codex

---

## 1. Entorno, datos y precondiciones

### 1.1 Entorno

| Elemento | Requisito |
|---|---|
| Flutter | Versión fijada en `.fvmrc` (usar `fvm flutter`) |
| Emuladores | Dos instancias simultáneas: `emulator-5554` = trabajador, `emulator-5556` = cliente (convención de `capturas-app/`) |
| Dispositivo físico | Al menos 1 Android de gama baja (≤ 3 GB RAM) para GPS real, push y segundo plano |
| iOS | Al menos 1 iPhone/simulador si se publica en App Store |
| Backend | **Usar un entorno de staging.** Los emuladores apuntaban a producción (Railway) según `COMUNICACION_AGENTES.md`. No ejecutar flujos que creen usuarios, pagos ni reportes contra producción. |
| `test/api_test.dart` | **No ejecutar contra producción**: crea usuarios. Requiere `API_BASE_URL` de staging. |

### 1.2 Cuentas y datos de prueba

| ID | Rol | Estado | Uso |
|---|---|---|---|
| U-C1 | Cliente | Activo, con método de pago | Flujo principal cliente |
| U-C2 | Cliente | Recién registrado, sin solicitudes | Estados vacíos |
| U-W1 | Trabajador | Verificado, con habilidades, modalidades y portafolio | Flujo principal trabajador |
| U-W2 | Trabajador | Sin verificación de identidad | `VerificationCheckpointScreen` |
| U-W3 | Trabajador | Sin habilidades | Redirección a `SkillsSelectionScreen` |
| U-B1 | Cualquiera | Bloqueado en admin | `BlockedScreen` |
| U-G1 | Cuenta Google nueva | Sin tipo de cuenta | `GoogleAccountTypeScreen` |

Las credenciales no se escriben en este documento ni en `COMUNICACION_AGENTES.md`.

### 1.3 Condiciones de red y sistema a simular

- Wi-Fi estable, 4G, 3G lento (throttling), modo avión y cambio de red en mitad de una acción.
- GPS desactivado, permiso de ubicación denegado, denegado permanentemente, ubicación aproximada (no precisa).
- Notificaciones denegadas; optimización de batería activa (Android).
- App en primer plano, en segundo plano, y cerrada (cold start desde push).

---

## 2. Criterios transversales (checklist para cada pantalla)

Cada pantalla de la sección 4 se valida contra **todas** las reglas de esta sección además de sus casos propios.

### 2.1 Tipografía

Fuente oficial: **Plus Jakarta Sans** vía `GoogleFonts.plusJakartaSansTextTheme`. Escala definida en `AppTheme.dark()`:

| Token | Tamaño | Peso | Uso esperado |
|---|---|---|---|
| `displayLarge` | 32 | 800 | Montos destacados, título de splash |
| `headlineLarge` | 24 | 700 | Título principal de pantalla |
| `headlineMedium` | 20 | 700 | Títulos de sección / AppBar |
| `headlineSmall` | 17 | 600 | Subtítulos, títulos de tarjeta |
| `bodyLarge` | 15 | 400, alto 1.5 | Párrafos (color muted) |
| `bodyMedium` | 15 | 600 | Texto de botones y valores |
| `bodySmall` | 12 | 500 | Metadatos, fechas, ayudas |
| Excepciones de componente | 13 (chip), 11 (label nav), 10 (badge nav) | — | Solo dentro de `chamba_widgets.dart` |

**Reglas a verificar**

- TIP-01 Ningún texto usa un tamaño fuera de la escala `{32, 24, 20, 17, 15, 13, 12, 11, 10}`.
- TIP-02 Ningún texto legible por el usuario es menor de **12 px** (10–11 solo en badges/labels de navegación).
- TIP-03 No hay tamaños fraccionarios (12.5, 13.5, 15.5).
- TIP-04 Los textos se obtienen de `Theme.of(context).textTheme` en vez de `TextStyle(fontSize: …)` sueltos.
- TIP-05 Toda la app usa Plus Jakarta Sans (ningún texto cae a Roboto por un `TextStyle` sin `fontFamily` fuera del tema; revisar diálogos, snackbars, `showModalBottomSheet`, `DatePicker`/`TimePicker`).
- TIP-06 Con escala de texto del sistema 1.3 y 2.0 no hay desbordes (franjas amarillas/negras), textos cortados sin elipsis ni botones con el texto partido.
- TIP-07 Mayúsculas: definir una sola convención para etiquetas de estado y CTAs (ver 2.4).

**[HALLAZGO] Tamaños de letra fuera de escala detectados por pantalla** (literal `fontSize:` en el código):

| Pantalla | Tamaños usados | Fuera de escala |
|---|---|---|
| `incoming_request_screen` | 10 11 12 13 14 15 16 18 20 22 | 14, 16, 18, 22 |
| `tracking_screen` | 9 10 11 12 13 14 16 18 20 22 26 | **9**, 14, 16, 18, 22, 26 |
| `job_in_progress_screen` | 9 10 11 12 13 14 16 18 20 | **9**, 14, 16, 18 |
| `request_form_screen` | 10 11 12 **12.5** 13 **13.5** 14 15 16 18 23 | 12.5, 13.5, 14, 16, 18, 23 |
| `request_form_widgets` | 10 **10.5** 11 **12.5** 13 **15.5** 18 20 | 10.5, 12.5, 15.5, 18 |
| `request_modality_screen` | 11 12 **12.5** 14 20 27 | 12.5, 14, 27 |
| `explore_screen` | 10 11 12 13 14 15 16 17 18 | 14, 16, 18 |
| `request_status_screen` | 10 12 13 14 16 18 20 | 14, 16, 18 |
| `job_history_details_screen` | 11 12 13 14 15 16 18 20 | 14, 16, 18 |
| `wallet_screen` | 10 12 13 14 15 16 18 20 24 40 | 14, 16, 18, 40 |
| `messages_screen` | 10 11 12 13 14 15 16 28 | 14, 16, 28 |
| `chat_screen` | 10 11 12 14 15 18 20 | 14, 18 |
| `counter_offer_screen` | 12 13 14 15 16 18 22 | 14, 16, 18, 22 |
| `worker_profile_screen` | 11 12 13 14 16 32 | 14, 16 |
| `support_screen` | 10 11 12 14 15 16 22 | 14, 16, 22 |
| `google_account_type_screen` | 14 18 20 32 | 14, 18 |
| `profile_menu_screen` | 12 26 | 26 |
| `confetti_celebration` | 13.5 19 | 13.5, 19 |

Pantallas que respetan el tema (sin `fontSize` literales): blocked, register, rating, identity_verification,
radar, skills_selection, verification_checkpoint, work_modalities, worker_portfolio, role_selection,
empty_requests, request_outcome. Usarlas como referencia visual.

### 2.2 Botones — jerarquía y coherencia

| Nivel | Componente oficial | Especificación |
|---|---|---|
| Primario | `ChambaPrimaryButton` (morado; variante amarilla para "aceptar/confirmar dinero") | Alto 52 (compacto 44), radio 16, escala 0.97 al presionar, deshabilitado opacidad 0.6 |
| Secundario | `ChambaSecondaryButton` u `OutlinedButton` del tema | Radio 16, borde `colorGlassBorderSoft` |
| Terciario | `TextButton` del tema | Color `colorPrimaryLight` |
| Destructivo | `TextButton`/secundario con color `colorError` | "Cancelar trabajo", "Eliminar", "Cerrar sesión" |
| Icono | `IconButton` | Área táctil ≥ 48×48 y `tooltip` |

**Reglas a verificar**

- BTN-01 Máximo **un** botón primario visible por pantalla/estado.
- BTN-02 Mismo tipo de acción → mismo componente en toda la app (p. ej. "Reintentar" siempre igual; "Cancelar" de diálogos siempre `TextButton`).
- BTN-03 Las acciones destructivas usan color de error y piden confirmación.
- BTN-04 Todo botón que dispara una petición se deshabilita y muestra *loading* mientras espera (sin doble envío por doble tap).
- BTN-05 Áreas táctiles ≥ 48×48 px (incluye iconos de mapa: zoom, centrar, cerrar).
- BTN-06 Alturas y radios iguales entre pantallas (52/44 y radio 16).
- BTN-07 Orden en diálogos: [Cancelar/No] a la izquierda, [Confirmar] a la derecha, en todas las confirmaciones.
- BTN-08 Texto de botón en *sentence case* ("Aceptar trabajo"), salvo que se decida otra convención para todos.
- BTN-09 Todos los `IconButton` tienen `tooltip` (lector de pantalla). **[HALLAZGO]** solo hay 14 `tooltip` en `lib/features` frente a decenas de `IconButton`.

**[HALLAZGO] Botones Material crudos (`ElevatedButton`/`FilledButton`) en vez de los componentes Chamba:**

| Pantalla | Elevated/Filled | Primary | Secondary | Outlined | Text | Icon |
|---|---|---|---|---|---|---|
| `incoming_request_screen` | **9** | 1 | 1 | 4 | 6 | 2 |
| `request_status_screen` | **8** | 0 | 2 | 0 | 8 | 2 |
| `request_form_screen` | **4** | 0 | 0 | 2 | 3 | 2 |
| `job_history_details_screen` | **4** | 0 | 0 | 2 | 0 | 1 |
| `explore_screen` | **2** | 3 | 0 | 0 | 2 | 1 |
| `wallet_screen` | **2** | 0 | 1 | 0 | 1 | 3 |
| `profile_menu_screen` | 1 | 0 | 0 | 0 | 1 | 0 |
| `worker_portfolio_screen` | 1 | 0 | 0 | 0 | 4 | 0 |
| `job_in_progress_screen` | 0 | 2 | 1 | 0 | **13** | 3 |

Verificar visualmente que alto, radio, color, sombra y animación de presión de estos botones coinciden con `ChambaPrimaryButton`.

### 2.3 Color y estilo visual

- COL-01 Solo tema oscuro; fondo `ChambaBackground` (gradiente de 5 paradas) en todas las pantallas de sesión.
- COL-02 Colores desde `AppTheme.*`. **[HALLAZGO]** colores hardcodeados (`Color(0x…)`/`Colors.red|green|…`):
  `job_history_details` 75, `request_status` 62, `wallet` 44, `request_modality` 31, `incoming_request` 25,
  `explore` 21, `request_form_widgets` 14, `request_form` 13, `messages` 12, `chat` 10, `tracking` 10, `job_in_progress` 9.
  Verificar que el tono coincide con los tokens (morado `#8B5CF6`, amarillo `#EAB308`, éxito `#22C55E`, error `#F97373`).
- COL-03 Estados con color semántico coherente: Pendiente = morado suave, Aceptada/Completado = éxito, Rechazada/Cancelado = error, Expirada = gris, Advertencia = `colorWarning`.
- COL-04 Tarjetas `GlassCard`: radio 20 (contenedores 20–24), borde 1 px `colorGlassBorder`, padding 16.
- COL-05 Inputs: radio 14, borde 1.2 px, foco 1.5 px `colorPrimaryLight`, icono prefijo muted.
- COL-06 Contraste: texto muted `#9FB0C6` sobre fondo `#07111F` y sobre tarjetas glass ≥ 4.5:1; texto blanco sobre amarillo `#EAB308` (variante amarilla del botón) — **medir**, probablemente < 4.5:1.
- COL-07 Espaciado: márgenes laterales 20–24, entre secciones 16–20.

### 2.4 Textos, idioma y formato

- TXT-01 Español latinoamericano con tildes y ñ correctas. **[HALLAZGO]** cadenas sin tilde, entre otras:
  `explore_screen` ("ubicacion", "Sesion expirada… sesion", "estas buscando", "Sin categorias", "analizara/sugerira"),
  `request_form_screen` ("ubicacion", "Maximo 5 fotos", "imagenes", "Sesion expirada", "Camara", "Galeria"),
  `empty_requests_screen` ("Actualizar busqueda", "Busqueda actualizada"),
  `identity_verification_screen` ("No se encontro sesion", "Verificacion enviada"),
  `profile_menu_screen` ("Cerrar sesion", "Quieres cerrar tu sesion actual?" — falta "¿").
  Contraste: `worker_portfolio_screen` sí usa "Cámara/Galería" → misma acción con distinta ortografía.
- TXT-02 Moneda: un solo formato. **[HALLAZGO]** coexisten `Bs 120` (counter_offer, request_status, wallet, tracking, worker_profile…) y `Bs. 120` (`incoming_request_screen`). `DESIGN_SPEC.md` además indica prefijo "$". Definir: `Bs 120,00` o `Bs 120.00` y aplicarlo en todas partes, con separador de miles.
- TXT-03 Mayúsculas: hoy se mezclan CTAs en mayúsculas ("VOLVER AL INICIO", "CONFIRMAR LLEGADA", "LLEGUÉ AL SITIO", "TRABAJO TERMINADO", "CALIFICAR", "HACER CONTRAOFERTA") con CTAs en *sentence case* ("Volver al inicio" en `request_status`, "Aceptar trabajo"). Mismo texto, distinta forma: "VOLVER AL INICIO" (blocked) vs "Volver al inicio" (request_status).
- TXT-04 Los mensajes de error no exponen excepciones crudas. **[HALLAZGO]** `'Error: $e'` (incoming_request), `'Error al aceptar oferta: $e'` (request_status), `'Error al seleccionar imagenes: $e'` (request_form), `'Error al enviar verificacion: $e'` (identity_verification).
- TXT-05 Fechas y horas en formato local (`dd/MM/yyyy`, 24 h o 12 h — decidir uno).
- TXT-06 Textos largos (nombres, direcciones, descripciones) truncan con elipsis y no rompen el layout.

### 2.5 Estados de pantalla

Para cada pantalla que carga datos:

- EST-01 **Cargando**: indicador morado centrado o skeleton; sin parpadeo del estado vacío antes de los datos.
- EST-02 **Vacío**: icono 64 px muted + título `headlineSmall` + descripción `bodyLarge` + CTA opcional.
- EST-03 **Error**: mensaje entendible + botón "Reintentar" que realmente vuelve a cargar.
- EST-04 **Sin conexión**: aparece `OfflineBanner` (global, `app.dart`); al volver la red, la pantalla se recupera sola o con "Reintentar".
- EST-05 **Sesión expirada (401)**: redirige a Login una sola vez, sin pila de pantallas rota.
- EST-06 **Pull-to-refresh** donde hay listas (mensajes, notificaciones, historial, billetera).

### 2.6 Navegación y comportamiento general

- NAV-01 Botón atrás de Android: comportamiento esperado en cada pantalla (no sale de la app desde un flujo intermedio; desde el shell, confirma o minimiza).
- NAV-02 Transición `FadeUp` (300–400 ms, easeOutCubic) uniforme.
- NAV-03 Doble tap rápido en un elemento que navega no apila dos pantallas iguales.
- NAV-04 Teclado: no tapa el campo enfocado ni el botón de enviar; se cierra al tocar fuera.
- NAV-05 Rotación: la app está bloqueada en vertical o soporta horizontal sin romperse (decidir).
- NAV-06 Notch / barra de gestos: contenido dentro de `SafeArea`; bottom nav no queda bajo la barra de gestos.

### 2.7 Accesibilidad

- ACC-01 TalkBack / VoiceOver: cada control interactivo anuncia nombre y rol. **[HALLAZGO]** solo 2 usos de `Semantics(` en todo `lib/`.
- ACC-02 Escala de texto 1.3 y 2.0 (ver TIP-06). Solo `request_form_widgets.dart` consulta `textScalerOf`.
- ACC-03 Información no transmitida solo por color (estados de oferta llevan texto además de color).
- ACC-04 Contadores regresivos anunciados de forma razonable (no cada segundo).

### 2.8 Rendimiento

- REN-01 Arranque en frío < 3 s hasta la primera pantalla útil en gama media.
- REN-02 Mapas: desplazamiento a ≥ 50 fps, sin fugas al entrar/salir 10 veces (`explore`, `incoming_request`, `tracking`, `job_in_progress`, `request_form`).
- REN-03 Temporizadores y sockets se cancelan al salir de cada pantalla (sin `setState() called after dispose`).
- REN-04 Imágenes de red con placeholder y caché (`ChambaNetworkImage`).

---

## 3. Mapa de navegación

```
SplashScreen
 ├─ sin sesión ───────────────► LoginScreen ─┬─► RegisterScreen ─► TermsAndConditionsScreen
 │                                            └─► GoogleAccountTypeScreen
 ├─ usuario bloqueado ────────► BlockedScreen ─► LoginScreen
 ├─ trabajador sin habilidades ► SkillsSelectionScreen
 ├─ faltan permisos ──────────► RequiredPermissionsScreen ─► (siguiente)
 └─ con sesión ───────────────► MainShellScreen
                                 ├─ CLIENTE: [Explorar] [Mensajes] [Perfil]
                                 └─ TRABAJADOR: [Solicitudes] [Billetera] [Mensajes] [Perfil]

Cliente
 Explore ─► RequestModality ─► RequestForm ─► RequestStatus ─┬─► WorkerProfile
                                                             ├─► Tracking ─► Chat / Support
                                                             └─► Support
 trabajo finalizado ─► RatingScreen ─► MainShell / Support

Trabajador
 IncomingRequest ─┬─► CounterOffer
                  ├─► VerificationCheckpoint ─► IdentityVerification ─► MainShell
                  ├─► JobInProgress ─► Chat / Messages / Support
                  └─► Chat

Perfil ─► JobHistory ─► JobHistoryDetails ─► Chat / Rating
       ─► SkillsSelection · WorkModalities · WorkerPortfolio · VerificationCheckpoint
       ─► RequestStatus · Tracking · Rating · Support · Login (cerrar sesión)
Mensajes ─► Notifications ;  Push ─► notification_router ─► Chat / Support / RequestOutcome / …
```

Sin ruta de entrada en el código: `RadarScreen`, `EmptyRequestsScreen` (ver M13).

---

## 4. Pruebas por módulo y pantalla

Formato de cada caso: **ID — Descripción → Resultado esperado.**
Además de los casos listados, cada pantalla pasa el checklist de la sección 2.

### M1 — Arranque y onboarding

#### 1.1 `SplashScreen` (`onboarding/.../splash_screen.dart`)
Diseño: logo 150×150 en contenedor glass, "Chamba" `displayLarge`, barra de progreso, "Cargando…" `bodySmall` (único `fontSize` literal: 11 → debería ser 12).

- SPL-01 Sin sesión guardada → navega a `LoginScreen`.
- SPL-02 Sesión de usuario bloqueado → `BlockedScreen`.
- SPL-03 Trabajador sin habilidades → `SkillsSelectionScreen(forceToHomeAfterSave: true)`.
- SPL-04 Faltan permisos requeridos → `RequiredPermissionsScreen` y luego el destino correcto.
- SPL-05 Sesión válida → `MainShellScreen` con el rol correcto (cliente 3 tabs / trabajador 4 tabs).
- SPL-06 Trabajo activo guardado en sesión → reanuda en la pantalla del trabajo en curso.
- SPL-07 Sin red al arrancar → mensaje claro y reintento; no se queda colgado indefinidamente.
- SPL-08 Token expirado → Login (sin crash).
- SPL-09 Cold start desde push → llega a la pantalla de la notificación (no al inicio). Relacionado con `AppFlows.initialRouteResolved`.
- SPL-10 El splash usa `pushReplacement`: atrás desde la pantalla siguiente no vuelve al splash.

#### 1.2 `RoleSelectionScreen`
Diseño: icono 112×112, "CHAMBA", tagline amarillo, descripción, botón primario + `OutlinedButton`.

- ROL-01 "Iniciar sesión" → Login; "Crear cuenta" → Register.
- ROL-02 Ambos botones de igual ancho y alto (52); el outlined con radio 16.
- ROL-03 Verificar si la pantalla sigue en uso: el splash va directo a Login. Si no tiene entrada, tratar como huérfana (M13).

#### 1.3 `RequiredPermissionsScreen`
Permisos: ubicación, ubicación siempre, ubicación precisa, notificaciones, intent de pantalla completa, batería sin restricciones (Android).

- PER-01 Cada permiso muestra título + descripción + estado (concedido/pendiente).
- PER-02 "Solicitar" abre el diálogo del sistema; al conceder, el estado se actualiza sin reiniciar.
- PER-03 Permiso denegado permanentemente → botón abre Ajustes del sistema; al volver, "Volver a verificar permisos" refresca.
- PER-04 El botón de continuar solo se habilita con los permisos obligatorios (definir cuáles lo son por rol).
- PER-05 Cliente no ve permisos exclusivos de trabajador (ubicación siempre, batería) si no aplican.
- PER-06 Android 13+ (notificaciones runtime) y Android 14 (full screen intent) — probar ambos.
- PER-07 iOS: textos de `Info.plist` coherentes con lo que muestra la pantalla.
- PER-08 Botones: 1 primario, 2 outlined, 1 text — revisar jerarquía (BTN-01).

#### 1.4 `BlockedScreen`
- BLK-01 Muestra motivo/mensaje y CTA. CTA "VOLVER AL INICIO" en mayúsculas → alinear con TXT-03.
- BLK-02 El CTA cierra sesión y lleva a Login; atrás no regresa a contenido protegido.

### M2 — Autenticación

#### 2.1 `LoginScreen` (flujo en 2 pasos)
- LOG-01 Paso 1: campo "Correo o teléfono" vacío → error de validación; botón deshabilitado o mensaje inline.
- LOG-02 Identificador inexistente → mensaje claro (y ofrecer crear cuenta).
- LOG-03 Identificador válido → pasa a paso 2 con contraseña; se muestra el identificador elegido.
- LOG-04 "Cambiar usuario" vuelve al paso 1 conservando el texto.
- LOG-05 Toggle mostrar/ocultar contraseña funciona y tiene tooltip.
- LOG-06 Contraseña incorrecta → error sin revelar si el usuario existe más allá de lo ya mostrado.
- LOG-07 Login correcto cliente → shell cliente; trabajador → shell trabajador (o habilidades si no tiene).
- LOG-08 "Continuar con Google": cuenta nueva → `GoogleAccountTypeScreen`; cuenta existente → shell; cancelar el selector → sin error rojo.
- LOG-09 Doble tap en "Siguiente"/"Entrar" no envía dos peticiones (BTN-04).
- LOG-10 Teclado: tipo email en paso 1, acción "siguiente/enviar" del teclado ejecuta la acción.
- LOG-11 "Crear cuenta" → `RegisterScreen`. **[HALLAZGO]** No existe "Olvidé mi contraseña" en `features/auth` aunque DESIGN_SPEC lo describe: un usuario sin Google que olvida su clave no puede recuperar la cuenta. Definir si se implementa.
- LOG-12 Tipografía: único literal `fontSize: 12`. Botones: 1 primario + 2 outlined + 2 text → revisar jerarquía.

#### 2.2 `RegisterScreen`
Campos: chips "Quiero contratar" / "Quiero trabajar", Nombre, Apellido (opcional), Correo, Teléfono (opcional, `IntlPhoneField`), CI (solo trabajador), Contraseña, aceptar Términos.

- REG-01 Cambiar rol muestra/oculta "Número de Carnet (CI)" y su validación.
- REG-02 Nombre y correo obligatorios; correo con formato inválido rechazado.
- REG-03 Contraseña < 4 caracteres → error. **Revisar política**: 4 caracteres es débil; proponer ≥ 8.
- REG-04 Teléfono: prefijo por defecto de Bolivia (+591), validación de longitud, se permite vacío.
- REG-05 Sin aceptar términos → no permite crear cuenta y lo indica.
- REG-06 "Ver Términos y Condiciones" abre `TermsAndConditionsScreen` y al volver conserva lo escrito.
- REG-07 Correo/CI ya registrados → mensaje claro del backend.
- REG-08 Registro trabajador → flujo de habilidades/permisos; cliente → permisos/shell.
- REG-09 Formulario largo con teclado abierto: scroll correcto hasta el botón.
- REG-10 "Ya tengo cuenta" vuelve a Login.

#### 2.3 `GoogleAccountTypeScreen`
- GAT-01 Dos tarjetas: "Quiero Ofrecer Servicios" / "Quiero Contratar" con descripción. Title Case aquí vs sentence case en Register ("Quiero contratar") → TXT-03.
- GAT-02 Elegir tipo crea el perfil y continúa al flujo correcto; atrás no deja cuenta a medias.
- GAT-03 Tipografía: literales 14, 18, 20, 32 → mapear a tokens. Sin `ChambaPrimaryButton`: verificar consistencia de las tarjetas-botón.

#### 2.4 `TermsAndConditionsScreen`
- TYC-01 Texto completo, scroll fluido, legible (literal 13 → 12 o 15).
- TYC-02 Botón atrás/cerrar con tooltip; fecha/versión de los términos visible.

### M3 — Shell, navegación inferior y elementos globales

#### 3.1 `MainShellScreen` + `ChambaBottomNavWithBadge`
- SHL-01 Cliente: tabs Explorar · Mensajes · Perfil. Trabajador: Solicitudes · Billetera · Mensajes · Perfil.
- SHL-02 Icono activo morado, inactivo muted; label 11 px. Spec dice label "siempre muted" → confirmar que el label activo es distinguible.
- SHL-03 Badge de mensajes no leídos (rojo, ≥ 18×18) se actualiza en tiempo real y se limpia al leer. "99+" para valores grandes.
- SHL-04 Cambiar de tab conserva el estado (scroll, filtros) de cada tab.
- SHL-05 `IncomingRequestScreen(isActive: currentIndex == 0)`: al salir del tab se pausan polling/mapa; al volver se reanudan.
- SHL-06 Bottom nav: alto 72, radio superior 24, no se superpone con la barra de gestos ni con FABs/sheets.
- SHL-07 Atrás de Android en el shell (NAV-01).

#### 3.2 Globales
- GLB-01 `OfflineBanner`: aparece al perder red en cualquier pantalla (incluidos diálogos), no tapa el AppBar, desaparece al reconectar. Literal 13 px.
- GLB-02 `ToastService`: estilo único (fondo `colorSurfaceSoft`, borde glass, icono de estado), 3 s, sobre el bottom nav; tipos éxito/error/info con colores correctos.
- GLB-03 `ConfettiCelebration`: no bloquea interacción, literales 13.5 y 19 → tokens.
- GLB-04 Sonidos (`SoundEffectService`, `NewRequestAlert`) respetan modo silencio/vibración.

### M4 — Cliente: Explorar y crear solicitud

#### 4.1 `ExploreScreen` (tab principal del cliente)
Elementos: mapa con zoom ±/centrar, compositor de texto con micrófono (voz), ayuda, panel de trabajadores cercanos, banner de trabajo en curso, "Ver solicitudes cercanas", "Verificar mi perfil".

- EXP-01 Ubicación desactivada / denegada / bloqueada → `_buildLocationBlocked` con CTA "Activar ubicación"/"Permitir ubicación" que funciona en cada caso.
- EXP-02 Mapa centra en la ubicación del usuario; botones zoom +/- y centrar ≥ 48 px con tooltip.
- EXP-03 Muestra "Trabajadores cercanos: N" y marcadores consistentes con N.
- EXP-04 Enviar texto vacío → "Describe primero lo que estás buscando."
- EXP-05 Texto válido → análisis (loading visible) → `RequestModalityScreen` con categorías sugeridas.
- EXP-06 Voz: permiso de micrófono denegado → mensaje; reconocimiento no disponible → "Reconocimiento de voz no disponible"; feedback sonoro al iniciar/parar; animación del nivel del micrófono.
- EXP-07 Hoja de ayuda (`_showHelpSheet`) se abre/cierra y su texto tiene tildes.
- EXP-08 Con trabajo activo → banner "TRABAJO EN CURSO" que lleva a `TrackingScreen`; con solicitud abierta → `RequestStatusScreen`.
- EXP-09 Evento de socket `new offer` mientras se está en Explore → aviso y acceso a la solicitud.
- EXP-10 Evento `job finished` → navega a Rating una sola vez.
- EXP-11 Pull/refresh y `_refresh` no duplican marcadores.
- EXP-12 Ruta `explore → IncomingRequestScreen`: confirmar en qué caso un cliente llega ahí (¿rol dual?) y si es intencional.
- EXP-13 Tipografía: 9 tamaños distintos (10–18) → unificar. 3 primarios + 2 Elevated → BTN-01/BTN-02.

#### 4.2 `RequestModalityScreen`
Opciones: "Por trabajo — Precio cerrado", "Por hora — Pagas por horas trabajadas", "Por día — Pagas una jornada completa".

- MOD-01 Selección única, estado seleccionado claro (no solo color).
- MOD-02 Continuar → `RequestFormScreen` con la modalidad elegida.
- MOD-03 Tipografía: 11, 12, 12.5, 14, 20, 27 → fuera de escala; 31 colores hardcodeados.
- MOD-04 Atrás vuelve a Explore conservando el texto escrito.

#### 4.3 `RequestFormScreen` + `request_form_widgets.dart`
Secciones: Información del servicio (descripción 0/120), Detalles (categoría, ubicación, fecha y hora de inicio), Monto total, Método de pago, Fotos (cámara/galería/archivos, máx. 5).

- FRM-01 Descripción: contador `n/120`, no permite exceder; descripción vacía bloquea el envío con mensaje.
- FRM-02 Categoría: picker muestra sugeridas; obligatorio.
- FRM-03 Ubicación: detecta GPS, geocodifica a dirección; "Ver / Actualizar ubicación" abre mapa; "Actualizar con mi GPS actual" y "Confirmar y cerrar" funcionan; sin mapa → "Mapa no disponible".
- FRM-04 GPS con timeout (10 s) → mensaje y reintento.
- FRM-05 Fecha/hora de inicio: no permite fechas pasadas; formato local; texto de fecha usa `start_date_label`.
- FRM-06 Monto: solo numérico, > 0, con prefijo de moneda coherente (TXT-02); teclado numérico.
- FRM-07 Método de pago: carga métodos (loading), selección, error si no hay métodos; tarjeta vía Stripe (probar con tarjeta de prueba en staging).
- FRM-08 Fotos: cámara, galería y archivos; la 6.ª foto muestra "Máximo 5 fotos"; eliminar miniatura; error de selección sin excepción cruda (TXT-04).
- FRM-09 Subida a Cloudinary con red lenta: progreso visible, el envío espera a las subidas, fallo parcial manejado.
- FRM-10 Envío (timeout 12 s) → `RequestStatusScreen`; doble tap no crea dos solicitudes.
- FRM-11 Sesión expirada durante el envío → "Sesión expirada." y Login.
- FRM-12 Regla de negocio: cliente con una solicitud activa no puede crear otra (confirmar regla con backend).
- FRM-13 Con escala de texto 1.3/2.0: `request_form_widgets` cambia layout según `textScaler` (< 1.15) → verificar ambas ramas.
- FRM-14 Tipografía: 11 tamaños distintos incluidos 12.5, 13.5, 23 y en widgets 10.5, 15.5 → peor pantalla de la app en escala tipográfica.
- FRM-15 Textos: "Camara/Galeria" sin tilde vs "Cámara/Galería" en portafolio.

### M5 — Cliente: Estado de la solicitud y ofertas

#### 5.1 `RequestStatusScreen`
Elementos: mapa con avatares, lista de ofertas con contador, orden (Más recientes / Menor precio / Mayor precio), mejorar presupuesto, editar, compartir, cancelar solicitud, aceptar oferta, ver perfil.

- RST-01 Sin ofertas → "Nadie ha aceptado aún. Sube tu presupuesto…" + CTA "Mejorar presupuesto".
- RST-02 Oferta nueva por socket aparece sin recargar; contador regresivo por oferta; al expirar desaparece o cambia a "Expirada".
- RST-03 Ordenar por las 3 opciones produce el orden correcto.
- RST-04 Mejorar oferta: monto ≤ actual → "Debe ser mayor a Bs X"; monto válido → presupuesto actualizado y notificado a trabajadores.
- RST-05 Aceptar oferta → banner "¡OFERTA ACEPTADA!/¡TRABAJO CONFIRMADO!" y paso a `TrackingScreen`; doble tap no acepta dos ofertas.
- RST-06 Aceptar oferta de un trabajador que ya tomó otro trabajo → error claro (regla "un worker = un trabajo").
- RST-07 "Ver perfil" → `WorkerProfileScreen` con los datos del trabajador de esa oferta.
- RST-08 Compartir solicitud → hoja del sistema; "Enlace copiado al portapapeles".
- RST-09 Cancelar solicitud → confirmación ("Sí, cancelar solicitud" / "No, volver"); orden de botones BTN-07; trabajadores con oferta son notificados.
- RST-10 Reconexión de socket (`_onReconnect`, ping loop) tras modo avión 30 s → estado correcto sin duplicados.
- RST-11 Eventos `job completed/cancelled/reminder` → navegación única (AppFlows).
- RST-12 Solicitud inexistente → "Volver al inicio".
- RST-13 `_isSimulating` / `_isWorkerThinking` animan rutas "ping" hacia los trabajadores en el mapa; `_load` pone `_isSimulating = false` en ambas ramas, así que la animación parece no ejecutarse nunca tras la primera carga. Confirmar si es código muerto. Además usa coordenadas fijas de La Paz (-16.5002, -68.1342) si la solicitud no trae ubicación → verificar que el mapa no se centre en La Paz para usuarios de otras ciudades.
- RST-14 Botones: 8 Elevated + 2 secundarios + 8 text → mayor dispersión de estilos; 62 colores hardcodeados. Emoji 🎉 en títulos: decidir si es estilo oficial.

#### 5.2 `WorkerProfileScreen`
- WPR-01 Avatar, nombre, rating, habilidades, galería, reseñas, tarifas por modalidad (Bs).
- WPR-02 Estados vacíos de habilidades, galería y reseñas.
- WPR-03 Tocar foto de galería → visor a pantalla completa con cierre.
- WPR-04 CTA para aceptar/contratar desde el perfil (si existe) coherente con el de `RequestStatus`.
- WPR-05 Tipografía: literal 32 (nombre) y 11–16.

### M6 — Trabajador: Solicitudes entrantes, ofertas y verificación

#### 6.1 `IncomingRequestScreen` (tab principal del trabajador, 2 723 líneas)
Elementos: mapa con ubicación propia y radio, interruptor DISPONIBLE/OCUPADO/EN TRABAJO, botón "Mi ubicación", filtros, tarjeta de solicitud, acciones (Aceptar trabajo, contraofertar, No me interesa, Bloquear cliente, Reportar publicación, Ver detalles), tarjeta flotante de oferta aceptada.

- INC-01 Toggle disponibilidad: cambia estado en backend, muestra loading y no permite toggles concurrentes.
- INC-02 Trabajador no verificado → "Verificación requerida" → `VerificationCheckpointScreen`.
- INC-03 "Mi ubicación" sin GPS → "Activa el GPS para centrar tu ubicación".
- INC-04 Filtros: "Aplicar filtros" filtra la lista; reset de filtros.
- INC-05 Nueva solicitud por socket → aparece con animación, sonido/alerta, "hace X min" correcto.
- INC-06 Polling cada 8 s no duplica tarjetas ni parpadea.
- INC-07 "Aceptar trabajo" (acepta presupuesto) → "Oferta enviada"; muestra "Tu oferta Bs X" con contador de 120 s.
- INC-08 Contraofertar → `CounterOfferScreen`; al volver se ve la oferta enviada.
- INC-09 Oferta expirada → "Tu oferta expiró. Puedes mejorarla." + "Reofertar".
- INC-10 Oferta rechazada → "Oferta declinada".
- INC-11 Contraoferta del cliente → aviso y opción de aceptarla.
- INC-12 Oferta aceptada por el cliente → banner animado (elasticOut 600 ms) + "Ver Trabajo"/"Ir al Chat" → `JobInProgressScreen`.
- INC-13 "No me interesa" → "Solicitud descartada" y no vuelve a aparecer.
- INC-14 "Bloquear cliente" → confirmación → "Cliente bloqueado"; sus solicitudes desaparecen.
- INC-15 "Reportar publicación" → motivo obligatorio ("Motivo del reporte...") → "Publicación reportada".
- INC-16 "Ir al Chat" antes de aceptar → "El chat se habilita al aceptar una oferta."
- INC-17 Con trabajo asignado: estado OCUPADO/EN TRABAJO; no puede ofertar a otras solicitudes (regla backend nueva en `mobile-offers.service.ts`).
- INC-18 Solicitud cancelada por el cliente mientras se ve → se retira con aviso.
- INC-19 `isActive=false` (otro tab) → no suena alerta duplicada ni consume GPS innecesariamente.
- INC-20 Errores sin excepción cruda (`'Error: $e'`, TXT-04).
- INC-21 Moneda "Bs." (con punto) aquí vs "Bs" en el resto (TXT-02).
- INC-22 Botones: 9 Elevated + 4 Outlined + 6 Text + 1 Primary + 1 Secondary → revisar jerarquía de la tarjeta de solicitud (un solo primario: "Aceptar trabajo", variante amarilla según spec).
- INC-23 Tipografía: 10 tamaños distintos (10–22).

#### 6.2 `CounterOfferScreen`
- CTO-01 Muestra detalles del trabajo ("ver detalles") y precio según modalidad (por trabajo/hora/día).
- CTO-02 Presets +5 % / +10 % / +20 % calculan bien y redondean de forma consistente.
- CTO-03 Edición manual: monto inválido → "Ingresa un monto válido."; ¿se permite contraofertar por debajo del presupuesto? Definir regla.
- CTO-04 Enviar → "Contraoferta enviada correctamente" y vuelve; doble tap seguro.
- CTO-05 Sin solicitud activa → "No hay solicitud activa."
- CTO-06 "HACER CONTRAOFERTA" en mayúsculas (TXT-03). Literales 12–22.

#### 6.3 `VerificationCheckpointScreen`
- VCP-01 Explica por qué verificar; "Verificar ahora" → `IdentityVerificationScreen`; "Volver" regresa.
- VCP-02 Estado "en proceso" o "rechazada" muestra el mensaje adecuado en vez del CTA genérico.

#### 6.4 `IdentityVerificationScreen`
- IDV-01 Paso 1 foto del carnet; paso 2 selfie; indicador de progreso de 2 barras.
- IDV-02 Permiso de cámara denegado → mensaje + Ajustes.
- IDV-03 Error de cámara → "Error al tomar foto del carnet" / "Error al tomar selfie".
- IDV-04 Enviar sin ambas fotos → "Por favor toma ambas fotos".
- IDV-05 Retomar foto en cada paso; previsualización correcta (orientación).
- IDV-06 Envío exitoso → "Verificación enviada correctamente" → shell; estado pendiente visible en Perfil ("Verificación en proceso").
- IDV-07 Aprobación/rechazo desde admin → push `verification_update` y cambio de estado en la app.
- IDV-08 Textos sin tilde (TXT-01); error crudo `$e` (TXT-04).

### M7 — Trabajo en curso

#### 7.1 `JobInProgressScreen` (trabajador)
Estados: EN CAMINO → LLEGASTE → EN TRABAJO → TRABAJO TERMINADO.

- JIP-01 Ruta en mapa (`_fetchRoute`), distancia formateada (m/km), seguir al trabajador.
- JIP-02 "LLEGUÉ AL SITIO" fuera de la zona → confirmación "¿Ya estás en el lugar?" / "Todavía no".
- JIP-03 Llegada marcada → "Llegada marcada. Esperando confirmación del cliente."
- JIP-04 Cliente confirma llegada → estado EN TRABAJO con cronómetro.
- JIP-05 "Marcar como completado" → confirmación → diálogo de completado **una sola vez** (fix reciente) → inicio.
- JIP-06 Cancelar trabajo → confirmación → cliente notificado → inicio; si se pierde el evento de cancelación la pantalla no queda atascada (fix reciente).
- JIP-07 Chat, Mensajes y Soporte/Reporte accesibles.
- JIP-08 Ubicación en segundo plano: con app minimizada el cliente sigue viendo la posición (`worker_background_service`).
- JIP-09 Reconexión (`_onReconnect`) restaura el estado real del trabajo.
- JIP-10 Botones: 13 `TextButton` → revisar jerarquía y unificar CTAs principales en mayúsculas (TXT-03).
- JIP-11 Tipografía: incluye **9 px** (ilegible) → TIP-02.

#### 7.2 `TrackingScreen` (cliente)
- TRK-01 Posición del trabajador en vivo y ruta; contador de mensajes no leídos en el acceso al chat.
- TRK-02 Trabajador llega → "CONFIRMAR LLEGADA" activo; al confirmar arranca el cronómetro.
- TRK-03 Modalidad por hora: "CRONÓMETRO EN VIVO", "TIEMPO TRANSCURRIDO", "COSTO ACUMULADO" correctos; pausar/reanudar sincroniza con servidor (`_serverElapsedSeconds`).
- TRK-04 Modalidad por día: "TRABAJO POR JORNADA DIARIA"; precio fijo: "PRECIO FIJO GARANTIZADO".
- TRK-05 Cronómetro sobrevive a minimizar/reabrir la app (reloj del servidor).
- TRK-06 Cancelar trabajo → "¿Estás seguro de que deseas cancelar?" (No / Sí).
- TRK-07 Trabajo completado → `RatingScreen` una vez.
- TRK-08 Tipografía: 11 tamaños (9–26), incluye **9 px**.

#### 7.3 `RequestOutcomeScreen`
- OUT-01 Abierta desde push (`request_timeout`, `request_closed`…): muestra "Resultado del trabajo" con el estado correcto; "Reintentar" ante error.
- OUT-02 CTA final coherente con el resto de pantallas de resultado.

### M8 — Calificación

#### 8.1 `RatingScreen`
- RAT-01 5 estrellas táctiles (≥ 48 px), vacías muted, llenas amarillas; selección anunciada a lector de pantalla.
- RAT-02 Enviar sin estrellas → bloqueado con mensaje.
- RAT-03 Comentario opcional, límite de caracteres visible.
- RAT-04 Enviar → "Calificación enviada: N estrellas" → shell; no se puede calificar dos veces el mismo trabajo.
- RAT-05 Sin servicio finalizado → "No hay servicio finalizado para calificar."
- RAT-06 "Reportar" → `SupportScreen` con contexto del trabajo.
- RAT-07 Atrás: ¿se puede omitir la calificación? Comportamiento definido y consistente (pantalla abierta con `pushAndRemoveUntil`).
- RAT-08 CTA "CALIFICAR" en mayúsculas (TXT-03).

### M9 — Mensajería y notificaciones

#### 9.1 `MessagesScreen`
- MSG-01 Lista de conversaciones: avatar, "Nombre · estado", último mensaje truncado, hora, badge no leídos.
- MSG-02 Accesos a "Historial de trabajos" y "Notificaciones" (con badge de no leídas).
- MSG-03 Mensaje nuevo por socket → la conversación sube al inicio y el badge se actualiza.
- MSG-04 Estado vacío y pull-to-refresh.
- MSG-05 Conversaciones de trabajos cerrados: solo lectura (ver `job_chat_policy`).
- MSG-06 Tipografía: literal 28 y otros 7 tamaños. DESIGN_SPEC describe tabs "Activos/Archivados" que no existen → actualizar spec o implementar.

#### 9.2 `ChatScreen` ("Chat del trabajo")
- CHT-01 Mensajes propios a la derecha (morado), ajenos a la izquierda (glass); hora; agrupación por fecha (`_dateLabel`).
- CHT-02 Enviar texto: vacío deshabilitado; envío optimista; fallo → reintento visible.
- CHT-03 Respuestas rápidas (`_quickReplies`) insertan/envían el texto correcto.
- CHT-04 Fotos: "Tomar foto del trabajo" / "Elegir foto" → "Revisando y enviando foto..." → visor a pantalla completa.
- CHT-05 Alerta de contacto ("Mantengamos tu trabajo protegido" / "Entendido") al compartir teléfono/correo/enlaces.
- CHT-06 Paginación hacia arriba (`_loadOlder`) sin saltos de scroll.
- CHT-07 Marcar como leído al ver (`_scheduleRead`) y doble check.
- CHT-08 Trabajo cerrado → chat cerrado (`_closed`), composer deshabilitado con explicación.
- CHT-09 Teclado no tapa el composer; scroll al final al abrir y al enviar.
- CHT-10 Dos dispositivos: mensajes llegan en < 2 s en ambos sentidos; sin duplicados tras reconexión.

#### 9.3 `NotificationsScreen`
- NOT-01 Lista con icono por tipo, título, cuerpo, hora; no leídas resaltadas.
- NOT-02 Tocar una notificación navega al destino correcto (mismo mapeo que push, ver M12) y la marca como leída.
- NOT-03 Estado vacío, error + "Reintentar", pull-to-refresh.

### M10 — Trabajador: Perfil profesional y billetera

#### 10.1 `SkillsSelectionScreen`
- SKL-01 Chips de categorías; mínimo 1 ("Selecciona al menos 1 habilidad"), máximo 5 ("Selecciona máximo 5 habilidades").
- SKL-02 "Nueva categoría" (diálogo, ej. "Instalación de paneles"): vacía rechazada, duplicada rechazada, se agrega y queda seleccionada.
- SKL-03 Guardar → "Habilidades guardadas: N"; con `forceToHomeAfterSave` va al shell, si no vuelve al perfil.
- SKL-04 Sin conexión → "Sin conexión. Intenta nuevamente."; 401 → "Sesión expirada…".
- SKL-05 Grid de chips con nombres largos y escala de texto 2.0.

#### 10.2 `WorkModalitiesScreen`
- WMD-01 Activar/desactivar "Por trabajo", "Por hora" (tarifa por hora), "Por día" (tarifa por día).
- WMD-02 Tarifa obligatoria y > 0 para modalidades activas; formato Bs.
- WMD-03 Al menos una modalidad activa.
- WMD-04 Guardar persiste y se refleja en `WorkerProfileScreen` del lado cliente.
- WMD-05 Navega a `VerificationCheckpointScreen` si corresponde.

#### 10.3 `WorkerPortfolioScreen` + `WorkerPortfolioGallery`
- PRT-01 Estado vacío "Aún no tienes fotos publicadas" + "Agregar foto".
- PRT-02 Agregar desde Galería/Cámara, descripción opcional, "Publicar".
- PRT-03 Eliminar foto → confirmación "Esta foto dejará de aparecer en tu perfil." (Cancelar/Eliminar en rojo).
- PRT-04 Límite de fotos y tamaño de archivo; subida lenta con progreso.
- PRT-05 Las fotos aparecen en el perfil público del trabajador.
- PRT-06 Código con escapes `á` en strings: verificar que se renderizan como "á".

#### 10.4 `WalletScreen` (tab Billetera)
- WAL-01 Resumen: total ganado, Trabajos, Promedio, Efectivo, Tarjeta/Digital — los números cuadran entre sí.
- WAL-02 Filtros de período: Hoy, Esta semana, Este mes, Total (y "Últimos 3 días" si existe) recalculan todo.
- WAL-03 **Solo** trabajos completados y pagados suman; ofertas rechazadas/canceladas no (bug equivalente hallado por Codex en el admin).
- WAL-04 "Actividad reciente" + "Ver todo" → modal de historial; "Estadísticas" → modal.
- WAL-05 Estado vacío → "Buscar trabajos" lleva al tab Solicitudes.
- WAL-06 Sin red → estado offline; 401 → Login.
- WAL-07 Tipografía: literal **40** para el total (fuera de escala, mayor que `displayLarge` 32), 24, 18, 16, 14. 44 colores hardcodeados.

### M11 — Perfil, historial y soporte

#### 11.1 `ProfileMenuScreen`
- PRF-01 Avatar 80×80 editable: "Elegir nueva foto", "Quitar foto" → "Foto actualizada"/"Foto eliminada"; ver foto a pantalla completa.
- PRF-02 Opciones del trabajador: Mis trabajos (portafolio), Historial y pagos, Mis habilidades, Modalidades de trabajo, Verificación, Soporte, Cerrar sesión.
- PRF-03 Opciones del cliente: Seguimiento activo, Mis solicitudes, Historial de trabajos, Calificar servicio, Soporte, Cerrar sesión.
- PRF-04 Cada opción navega al destino correcto (ver mapa §3); "Seguimiento activo" sin trabajo activo → mensaje, no pantalla rota.
- PRF-05 Badge de mensajes de soporte no leídos (`_unreadSupportCount`).
- PRF-06 "Verificación en proceso" visible cuando corresponde.
- PRF-07 Cerrar sesión → confirmación "¿Quieres cerrar tu sesión actual?" → Login; limpia sesión, socket y token push (otro usuario en el mismo teléfono no recibe pushes del anterior).
- PRF-08 Todas las filas con mismo alto, icono, subtítulo y chevron; "Cerrar sesión" en rojo.
- PRF-09 Literales 12 y 26 → tokens. Textos sin tilde (TXT-01).

#### 11.2 `JobHistoryScreen`
- HIS-01 Lista de trabajos finalizados y cancelados con monto (Bs), fecha y estado.
- HIS-02 Estado vacío, error + "Reintentar", paginación si aplica.
- HIS-03 Tocar → `JobHistoryDetailsScreen`.

#### 11.3 `JobHistoryDetailsScreen`
- HSD-01 Etiqueta de estado (COMPLETADO, CANCELADO, EN CURSO, ASIGNADO) con color semántico (COL-03).
- HSD-02 Categoría, ubicación (mapa), ID del trabajo, montos y método de pago correctos.
- HSD-03 Abrir chat → conversación histórica; sin conversación → "No hay una conversación activa para este trabajo."
- HSD-04 Calificar desde el historial si aún no se calificó; ya calificado → oculto o deshabilitado.
- HSD-05 **75 colores hardcodeados** (máximo de la app) y 4 Elevated + 2 Outlined → revisión visual completa contra tokens.

#### 11.4 `SupportScreen`
- SUP-01 Motivos: Problema con el cobro, Trabajador no se presentó, Trabajo mal realizado, Comportamiento inadecuado, Otro problema.
- SUP-02 "Reportar un problema" crea una disputa vinculada al trabajo (cuando se abre desde un trabajo).
- SUP-03 Chat con soporte: "Escribe tu mensaje...", envío, mensajes del admin en tiempo real, marcar como leído, autoscroll solo si se está cerca del final.
- SUP-04 Disputas activas listadas; disputa resuelta se refleja (push `dispute_resolved`).
- SUP-05 Si el envío falla, **el borrador no se pierde** (bug equivalente encontrado por Codex en el admin).
- SUP-06 Literal 22 y otros 6 tamaños.

### M12 — Push, segundo plano y alertas

Fuente: `core/push/notification_router.dart`, `notification_presentation_policy.dart`, `worker_background_service.dart`.

| ID | Tipo de push | Destino esperado | Primer plano | Segundo plano | App cerrada |
|---|---|---|---|---|---|
| PSH-01 | `message_new`, `chat_message` | Chat del trabajo | ☐ | ☐ | ☐ |
| PSH-02 | `support_message`, `dispute_created`, `dispute_resolved` | Soporte | ☐ | ☐ | ☐ |
| PSH-03 | `new_review`, `verification_update` | Perfil / Notificaciones | ☐ | ☐ | ☐ |
| PSH-04 | `request_new` (trabajador) | Solicitudes entrantes | ☐ | ☐ | ☐ |
| PSH-05 | `offer_accepted`, `arrival_confirmed`, `job_starting_soon`, `worker_arrived`, `job_finished` | Trabajo en curso / Tracking / Rating | ☐ | ☐ | ☐ |
| PSH-06 | `offer_new`, `counter_offer`, `offer_client_counter`, `improve_offer_reminder`, `request_timeout`, `offer_rejected`, `request_closed` | RequestStatus / IncomingRequest / RequestOutcome | ☐ | ☐ | ☐ |

- PSH-07 En primer plano, la política de presentación evita mostrar un push del chat que ya está abierto.
- PSH-08 Push recibido por el rol equivocado (cuenta cambiada en el mismo teléfono) → ignorado.
- PSH-09 `fullScreenIntent` de nueva solicitud con pantalla bloqueada (Android 14).
- PSH-10 Servicio en segundo plano del trabajador: notificación persistente con texto claro; se detiene al ponerse No disponible o cerrar sesión.
- PSH-11 `VolumeService`/`NewRequestAlert`: alerta audible respetando modo silencio; sin sonido duplicado si hay dos pantallas escuchando.

### M13 — Pantallas sin ruta (código huérfano)

- ORF-01 `RadarScreen` (591 líneas): ningún archivo la instancia. Decidir: enlazarla (DESIGN_SPEC la describe como "zona de trabajo") o eliminarla. Si se enlaza, probar slider de radio 1–50 km, disponibilidad y resumen.
- ORF-02 `EmptyRequestsScreen`: sin uso. Mismo criterio.
- ORF-03 `RoleSelectionScreen`: confirmar si tiene entrada real (el splash va a Login).
- ORF-04 `DESIGN_SPEC.md` describe `offers_screen.dart` (no existe), tabs "Activos/Archivados" (no existen) y prefijo "$". Actualizar la especificación tras esta ronda de pruebas.

---

## 5. Flujos de extremo a extremo (E2E)

Ejecutar con dos dispositivos simultáneos (cliente y trabajador) contra staging.

| ID | Flujo | Pasos clave | Resultado esperado |
|---|---|---|---|
| E2E-01 | Camino feliz precio cerrado | Cliente crea solicitud → trabajador acepta presupuesto → cliente acepta oferta → trabajador "Llegué" → cliente confirma → trabajador completa → cliente califica | Cada pantalla cambia de estado en < 3 s, sin diálogos duplicados; billetera e historial reflejan el monto |
| E2E-02 | Por hora con pausas | Igual que E2E-01 con modalidad por hora, pausar/reanudar 2 veces | Costo acumulado = tarifa × tiempo efectivo, igual en ambos teléfonos y en el admin |
| E2E-03 | Negociación | Trabajador contraoferta → cliente mejora presupuesto → trabajador reoferta → cliente acepta | Montos correctos en cada paso; ofertas viejas expiradas |
| E2E-04 | Oferta expira | Trabajador oferta y nadie responde 120 s | Ambos lados muestran expiración; reofertar funciona |
| E2E-05 | Cancelación en cada etapa | Cancelar (cliente y trabajador) antes de aceptar, en camino, tras llegada, en trabajo | Ambos vuelven al inicio una vez, con aviso; trabajo marcado cancelado; trabajador queda disponible |
| E2E-06 | Un trabajador = un trabajo | Trabajador con trabajo asignado intenta ofertar a otra solicitud | Bloqueado por backend con mensaje claro |
| E2E-07 | Registro trabajador completo | Registro → permisos → habilidades → modalidades → verificación → aprobación en admin → recibir solicitud | Cada paso persiste; push de verificación llega |
| E2E-08 | Pérdida de red | Modo avión 60 s en cada fase de E2E-01 | `OfflineBanner`, reconexión, estado final correcto, sin duplicados |
| E2E-09 | App matada | Matar la app del trabajador durante "en camino" y reabrir | Reanuda en `JobInProgressScreen` con el estado real |
| E2E-10 | Push en frío | Con app cerrada, recibir `offer_new` / `message_new` y tocar | Abre directamente el destino, no el inicio |
| E2E-11 | Bloqueo y reporte | Trabajador bloquea cliente y reporta otra publicación | No ve más solicitudes de ese cliente; reporte visible en admin |
| E2E-12 | Disputa | Cliente reporta "Trabajo mal realizado" → admin responde → resuelve | Chat de soporte en tiempo real y notificación de resolución |
| E2E-13 | Cambio de cuenta | Cerrar sesión cliente y entrar como trabajador en el mismo teléfono | Sin datos, badges ni pushes de la cuenta anterior |

---

## 6. Matriz de dispositivos y configuraciones

| Config | Ancho lógico | Escala texto | Prioridad |
|---|---|---|---|
| Android pequeño (p. ej. 360×640) | 360 | 1.0 / 1.3 | Alta (gama baja en Bolivia) |
| Android medio (p. ej. Pixel 7, 412×915) | 412 | 1.0 / 2.0 | Alta |
| Android con notch y gestos | 393 | 1.0 | Media |
| Tablet Android 10" | 800 | 1.0 | Baja |
| iPhone SE (375×667) | 375 | 1.0 / 1.3 | Media (si hay iOS) |
| iPhone 15 (393×852) | 393 | 1.0 | Media |

Versiones de Android: 10, 12, 13, 14, 15. Ejecutar todo el checklist de la sección 2 al menos en 360 px con escala 1.3.

---

## 7. Pruebas automatizadas

### 7.1 Existentes (`test/`)
`auth_session_test`, `job_session_test`, `create_request_usecase_test`, `worker_usecases_test`, `worker_job_clock_test`,
`worker_portfolio_test`, `job_history_payment_test`, `request_form_controls_test`, `job_chat_events_test`,
`job_chat_policy_test`, `job_chat_widgets_test`, `notification_presentation_policy_test`, `widget_test`,
`api_test` (requiere `API_BASE_URL` de staging; no ejecutar contra producción).
Último resultado registrado: 45 OK con `api_test` fallando por falta de URL.

### 7.2 Propuestas
- AUT-01 **Golden tests** por pantalla a 360 px y 412 px, escala 1.0 y 1.3 (detecta regresiones de tipografía/botones).
- AUT-02 Test de lint propio: falla si aparece `fontSize:` con valor fuera de la escala, o `Color(0x` fuera de `app_theme.dart`.
- AUT-03 Widget tests de validación: Login (2 pasos), Register (CI condicional, contraseña), RequestForm (120 caracteres, 5 fotos), CounterOffer (presets), Skills (1–5).
- AUT-04 Test de `notification_router`: cada tipo de la tabla M12 → pantalla esperada por rol.
- AUT-05 Test de `AppFlows`: dos `goToRating` en < 5 s abren una sola pantalla.
- AUT-06 `integration_test` para E2E-01 con backend de staging o mock.
- AUT-07 Test de billetera: solo trabajos completados suman (WAL-03).

---

## 8. Resumen de hallazgos del análisis estático

Pendientes de confirmar en dispositivo. Severidad propuesta: A = alta, M = media, B = baja.

| # | Hallazgo | Dónde | Sev. |
|---|---|---|---|
| H-01 | Texto de 9 px (ilegible) | `tracking_screen`, `job_in_progress_screen` | A |
| H-02 | Tamaños fraccionarios 10.5/12.5/13.5/15.5 y valores fuera de escala (14, 16, 18, 22, 23, 26, 27, 28, 40) | 18 archivos, ver §2.1 | M |
| H-03 | Botones `ElevatedButton/FilledButton` crudos en lugar de `ChambaPrimaryButton` | 8 pantallas, ver §2.2 | M |
| H-04 | Colores hardcodeados fuera de `AppTheme` (hasta 75 en una pantalla) | ver COL-02 | M |
| H-05 | Moneda inconsistente: "Bs" vs "Bs." (y "$" en la spec) | `incoming_request_screen` vs resto | M |
| H-06 | Textos sin tildes / sin "¿" | explore, request_form, empty_requests, identity_verification, profile_menu | M |
| H-07 | Mayúsculas inconsistentes en CTAs ("VOLVER AL INICIO" vs "Volver al inicio") | blocked, job_in_progress, tracking, rating, counter_offer | B |
| H-08 | Excepciones crudas `$e` mostradas al usuario | incoming_request, request_status, request_form, identity_verification | M |
| H-09 | Accesibilidad casi ausente: 2 `Semantics`, 14 `tooltip` | global | M |
| H-10 | Pantallas sin ruta: `RadarScreen`, `EmptyRequestsScreen` | worker/request | B |
| H-11 | Animación "ping" (`_isSimulating`) aparentemente muerta y coordenadas fijas de La Paz como respaldo del mapa | request_status | B |
| H-12 | Contraseña mínima de 4 caracteres | register | M |
| H-13 | `DESIGN_SPEC.md` desactualizado (offers_screen, tabs de mensajes, "$") | docs | B |
| H-14 | Contraste de texto blanco sobre amarillo `#EAB308` | `ChambaPrimaryButton` variante amarilla | M |
| H-15 | Riesgo de que la billetera sume ofertas no completadas (análogo al bug del admin) | wallet | A si se confirma |
| H-16 | No hay flujo de recuperación de contraseña | login | A |

---

## 9. Registro de defectos y criterios de salida

### 9.1 Plantilla de defecto

```
ID: BUG-XXX            Caso: <ID del caso, p. ej. FRM-08>
Módulo / pantalla:     M4 / RequestFormScreen
Dispositivo / SO:      Pixel 7, Android 14, escala texto 1.3
Rol / cuenta:          Cliente U-C1
Pasos:                 1. … 2. … 3. …
Resultado esperado:    …
Resultado actual:      …
Severidad:             Crítica | Alta | Media | Baja
Evidencia:             capturas-app/<archivo>.png (sin datos personales visibles)
```

Severidad: **Crítica** = bloquea un flujo de dinero/trabajo o pierde datos; **Alta** = función principal falla con workaround difícil;
**Media** = inconsistencia visible o función secundaria falla; **Baja** = cosmético.

### 9.2 Criterios de salida
- 100 % de los casos de M2, M4, M5, M6, M7 y E2E-01 a E2E-06 ejecutados.
- 0 defectos críticos y 0 altos abiertos.
- Checklist §2 aprobado en 360 px y 412 px.
- Tipografía y botones: hallazgos H-01 a H-03 resueltos o aceptados explícitamente.

---

## 10. Instrucciones para la revisión de Codex

Codex: por favor revisa este plan **contra el código** de `app-chamba/lib` (y contratos de `backend-chamba` donde aplique) y deja tus comentarios en una sección nueva al final de este archivo (`## 11. Revisión de Codex`), sin borrar contenido. Puntos concretos:

1. **Cobertura**: ¿falta alguna pantalla, diálogo, bottom sheet o estado relevante? ¿Algún flujo de negocio del backend (pagos Stripe, disputas, bloqueo, regla un worker = un trabajo) sin caso?
2. **Exactitud**: confirma o corrige los hallazgos H-01 a H-16, en especial H-11 (animación en `RequestStatusScreen`), H-15 (billetera), H-16 (recuperar contraseña) y la existencia de rutas para `RadarScreen`/`EmptyRequestsScreen`/`RoleSelectionScreen`.
3. **Reglas de negocio**: valida los límites usados (120 caracteres, 5 fotos, 1–5 habilidades, 120 s de oferta, polling 8 s, contraseña ≥ 4) contra backend.
4. **Escala tipográfica y botones**: ¿estás de acuerdo con la escala permitida de §2.1 y la jerarquía de §2.2, o propones otra?
5. **Prioridad**: marca qué casos deberían automatizarse primero (§7.2).
6. **Restricciones**: no modificar la app ni ejecutar pruebas contra producción durante la revisión; coordinar en `COMUNICACION_AGENTES.md`.
