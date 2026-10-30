# Spec Delta

## ADDED Requirements

### Requirement: Unirse y quedarse con el lugar cuentan intentos
Unirse a un parche con un `PCH-` y quedarse con un lugar con un `SOY-` SHALL contar cada código que no sirve como intento fallido, en el mismo límite de 5 por hora que los `CRZ-` y la vista previa. Con 5 en la última hora, la base MUST rechazar unirse o quedarse con un lugar, incluso con un código válido, con "Hiciste demasiados intentos. Espera una hora e intenta de nuevo." Un código válido MUST NOT contar.

#### Scenario: Adivinar llamando directo
- **WHEN** alguien llama 5 veces a unirse con códigos `PCH-` que no existen en menos de una hora
- **THEN** el sexto intento, aunque el código exista, se rechaza por demasiados intentos y no lo une al parche

#### Scenario: Se suman con la vista previa
- **WHEN** alguien ya tiene 4 intentos fallidos con `CRZ-` y luego intenta quedarse con un lugar `SOY-` que no existe
- **THEN** queda con 5 y la vista previa del siguiente código dice "Hiciste demasiados intentos. Espera una hora e intenta de nuevo."
