# ambientes Specification

## Purpose
Define los ambientes de Cruce (local, testing y prod), cómo se distingue la app de cada uno y cómo se protege prod para que nunca use datos ni cuentas de otro ambiente.

## Requirements

### Requirement: Tres ambientes separados
Cruce SHALL tener tres ambientes: `local`, `testing` y `prod`. Cada ambiente MUST usar su propia base de datos y sus propias cuentas. Una cuenta o un movimiento creado en un ambiente MUST NOT aparecer en otro.

#### Scenario: Cuenta creada en testing
- **WHEN** alguien entra con su correo en la app de testing y anota un gasto
- **THEN** la app de prod no conoce esa cuenta ni ese gasto

#### Scenario: Cada compilación apunta a su ambiente
- **WHEN** se compila la app en la configuración de local, de testing o de prod
- **THEN** la app habla con la base de datos de ese ambiente y con ninguna otra

### Requirement: Apps de cada ambiente lado a lado
La app de cada ambiente SHALL instalarse en el mismo iPhone sin reemplazar a las otras. Cada una SHALL mostrar en la pantalla de inicio su propio nombre: "Cruce Dev" (local), "Cruce Test" (testing) o "Cruce" (prod).

#### Scenario: Testing y prod en el mismo iPhone
- **WHEN** alguien tiene instalada la app de prod e instala la de testing
- **THEN** quedan las dos apps, cada una con su nombre y su sesión

### Requirement: Ícono distinto fuera de prod
Las apps de local y de testing SHALL tener un ícono que se distinga a simple vista del ícono de prod. La app de prod SHALL usar el ícono original sin marcas.

#### Scenario: Íconos en la pantalla de inicio
- **WHEN** las apps de testing y de prod están en la misma pantalla de inicio
- **THEN** el ícono de testing lleva una marca visible de testing y el de prod no lleva ninguna

### Requirement: El ambiente se ve en Ajustes
Fuera de prod, Ajustes SHALL mostrar el nombre del ambiente junto a la versión, por ejemplo "Cruce 1.0 (1) · testing". En prod, Ajustes SHALL mostrar solo la versión.

#### Scenario: Ajustes en testing
- **WHEN** alguien abre Ajustes en la app de testing
- **THEN** la línea de la versión termina en "· testing"

#### Scenario: Ajustes en prod
- **WHEN** alguien abre Ajustes en la app de prod
- **THEN** la línea de la versión no menciona ningún ambiente

### Requirement: Prod no usa la configuración de otro ambiente
Si a la app de prod le falta la dirección o la clave de su base de datos, la app SHALL detenerse al arrancar con un mensaje que diga qué falta. La app MUST NOT usar en su lugar la configuración de testing ni la de local.

#### Scenario: Claves de prod sin llenar
- **WHEN** se compila y se abre la app de prod sin las claves de prod
- **THEN** la app se detiene con un mensaje que nombra la clave que falta y no se conecta a ninguna base de datos

### Requirement: Migraciones por ambiente
El repositorio SHALL ofrecer un comando que suba las migraciones a un ambiente de la nube que se nombra de forma explícita. Antes de cambiar algo, el comando SHALL decir a qué ambiente y a qué proyecto apunta.

#### Scenario: Subir a testing
- **WHEN** alguien corre el comando con el ambiente `testing`
- **THEN** el comando dice que apunta a testing y aplica ahí las migraciones pendientes

#### Scenario: Sin ambiente
- **WHEN** alguien corre el comando sin decir el ambiente o con un nombre que no existe
- **THEN** el comando termina con error, explica cómo usarlo y no cambia ninguna base de datos

### Requirement: Subir a prod pide confirmación
Subir migraciones a prod SHALL pedir una confirmación escrita y SHALL sacar un respaldo de prod antes de aplicar cualquier cambio. Si el respaldo falla, el comando MUST NOT aplicar las migraciones.

#### Scenario: Confirmación correcta
- **WHEN** alguien sube migraciones a prod y escribe la confirmación pedida
- **THEN** se saca el respaldo de prod y después se aplican las migraciones

#### Scenario: Confirmación distinta
- **WHEN** alguien sube migraciones a prod y escribe otra cosa
- **THEN** el comando termina sin respaldar ni aplicar nada

#### Scenario: Prod todavía no existe
- **WHEN** alguien sube migraciones a prod y el proyecto de prod no está configurado
- **THEN** el comando termina con un mensaje que dice que prod todavía no existe y no cambia ninguna base de datos
