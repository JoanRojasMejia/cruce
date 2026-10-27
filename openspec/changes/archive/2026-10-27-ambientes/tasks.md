# Tasks

## 1. Ambiente visible en Ajustes (lógica)

- [x] 1.1 Agregar en CruceCore la función pura que arma la línea de la versión con el ambiente ("Cruce 1.0 (1) · testing"; en `prod` o sin ambiente, solo la versión). Escribir antes las pruebas de Swift Testing para local, testing, prod y sin ambiente, y verlas fallar. Verificar con `swift test` en verde y `swift format lint --strict`.

## 2. Configuraciones y esquemas de la app

- [x] 2.1 En `ios/project.yml`, agregar la configuración `Staging` de tipo release y los esquemas `Cruce Test` (Staging) y `Cruce Prod` (Release). El esquema `Cruce` sigue con Debug. Usar `Cruce/Config/Cruce.xcconfig` en las tres configuraciones. Verificar que `xcodegen` genera el proyecto y que `xcodebuild -list` muestra las tres configuraciones y los tres esquemas.
- [x] 2.2 En `Cruce/Config/Cruce.xcconfig`, definir por configuración `PRODUCT_BUNDLE_IDENTIFIER`, `APP_DISPLAY_NAME`, `ASSETCATALOG_COMPILER_APPICON_NAME` y `APP_ENVIRONMENT`, y quitar de `project.yml` los valores fijos que se pisan. En el `Info.plist`, usar `CFBundleDisplayName = $(APP_DISPLAY_NAME)` y agregar `CRUCE_ENVIRONMENT = $(APP_ENVIRONMENT)`. Verificar con `xcodebuild -showBuildSettings` en cada configuración que el identificador, el nombre y el ambiente son los esperados.
- [x] 2.3 Generar `AppIconDev` y `AppIconTest` desde `AppIcon-1024.png`, con una franja en tinta con "DEV" o "TEST" en Archivo Black, y dejar el comando de ImageMagick en `ios/README.md`. Verificar mirando los dos PNG y el ícono de la app en el simulador.
- [x] 2.4 Mostrar en `SettingsView` la línea de la versión con la función de 1.1, leyendo `CRUCE_ENVIRONMENT`. Verificar con una captura de Ajustes en el simulador: con Debug dice "· local" y con Staging dice "· testing". *Hecho: Debug muestra "Cruce 1.0 (1) · local" y el `Info.plist` de Staging trae `CRUCE_ENVIRONMENT = testing`. En Staging no se llega a Ajustes sin una cuenta vinculada (CP4), así que la línea "· testing" en pantalla queda para el CP4; la regla está probada con `swift test` y el valor del `Info.plist` se revisó.*
- [x] 2.5 Actualizar `ios/Config.example.xcconfig`: `Debug` va a local, `Staging` a testing (`pqdjiecynyjnianslikp`) y `Release` a prod, con `pega-aqui…` y la nota de que prod todavía no existe. Mover las claves de nube del `ios/Config.xcconfig` local de `Release` a `Staging`. Agregar a las pruebas de `SupabaseConfig.read` el caso "sin claves no toma otras". Verificar:
  - Staging en el simulador entra a testing y pide el código por correo;
  - Release en el simulador se detiene con el mensaje "Falta SUPABASE_URL…";
  - las pruebas pasan.

  *Hecho: Release se detiene con "Fatal error: Falta SUPABASE_URL…" y las pruebas de `SupabaseConfig` pasan (la lectura pasó a CruceCore para poder probarla). Staging arranca contra testing sin errores. El 27 oct 2026 Joan instaló "Cruce Test" en su iPhone y entró con el código que llegó por correo (con SMTP de Gmail en testing; ver `supabase/README.md`).*
- [x] 2.6 Cambiar a `com.joanrojas.cruce.dev` el identificador en el comentario de `DebugScreen`, en los comandos `simctl` de CLAUDE.md §4 y en `ios/README.md`. Documentar en `ios/README.md` los tres esquemas y el límite de la cuenta gratuita. Verificar:
  - `xcrun simctl launch <udid> com.joanrojas.cruce.dev -screen history` abre el historial;
  - `rg -n "com\.joanrojas\.cruce\b" ios CLAUDE.md` ya no encuentra comandos con el identificador viejo;
  - `xcodebuild … build` compila los tres esquemas.

## 3. Scripts de Supabase por ambiente

- [x] 3.1 Crear `supabase/ambientes.env` con `TESTING_PROJECT_REF=pqdjiecynyjnianslikp` y `PROD_PROJECT_REF=` vacío, y `scripts/lib/ambiente.sh`, que traduce `testing` o `prod` en el identificador del proyecto y falla con un mensaje claro si el ambiente no existe o si su identificador está vacío. Verificar con `shellcheck` y corriendo el ayudante con `testing`, con `prod` (debe decir "prod todavía no existe") y con `otro`.
- [x] 3.2 Cambiar `scripts/backup-db.sh` para que reciba `testing`, `prod` o `--local`; sin argumento, que muestre cómo usarlo y termine con error. Que vincule el proyecto antes de respaldar, diga a qué ambiente apunta y ponga el ambiente en el nombre de la carpeta (`backups/<fecha>_<hora>_testing/`). Verificar con `shellcheck`:
  - sin argumento → error y ninguna carpeta;
  - `prod` → "todavía no existe" y ninguna carpeta;
  - `--local` → respaldo con "local" en el nombre;
  - `testing` → respaldo de la nube. Lo corre Joan, porque pide la contraseña de la base.

  *Hecho: `shellcheck` limpio; sin argumento y con `otro` muestra cómo usarlo (salida 2); `prod` dice que todavía no existe; `--local` dejó `backups/2026-10-27_004704_local`, ignorado por git. Joan corrió `testing` el 27 oct 2026: dejó `backups/2026-10-27_005807_testing`.*
- [x] 3.3 Crear `scripts/db-push.sh <testing|prod>`. Debe vincular el proyecto, decir a qué ambiente apunta, mostrar `supabase db push --dry-run` y aplicar. En prod, además, pide escribir `prod`, corre `backup-db.sh prod` y se detiene si algo falla. Verificar con `shellcheck`:
  - sin argumento → error;
  - `prod` → "todavía no existe";
  - `testing` → dice "testing" y que no hay migraciones pendientes. Lo corre Joan.

  *Hecho: `shellcheck` limpio; sin argumento → error; `prod` → "todavía no existe". En una copia aparte con un identificador de prod falso: si la respuesta es "no", cancela sin respaldar; con "prod", el respaldo falla y no se aplica nada. Joan corrió `testing` el 27 oct 2026: dijo "Ambiente: testing (proyecto pqdjiecynyjnianslikp)" y "Remote database is up to date".*
- [x] 3.4 Documentar en `supabase/README.md`:
  - los dos scripts y `ambientes.env`;
  - que los proyectos gratis se pausan tras una semana sin uso;
  - el runbook para crear prod: crear el proyecto, llenar `PROD_PROJECT_REF`, correr `db-push.sh prod`, pegar la plantilla del correo y llenar `Release` en `ios/Config.xcconfig`.
  
  Verificar que cada comando del README corre como está escrito, salvo los de prod, que esperan a que exista.

## 4. Documentación del proyecto

- [x] 4.1 Actualizar:
  - CLAUDE.md §2 (fila de ambientes), §4 (configuración por ambiente y scripts) y §8 (cuenta gratuita y pausa de testing);
  - `docs/arquitectura.md`, con una sección de ambientes;
  - `docs/ROADMAP.md`: el paso del CP3 en la nube se hace en testing.
  
  Verificar con `rg -n "Release.*nube|la nube \(Release\)" CLAUDE.md ios/README.md` que ya no quedan frases que digan que Release apunta a testing.

## 5. Verificación de punta a punta

- [x] 5.1 Correr la suite completa: `swift test`, `swift format lint --strict --recursive ios/Cruce ios/Packages/CruceCore`, el chequeo del backend, `supabase test db` y `xcodebuild … build` con los tres esquemas. Instalar "Cruce Test" y "Cruce Dev" en el mismo simulador y confirmar que conviven, cada una con su nombre, su ícono y su línea en Ajustes. Todo en verde.

## Workflow follow-up

- Joan, opcional: renombrar el proyecto `cruce` a `cruce-testing` en el panel de Supabase.
- Hacer el paso del CP3 en la nube contra testing: SMTP propio, plantilla y entrar con los correos de Joan y Jesús. *Joan entró el 27 oct 2026; falta Jesús.*
- Archivar el cambio con `openspec archive ambientes` cuando se cumpla el "Hecho cuando" y proponer el commit.
