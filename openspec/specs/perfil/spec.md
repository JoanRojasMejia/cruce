# perfil Specification

## Purpose
Permitir que cada persona cambie el nombre con que la ven sus amigos en Cruce.

## Requirements

### Requirement: Cambiar el nombre
La tarjeta del perfil en Ajustes SHALL abrir una pantalla para cambiar el nombre propio. Al guardar, el nombre nuevo SHALL verse en toda la app de quien lo cambió y, la próxima vez que la otra persona cargue sus cruces, también en la suya. Sin conexión, la app MUST mostrar un error y conservar el nombre anterior.

#### Scenario: Joan se cambia el nombre
- **WHEN** Joan cambia su nombre a "Joan R." y guarda
- **THEN** Ajustes dice "Joan R." y, cuando Jesús recarga, su cruce dice "Con Joan R."

### Requirement: Nombre válido
El nombre MUST tener entre 1 y 40 caracteres sin contar los espacios de los extremos, que se quitan al guardar. Con un nombre vacío o igual al actual, "Guardar" MUST estar desactivado.

#### Scenario: Nombre vacío
- **WHEN** Joan borra su nombre y deja solo espacios
- **THEN** "Guardar" queda desactivado

#### Scenario: Nombre demasiado largo
- **WHEN** Joan escribe un nombre de 41 caracteres
- **THEN** la app no deja escribir más de 40

#### Scenario: Sin conexión
- **WHEN** Joan guarda un nombre nuevo sin conexión
- **THEN** la app muestra un error y su nombre sigue siendo el anterior
