# Spec Delta

## Purpose

Define cómo se saca y se guarda una copia de la base de datos de la nube mientras el plan contratado no incluya respaldos automáticos.

## ADDED Requirements

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
