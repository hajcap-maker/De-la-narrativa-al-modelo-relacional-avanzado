# De la narrativa al modelo relacional avanzado: Congreso ConectaTech

## 1. Hechos explícitos de la narrativa

1. ConectaTech organiza congresos **presenciales, virtuales e híbridos** en distintas ciudades.
2. Cada **edición** tiene nombre, año, fechas y un estado de preparación.
3. Una edición presencial o híbrida usa **una sede con varias salas**; una sala tiene nombre y capacidad.
4. Una **sala no puede alojar dos sesiones con horarios superpuestos**.
5. Una **sesión virtual puede no tener sala**, pero necesita información de transmisión.
6. Las **personas** se registran con nombre, correo y país.
7. Dentro de una edición una persona participa como **asistente, ponente o ambos**; toda persona inscrita en una edición tiene **al menos un rol**.
8. Los asistentes eligen un **tipo de acreditación**; los ponentes mantienen una **biografía profesional**.
9. Una **sesión** tiene título, resumen, fecha, hora inicial y hora final, y es **exactamente** una charla o un taller.
10. Las charlas reservan **minutos para preguntas**; los talleres tienen **cupo práctico** y **requisitos de materiales**.
11. Una sesión puede requerir haber completado **una o más sesiones previas**; ninguna es prerrequisito de sí misma.
12. Un asistente se inscribe en **varias sesiones** y una sesión recibe **muchos asistentes**; la inscripción guarda fecha, estado y (después del evento) asistencia; no puede repetirse.
13. Una sesión tiene **varios ponentes** y un ponente interviene en **varias sesiones**; la asignación conserva **rol** y **orden** en el programa.
14. Las **empresas patrocinadoras** apoyan distintas ediciones; el acuerdo registra categoría, monto y fecha de confirmación; **solo un acuerdo vigente por empresa y edición**.
15. Se debe poder **reconstruir una edición completa desde una base vacía**, consultar programa, cupos y participación, y que **PostgreSQL rechace los estados imposibles**.

## 2. Supuestos de negocio y decisiones de diseño propias

| # | Supuesto o decisión | Justificación |
|---|---|---|
| S1 | La **participación** (persona dentro de una edición) es el supertipo de asistente y ponente, no la persona en sí. | Los roles se definen "dentro de una edición": una misma persona puede ser solo asistente en una y ponente en otra. |
| S2 | Las ediciones virtuales **no tienen sede** (`id_sede` NULL) y las presenciales/híbridas **sí**. | Lo exige la narrativa; se verifica con `ck_edicion_sede_modalidad`. |
| S3 | `edicion.ciudad` es obligatoria; para una edición virtual se registra `'En línea'`. | Mantiene una consulta uniforme por ciudad. |
| S4 | Las sesiones dentro de una edición híbrida pueden ser presenciales (con sala) o solo en línea (sin sala, con transmisión). | La narrativa admite sesiones sin sala; una sesión con sala también puede tener transmisión. |
| S5 | La sala de una sesión debe pertenecer a la sede de su edición y la fecha de la sesión debe caer entre las fechas de la edición. | Evita programas incoherentes; trigger `fn_sesion_contexto`. |
| S6 | Una sala libera el horario al terminar: dos sesiones **pueden ser consecutivas** (rango `[inicio, fin)`). | Realismo operativo: una sesión puede empezar cuando termina la anterior. |
| S7 | Los **tipos de acreditación** forman un catálogo propio (`tipo_acreditacion`). | Evita texto libre repetido y permite una FK. |
| S8 | Un prerrequisito debe pertenecer a la misma edición y **terminar antes** de que empiece la sesión dependiente. | Da sentido temporal y, de paso, **impide ciclos** (A requiere B y B requiere A). |
| S9 | Ocupan cupo las inscripciones `pendiente` y `confirmada`; `cancelada` y `lista_espera` no. | Una cancelación libera el lugar. |
| S10 | La asistencia (`asistio`) solo se registra para inscripciones confirmadas y para sesiones que ya ocurrieron. | La narrativa dice "después del evento". |
| S11 | Un ponente no puede tener dos sesiones superpuestas en el tiempo. | Regla operativa razonable; trigger `fn_asignacion_validar`. |
| S12 | Los acuerdos de patrocinio cancelados o vencidos se conservan como historial; el único-vigente se impone con un **índice único parcial**. | Permite renegociar sin perder trazabilidad. |
| S13 | Los montos llevan moneda (`USD` por defecto) y las consultas no suman divisas distintas. | Evita totales sin sentido. |
| S14 | Los correos se almacenan en minúsculas (`CHECK`) para que `UNIQUE` sea efectivo sin distinguir mayúsculas. | Evita duplicados como `Ana@x.com` / `ana@x.com`. |
| S15 | Las modificaciones posteriores de horarios de una sesión **no** revalidan prerrequisitos ya registrados. | Límite consciente del alcance; se documenta para el equipo. |

## 3. Entidades, atributos, dominios e identificadores

| Entidad | Atributos (dominio) | Identificador |
|---|---|---|
| **Sede** | nombre (texto 120), dirección (200), ciudad (80), país (60) | Subrogada `id_sede`; alterna (nombre, ciudad) |
| **Sala** | nombre (80), capacidad (entero > 0) | `id_sala`; alterna (sede, nombre) |
| **Edición** | nombre, año, ciudad, modalidad {presencial, virtual, hibrida}, fecha inicio/fin, estado {borrador, en_preparacion, lista, en_curso, finalizada, cancelada} | `id_edicion`; alterna (nombre, año) |
| **Tipo_Acreditación** | nombre (40), descripción (200) | `id_tipo_acreditacion`; alterna nombre |
| **Empresa** | nombre (120), país, sitio web (opcional, https) | `id_empresa`; alterna nombre |
| **Persona** | nombre, correo (formato válido, minúsculas), país | `id_persona`; alterna correo |
| **Participación_Edición** *(supertipo solapado)* | fecha de registro | `id_participacion`; alterna (persona, edición) |
| **Asistente** *(subtipo)* | tipo de acreditación | `id_participacion` (PK=FK) |
| **Ponente** *(subtipo)* | biografía (≥ 20 caracteres) | `id_participacion` (PK=FK) |
| **Sesión** *(supertipo disjunto)* | título, resumen, fecha, hora inicio, hora fin, tipo {charla, taller} | `id_sesion`; alternas (sesión, tipo) y (edición, título) |
| **Charla** *(subtipo)* | minutos de preguntas (0–120) | `id_sesion` (PK=FK) |
| **Taller** *(subtipo)* | cupo práctico (> 0), requisitos de materiales | `id_sesion` (PK=FK) |
| **Info_Transmisión** | plataforma, URL (https), código de acceso (opcional), grabación disponible | `id_sesion` (PK=FK, 1:1) |
| **Prerrequisito_Sesión** *(asociativa recursiva)* | — | (`id_sesion`, `id_sesion_prerrequisito`) |
| **Inscripción_Sesión** *(asociativa)* | fecha, estado {pendiente, confirmada, cancelada, lista_espera}, asistió (opcional) | (`id_participacion`, `id_sesion`) |
| **Asignación_Ponente** *(asociativa)* | rol {principal, co_ponente, moderador, facilitador, panelista}, orden en programa (> 0) | (`id_sesion`, `id_participacion`); alterna (sesión, orden) |
| **Acuerdo_Patrocinio** *(asociativa)* | categoría {platino, oro, plata, bronce, aliado}, monto (> 0), moneda, fecha de confirmación, estado {vigente, cancelado, vencido} | `id_acuerdo`; único parcial (empresa, edición) si vigente |

## 4. Relaciones, cardinalidades y opcionalidad

| # | Relación | Cardinalidad | Opcionalidad y justificación |
|---|---|---|---|
| 1 | Sede – Sala | 1:N | Una sala pertenece a una sola sede (obligatorio); una sede tiene una o más salas. |
| 2 | Sede – Edición | 1:N | Una edición tiene sede solo si es presencial o híbrida (**opcional** del lado edición); una sede puede alojar varias ediciones. |
| 3 | Edición – Sesión | 1:N | Toda sesión pertenece a exactamente una edición. |
| 4 | Sala – Sesión | 1:N | La sala es **opcional** (sesión virtual); una sala aloja muchas sesiones, nunca superpuestas. |
| 5 | Sesión – Info_Transmisión | **1:1** | Opcional en la sesión con sala, **obligatoria** si no tiene sala. PK compartida garantiza el máximo de 1. |
| 6 | Sesión – Charla / Taller | 1:0..1 cada una | Jerarquía disjunta total: exactamente una de las dos. |
| 7 | Sesión – Sesión (prerrequisito) | N:M recursiva | Una sesión puede no tener prerrequisitos o tener varios. Se resuelve con `prerrequisito_sesion`. |
| 8 | Persona – Participación_Edición | 1:N | Una persona puede participar en muchas ediciones, una vez por edición. |
| 9 | Edición – Participación_Edición | 1:N | Una edición tiene muchas participaciones. |
| 10 | Participación – Asistente / Ponente | 1:0..1 cada una | Jerarquía solapada total: uno o ambos subtipos. |
| 11 | Tipo_Acreditación – Asistente | 1:N | Todo asistente elige exactamente un tipo. |
| 12 | Asistente – Sesión | N:M | Resuelta con `inscripcion_sesion`. |
| 13 | Ponente – Sesión | N:M | Resuelta con `asignacion_ponente`. |
| 14 | Empresa – Edición | N:M | Resuelta con `acuerdo_patrocinio`. |

## 5. Jerarquías

### 5.1 Sesión → Charla | Taller: **disjunta y total**

* **Disjunta**: una sesión no puede ser charla y taller a la vez. Se garantiza de forma declarativa: `sesion` guarda el discriminador `tipo_sesion` y es único junto con `id_sesion` (`uq_sesion_id_tipo`); cada subtipo tiene `tipo_sesion` fijo (`CHECK tipo_sesion = 'charla'` o `'taller'`) y una **FK compuesta** `(id_sesion, tipo_sesion)` hacia esa clave. Así `INSERT INTO taller` para una sesión de tipo `charla` falla (prueba 11).
* **Total**: no existen sesiones "genéricas". Un `CONSTRAINT TRIGGER` diferido (`trg_sesion_subtipo_total`) comprueba al `COMMIT` que la sesión tenga su fila en el subtipo indicado; la inserción del supertipo y del subtipo ocurre en la misma transacción.
* **Transformación**: *una tabla por supertipo y una por subtipo*. Se descartó la tabla única porque charla y taller tienen atributos obligatorios distintos (`minutos_preguntas` vs. `cupo_practico` y `requisitos_materiales`), que con una tabla única tendrían que ser `NULL` y perderían `NOT NULL`.
* **Identidad**: cada subtipo conserva la PK del supertipo (`PRIMARY KEY (id_sesion)` + `FOREIGN KEY` al supertipo).

### 5.2 Participación_Edición → Asistente | Ponente: **solapada y total**

* **Solapada**: una persona puede ser asistente y ponente en la misma edición. No hay discriminador excluyente: ambos subtipos pueden tener fila con la misma PK.
* **Total**: toda participación tiene al menos un rol. Lo exigen tres `CONSTRAINT TRIGGER` diferidos: al insertar la participación y al borrar una fila de `asistente` o `ponente`.
* **Transformación**: una tabla por supertipo y por subtipo, para conservar los atributos propios (`id_tipo_acreditacion` obligatorio en asistente, `biografia` obligatoria en ponente) y permitir que las asociativas apunten al rol exacto: `inscripcion_sesion` → `asistente` y `asignacion_ponente` → `ponente`. Esto impide a nivel de FK que un ponente "puro" se inscriba o que un asistente "puro" sea asignado como ponente.
* **Por qué el supertipo es la participación y no la persona**: el rol depende de la edición (supuesto S1).

## 6. Justificación de claves de las entidades asociativas

| Asociativa | Clave elegida | Justificación |
|---|---|---|
| `inscripcion_sesion` | PK compuesta (`id_participacion`, `id_sesion`) | La propia pareja identifica la inscripción y la PK impide duplicados ("no puede existir dos veces la misma inscripción"). No hay otros hijos que referencien la inscripción, así que no hace falta una subrogada. |
| `asignacion_ponente` | PK compuesta (`id_sesion`, `id_participacion`) + `UNIQUE (id_sesion, orden_programa)` | Un ponente aparece una sola vez por sesión y no puede haber dos ponentes con el mismo orden. El `UNIQUE` es `DEFERRABLE` para poder reordenar en una transacción. |
| `acuerdo_patrocinio` | PK subrogada `id_acuerdo` + índice único parcial (`id_empresa`, `id_edicion`) `WHERE estado='vigente'` | La narrativa permite varios acuerdos históricos pero **solo uno vigente**; una PK compuesta lo impediría. La subrogada permite conservar historial y el índice parcial impone la regla. |
| `prerrequisito_sesion` | PK compuesta (`id_sesion`, `id_sesion_prerrequisito`) | Un mismo prerrequisito no se repite para la misma sesión; `CHECK` evita la autorreferencia. |

## 7. Reglas de negocio y cómo las garantiza PostgreSQL

| # | Regla de negocio | Mecanismo en `sql/01_schema.sql` | Prueba |
|---|---|---|---|
| R1 | Una edición termina el mismo día o después de empezar y su año coincide con la fecha de inicio. | `ck_edicion_fechas`, `ck_edicion_anio` | — |
| R2 | El estado de una edición pertenece al catálogo definido. | `ck_edicion_estado` | 5 |
| R3 | Las ediciones presenciales e híbridas exigen sede; las virtuales no tienen sede. | `ck_edicion_sede_modalidad` | — |
| R4 | Toda sala tiene capacidad positiva y su nombre es único dentro de la sede. | `ck_sala_capacidad`, `uq_sala_sede_nombre` | — |
| R5 | El correo de una persona es único, con formato válido y en minúsculas. | `uq_persona_correo`, `ck_persona_correo_formato`, `ck_persona_correo_minuscula`, `NOT NULL` | 1, 7 |
| R6 | Una persona se registra una sola vez por edición. | `uq_participacion_persona_edicion` | — |
| R7 | Toda participación tiene al menos un rol (asistente, ponente o ambos). | `CONSTRAINT TRIGGER` diferidos `trg_participacion_rol_total`, `trg_asistente_rol_total`, `trg_ponente_rol_total` | 12 |
| R8 | Todo asistente tiene tipo de acreditación y todo ponente una biografía profesional de al menos 20 caracteres. | `NOT NULL` + `fk_asistente_acreditacion`; `ck_ponente_biografia` | — |
| R9 | Una sesión termina después de empezar. | `ck_sesion_horas` | 10 |
| R10 | La sesión cae dentro de las fechas de su edición y su sala pertenece a la sede de la edición. | `TRIGGER trg_sesion_contexto` | — |
| R11 | Una sala no aloja dos sesiones con horarios superpuestos. | `EXCLUDE USING gist (id_sala WITH =, tsrange(fecha+hora_inicio, fecha+hora_fin,'[)') WITH &&) WHERE (id_sala IS NOT NULL)` (extensión `btree_gist`) | 9 |
| R12 | Una sesión sin sala necesita información de transmisión (relación 1:1 como máximo uno). | `pk_info_transmision` (PK=FK) + `trg_sesion_requiere_transmision` | — |
| R13 | Toda sesión es exactamente una charla o un taller. | `ck_sesion_tipo`, FK compuesta `fk_charla_discriminador`/`fk_taller_discriminador`, `trg_sesion_subtipo_total` | 11 |
| R14 | La charla guarda minutos de preguntas (0–120); el taller exige cupo positivo y requisitos de materiales no vacíos. | `ck_charla_minutos`; `ck_taller_cupo`, `ck_taller_requisitos`, `NOT NULL` | — |
| R15 | Una sesión no es prerrequisito de sí misma; el prerrequisito es de la misma edición y termina antes. | `ck_prerreq_no_autorreferencia`, `trg_prerrequisito_validar` | 8 |
| R16 | Una inscripción no se repite y el asistente pertenece a la misma edición que la sesión. | `pk_inscripcion_sesion`, `fk_inscripcion_asistente`, `fk_inscripcion_sesion`, `trg_inscripcion_validar` | 2, 4 |
| R17 | El estado de la inscripción está en el catálogo; la asistencia solo se registra si está confirmada y la sesión ya ocurrió. | `ck_inscripcion_estado`, `ck_inscripcion_asistio`, `trg_inscripcion_validar` | — |
| R18 | No se supera el cupo práctico del taller ni el aforo de la sala. | `trg_inscripcion_validar` (con bloqueo de fila para concurrencia) | 13 |
| R19 | Cada ponente de una sesión tiene un rol válido y un orden único; pertenece a la misma edición y no se asigna a sesiones superpuestas. | `ck_asignacion_rol`, `ck_asignacion_orden`, `uq_asignacion_orden`, `trg_asignacion_validar` | — |
| R20 | Un acuerdo tiene categoría válida, monto positivo y solo existe uno vigente por empresa y edición. | `ck_acuerdo_categoria`, `ck_acuerdo_monto`, `uq_acuerdo_vigente_empresa_edicion` | 3, 6 |
| R21 | El nombre de una empresa y el de un tipo de acreditación no se repiten. | `uq_empresa_nombre`, `uq_tipo_acreditacion_nombre` | — |

Prohibición adicional (R22): **no se almacenan listas ni arrays de identificadores en una columna**; toda relación múltiple se modela con tablas asociativas.
