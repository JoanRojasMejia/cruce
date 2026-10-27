# Spec Delta

## ADDED Requirements

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
