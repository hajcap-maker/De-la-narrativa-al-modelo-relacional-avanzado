# Diccionario de datos · ConectaTech (PostgreSQL 18)

Todas las tablas están en el esquema `public`. Las columnas `id_*` marcadas *identity* usan `GENERATED ALWAYS AS IDENTITY`.
Las reglas **R#** corresponden a `narrativa-y-reglas.md`.

---

## 1. `sede`
Lugar físico donde se realizan ediciones presenciales o híbridas.

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_sede | integer | NO | identity | `PK pk_sede` |
| nombre | varchar(120) | NO | — | `UNIQUE uq_sede_nombre_ciudad (nombre, ciudad)` |
| direccion | varchar(200) | NO | — | — |
| ciudad | varchar(80) | NO | — | parte de `uq_sede_nombre_ciudad` |
| pais | varchar(60) | NO | — | — |

## 2. `sala`
Sala de una sede.

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_sala | integer | NO | identity | `PK pk_sala` |
| id_sede | integer | NO | — | `FK fk_sala_sede → sede(id_sede)` ON UPDATE CASCADE, ON DELETE RESTRICT; `UNIQUE uq_sala_sede_nombre (id_sede, nombre)` |
| nombre | varchar(80) | NO | — | parte de `uq_sala_sede_nombre` |
| capacidad | integer | NO | — | `CHECK ck_sala_capacidad (capacidad > 0)` (R4) |

## 3. `edicion`
Edición de un congreso.

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_edicion | integer | NO | identity | `PK pk_edicion` |
| id_sede | integer | SÍ | — | `FK fk_edicion_sede → sede` (RESTRICT); NULL cuando es virtual |
| nombre | varchar(120) | NO | — | `UNIQUE uq_edicion_nombre_anio (nombre, anio)` |
| anio | smallint | NO | — | `CHECK ck_edicion_anio (anio = EXTRACT(YEAR FROM fecha_inicio))` (R1) |
| ciudad | varchar(80) | NO | — | — |
| modalidad | varchar(10) | NO | — | `CHECK ck_edicion_modalidad IN ('presencial','virtual','hibrida')` |
| fecha_inicio | date | NO | — | — |
| fecha_fin | date | NO | — | `CHECK ck_edicion_fechas (fecha_fin >= fecha_inicio)` (R1) |
| estado | varchar(15) | NO | `'borrador'` | `CHECK ck_edicion_estado IN ('borrador','en_preparacion','lista','en_curso','finalizada','cancelada')` (R2) |

Restricción de tabla: `CHECK ck_edicion_sede_modalidad` — virtual ⇒ sin sede; presencial/híbrida ⇒ con sede (R3).

## 4. `tipo_acreditacion`
Catálogo de acreditaciones.

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_tipo_acreditacion | integer | NO | identity | `PK pk_tipo_acreditacion` |
| nombre | varchar(40) | NO | — | `UNIQUE uq_tipo_acreditacion_nombre` |
| descripcion | varchar(200) | NO | — | — |

## 5. `empresa`
Empresa patrocinadora.

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_empresa | integer | NO | identity | `PK pk_empresa` |
| nombre | varchar(120) | NO | — | `UNIQUE uq_empresa_nombre` |
| pais | varchar(60) | NO | — | — |
| sitio_web | varchar(200) | SÍ | — | `CHECK ck_empresa_sitio_web (sitio_web IS NULL OR sitio_web ~ '^https?://')` |

## 6. `persona`
Persona registrada.

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_persona | integer | NO | identity | `PK pk_persona` |
| nombre | varchar(120) | NO | — | — |
| correo | varchar(150) | NO | — | `UNIQUE uq_persona_correo`; `CHECK ck_persona_correo_formato` (expresión regular); `CHECK ck_persona_correo_minuscula (correo = lower(correo))` (R5) |
| pais | varchar(60) | NO | — | — |

## 7. `participacion_edicion` (supertipo de la jerarquía solapada total)
Persona dentro de una edición.

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_participacion | integer | NO | identity | `PK pk_participacion_edicion` |
| id_persona | integer | NO | — | `FK fk_participacion_persona → persona` (RESTRICT) |
| id_edicion | integer | NO | — | `FK fk_participacion_edicion → edicion` (RESTRICT) |
| fecha_registro | date | NO | `CURRENT_DATE` | — |

Restricciones de tabla: `UNIQUE uq_participacion_persona_edicion (id_persona, id_edicion)` (R6). Trigger diferido `trg_participacion_rol_total` (R7).

## 8. `asistente` (subtipo)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_participacion | integer | NO | — | `PK pk_asistente`; `FK fk_asistente_participacion → participacion_edicion` ON DELETE CASCADE (PK = FK) |
| id_tipo_acreditacion | integer | NO | — | `FK fk_asistente_acreditacion → tipo_acreditacion` (RESTRICT) (R8) |

Trigger diferido `trg_asistente_rol_total` al borrar (R7).

## 9. `ponente` (subtipo)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_participacion | integer | NO | — | `PK pk_ponente`; `FK fk_ponente_participacion → participacion_edicion` ON DELETE CASCADE (PK = FK) |
| biografia | text | NO | — | `CHECK ck_ponente_biografia (char_length(btrim(biografia)) >= 20)` (R8) |

Trigger diferido `trg_ponente_rol_total` al borrar (R7).

## 10. `sesion` (supertipo de la jerarquía disjunta total)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_sesion | integer | NO | identity | `PK pk_sesion` |
| id_edicion | integer | NO | — | `FK fk_sesion_edicion → edicion` (RESTRICT); `UNIQUE uq_sesion_edicion_titulo (id_edicion, titulo)` |
| id_sala | integer | SÍ | — | `FK fk_sesion_sala → sala` (RESTRICT); NULL = sesión virtual |
| tipo_sesion | varchar(6) | NO | — | `CHECK ck_sesion_tipo IN ('charla','taller')`; `UNIQUE uq_sesion_id_tipo (id_sesion, tipo_sesion)` (R13) |
| titulo | varchar(160) | NO | — | parte de `uq_sesion_edicion_titulo` |
| resumen | text | NO | — | — |
| fecha | date | NO | — | — |
| hora_inicio | time | NO | — | — |
| hora_fin | time | NO | — | `CHECK ck_sesion_horas (hora_fin > hora_inicio)` (R9) |

Restricción de exclusión: `EXCLUDE ex_sesion_sala_sin_solape USING gist (id_sala WITH =, (tsrange(fecha + hora_inicio, fecha + hora_fin, '[)')) WITH &&) WHERE (id_sala IS NOT NULL)` (R11).
Triggers: `trg_sesion_contexto` (BEFORE, R10), `trg_sesion_subtipo_total` (diferido, R13), `trg_sesion_requiere_transmision` (diferido, R12).

## 11. `charla` (subtipo)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_sesion | integer | NO | — | `PK pk_charla`; `FK fk_charla_supertipo → sesion(id_sesion)` ON DELETE CASCADE (PK = FK) |
| tipo_sesion | varchar(6) | NO | `'charla'` | `CHECK ck_charla_tipo (tipo_sesion = 'charla')`; `FK fk_charla_discriminador (id_sesion, tipo_sesion) → sesion(id_sesion, tipo_sesion)` ON DELETE CASCADE |
| minutos_preguntas | smallint | NO | — | `CHECK ck_charla_minutos (BETWEEN 0 AND 120)` (R14) |

## 12. `taller` (subtipo)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_sesion | integer | NO | — | `PK pk_taller`; `FK fk_taller_supertipo → sesion(id_sesion)` ON DELETE CASCADE (PK = FK) |
| tipo_sesion | varchar(6) | NO | `'taller'` | `CHECK ck_taller_tipo (tipo_sesion = 'taller')`; `FK fk_taller_discriminador (id_sesion, tipo_sesion) → sesion(id_sesion, tipo_sesion)` ON DELETE CASCADE |
| cupo_practico | integer | NO | — | `CHECK ck_taller_cupo (cupo_practico > 0)` (R14, R18) |
| requisitos_materiales | text | NO | — | `CHECK ck_taller_requisitos (char_length(btrim(...)) > 0)` (R14) |

## 13. `info_transmision` (relación 1:1 con `sesion`)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_sesion | integer | NO | — | `PK pk_info_transmision`; `FK fk_info_transmision_sesion → sesion` ON DELETE CASCADE (PK = FK ⇒ máximo una por sesión) |
| plataforma | varchar(60) | NO | — | — |
| url_transmision | varchar(300) | NO | — | `CHECK ck_info_transmision_url (url_transmision ~ '^https://')` |
| codigo_acceso | varchar(40) | SÍ | — | — |
| grabacion_disponible | boolean | NO | `false` | — |

Trigger diferido `trg_transmision_requerida_al_borrar` (R12).

## 14. `prerrequisito_sesion` (relación recursiva)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_sesion | integer | NO | — | parte de `PK pk_prerrequisito_sesion`; `FK fk_prerreq_sesion → sesion` ON DELETE CASCADE |
| id_sesion_prerrequisito | integer | NO | — | parte de la PK; `FK fk_prerreq_requerida → sesion` ON DELETE CASCADE |

Restricción de tabla: `CHECK ck_prerreq_no_autorreferencia (id_sesion <> id_sesion_prerrequisito)` (R15). Trigger `trg_prerrequisito_validar` (misma edición y orden temporal).

## 15. `inscripcion_sesion` (asociativa asistente–sesión)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_participacion | integer | NO | — | parte de `PK pk_inscripcion_sesion`; `FK fk_inscripcion_asistente → asistente` ON DELETE CASCADE |
| id_sesion | integer | NO | — | parte de la PK; `FK fk_inscripcion_sesion → sesion` ON DELETE CASCADE |
| fecha_inscripcion | date | NO | `CURRENT_DATE` | — |
| estado | varchar(15) | NO | `'pendiente'` | `CHECK ck_inscripcion_estado IN ('pendiente','confirmada','cancelada','lista_espera')` (R17) |
| asistio | boolean | SÍ | — | `CHECK ck_inscripcion_asistio (asistio IS NULL OR estado = 'confirmada')` (R17) |

Trigger `trg_inscripcion_validar`: misma edición, asistencia solo si la sesión ya ocurrió, cupo del taller y aforo de la sala (R16–R18).

## 16. `asignacion_ponente` (asociativa ponente–sesión)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_sesion | integer | NO | — | parte de `PK pk_asignacion_ponente`; `FK fk_asignacion_sesion → sesion` ON DELETE CASCADE |
| id_participacion | integer | NO | — | parte de la PK; `FK fk_asignacion_ponente → ponente` ON DELETE CASCADE |
| rol_ponente | varchar(15) | NO | `'principal'` | `CHECK ck_asignacion_rol IN ('principal','co_ponente','moderador','facilitador','panelista')` |
| orden_programa | smallint | NO | — | `CHECK ck_asignacion_orden (orden_programa > 0)`; `UNIQUE uq_asignacion_orden (id_sesion, orden_programa) DEFERRABLE INITIALLY IMMEDIATE` |

Trigger `trg_asignacion_validar`: misma edición y sin superposición del ponente (R19).

## 17. `acuerdo_patrocinio` (asociativa empresa–edición)

| Columna | Tipo | Nulo | Defecto | Restricciones |
|---|---|---|---|---|
| id_acuerdo | integer | NO | identity | `PK pk_acuerdo_patrocinio` |
| id_empresa | integer | NO | — | `FK fk_acuerdo_empresa → empresa` (RESTRICT) |
| id_edicion | integer | NO | — | `FK fk_acuerdo_edicion → edicion` (RESTRICT) |
| categoria | varchar(10) | NO | — | `CHECK ck_acuerdo_categoria IN ('platino','oro','plata','bronce','aliado')` (R20) |
| monto | numeric(12,2) | NO | — | `CHECK ck_acuerdo_monto (monto > 0)` (R20) |
| moneda | char(3) | NO | `'USD'` | `CHECK ck_acuerdo_moneda (moneda ~ '^[A-Z]{3}$')` |
| fecha_confirmacion | date | NO | — | — |
| estado | varchar(10) | NO | `'vigente'` | `CHECK ck_acuerdo_estado IN ('vigente','cancelado','vencido')` |

Índice único parcial: `uq_acuerdo_vigente_empresa_edicion ON (id_empresa, id_edicion) WHERE estado = 'vigente'` (R20).

---

## Índices de apoyo
`idx_edicion_sede`, `idx_sala_sede`, `idx_sesion_edicion_fecha`, `idx_participacion_edicion`, `idx_asistente_acreditacion`, `idx_inscripcion_sesion`, `idx_asignacion_ponente`, `idx_prerreq_requerida`, `idx_acuerdo_edicion`.

## Funciones de validación
`fn_sesion_contexto`, `fn_sesion_subtipo_total`, `fn_sesion_requiere_transmision`, `fn_participacion_rol_total`, `fn_prerrequisito_validar`, `fn_inscripcion_validar`, `fn_asignacion_validar`.
