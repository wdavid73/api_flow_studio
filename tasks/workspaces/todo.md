# Todo: proyectos y workspace exportable

Plan: [plan.md](plan.md) · Spec: [SPEC-workspaces.md](../../SPEC-workspaces.md)

## Phase 1 — projects-core
- [x] P1: Modelo de proyecto y repositorio
- [x] P2: Migración de los datos actuales a Default
- [x] P3: El proyecto activo decide el store; todo recarga al cambiar

### Checkpoint: Core
- [x] analyze limpio, `fvm flutter test` y recorridos en memoria verdes

## Phase 2 — projects-ui
- [x] P4: Selector de proyecto en el header
- [x] P5: Crear, renombrar y eliminar, con recorrido de proyectos

### Checkpoint: Proyectos
- [x] analyze limpio, ambos runners verdes

## Phase 3 — history-limits
- [ ] P6: Recorte del cuerpo y límite global
- [ ] P7: Borrar historial

## Phase 4 — workspace-transfer
- [ ] P8: Formato del workspace y exportar (motor)
- [ ] P9: Importar como proyecto nuevo (motor)
- [ ] P10: Acciones de exportar e importar en la UI
- [ ] P11: Recorrido ida y vuelta, docs y corridas finales

### Checkpoint: Done
- [ ] Todos los criterios del spec cumplidos o justificados
