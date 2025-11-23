# ChainForge Tasks & Planning

Este directorio contiene la planificación detallada de tareas para el desarrollo de ChainForge.

## Estructura

```
tasks/
├── README.md          # Este archivo
└── v3/                # Plan de ChainForge v3.0
    ├── 00-INDEX.md    # Índice general y roadmap
    ├── 01-*.md        # Tareas individuales (PRs)
    ├── 02-*.md
    └── ...
```

## Cómo Usar

### 1. Revisar el Plan General

Empieza leyendo `v3/00-INDEX.md` para entender:
- Filosofía y objetivos de v3
- Fases del proyecto
- Timeline estimado
- Dependencias globales

### 2. Leer Tareas Individuales

Cada archivo `XX-nombre-tarea.md` contiene:
- **Objetivo**: Qué se busca lograr
- **Complejidad**: Small/Medium/Large
- **Estimación**: Días de trabajo
- **Dependencias**: Qué tareas deben completarse primero
- **Implementación**: Detalles técnicos, código ejemplo
- **Tests**: Qué tests se necesitan
- **Criterios de Aceptación**: Checklist de completitud

### 3. Hacer Modificaciones

Puedes editar estos archivos para:
- Ajustar estimaciones
- Cambiar el scope de features
- Reorganizar prioridades
- Agregar notas técnicas
- Actualizar status

### 4. Tracking de Progreso

Sugerencia: Agregar checkbox al inicio de cada archivo para marcar progreso:

```markdown
# Task 01: Structured Logging

**Status**: 🔴 Not Started | 🟡 In Progress | 🟢 Completed
**PR**: #9 (link when created)
**Branch**: feature/v3-01-structured-logging

...resto del contenido...
```

## Fases de v3.0

### 📊 Fase 1: Observabilidad (2-3 semanas)
Fundamento para monitoring y debugging profesional.

- Task 01: Structured Logging
- Task 02: Health Check & Metrics

### 👨‍💻 Fase 2: Developer Experience (3-4 semanas)
Herramientas para facilitar el uso de ChainForge.

- Task 03: CLI Tool
- Task 04: OpenAPI SDK
- Task 05: Pagination & Search APIs

### ⛓️ Fase 3: Blockchain Avanzado (4-5 semanas)
Conceptos blockchain más sofisticados.

- Task 06: Dynamic Difficulty Adjustment
- Task 07: Merkle Trees
- Task 08: Structured Transactions
- Task 09: Digital Signatures

### 🏗️ Fase 4: Infrastructure (3-4 semanas)
Performance y escalabilidad.

- Task 10: Redis Integration
- Task 11: Async Mining (Sidekiq)
- Task 12: Performance Optimization

### 🎨 Fase 5: Block Explorer UI (4-5 semanas)
Visualización y experiencia de usuario.

- Task 13: Block Explorer Web UI
- Task 14: WebSocket Support (Opcional)

### ✅ Fase 6: Testing & Docs (2 semanas)
Cierre y documentación completa.

- Task 15: Integration Tests
- Task 16: Documentation Update

## Timeline

**Total**: 16 semanas / 4 meses

- **Mes 1**: Fases 1-2 (Fundamentos)
- **Mes 2**: Fase 3 (Blockchain avanzado)
- **Mes 3**: Fase 4 + inicio Fase 5
- **Mes 4**: Fase 5 + Fase 6

## Orden de Ejecución

⚠️ **IMPORTANTE**: Seguir el orden numérico de tasks dentro de cada fase. Algunas tienen dependencias:

```
01 ──┐
     ├──> 02 ──> (Fase 1 completa)
     │
     ├──> 03 ──┐
     │         │
     │         ├──> 04 ──> 05 ──> (Fase 2 completa)
     │         │
     │         └──> (Fase 3 puede empezar)
     │
     └──> 06 ──> 07 ──> 08 ──> 09 ──> (Fase 3 completa)
          │
          └──> 10 ──> 11 ──> 12 ──> (Fase 4 completa)
               │
               └──> 13 ──> 14? ──> (Fase 5 completa)
                    │
                    └──> 15 ──> 16 ──> (v3.0 completo!)
```

## Dependencias Críticas

- **Task 02** requiere **Task 01** (logging para metrics)
- **Task 11** requiere **Task 10** (Redis para Sidekiq)
- **Task 13** beneficia de **Tasks 02, 05** (metrics, pagination)
- **Task 09** funciona mejor con **Task 08** (transactions)

## Flexibilidad

Puedes modificar el plan:
- Cambiar orden dentro de una fase (si no hay dependencias)
- Postponer features (Task 14 es opcional)
- Dividir tasks grandes en sub-tasks
- Agregar nuevas tasks

## Notas de Implementación

### Git Workflow
```bash
# Para cada task:
git checkout master
git pull origin master
git checkout -b feature/v3-XX-nombre-task
# ... hacer cambios ...
git add .
git commit -m "feat: descripción del task"
git push origin feature/v3-XX-nombre-task
# Crear PR
```

### Branch Naming
- `feature/v3-01-structured-logging`
- `feature/v3-02-health-metrics`
- etc.

### Commit Messages
- `feat: add structured logging with semantic_logger`
- `test: add tests for health check endpoint`
- `docs: update CLAUDE.md with logging info`
- `refactor: extract metrics to separate module`

### Pull Request Template
```markdown
## Task: XX - Nombre

**Fase**: X
**Complejidad**: Small/Medium/Large
**Estimated**: X days
**Actual**: X days

## Changes
- Lista de cambios principales

## Testing
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] RuboCop clean
- [ ] Coverage >90%

## Documentation
- [ ] README.md updated
- [ ] CLAUDE.md updated (if architecture changed)
- [ ] API_DOCUMENTATION.md updated (if API changed)

## Screenshots
(if UI changes)

## Checklist
- [ ] All criteria met (see task file)
- [ ] CI passes
- [ ] Reviewed

Related Task: `tasks/v3/XX-task-name.md`
```

## Tracking Progress

Puedes crear un archivo `v3/PROGRESS.md` para tracking:

```markdown
# v3.0 Progress Tracking

## Fase 1: Observabilidad
- [x] 01 - Structured Logging (PR #9, merged 2025-11-15)
- [ ] 02 - Health & Metrics (PR #10, in progress)

## Fase 2: Developer Experience
- [ ] 03 - CLI Tool
- [ ] 04 - Ruby Client SDK
- [ ] 05 - Pagination & Search

...
```

## Preguntas Frecuentes

**P: ¿Puedo cambiar el orden de las tasks?**
R: Sí, siempre que respetes las dependencias. Revisa el diagrama de dependencias arriba.

**P: ¿Qué hago si una task es muy grande?**
R: Divídela en sub-tasks (01a, 01b, etc.) o crea PRs incrementales.

**P: ¿Debo completar todas las tasks?**
R: No necesariamente. Task 14 (WebSockets) es opcional. Puedes posponer features para v3.1/v3.2.

**P: ¿Cómo manejo breaking changes?**
R: Documéntalos claramente en el task file y en CHANGELOG.md. Provee migration path cuando sea posible.

**P: ¿Qué hago si descubro que falta algo?**
R: Crea un nuevo archivo task (17-nombre-nuevo.md) con el mismo formato.

## Recursos

- [v2 Documentation](../../README.md) - Estado actual
- [CHANGELOG](../../CHANGELOG.md) - Historia de versiones
- [CONTRIBUTING](../../CONTRIBUTING.md) - Guías de contribución
- [CLAUDE.md](../../CLAUDE.md) - Arquitectura actual

---

**Creado**: 2025-11-09
**Versión actual**: v2.0.0
**Próxima versión**: v3.0.0 (en planificación)
**Archivos totales**: 17 (1 index + 16 tasks)
