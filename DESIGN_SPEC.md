# ESPECIFICACIÓN DE DISEÑO — APP CHAMBA

> Documento para rediseño UI. Describe todas las pantallas, componentes, colores, tipografía y patrones de diseño actuales.

---

## 1. PALETA DE COLORES

### Colores Primarios
| Nombre | Hex / RGBA | Uso |
|--------|-----------|-----|
| `colorPrimary` | `#8B5CF6` | Botones principales, íconos activos, acentos |
| `colorPrimaryLight` | `#A78BFA` | Hover, bordes focused, acentos claros |
| `colorPrimaryDark` | `#6D28D9` | Pressed state, sombras |
| `colorPrimaryGlow` | `rgba(139,92,246,0.25)` | Efecto glow en botones/cards |
| `colorPrimarySoft` | `rgba(36,27,75,0.20)` | Fondos de chips no seleccionados |

### Color de Acento (Amarillo)
| Nombre | Hex / RGBA | Uso |
|--------|-----------|-----|
| `colorHighlight` | `#EAB308` | Tagline, botones variante amarilla, badges |
| `colorHighlightSoft` | `rgba(234,179,8,0.20)` | Fondos de alertas/estados especiales |

### Fondos
| Nombre | Hex | Uso |
|--------|-----|-----|
| `colorBg` | `#07111F` | Fondo principal de todas las pantallas |
| `colorBgAccent` | `#0B172A` | Fondo ligeramente elevado |
| `colorBgAlt` | `#111C30` | Fondo alternativo para secciones |
| Gradiente de fondo | `#050B16` → `#091223` → `#0E1A31` → `#11182A` → `#07111F` | Fondo degradado en pantallas principales |

### Glassmorphism
| Nombre | RGBA | Uso |
|--------|------|-----|
| `colorGlassBase` | `rgba(255,255,255,0.10)` | Cards normales |
| `colorGlassHigh` | `rgba(255,255,255,0.16)` | Cards elevadas / dialogs |
| `colorGlassBorder` | `rgba(255,255,255,0.22)` | Borde de cards |
| `colorGlassBorderSoft` | `rgba(255,255,255,0.12)` | Borde de inputs |
| `colorGlassDarkSoft` | `rgba(13,23,42,0.72)` | Overlay oscuro sobre mapa |
| `colorGlassInputSoft` | `rgba(7,17,31,0.82)` | Fondo de inputs de texto |

### Textos y Superficies
| Nombre | Hex | Uso |
|--------|-----|-----|
| `colorText` | `#F8FAFC` | Texto principal (blanco cálido) |
| `colorMuted` | `#9FB0C6` | Texto secundario, labels |
| `colorSurfaceSoft` | `#182235` | Superficies internas de cards |

### Estados
| Nombre | Hex / RGBA | Uso |
|--------|-----------|-----|
| `colorSuccess` | `#22C55E` | Éxito, trabajo completado |
| `colorSuccessSoft` | `rgba(34,197,94,0.20)` | Fondo de estado exitoso |
| `colorError` | `#F97373` | Errores, contadores críticos |
| `colorErrorSoft` | `rgba(249,115,115,0.20)` | Fondo de estado de error |
| `colorWarningSoft` | `rgba(245,158,11,0.20)` | Fondo de advertencias |

---

## 2. TIPOGRAFÍA

**Fuente**: Plus Jakarta Sans (Google Fonts)  
**Tema**: Solo dark mode

### Escala Tipográfica
| Estilo | Tamaño | Peso | Line Height | Color | Letter Spacing |
|--------|--------|------|-------------|-------|----------------|
| Display Large | 32px | 800 (ExtraBold) | normal | colorText | -0.5px |
| Headline Large | 24px | 700 (Bold) | normal | colorText | normal |
| Headline Medium | 20px | 700 (Bold) | normal | colorText | normal |
| Headline Small | 17px | 600 (SemiBold) | normal | colorText | normal |
| Body Large | 15px | 400 (Regular) | 1.5 | colorMuted | normal |
| Body Medium | 15px | 600 (SemiBold) | normal | colorText | normal |
| Body Small | 12px | 500 (Medium) | normal | colorMuted | 0.3px |

---

## 3. COMPONENTES UI GLOBALES

### ChambaPrimaryButton — Botón Principal
- **Forma**: Rectángulo con border-radius 16px
- **Variante Púrpura** (default): fondo `colorPrimary`, texto blanco, sombra púrpura
- **Variante Amarilla**: fondo `colorHighlight`, texto blanco, sombra amarilla
- **Tamaño Regular**: alto 52px, padding 16px horizontal / 13px vertical
- **Tamaño Compact**: alto 44px, padding 12px horizontal / 10px vertical
- **Animación al presionar**: escala a 0.97x en 150ms (easeOut)
- **Deshabilitado**: opacidad 0.6
- **Puede incluir**: ícono a la izquierda + texto

### GlassCard — Tarjeta Glassmorphic
- **Efecto**: `backdrop-filter: blur(10px)`, elevada = 12px
- **Fondo**: `colorGlassBase` normal, `colorGlassHigh` cuando elevada
- **Borde**: 1px sólido `colorGlassBorder`
- **Border-radius**: 20px (configurable)
- **Padding interno**: 16px (configurable)
- **Sombra**: medium normal, large cuando elevada

### ChambaChip — Chip Seleccionable
- **Forma**: Cápsula (border-radius 100px)
- **No seleccionado**: fondo `colorPrimarySoft`, borde `colorPrimaryLight` con 20% opacidad, texto `colorMuted`
- **Seleccionado**: fondo `colorPrimary`, texto blanco, sombra pequeña
- **Padding**: 14px horizontal / 8px vertical
- **Animación**: 180ms easeOut al cambiar estado

### ChambaBackground — Fondo Decorativo
- **Gradiente**: linear de 5 stops (ver paleta de fondos)
- **Círculo de brillo superior-izquierda**: 240px, púrpura 5% opacidad
- **Círculo de brillo inferior-derecha**: 250px, amarillo 5% opacidad
- **Opcional**: grid de puntos superpuesto

### glassInputDecoration — Inputs de Texto
- **Fondo**: `colorGlassInputSoft`
- **Borde normal**: 1px `colorGlassBorderSoft`
- **Borde focused**: 1.5px `colorPrimaryLight`
- **Border-radius**: 14px
- **Padding**: 16px horizontal / 15px vertical
- **Ícono prefix**: color `colorMuted`
- **Cursor**: color `colorPrimary`

### ChambaBottomNav — Navegación Inferior
- **Alto total**: 72px
- **Border-radius superior**: 24px
- **Fondo**: glassmorphism (`colorGlassHigh`)
- **Ícono activo**: `colorPrimary`
- **Ícono inactivo**: `colorMuted`
- **Etiqueta**: siempre `colorMuted`, tamaño 11px
- **Spacing ícono-etiqueta**: 4px vertical
- **Badge**: círculo rojo `colorError`, mín. 18x18px, top-right del ícono

---

## 4. DIMENSIONES Y ESPACIADO

### Border Radius
| Elemento | Valor |
|----------|-------|
| Botones principales | 16px |
| Cards y contenedores | 20-24px |
| Inputs de texto | 14px |
| Chips y cápsulas | 100px |
| Avatares circulares | 50% |
| Bottom nav (superior) | 24px |

### Padding de Pantallas
| Contexto | Valor |
|----------|-------|
| Horizontal de pantalla | 20-24px |
| Vertical de pantalla | 16px |
| Interno de cards | 16px |
| Entre elementos | 8-12px |
| Entre secciones | 16-20px |
| Entre bloques principales | 24-32px |

### Tamaños Fijos
| Elemento | Tamaño |
|----------|--------|
| Avatar login | 100×100px |
| Logo rol/onboarding | 112×112px |
| Logo splash | 150×150px |
| Bottom nav height | 72px |
| Progress bars | 4px alto |
| Badge notificaciones | mín. 18×18px |

---

## 5. SOMBRAS Y EFECTOS

### Box Shadows
```
shadowSm:  y:4px  blur:10px  color: rgba(4,10,20,0.20)
shadowMd:  y:10px blur:28px  color: rgba(2,6,23,0.30)
shadowLg:  y:16px blur:42px  color: rgba(2,6,23,0.40)
shadowYellow: y:10px blur:24px color: rgba(234,179,8,0.25)
```

### Blur / Glassmorphism
- Cards normales: `blur(10px)`
- Cards elevadas / modales: `blur(12px)`

### Animaciones
| Elemento | Duración | Curva |
|----------|----------|-------|
| Transición de página | 300-400ms | easeOutCubic |
| Presión de botón | 150ms | easeOut |
| Chips | 180ms | easeOut |
| Bottom nav tabs | 220ms | AnimatedTextStyle |
| Banner de oferta aceptada | 600ms | elasticOut |

---

## 6. ASSETS ACTUALES

### Imágenes
| Archivo | Uso |
|---------|-----|
| `assets/images/icon/icon.png` | Ícono de la app |
| `assets/images/branding/chamba_splash_logo.png` | Logo en splash screen |
| `assets/images/branding/chamba_handshake_icon.png` | Ilustración de apretón de manos |
| `assets/images/branding/chamba_favicon.png` | Favicon web |

### Iconografía
Sistema de iconos: **Material Icons (Google)**  
Tamaños comunes: 16px, 20px, 24px

Íconos usados:
- `home_filled` — inicio worker
- `chat_bubble` — mensajes
- `person` — perfil
- `account_balance_wallet` — billetera
- `arrow_back` — navegar atrás
- `search` — búsqueda
- `map` — mapa / radar
- `star` — calificación
- `lock_outline` — contraseña
- `person_outline` — nombre / usuario
- `alternate_email` — correo
- `phone_android_outlined` — teléfono
- `badge_outlined` — CI / documento
- `visibility` / `visibility_off` — mostrar contraseña
- `handshake` — rol selector
- `add` / `close` — acciones generales

---

## 7. NAVEGACIÓN Y FLUJOS

### Estructura de Navegación

**Cliente (3 tabs en bottom nav)**
1. Explorar — buscar trabajadores
2. Mensajes — conversaciones activas
3. Perfil — menú de cuenta

**Trabajador (4 tabs en bottom nav)**
1. Solicitudes — trabajos entrantes
2. Billetera — ganancias e historial
3. Mensajes — conversaciones
4. Perfil — menú de cuenta

### Flujo Cliente
```
Splash → Login / Registro → Selección de Rol → Explore
  └─ Explore → Crear Solicitud
  └─ Explore → Ver Perfil Trabajador → Hacer Oferta
  └─ Mensajes → Chat Individual
  └─ Perfil → Editar datos / Historial / Soporte / Logout
```

### Flujo Trabajador
```
Splash → Login / Registro → Selección de Habilidades → Solicitudes Entrantes
  └─ Solicitudes → Ver detalle → Aceptar / Rechazar / Contraofertar
  └─ Billetera → Ver ganancias con filtros
  └─ Mensajes → Chat Individual
  └─ Perfil → Habilidades / Verificación / Historial / Logout
```

### Flujo de Verificación de Identidad
```
Perfil → Verificación → Foto CI → Foto Rostro → Estado pendiente → Aprobado / Rechazado
```

---

## 8. PANTALLAS — DESCRIPCIÓN DETALLADA

---

### SPLASH SCREEN
**Archivo**: `splash_screen.dart`  
**Propósito**: Carga inicial y resolución de ruta de sesión

**Layout** (centrado vertical):
- Logo circular en contenedor glass — 150×150px
- Texto "Chamba" — Display Large, sombra púrpura
- Barra de progreso lineal animada — blanco, 100% ancho
- Texto "Cargando..." — Body Small, opacidad animada

**Comportamiento**: Dura ~2 segundos, luego navega según sesión existente

---

### ROLE SELECTION SCREEN
**Archivo**: `role_selection_screen.dart`  
**Propósito**: Presentación de la app y punto de entrada

**Layout** (centrado vertical, fondo ChambaBackground):
- Ícono handshake en círculo glass — 112×112px
- Texto "CHAMBA" — Display Small, w800
- Tagline "ENCUENTRA TRABAJO. ENCUENTRA TRABAJADORES." — amarillo, w700, centrado
- Descripción breve — Body Large, colorMuted, centrado
- Espacio
- `ChambaPrimaryButton` "Iniciar sesión" — ancho completo
- `OutlinedButton` "Crear cuenta" — ancho completo, borde `colorPrimaryLight`

---

### LOGIN SCREEN
**Archivo**: `login_screen.dart`  
**Propósito**: Autenticación en 2 pasos

**Layout**:
- Logo circular con backdrop filter — 100×100px
- Título "Iniciar sesión" — Headline Small
- **Paso 1**:
  - Input email/teléfono (ícono `person_outline`)
  - `ChambaPrimaryButton` "Siguiente"
  - `TextButton` "Crear cuenta"
- **Paso 2**:
  - Input contraseña (ícono `lock_outline` + toggle visibilidad)
  - `ChambaPrimaryButton` "Entrar"
  - `TextButton` "Cambiar usuario"
  - `TextButton` "Olvidé mi contraseña"

**Validaciones**: Email/teléfono requerido; contraseña requerida

---

### REGISTER SCREEN
**Archivo**: `register_screen.dart`  
**Propósito**: Registro de nueva cuenta

**Layout** (scroll):
- **Selector de rol** — 2 `ChambaChip` en fila: "Quiero contratar" / "Quiero trabajar"
- Input Nombre (ícono `person_outline`) — requerido
- Input Apellido (ícono `badge_outlined`) — opcional
- Input Correo (ícono `alternate_email`) — requerido
- Input Teléfono internacional (`IntlPhoneField`) — opcional
- *Solo si trabajador*: Input CI (ícono `badge_outlined`) — requerido
- Input Contraseña (ícono `lock_outline` + toggle) — mín. 4 caracteres
- Checkbox + texto "Acepto Términos y Condiciones"
- `TextButton.icon` "Ver Términos y Condiciones"
- `ChambaPrimaryButton` "Crear cuenta" — ancho completo
- `TextButton` "Ya tengo cuenta"

Todo envuelto en `GlassCard`

---

### SKILLS SELECTION SCREEN
**Archivo**: `skills_selection_screen.dart`  
**Propósito**: Onboarding del trabajador — elegir habilidades

**Layout**:
- Título + descripción
- Grid de `ChambaChip` (3 columnas aprox.)
  - Construcción, Electricidad, Plomería, Jardinería, Transporte, Limpieza, Mecánica, Carpintería
- `ChambaPrimaryButton` "Guardar" — deshabilitado si no hay selección

---

### IDENTITY VERIFICATION SCREEN
**Archivo**: `identity_verification_screen.dart`  
**Propósito**: Captura de fotos para verificación KYC

**Layout**:
- Indicadores de progreso (2 barras de 4px)
- **Paso 1** — Foto de carnet de identidad
  - Área de imagen con placeholder
  - Botón capturar / galería
  - Instrucciones (texto Body Large)
- **Paso 2** — Foto de rostro
  - Mismo layout que paso 1
- `ChambaPrimaryButton` "Siguiente" / "Completar verificación"

---

### EXPLORE SCREEN (CLIENTE)
**Archivo**: `explore_screen.dart`  
**Propósito**: Vista principal del cliente

**Layout**:
- **Mapa de fondo** (`FlutterMap`) — ocupa ~60% superior
  - Marcadores de trabajadores cercanos
  - Marcador de ubicación propia
- **Barra de búsqueda** flotante sobre mapa
  - Input "Busca una tarea..." con ícono búsqueda
  - Botón de voz
- **Scroll horizontal** de categorías (`ChambaChip`)
- **DraggableScrollableSheet** inferior:
  - Título "Trabajadores cercanos"
  - Lista de cards de trabajadores con: avatar, nombre, habilidades, distancia, rating
- **Banner superior** (si hay solicitud activa): "Tienes una solicitud activa" con botón ver
- `FloatingActionButton` (púrpura, ícono `add`): Crear nueva solicitud

---

### REQUEST FORM SCREEN
**Archivo**: `request_form_screen.dart`  
**Propósito**: Crear solicitud de trabajo

**Layout** (scroll):
- Input Descripción — multiline, mín. 3 líneas
- Dropdown "Tipo de precio": Precio fijo / Por hora
- Input Presupuesto (numérico, prefijo "$")
- Selector de fotos — grid de miniaturas + botón añadir
- Campo de ubicación — dirección con ícono mapa, botón geolocalizar
- Selector de categoría — `ChambaChip` horizontal scroll
- `ChambaPrimaryButton` "Publicar solicitud" — ancho completo

---

### INCOMING REQUEST SCREEN (WORKER)
**Archivo**: `incoming_request_screen.dart`  
**Propósito**: Vista principal del trabajador — solicitudes en tiempo real

**Layout**:
- **Mapa** (`FlutterMap`) — fondo completo
  - Marcador de ubicación del cliente
  - Círculo de rango activo
- **Toggle de disponibilidad** — flotante superior derecha
  - Switch grande con etiqueta "Disponible" / "No disponible"
- **DraggableScrollableSheet**:
  - Si hay solicitud nueva:
    - Datos del trabajo: descripción, presupuesto, distancia
    - Contador regresivo en rojo (120s)
    - Foto(s) del trabajo
    - `ChambaPrimaryButton` "Aceptar" (variante amarilla)
    - `TextButton` "Rechazar"
    - `TextButton` "Ver perfil del cliente"
  - Si no hay solicitudes:
    - Ilustración vacía + texto "Esperando solicitudes..."
- **Banner animado** cuando se acepta una oferta: scale 0.0→1.0 con elasticOut 600ms

---

### RADAR SCREEN (WORKER)
**Archivo**: `radar_screen.dart`  
**Propósito**: Ver y ajustar zona de trabajo del trabajador

**Layout**:
- **Mapa** — fondo completo con círculo de rango
- **Panel inferior** en GlassCard:
  - Slider "Rango de trabajo" — 1km a 50km
  - Toggle de disponibilidad
  - Estadísticas: trabajos en zona, distancia promedio

---

### WALLET SCREEN (WORKER)
**Archivo**: `wallet_screen.dart`  
**Propósito**: Ganancias e historial de trabajos

**Layout**:
- **Header con resumen**: Total ganado (Display Large, amarillo)
- **Filtros de período** — scroll horizontal de `ChambaChip`:
  - Hoy, Últimos 3 días, Esta semana, Este mes, Total
- **Lista de trabajos completados** — GlassCard por trabajo:
  - Título del trabajo
  - Precio acordado (colorSuccess, Body Medium)
  - Fecha/hora (Body Small, colorMuted)
  - Rating recibido (estrellas pequeñas)

---

### MESSAGES SCREEN
**Archivo**: `messages_screen.dart`  
**Propósito**: Lista de conversaciones

**Layout**:
- **TabBar** — "Activos" / "Archivados"
- **Lista de conversaciones** — por cada thread:
  - Avatar circular del otro usuario (40×40px)
  - Nombre + último mensaje (truncado)
  - Fecha/hora
  - Badge de no leídos (si hay)
- **Estado vacío**: Ilustración + texto "No tienes mensajes"
- Pull-to-refresh

---

### CHAT SCREEN
**Archivo**: `chat_screen.dart`  
**Propósito**: Conversación individual

**Layout**:
- **AppBar**: Avatar + nombre del otro usuario, botón atrás
- **Lista de mensajes** (scroll invertido, más reciente abajo):
  - Mensajes propios: alineados derecha, fondo `colorPrimary`, texto blanco, border-radius asimétrico
  - Mensajes ajenos: alineados izquierda, fondo `colorGlassBase`, texto `colorText`, border-radius asimétrico
  - Timestamp debajo de cada mensaje (Body Small, colorMuted)
  - Indicador de "Visto" (doble check, colorPrimaryLight)
- **Barra inferior**:
  - Input texto con placeholder "Escribe un mensaje..."
  - Botón enviar (ícono `send`, púrpura)

---

### OFFERS SCREEN (CLIENTE)
**Archivo**: `offers_screen.dart`  
**Propósito**: Gestionar ofertas recibidas de trabajadores

**Layout** (lista):
- Por cada oferta — GlassCard expandible:
  - Avatar + nombre del trabajador
  - Rating del trabajador (estrellas)
  - Precio ofertado (Headline Medium)
  - Estado: `ChambaChip` de color según estado
    - Pendiente: `colorPrimarySoft`
    - Aceptada: `colorSuccessSoft`
    - Rechazada: `colorErrorSoft`
    - Expirada: gris
  - Contador regresivo si pendiente (rojo)
  - **Botones de acción** (si pendiente):
    - `ChambaPrimaryButton` "Aceptar" (variante amarilla)
    - `TextButton` "Contraofertar"
    - `TextButton` "Rechazar" (colorError)

---

### COUNTER OFFER SCREEN
**Archivo**: `counter_offer_screen.dart`  
**Propósito**: Hacer contraoferta al trabajador

**Layout**:
- Información de la oferta original (GlassCard)
- Input "Nuevo presupuesto" (numérico)
- Input "Comentario" (multiline)
- `ChambaPrimaryButton` "Enviar contraoferta" — ancho completo

---

### WORKER PROFILE SCREEN
**Archivo**: `worker_profile_screen.dart`  
**Propósito**: Ver perfil público de un trabajador

**Layout**:
- Avatar circular grande (80×80px) centrado
- Nombre completo — Headline Large
- Rating promedio — estrellas doradas + número
- Habilidades — fila de `ChambaChip` (no interactivos, estáticos)
- Descripción / "Sobre mí" — Body Large, colorMuted
- Estadísticas: trabajos completados, tiempo en app
- `ChambaPrimaryButton` "Hacer oferta" — ancho completo

---

### RATING SCREEN
**Archivo**: `rating_screen.dart`  
**Propósito**: Calificar al trabajador después de completar el trabajo

**Layout** (centrado):
- Avatar del trabajador
- Nombre del trabajador
- Selector de estrellas — 5 estrellas grandes, interactivas (tocar para seleccionar)
  - Vacías: `colorMuted`
  - Llenas: `colorHighlight` (amarillo)
- Input "¿Cómo fue la experiencia?" — multiline opcional
- `ChambaPrimaryButton` "Enviar calificación"

---

### PROFILE MENU SCREEN
**Archivo**: `profile_menu_screen.dart`  
**Propósito**: Menú central de cuenta

**Layout**:
- Avatar editable (80×80px, ícono de edición en esquina)
- Nombre completo — Headline Medium
- Email — Body Large, colorMuted
- Teléfono — Body Large, colorMuted
- **Lista de opciones** (GlassCard por sección):
  - *Cliente*: Editar perfil, Mis solicitudes, Historial
  - *Trabajador*: Editar perfil, Mis habilidades, Verificación de identidad, Historial de trabajos, Mis calificaciones
  - *Ambos*: Reportes / Reviews, Soporte, Cerrar sesión (rojo)
- Cada opción: ícono izquierda + texto + ícono `chevron_right` derecha

---

### SUPPORT SCREEN
**Archivo**: relacionado con perfil  
**Propósito**: Contacto y ayuda

**Layout**:
- FAQs expandibles (Accordion)
- Botón "Contactar soporte" (chat/email)
- Versión de la app

---

## 9. PATRONES DE DISEÑO RECURRENTES

### Empty States
- Ícono ilustrativo centrado (colorMuted, tamaño 64px)
- Texto principal — Headline Small
- Descripción — Body Large, colorMuted
- Botón opcional de acción

### Loading States
- `CircularProgressIndicator` centrado, color `colorPrimary`
- Pantalla con opacidad reducida (0.5) durante carga

### Error States
- GlassCard con borde `colorErrorSoft`
- Ícono error (rojo)
- Mensaje descriptivo
- Botón "Reintentar"

### Confirmation Dialogs
- Fondo overlay oscuro semi-transparente
- GlassCard centrada (border-radius 24px)
- Título + descripción
- Dos botones: Cancelar (TextButton) + Confirmar (`ChambaPrimaryButton`)

### Snackbars / Toast
- Fondo: `colorSurfaceSoft`
- Borde `colorGlassBorder`
- Ícono de estado a la izquierda
- Duración: 3 segundos
- Posición: bottom, arriba del bottom nav

---

## 10. CONSIDERACIONES GENERALES PARA REDISEÑO

1. **Solo dark theme** — no existe variante light
2. **Glassmorphism** es el lenguaje visual central — aplicar en inputs, cards y modales
3. **Gradiente de fondo** con 5 stops crea profundidad; mantener en todas las pantallas
4. **Púrpura** es el color principal de acción; **amarillo** como acento para llamadas a la atención
5. **Plus Jakarta Sans** en pesos 400–800; mantener consistencia en escala tipográfica
6. **Mínimo 48×48px** para áreas táctiles (accesibilidad)
7. **Bottom nav** es fija y siempre visible durante la sesión activa
8. **Mapas** (`FlutterMap`) ocupan fondo completo en pantallas de explore/radar/solicitudes
9. **Tiempo real**: indicadores de "en línea", contadores regresivos, badges de no leídos son críticos
10. **Español latinoamericano** en todos los textos

---

*Generado: 2026-05-29 — App Chamba v1.0*
