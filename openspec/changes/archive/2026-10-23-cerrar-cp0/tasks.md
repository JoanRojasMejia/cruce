# Tasks

## 1. Repositorio

- [x] 1.1 `git init` y primer commit con el estado inicial (verificado: `git log` muestra `chore: estado inicial del proyecto Cruce`)
- [x] 1.2 Autor de los commits con el correo noreply de GitHub, configurado solo en el repo (verificado: `git log --format='%ae'`)
- [x] 1.3 Repositorio público en https://github.com/JoanRojasMejia/cruce tras revisar que no hay secretos en archivos ni en el historial

## 2. Compilar y probar la app

- [x] 2.1 `cd ios && xcodegen` genera `Cruce.xcodeproj` sin errores
- [x] 2.2 `xcodebuild … build` compila sin errores ni avisos de Swift (Xcode 27 beta, iPhone 16, iOS 18.2)
- [x] 2.3 `xcodebuild … test`: 12 pruebas en verde (`BalanceCalculatorTests`, `MoneyTests`)
- [x] 2.4 `cd backend && go vet ./... && go test ./...` en verde

## 3. Verificación en el simulador

- [x] 3.1 Las fuentes Archivo cargan (nombres PostScript correctos y texto con Archivo en pantalla)
- [x] 3.2 Las ilustraciones y el ícono de la app aparecen
- [x] 3.3 Flujo completo sin crashes: onboarding → crear cuenta → invitar → conectados → inicio → agregar → gasto guardado → historial → detalle → eliminar → saldar → a paz y salvo → ajustes → cerrar sesión

## 4. Corrección de superficies transparentes

- [x] 4.1 `NeoSurface` no pinta sombra cuando el desplazamiento es 0 (verificado en el simulador: "ANTES" en Saldar y "Esperando a tu amigo…" en Invitar se ven como en el diseño)

## Workflow follow-up

- Archivar el cambio con `openspec archive cerrar-cp0` para crear las specs base.
