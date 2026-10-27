# Design

## Context

- **App:**
  - `ios/project.yml` tiene dos configuraciones, `Debug` y `Release`, que comparten `Cruce/Config/Cruce.xcconfig`.
  - Ese archivo incluye `ios/Config.xcconfig`, que git ignora. Ahí, `SUPABASE_URL[config=…]` y `SUPABASE_ANON_KEY[config=…]` eligen el destino por configuración.
  - `SupabaseConfig` lee esas claves del `Info.plist` y detiene la app si faltan o si siguen con el texto `pega-aqui…`.
  - Hay un solo identificador, `com.joanrojas.cruce`, y un solo esquema, `Cruce`.
  - `DebugScreen` y `AppStores.sample` existen solo con `#if DEBUG`.
- **Supabase:**
  - `scripts/backup-db.sh` respalda `--linked`: el proyecto que dejó en `supabase/.temp/project-ref` el último `supabase link`.
  - Las migraciones se subieron con `supabase db push` sobre ese mismo proyecto vinculado.
- **Cuenta de Apple:** es gratuita. Permite instalar desde Xcode, pero con límites de apps instaladas y de identificadores por semana.

## Goals / Non-Goals

**Goals:**
- Que elegir el ambiente sea elegir un esquema en Xcode o un argumento en un script. Nada de editar archivos para cambiar de destino.
- Que el camino a prod siempre sea explícito: confirmación escrita, respaldo antes de migrar y ningún respaldo de configuración.

**Non-Goals:**
- Crear el proyecto de prod, que va con la primera versión en TestFlight. Queda todo listo para cuando exista: un identificador vacío y una sección en el `.xcconfig`.
- Ramas de Supabase (Branching), que es del plan de pago.
- Subir migraciones desde GitHub Actions.
- Ambientes del backend de Go (CP8).

## Decisions

### D1. `Staging` es una configuración nueva, basada en `Release`
- **Qué:** en XcodeGen, `configs: { Debug: debug, Staging: release, Release: release }`.
- **Por qué de tipo release:** testing debe probar lo mismo que irá a prod, con optimizaciones y sin `DEBUG`. Por eso no trae `DebugScreen` ni los datos de ejemplo.
- **Alternativa descartada:** basar `Staging` en `debug`. Habría dejado código de prueba en la app que usan Joan y Jesús, y la app de testing no se parecería a la de prod.

### D2. Lo que cambia por configuración vive en `Cruce/Config/Cruce.xcconfig` (versionado)
- **Ajustes por configuración:**
  - `PRODUCT_BUNDLE_IDENTIFIER`: `.dev`, `.staging` o ninguno;
  - `APP_DISPLAY_NAME`: "Cruce Dev", "Cruce Test" o "Cruce";
  - `ASSETCATALOG_COMPILER_APPICON_NAME`: `AppIconDev`, `AppIconTest` o `AppIcon`;
  - `APP_ENVIRONMENT`: `local`, `testing` o `prod`.
- **Dónde:** van con selectores `[config=…]` en ese archivo, que ya está en git. El `ios/Config.xcconfig` ignorado conserva solo la URL y la clave anónima de cada ambiente.
- **Info.plist:** toma `CFBundleDisplayName = $(APP_DISPLAY_NAME)` y una clave nueva, `CRUCE_ENVIRONMENT = $(APP_ENVIRONMENT)`.
- **Por qué:** los ajustes que no son secretos quedan revisables en git. Los que dependen de quien desarrolla siguen fuera.
- **Alternativa descartada:** `settings.configs` en `project.yml`. Funciona, pero reparte la configuración en dos lugares.

### D3. Tres esquemas
- **Cuáles:**
  - `Cruce`: ejecutar con `Debug`. Se queda con ese nombre porque `ios.yml` y la documentación lo usan.
  - `Cruce Test`: ejecutar y archivar con `Staging`.
  - `Cruce Prod`: ejecutar y archivar con `Release`.
- **Por qué:** elegir el ambiente es elegir el esquema en la barra de Xcode.

### D4. El ambiente se lee del `Info.plist` y lo muestra Ajustes
- **Qué:** `SettingsView.appVersion` agrega `" · \(ambiente)"` cuando `CRUCE_ENVIRONMENT` existe y no es `prod`.
- **Prueba:** la regla vive en una función pura de CruceCore (`AppVersionText`, o el nombre que se elija), probada con `swift test`.
- **Alternativa descartada:** una cinta sobre todas las pantallas. Ensucia las capturas y el diseño, y el ícono y el nombre ya distinguen la app.

### D5. Prod sin claves se detiene, sin plan B
- **Qué:** `SupabaseConfig` ya detiene la app si falta una clave.
- **Cambio:** `Config.example.xcconfig` deja la sección de `Release` con `pega-aqui…` y una nota de que prod todavía no existe.
- **Paso manual:** el `ios/Config.xcconfig` local de Joan hoy tiene las claves de testing en `Release`. Se pasan a `Staging` y `Release` queda vacío.
- **Prueba:** se agrega una que confirma que un `Info.plist` sin claves falla en lugar de tomar otras.

### D6. Identificadores de los proyectos en `supabase/ambientes.env` (versionado)
- **Contenido:** `TESTING_PROJECT_REF=pqdjiecynyjnianslikp` y `PROD_PROJECT_REF=` (vacío por ahora).
- **Por qué versionado:** el identificador no es un secreto; ya aparece en la URL pública de la app.
- **Uso:** los scripts lo cargan con un ayudante común, `scripts/lib/ambiente.sh`. El ayudante traduce `testing` o `prod` en el identificador del proyecto y falla con un mensaje claro si el ambiente no existe o si su identificador está vacío.

### D7. Los scripts vinculan el proyecto en cada corrida
- **Qué:** `db-push.sh` y `backup-db.sh` corren `supabase link --project-ref <ref>` justo antes de trabajar y dicen en pantalla a qué ambiente apuntan.
- **Por qué:** el vínculo guardado en `supabase/.temp` es estado oculto. Si se confía en él, es fácil respaldar o migrar el proyecto equivocado.
- **Contraseñas:** la de la base la sigue pidiendo el CLI, o la lee de `SUPABASE_DB_PASSWORD`. Cada proyecto tiene la suya.
- **`db-push.sh prod`, en orden:**
  1. pide escribir `prod`;
  2. corre `backup-db.sh prod`;
  3. corre `supabase db push --linked`.
  
  Si un paso falla, se detiene ahí.
- **Antes de aplicar:** los dos ambientes muestran primero `supabase db push --dry-run`.

### D8. Íconos de local y testing generados desde el ícono original
- **Qué:** `AppIconDev` y `AppIconTest` se generan desde `AppIcon-1024.png` con ImageMagick. Cada uno lleva una franja en tinta (`CruceColor.ink`) con "DEV" o "TEST" en Archivo Black, sobre el amarillo de la marca.
- **Por qué:** se distingue a simple vista sin inventar colores nuevos.
- **El comando** queda en `ios/README.md` para poder regenerarlos.

## Risks / Trade-offs

- **[Cuenta gratuita de Apple]** Limita cuántas apps instaladas desde Xcode hay a la vez y cuántos identificadores nuevos se registran por semana. Con tres identificadores puede tocar el límite → En el iPhone basta con tener testing, y local vive en el simulador. Se documenta en `ios/README.md` y en CLAUDE.md §8.
- **[El Debug cambia de identificador]** La app de Debug ya instalada en el simulador y en el iPhone queda vieja → Se borra a mano una vez. Se actualizan los comandos `simctl launch` en CLAUDE.md §4, `DebugScreen` y la memoria del proyecto.
- **[Proyecto gratis en pausa]** Supabase pausa los proyectos gratis tras una semana sin uso, y testing puede quedar pausado → Se reactiva desde el panel. Va en `supabase/README.md`.
- **[Plantilla del correo por proyecto]** Hay que pegarla en cada proyecto. En testing ahora; en prod cuando exista → Se deja como paso del runbook de prod.
- **[Respaldos sin ambiente]** Los respaldos viejos en `backups/` no dicen de qué ambiente son → Todos son del proyecto actual, o sea testing. No se renombran.

## Migration Plan

1. Fusionar el cambio.
2. Cada quien corre `xcodegen` y mueve sus claves de nube de `Release` a `Staging` en `ios/Config.xcconfig`.
3. Joan, opcional: renombra el proyecto `cruce` a `cruce-testing` en el panel de Supabase. El identificador no cambia.
4. **Vuelta atrás:** revertir el commit y volver a correr `xcodegen`. Ninguna base de datos cambia con este cambio.
