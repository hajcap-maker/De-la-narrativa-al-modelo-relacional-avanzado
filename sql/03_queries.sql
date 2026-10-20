-- =====================================================================
-- ConectaTech · 03_queries.sql
-- Consultas avanzadas de solo lectura (cada una cruza 3 o más tablas con JOIN).
-- Ejecutar después de 01_schema.sql y 02_seed.sql.
-- =====================================================================

\echo
\echo '=== Q1. Programa completo: sesión, ubicación/transmisión, ponentes y prerrequisitos ==='
-- Tablas: sesion, edicion, sala, sede, info_transmision, asignacion_ponente,
--         participacion_edicion, persona (+ subconsulta sobre prerrequisito_sesion).
-- LEFT JOIN conserva sesiones sin sala (virtuales) o sin ponentes asignados.
-- string_agg ... ORDER BY respeta el orden_programa guardado en la asignación.
SELECT e.nombre                                         AS edicion,
       s.fecha,
       to_char(s.hora_inicio, 'HH24:MI') || '-' || to_char(s.hora_fin, 'HH24:MI') AS horario,
       s.tipo_sesion                                    AS tipo,
       s.titulo,
       COALESCE(sa.nombre || ' (' || sd.nombre || ')', 'Virtual')        AS ubicacion,
       COALESCE(it.plataforma, 'Sin transmisión')                        AS transmision,
       COALESCE(string_agg(per.nombre || ' [' || ap.rol_ponente || ']', ', '
                           ORDER BY ap.orden_programa), 'Por confirmar') AS ponentes,
       (SELECT string_agg(sp.titulo, '; ' ORDER BY sp.fecha, sp.hora_inicio)
          FROM prerrequisito_sesion pr
          JOIN sesion sp ON sp.id_sesion = pr.id_sesion_prerrequisito
         WHERE pr.id_sesion = s.id_sesion)                               AS prerrequisitos
  FROM sesion s
  JOIN edicion e                    ON e.id_edicion = s.id_edicion
  LEFT JOIN sala sa                 ON sa.id_sala = s.id_sala
  LEFT JOIN sede sd                 ON sd.id_sede = sa.id_sede
  LEFT JOIN info_transmision it     ON it.id_sesion = s.id_sesion
  LEFT JOIN asignacion_ponente ap   ON ap.id_sesion = s.id_sesion
  LEFT JOIN participacion_edicion pe ON pe.id_participacion = ap.id_participacion
  LEFT JOIN persona per             ON per.id_persona = pe.id_persona
 GROUP BY e.nombre, s.id_sesion, sa.nombre, sd.nombre, it.plataforma
 ORDER BY e.nombre, s.fecha, s.hora_inicio;

\echo
\echo '=== Q2. Cupos de talleres: capacidad práctica vs. inscritos activos ==='
-- Tablas: taller, sesion, edicion, sala, inscripcion_sesion.
-- Cuenta como ocupado un cupo 'pendiente' o 'confirmada'; las canceladas liberan el lugar.
-- Se muestra además el aforo de la sala (si existe) porque el trigger también lo respeta.
SELECT e.nombre                                                            AS edicion,
       s.titulo                                                            AS taller,
       t.cupo_practico                                                     AS cupo,
       COUNT(*) FILTER (WHERE i.estado IN ('pendiente', 'confirmada'))     AS inscritos_activos,
       t.cupo_practico
         - COUNT(*) FILTER (WHERE i.estado IN ('pendiente', 'confirmada')) AS cupos_disponibles,
       ROUND(100.0 * COUNT(*) FILTER (WHERE i.estado IN ('pendiente', 'confirmada'))
             / t.cupo_practico, 1)                                         AS pct_ocupacion,
       COUNT(*) FILTER (WHERE i.estado = 'cancelada')                      AS canceladas,
       COALESCE(sa.capacidad::text, 'n/a (virtual)')                       AS aforo_sala
  FROM taller t
  JOIN sesion s                     ON s.id_sesion = t.id_sesion
  JOIN edicion e                    ON e.id_edicion = s.id_edicion
  LEFT JOIN sala sa                 ON sa.id_sala = s.id_sala
  LEFT JOIN inscripcion_sesion i    ON i.id_sesion = t.id_sesion
 GROUP BY e.nombre, s.id_sesion, s.titulo, t.cupo_practico, sa.capacidad
 ORDER BY e.nombre, s.fecha, s.hora_inicio;

\echo
\echo '=== Q3a. Participación por persona y rol dentro de cada edición ==='
-- Tablas: participacion_edicion, persona, edicion, asistente, tipo_acreditacion, ponente.
-- LEFT JOIN a ambos subtipos revela la jerarquía solapada: solo asistente, solo ponente o ambos.
SELECT e.nombre AS edicion,
       p.nombre AS persona,
       p.pais,
       CASE WHEN a.id_participacion IS NOT NULL AND po.id_participacion IS NOT NULL THEN 'Asistente y ponente'
            WHEN a.id_participacion IS NOT NULL                                      THEN 'Solo asistente'
            ELSE 'Solo ponente' END                                                  AS rol,
       COALESCE(ta.nombre, '-')                                                      AS acreditacion,
       (SELECT COUNT(*) FROM inscripcion_sesion i
         WHERE i.id_participacion = pe.id_participacion
           AND i.estado = 'confirmada')                                              AS sesiones_confirmadas,
       (SELECT COUNT(*) FROM asignacion_ponente ap
         WHERE ap.id_participacion = pe.id_participacion)                            AS sesiones_como_ponente
  FROM participacion_edicion pe
  JOIN persona p                    ON p.id_persona = pe.id_persona
  JOIN edicion e                    ON e.id_edicion = pe.id_edicion
  LEFT JOIN asistente a             ON a.id_participacion = pe.id_participacion
  LEFT JOIN tipo_acreditacion ta    ON ta.id_tipo_acreditacion = a.id_tipo_acreditacion
  LEFT JOIN ponente po              ON po.id_participacion = pe.id_participacion
 ORDER BY e.nombre, p.nombre;

\echo
\echo '=== Q3b. Resumen de participación por rol y edición ==='
-- Tablas: edicion, participacion_edicion, asistente, ponente.
SELECT e.nombre                                       AS edicion,
       COUNT(*)                                       AS personas_inscritas,
       COUNT(a.id_participacion)                      AS asistentes,
       COUNT(po.id_participacion)                     AS ponentes,
       COUNT(*) FILTER (WHERE a.id_participacion IS NOT NULL
                          AND po.id_participacion IS NOT NULL) AS con_ambos_roles
  FROM edicion e
  JOIN participacion_edicion pe     ON pe.id_edicion = e.id_edicion
  LEFT JOIN asistente a             ON a.id_participacion = pe.id_participacion
  LEFT JOIN ponente po              ON po.id_participacion = pe.id_participacion
 GROUP BY e.id_edicion, e.nombre
 ORDER BY e.nombre;

\echo
\echo '=== Q4. Recaudación de patrocinios vigentes por edición ==='
-- Tablas: edicion, acuerdo_patrocinio, empresa.
-- El LEFT JOIN incluye ediciones sin patrocinio (total 0). Se agrupa por moneda para no sumar divisas distintas.
SELECT e.nombre                                          AS edicion,
       e.anio,
       COALESCE(ac.moneda, '---')                        AS moneda,
       COUNT(ac.id_acuerdo)                              AS acuerdos_vigentes,
       COALESCE(SUM(ac.monto), 0)                        AS total_recaudado,
       string_agg(em.nombre || ' (' || ac.categoria || ')', ', '
                  ORDER BY ac.monto DESC)                AS patrocinadores
  FROM edicion e
  LEFT JOIN acuerdo_patrocinio ac   ON ac.id_edicion = e.id_edicion AND ac.estado = 'vigente'
  LEFT JOIN empresa em              ON em.id_empresa = ac.id_empresa
 GROUP BY e.id_edicion, e.nombre, e.anio, ac.moneda
 ORDER BY e.anio, e.nombre;

\echo
\echo '=== Q5. Cadena completa de prerrequisitos (CTE recursiva) ==='
-- Tablas: prerrequisito_sesion (recursiva), sesion (dos veces), edicion.
-- Recorre la relación recursiva y devuelve prerrequisitos directos (nivel 1) e indirectos (nivel > 1).
WITH RECURSIVE cadena AS (
    SELECT pr.id_sesion, pr.id_sesion_prerrequisito, 1 AS nivel
      FROM prerrequisito_sesion pr
    UNION ALL
    SELECT c.id_sesion, pr.id_sesion_prerrequisito, c.nivel + 1
      FROM cadena c
      JOIN prerrequisito_sesion pr ON pr.id_sesion = c.id_sesion_prerrequisito
)
SELECT e.nombre   AS edicion,
       s.titulo   AS sesion,
       p.titulo   AS debe_completar_antes,
       c.nivel
  FROM cadena c
  JOIN sesion s   ON s.id_sesion = c.id_sesion
  JOIN sesion p   ON p.id_sesion = c.id_sesion_prerrequisito
  JOIN edicion e  ON e.id_edicion = s.id_edicion
 ORDER BY e.nombre, s.titulo, c.nivel, p.titulo;

\echo
\echo '=== Q6. Asistencia real por sesión (solo eventos ya realizados) ==='
-- Tablas: sesion, edicion, inscripcion_sesion, asistente, tipo_acreditacion.
-- Compara inscripciones confirmadas contra asistencia registrada después del evento.
SELECT e.nombre                                                        AS edicion,
       s.titulo,
       COUNT(*) FILTER (WHERE i.estado = 'confirmada')                 AS confirmados,
       COUNT(*) FILTER (WHERE i.asistio IS TRUE)                       AS asistieron,
       COUNT(*) FILTER (WHERE i.asistio IS FALSE)                      AS no_asistieron,
       string_agg(DISTINCT ta.nombre, ', ')                            AS acreditaciones_presentes
  FROM sesion s
  JOIN edicion e                    ON e.id_edicion = s.id_edicion
  JOIN inscripcion_sesion i         ON i.id_sesion = s.id_sesion
  JOIN asistente a                  ON a.id_participacion = i.id_participacion
  JOIN tipo_acreditacion ta         ON ta.id_tipo_acreditacion = a.id_tipo_acreditacion
 WHERE s.fecha <= CURRENT_DATE
 GROUP BY e.nombre, s.id_sesion, s.titulo
 ORDER BY e.nombre, s.titulo;
