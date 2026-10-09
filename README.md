# Redmont Hustle

Videojuego 3D en primera persona de mundo abierto inspirado en *Schedule I*: empiezas sin
nada en una ciudad ficticia, montas un negocio clandestino **ficticio** (productos, recetas y
efectos inventados), atiendes pedidos por teléfono, evitas a la policía y vas ampliando
propiedades, empleados y territorio.

> Todo el contenido es ficción de juego: "Glimmer" y "Azure" son productos inventados, y
> todas las operaciones son sistemas simulados dentro del juego.

---

## 1. Tecnología elegida

**Godot 4.3 + GDScript** (renderizador *Forward+*, con *Compatibility/OpenGL* como alternativa).

Motivos:
- Motor 3D completo, ligero y gratuito; el proyecto se abre y ejecuta sin compilar nada.
- Física integrada (CharacterBody3D, RigidBody3D, Area3D) para jugador, NPC y objetos.
- Interfaz (Control/Containers), audio, guardado (FileAccess/JSON) y entrada configurable nativos.
- Proyecto en texto plano (escenas `.tscn` y scripts `.gd`), fácil de versionar y ampliar.

Todo el contenido gráfico y sonoro es **procedural** (shaders propios, iconos generados por
código, audio sintetizado al arrancar), así que no hay recursos externos que puedan faltar ni
referencias rotas.

---

## 2. Instalación y ejecución

### Requisitos
- **Godot 4.3** (estándar, no hace falta la versión .NET): <https://godotengine.org/download>
  (probado con `Godot_v4.3-stable`). Las versiones 4.4+ también deberían abrirlo.
- PC con GPU compatible con Vulkan (Forward+). Si tu GPU es antigua, ver "Modo compatibilidad".

### Ejecutar desde el editor
1. Abre Godot → **Importar** → selecciona la carpeta del proyecto (`project.godot`).
2. Pulsa **F5** (o el botón ▶). Se abre el menú principal.

### Ejecutar desde la línea de comandos
```bash
godot --path /ruta/a/game2
```

### Modo compatibilidad (GPU antigua / sin Vulkan)
```bash
godot --path /ruta/a/game2 --rendering-driver opengl3
```
(En este modo el SSAO no está disponible; el resto funciona igual.)

### Exportar un ejecutable
En el editor: **Proyecto → Exportar… → Añadir… → Windows Desktop / Linux** (descarga las
plantillas de exportación si Godot lo pide) → **Exportar proyecto**.

### Pruebas automáticas
```bash
# Prueba de integración del bucle de juego (sale con código 0 si todo pasa)
godot --headless --path . res://tests/test_runner.tscn
# Con renderizado real (recomendado, p. ej. con xvfb-run en Linux sin pantalla):
godot --rendering-driver opengl3 --path . res://tests/test_runner.tscn
```

---

## 3. Controles (todos reasignables en *Opciones → Controles*)

| Acción | Tecla por defecto |
|---|---|
| Moverse | W A S D |
| Correr (gasta resistencia) | Mayús izq. |
| Saltar | Espacio |
| Agacharse (menos visible para la policía) | C |
| Interactuar / hablar / abrir puertas / usar estaciones | E |
| Usar objeto en la mano / agarrar objeto físico / empujar NPC | Clic izquierdo |
| Lanzar objeto agarrado | Clic derecho |
| Soltar objeto (Mayús+G: toda la pila) | G |
| Casillas de la barra rápida | 1 – 8 o rueda del ratón |
| Inventario | I |
| Teléfono | Tab (o flecha arriba) |
| Mapa | M |
| Linterna | F |
| Guardado rápido / carga rápida (ranura 1) | F5 / F9 |
| Pausa / cerrar ventana | Esc |

En diálogos se pueden elegir las opciones con las teclas 1-9. En el inventario: arrastrar para
mover, Ctrl+arrastrar para mover media pila, Mayús+clic para transferir a la estantería,
clic derecho para usar.

---

## 4. Cómo se juega (bucle principal)

1. Empiezas en la **habitación 4 del Motel Sunset** (Northtown) con $300 y una regadera.
2. Ve al **Lucky Diner** y habla con **Marco**: te da 6 bolsitas de muestra.
3. **Kyle** te escribe al teléfono (Tab → Mensajes). Acepta, ve al punto de encuentro y
   entrégale el pedido hablando con él. Cobras y ganas experiencia.
4. Compra un **kit de maceta** y **tierra** en la Ferretería de Hank y **esporas** en el puesto
   de Ray (callejón). Instala la maceta en un hueco libre (marcador verde) de tu habitación.
5. Echa tierra, planta y **riega** (rellena la regadera en el fregadero). Crece en ~12 h de
   juego (12 minutos reales; 1 s real = 1 min de juego).
6. Cosecha, instala una **estación de empaquetado** y empaqueta en bolsitas o tarros.
7. Vende a tus clientes, regala **muestras** a los vecinos marcados con **?** para conseguir
   clientes nuevos, y deja que los clientes satisfechos te **recomienden**.
8. Duerme en tu cama (desde las 19:00) para pasar la noche y **autoguardar**.
9. Sube de rango para desbloquear **Downtown → Los Muelles → Uptown**, la **estación de
   mezcla** (efectos), el **laboratorio Azure**, nuevas propiedades y empleados.

---

## 5. Funciones terminadas

### Mundo y ambientación
- Ciudad de 4 distritos con calles, aceras, bordillos, pasos de cebra y marcas viales
  (shader procedural), 16 manzanas: **Northtown** (obrero), **Downtown** (oficinas, banco),
  **Los Muelles** (industrial, contenedores, grúa, agua) y **Uptown** (mansiones, villa, parque).
- Fachadas procedurales (ladrillo, paneles, revoque, madera) con ventanas, cornisas y
  **ventanas iluminadas de noche**; casas con tejado a dos aguas, jardín y valla.
- **13 edificios con interior accesible** y puertas animadas: motel (recepción y habitación),
  Gas-Mart, ferretería, diner, taller, apartamento Elm, banco, Neon Lounge, casa de empeños,
  suministros portuarios, nave del puerto, Uptown Gadgets y Villa Hillside. Horarios de apertura.
- Mobiliario: mostradores, estanterías con productos, neveras, reservados, taburetes, camas,
  sofás, televisores, fregaderos, alfombras, plantas, bancos, papeleras, contenedores, bidones.
- **Ciclo día/noche** con sol, luna, cielo procedural, niebla, 64 farolas que se encienden de
  noche y ambiente sonoro diurno/nocturno/interior.
- Coches aparcados, **tráfico** que circula por el carril derecho y frena ante el jugador,
  peatones y otros coches.
- Barreras policiales físicas entre distritos según el rango.

### Jugador
- Primera persona: andar, correr con resistencia, saltar, agacharse, balanceo de cámara,
  pasos, linterna, objeto visible en la mano.
- Interacción contextual (E) con indicador en pantalla; recoger/soltar objetos; agarrar y
  lanzar objetos físicos; empujar NPC (con consecuencias).
- Consumibles (bebida energética, barrita) y equipo permanente (mochila grande, zapatillas).

### Inventario y objetos
- 20 casillas (8 de barra rápida + 12 de mochila), iconos, cantidades, **límite de peso**
  (35 kg, 60 kg con mochila), pilas con datos (calidad/efectos), arrastrar y soltar,
  media pila, transferencia a contenedores, objetos en el suelo, objetos de misión, chatarra.

### Economía y negocio
- 36 objetos definidos en `data/items.json`; 6 tiendas con horario (`data/shops.json`),
  compra por cantidad, venta en la casa de empeños, rebajas por eventos.
- **Producción**: macetas (tierra, plantar, regar, crecimiento con agua, lámpara de cultivo,
  calidad y cosecha), **estación de mezcla** (6 efectos ficticios, hasta 3 por producto,
  aumentan el valor), **empaquetado** (bolsitas 1 u / tarros 5 u), **laboratorio Azure**
  (segundo producto, proceso de 6 h), **estanterías** de 20 casillas. Desmontaje de estaciones.
- **Propiedades**: habitación de motel alquilada ($40/día) y 3 propiedades a la venta
  (apartamento $1.500, nave $7.500, villa $20.000) con 3-10 huecos de estación.
- **Empleados** (botánico, empaquetador, químico) con salario diario que trabajan cada hora
  usando los suministros de las estanterías; se van si no se les puede pagar.
- Gastos diarios a las 7:00 (alquiler y salarios), **banco** con cajero (protege el dinero
  de multas y atracos, límite de ingreso diario), precios de venta configurables por producto,
  mercado con variación diaria por distrito.

### Clientes y NPC
- 16 clientes con distrito, presupuesto, exigencia, efectos preferidos y productos aceptados.
- **Pedidos por teléfono**: aceptar, rechazar o contraofertar (pueden rechazar y abandonar la
  negociación); citas en 13 puntos de encuentro con plazo de 4 h; venta directa cara a cara.
- Satisfacción según calidad y efectos, propinas, **relaciones** (0-100), recomendaciones que
  desbloquean clientes nuevos, **muestras gratis** para captar clientes potenciales.
- NPC con IA: peatones que recorren rutas por un grafo de navegación (aceras, pasos de
  cebra, callejones, puertas), horarios (se van a casa por la noche), saludan, miran al
  jugador, huyen de persecuciones, reaccionan a empujones y ven actividad ilegal como testigos.
- Tenderos y personajes de misión con horarios, diálogos con opciones, consejos, misiones
  ofrecidas y entregas; NPC que se niegan a hablar (de noche, enfadados, desconocidos).
- Personajes animados proceduralmente (andar, correr, gesticular, pánico, girar la cabeza).

### Policía y eventos
- **Sospecha** (0-100) y niveles de búsqueda (bajo sospecha / persecución / busca y captura).
- Agentes que patrullan y **perciben** al jugador (campo de visión, distancia, línea de visión,
  noche y agacharse reducen la visibilidad).
- **Testigos** civiles que denuncian con retraso; la policía acude al lugar.
- **Toque de queda** (22:00-05:00), **registros corporales**, huida de registros, agresión a
  agentes, persecuciones (los agentes abren puertas), escape rompiendo la línea de visión.
- **Detención**: multa (100 + 20% del efectivo), confiscación de objetos ilegales, traslado a
  comisaría, 3 h de calabozo y **cierre temporal del distrito** (12 h) o patrullas reforzadas.
- **Redadas** en propiedades si la sospecha es alta al empezar el día.
- **Eventos aleatorios**: fiestas (demanda +35%), operativos policiales, rebajas, atracadores
  nocturnos y pedidos urgentes.

### Misiones y progresión
- 13 misiones principales encadenadas + 4 secundarias (`data/quests.json`), objetivos de
  hablar, ir a un lugar, comprar, instalar, cosechar, empaquetar, mezclar, producir, vender,
  conseguir clientes, rango, ingresos, comprar propiedades, contratar, recoger y entregar.
- 7 rangos con XP; desbloqueo de distritos, objetos de tienda y empleados por rango.
- Estadísticas completas del jugador.

### Interfaz
- HUD: hora/día/distrito/toque de queda, dinero y banco, rango y XP, sospecha y nivel de
  búsqueda, barra de registro, mira, indicador de interacción, barra rápida, resistencia,
  peso, misión activa, entregas pendientes con tiempo restante, notificaciones y destino
  marcado con flecha y distancia.
- **Teléfono** con 9 apps: Mensajes (pedidos y negociación), Clientes, Mapa, Misiones,
  Productos (precios y mercado), Propiedades, Empleados, Estadísticas y Noticias.
- **Mapa** a pantalla completa con zoom, desplazamiento, puntos de interés, entregas,
  policía cercana, distritos cerrados y destino seleccionable.
- Ventanas de inventario/contenedor, tienda (comprar/vender), diálogo, mezcla, empaquetado,
  cajero, confirmación, dormir, detención, ayuda.
- **Menú principal**, **menú de pausa**, **opciones** (pantalla completa, V-Sync, sombras,
  MSAA, escala 3D, distancia de visión, SSAO, glow, límite de FPS, FPS en pantalla, volúmenes,
  sensibilidad, invertir Y, FOV, balanceo, **reasignación de teclas**) guardadas en
  `user://settings.cfg`.

### Guardado y carga
- Autoguardado al dormir + 3 ranuras manuales + guardado/carga rápida (F5/F9).
- Se guarda: posición y orientación del jugador, hora y día, dinero y banco, inventario,
  ventajas, rango/XP, estadísticas, distritos y cierres, propiedades, estaciones y su estado,
  estanterías, empleados, clientes (relaciones, pedidos, citas, mensajes), misiones,
  sospecha policial, mercado y eventos, objetos sueltos en el mundo y objetos físicos movidos.
- Escritura atómica (fichero temporal + renombrado); la carga recarga la escena completa.
- Ubicación: `user://saves/` (en Windows `%APPDATA%\Godot\app_userdata\Redmont Hustle\saves`).

---

## 6. Funciones pendientes / limitaciones conocidas

Lo siguiente **no** está implementado (o solo parcialmente) y no se presenta como terminado:

- **Conducir vehículos**: los coches aparcados son decorado y el tráfico es solo IA.
- **Colocación libre de estaciones**: se instalan en huecos predefinidos de cada propiedad.
- **Interiores de varias plantas**: solo la planta baja de los edificios es accesible.
- Los NPC civiles no entran en edificios (solo la policía durante una persecución).
- **Vendedores NPC** (que vendan por ti) y **proveedores con entregas a domicilio**.
- **Clima** (lluvia, etc.).
- Combate más allá de empujar; no hay armas (decisión de diseño).
- Personajes con modelos procedurales de primitivas (sin esqueletos ni animaciones
  capturadas); audio y música sintetizados (sin grabaciones ni voces).
- Solo idioma español.
- El rendimiento se ha comprobado con renderizado por software (llvmpipe); no se ha podido
  medir en una GPU real durante el desarrollo. La ciudad genera ~6.100 mallas, de las cuales
  ~5.700 tienen distancia de dibujado por tamaño, y las luces interiores se desvanecen con la
  distancia. Las opciones gráficas (sombras, escala 3D, distancia de visión, SSAO, MSAA)
  permiten ajustarlo en equipos modestos.

---

## 7. Pruebas realizadas

- **Compilación**: todos los scripts se importan sin errores (`godot --headless --editor --quit`).
- **Prueba de integración automatizada** (`tests/test_runner.tscn`, 94 comprobaciones,
  todas OK con renderizado OpenGL real), que recorre:
  partida nueva → abrir puerta → entrar al diner (trigger de ubicación) → diálogo con Marco →
  recompensa → pedido de Kyle → el NPC camina a la cita → entrega por diálogo y cobro →
  compras en 3 tiendas (UI real) → instalar maceta → tierra/plantar/regar → crecimiento con
  paso del tiempo → cosecha → empaquetado → muestra a cliente potencial → **guardar** →
  modificar estado → **cargar** (recarga de escena) → verificar dinero, inventario, día,
  estaciones, misiones, relaciones y posición → detención con multa y confiscación →
  agente que detecta al jugador en toque de queda, se acerca y le registra → tráfico activo →
  subida de rango y apertura de la barrera de Downtown → mezcla con aditivo y aumento de valor
  → compra de propiedad → estantería → contratación de botánica y empaquetador que trabajan
  solos → laboratorio Azure → venta en la casa de empeños → ingreso y retirada en el banco →
  misión secundaria con objeto en el mundo (recoger y entregar) → contraoferta aceptada y
  contraoferta abusiva con abandono del cliente → testigos que denuncian → atracador →
  dormir hasta las 7:00 con autoguardado → apertura de todas las ventanas de UI y apps del teléfono.
- **Capturas de pantalla** automáticas (`tests/screenshot_runner.tscn`) para revisar calles,
  interiores, noche, HUD, teléfono, mapa e inventario.

---

## 8. Estructura del proyecto

```
project.godot            Configuración (autoloads, ventana, físicas, uniforme global night_factor)
data/                    Datos del juego en JSON (objetos, tiendas, clientes, misiones, propiedades)
scenes/                  Escenas: main_menu, game, world/, player/, ui/
shaders/                 Fachadas, asfalto con marcas viales, superficies, agua
scripts/
  autoload/              Singletons: Events, ItemDB, Settings, Audio, GameState, Quests,
                         Customers, Police, Business, RandomEvents, SaveSystem
  core/                  Inventory (casillas/peso/serialización), IconFactory
  systems/               ShopData (tiendas, horarios, precios)
  world/                 World, CityBuilder, DayNight, Door, Station, WorldItem, PhysicsProp,
                         TrafficCar, CarModel, WaypointGraph, Interactable, Mats, Geo
  npc/                   NPC (IA y estados), Humanoid (modelo y animación procedurales)
  player/                Player (controlador en primera persona)
  ui/                    UIManager, HUD, ventanas (inventario, tienda, diálogo, teléfono, mapa,
                         pausa, opciones, guardado, mezcla, empaquetado, cajero...), menú principal
tests/                   Prueba de integración y herramienta de capturas
```

### Cómo ampliar
- **Objetos**: añade una entrada en `data/items.json` (el icono se genera con `icon.shape/color`).
- **Tiendas**: `data/shops.json` (inventario, horario, si compra objetos).
- **Clientes**: `data/customers.json` (aspecto, distrito, gustos, presupuesto, referente).
- **Misiones**: `data/quests.json` (objetivos, diálogos, recompensas, misión siguiente).
- **Edificios/interiores**: funciones `shell()`, `solid()` y `house()` de `city_builder.gd`.
