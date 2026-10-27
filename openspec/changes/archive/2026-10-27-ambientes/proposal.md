# Proposal

## Why

Hoy la app tiene dos destinos: Debug habla con Supabase local y Release con el único proyecto de la nube (`pqdjiecynyjnianslikp`). Ese proyecto ya tiene usuarios y datos de prueba. Si la primera versión real sale contra él, se mezclarían las cuentas de prueba con las reales. Hay que separar **testing** de **prod** antes del paso del CP3 en la nube, porque desde ahí Joan y Jesús empiezan a usar la nube.

## What Changes

- **Tres ambientes con nombre:** `local` (Supabase en Docker), `testing` (el proyecto actual `pqdjiecynyjnianslikp`) y `prod` (un proyecto nuevo, que se crea antes de la primera versión en TestFlight).
- **Una configuración de compilación por ambiente** en la app de iOS: `Debug` → local, `Staging` (nueva) → testing, `Release` → prod. Cada una con su esquema de Xcode.
- **Las tres apps se pueden instalar a la vez en el mismo iPhone:**
  - cada una tiene su identificador (`com.joanrojas.cruce.dev`, `com.joanrojas.cruce.staging`, `com.joanrojas.cruce`);
  - su nombre en la pantalla de inicio es "Cruce Dev", "Cruce Test" o "Cruce";
  - su ícono es distinto en local y en testing.
- **Ajustes dice el ambiente** cuando no es prod, junto a la versión: "Cruce 1.0 (1) · testing".
- **Prod nunca cae en otro ambiente:** si faltan las claves de prod, la app se detiene con un mensaje claro. No usa las de testing.
- **Scripts por ambiente:**
  - `scripts/db-push.sh <testing|prod>` sube las migraciones al ambiente elegido; prod pide confirmación y saca un respaldo antes;
  - `scripts/backup-db.sh` pide el ambiente (`testing`, `prod` o `--local`);
  - los identificadores de los proyectos de la nube quedan en un solo archivo versionado.
- **BREAKING (solo para quien desarrolla):**
  - `scripts/backup-db.sh` sin argumentos deja de respaldar "el proyecto vinculado" y pide el ambiente;
  - el identificador de la app en Debug pasa a `com.joanrojas.cruce.dev`, así que los comandos `simctl launch` de la documentación cambian;
  - `ios/Config.xcconfig` gana la sección de `Staging`.

## Capabilities

### New Capabilities
- `ambientes`: qué ambientes existen, cómo se distinguen las apps de cada uno, la protección para que prod no use otro ambiente y cómo llegan los cambios de la base a cada ambiente.

### Modified Capabilities
- `respaldo-base-datos`: el respaldo de la nube se hace eligiendo el ambiente, testing o prod, en lugar de usar el proyecto vinculado.

## Impact

- **App iOS:**
  - `ios/project.yml`: configuraciones, esquemas, identificadores, nombre visible e ícono por configuración;
  - `ios/Config.example.xcconfig` y el `ios/Config.xcconfig` local de cada quien;
  - `Info.plist`, con la clave del ambiente;
  - `SettingsView`, con la línea de la versión;
  - `Assets.xcassets`, con las variantes del ícono;
  - el comentario de `DebugScreen`.
- **Supabase:**
  - un archivo nuevo con los identificadores de los proyectos;
  - `scripts/db-push.sh` (nuevo) y `scripts/backup-db.sh`;
  - `supabase/README.md`.
  
  No cambian las migraciones ni las pruebas pgTAP.
- **Documentación:**
  - `CLAUDE.md` §2, §4 y §8;
  - `ios/README.md`;
  - `docs/arquitectura.md`;
  - `docs/ROADMAP.md`: el paso del CP3 en la nube pasa a hacerse en testing.
- **Fuera de alcance:**
  - crear el proyecto de prod, que va con la primera versión en TestFlight;
  - desplegar el backend de Go por ambiente (CP8);
  - subir migraciones desde la CI de forma automática.
- **Sin dependencias nuevas.**
