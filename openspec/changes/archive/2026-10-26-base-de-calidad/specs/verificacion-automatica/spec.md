# Spec Delta

## Purpose

Define qué se revisa automáticamente cada vez que un cambio llega al repositorio, cuándo corre cada revisión y cuáles revisiones son manuales por su costo.

## ADDED Requirements

### Requirement: Revisión automática de cada parte que cambia
Cada cambio que llega a la rama principal SHALL disparar sin intervención humana las revisiones de las partes que tocó: backend, base de datos o lógica de la app. El resultado de cada revisión MUST quedar visible junto al commit.

#### Scenario: Cambio en el backend
- **WHEN** llega a la rama principal un commit que modifica archivos del backend
- **THEN** corren solas las pruebas y el análisis estático del backend, y el commit muestra si pasaron o fallaron

#### Scenario: Cambio en la base de datos
- **WHEN** llega a la rama principal un commit que modifica las migraciones o las pruebas de la base de datos
- **THEN** la base de datos se levanta desde cero con las migraciones y corren todas sus pruebas

#### Scenario: Cambio en la lógica de la app
- **WHEN** llega a la rama principal un commit que modifica el paquete de lógica de la app
- **THEN** corren solas las pruebas de la lógica y la revisión de formato

### Requirement: Solo corre lo que cambió
Una revisión MUST NOT correr cuando el cambio no tocó la parte que revisa, para no gastar tiempo ni minutos en revisiones que no aportan.

#### Scenario: Cambio solo de documentación
- **WHEN** llega un commit que solo modifica documentación
- **THEN** no corre ninguna revisión de backend, base de datos ni lógica

#### Scenario: Cambio solo en el backend
- **WHEN** llega un commit que solo modifica el backend
- **THEN** no corren las revisiones de la base de datos ni de la lógica

### Requirement: Revisión fallida visible
Si una revisión falla, el resultado del commit SHALL marcarse como fallido e indicar cuál revisión falló. Una revisión MUST NOT reportarse como exitosa si alguno de sus pasos falló.

#### Scenario: Una prueba falla
- **WHEN** una prueba del backend falla en la revisión automática
- **THEN** el commit queda marcado como fallido y se ve que la revisión del backend fue la que falló

### Requirement: Formato uniforme del código
El código de Swift y de Go SHALL cumplir un formato único definido en el repositorio. Un archivo que no cumpla el formato MUST hacer fallar la revisión de su parte.

#### Scenario: Archivo de Go sin formato
- **WHEN** llega un commit con un archivo de Go que no cumple el formato estándar
- **THEN** la revisión del backend falla y nombra el archivo

#### Scenario: Archivo de Swift sin formato
- **WHEN** llega un commit con un archivo de Swift de la lógica que no cumple la configuración de formato del repositorio
- **THEN** la revisión de la lógica falla y nombra el archivo

### Requirement: Compilación de la app bajo demanda
La compilación completa de la app de iPhone SHALL poder lanzarse a mano desde el repositorio remoto. MUST NOT correr sola en cada commit, porque su costo por minuto es mucho mayor.

#### Scenario: Lanzamiento manual
- **WHEN** alguien lanza a mano la compilación de la app
- **THEN** la app se compila para el simulador y el resultado queda visible

#### Scenario: Commit normal en la app
- **WHEN** llega un commit que modifica la app de iPhone
- **THEN** la compilación de la app no se lanza sola

### Requirement: Revisiones sin secretos
Las revisiones automáticas SHALL correr sin llaves ni credenciales de la nube. MUST NOT leer ni escribir datos del proyecto de Supabase en la nube.

#### Scenario: Revisión de la base de datos
- **WHEN** corre la revisión de la base de datos
- **THEN** usa una base de datos local y temporal, sin conectarse al proyecto de la nube
