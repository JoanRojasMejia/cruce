## MODIFIED Requirements

### Requirement: Dónde aparece un cruce cerrado
Los cruces cerrados SHALL seguir apareciendo en "Tus cruces", en una sección "Cerrados" al final, en tono gris y con el nombre de la otra persona completo (sin cortarse). El inicio SHALL ser directamente un cruce solo cuando la persona tiene un único cruce y está abierto; en cualquier otro caso con cruces, el inicio SHALL ser "Tus cruces", con "Invitar a alguien" y "Tengo un código".

#### Scenario: El único cruce se cierra
- **WHEN** Joan solo tenía su cruce con Jesús y lo desvincula
- **THEN** el inicio de Joan pasa a ser "Tus cruces", con su cruce con Jesús en la sección "Cerrados" y los botones para invitar o unirse

#### Scenario: Un cruce abierto y uno cerrado
- **WHEN** Joan tiene un cruce abierto con Ana y uno cerrado con Jesús
- **THEN** "Tus cruces" muestra a Ana en la lista y a Jesús en la sección "Cerrados", al final y en gris, con "Con Jesús" completo
