# respaldo-base-datos Specification

## Purpose
Define cómo se saca y se guarda una copia de la base de datos de la nube mientras el plan contratado no incluya respaldos automáticos.

## Requirements

### Requirement: Respaldo con un solo comando
El repositorio SHALL ofrecer un comando que saque una copia completa de la base de datos, con el esquema y los datos, en archivos que se puedan restaurar.

#### Scenario: Respaldo exitoso
- **WHEN** alguien con acceso al proyecto corre el comando de respaldo
- **THEN** quedan archivos con el esquema y los datos de la base de datos

#### Scenario: Sin acceso al proyecto
- **WHEN** se corre el comando de respaldo sin un proyecto vinculado o sin credenciales
- **THEN** el comando termina con error y un mensaje que explica qué falta, sin dejar archivos a medias

### Requirement: Cada respaldo con fecha y hora
Cada respaldo SHALL guardarse con la fecha y la hora en el nombre. Un respaldo nuevo MUST NOT sobrescribir uno anterior.

#### Scenario: Dos respaldos el mismo día
- **WHEN** se corre el respaldo dos veces el mismo día
- **THEN** quedan dos juegos de archivos distintos, cada uno con su hora

### Requirement: Los respaldos no entran al repositorio
Los archivos de respaldo SHALL quedar en una carpeta local que git ignora. Los respaldos y las credenciales MUST NOT subirse al repositorio.

#### Scenario: Después de un respaldo
- **WHEN** se corre el respaldo y luego se revisa el estado de git
- **THEN** git no muestra los archivos del respaldo como cambios para subir

### Requirement: Respaldo por ambiente
El comando de respaldo SHALL respaldar el ambiente que se nombra: `testing`, `prod` o la base local. Sin un ambiente, o con uno que no existe, el comando MUST terminar con error, explicar cómo usarlo y no dejar archivos. El nombre de la carpeta del respaldo SHALL incluir el ambiente.

#### Scenario: Respaldo de testing
- **WHEN** alguien corre el respaldo con el ambiente `testing`
- **THEN** queda una carpeta con la fecha, la hora y "testing" en el nombre, con el esquema y los datos de testing

#### Scenario: Respaldo sin ambiente
- **WHEN** alguien corre el respaldo sin decir el ambiente
- **THEN** el comando termina con error, muestra cómo usarlo y no crea ninguna carpeta

#### Scenario: Prod todavía no existe
- **WHEN** alguien corre el respaldo de `prod` y el proyecto de prod no está configurado
- **THEN** el comando termina con un mensaje que dice que prod todavía no existe y no crea ninguna carpeta
