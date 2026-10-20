-- =====================================================================
-- ConectaTech · 04_invalid_tests.sql
-- 13 pruebas de datos inválidos. Cada una va en un bloque DO que:
--   1) intenta la operación prohibida,
--   2) si PostgreSQL la RECHAZA, imprime "Rechazo esperado: <mensaje> (SQLSTATE: <código>)",
--   3) si por error la ACEPTARA, lanza un código interno XX999 y el bloque avisa "FALLO DE LA PRUEBA".
-- Como todo error se captura dentro del bloque, el script continúa de principio a fin
-- y no deja datos modificados (el subbloque con EXCEPTION revierte cualquier cambio).
-- Requiere 01_schema.sql y 02_seed.sql ya ejecutados.
-- =====================================================================

\echo
\echo '#### PRUEBAS INVÁLIDAS ####'

-- ---------------------------------------------------------------------
-- 1. UNIQUE: correo duplicado en persona  -> uq_persona_correo (SQLSTATE 23505)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[1] UNIQUE: correo duplicado (uq_persona_correo)';
    INSERT INTO persona (nombre, correo, pais)
    VALUES ('Impostora Morales', 'ana.morales@example.com', 'Guatemala');
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 1: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 2. UNIQUE/PK compuesta: inscripción duplicada (misma participación y sesión)
--    -> pk_inscripcion_sesion (SQLSTATE 23505)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[2] PRIMARY KEY compuesta: inscripción duplicada (pk_inscripcion_sesion)';
    INSERT INTO inscripcion_sesion (id_participacion, id_sesion, estado)
    VALUES (1, 1, 'confirmada');   -- Ana ya está inscrita en la sesión 1
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 2: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 3. UNIQUE parcial: segundo patrocinio VIGENTE de la misma empresa y edición
--    -> uq_acuerdo_vigente_empresa_edicion (SQLSTATE 23505)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[3] UNIQUE parcial: dos acuerdos vigentes empresa-edición (uq_acuerdo_vigente_empresa_edicion)';
    INSERT INTO acuerdo_patrocinio (id_empresa, id_edicion, categoria, monto, fecha_confirmacion)
    VALUES (1, 1, 'plata', 3000.00, '2025-10-01');   -- TechNova ya tiene acuerdo vigente en la edición 1
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 3: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 4. FOREIGN KEY: inscripción a una sesión inexistente
--    -> fk_inscripcion_sesion (SQLSTATE 23503)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[4] FOREIGN KEY: sesión inexistente (fk_inscripcion_sesion)';
    INSERT INTO inscripcion_sesion (id_participacion, id_sesion, estado)
    VALUES (1, 9999, 'pendiente');
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 4: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 5. CHECK de dominio: estado de edición fuera del catálogo
--    -> ck_edicion_estado (SQLSTATE 23514)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[5] CHECK: estado de edición inválido (ck_edicion_estado)';
    UPDATE edicion SET estado = 'inventado' WHERE id_edicion = 1;
    RAISE EXCEPTION 'La actualización fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 5: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 6. CHECK numérico: monto de patrocinio negativo
--    -> ck_acuerdo_monto (SQLSTATE 23514)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[6] CHECK: monto negativo (ck_acuerdo_monto)';
    INSERT INTO acuerdo_patrocinio (id_empresa, id_edicion, categoria, monto, fecha_confirmacion)
    VALUES (3, 1, 'bronce', -500.00, '2025-10-02');
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 6: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 7. NOT NULL: persona sin correo
--    -> NOT NULL de persona.correo (SQLSTATE 23502)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[7] NOT NULL: persona sin correo';
    INSERT INTO persona (nombre, correo, pais)
    VALUES ('Persona Sin Correo', NULL, 'Guatemala');
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 7: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 8. CHECK de autorrelación: una sesión no puede ser prerrequisito de sí misma
--    -> ck_prerreq_no_autorreferencia (SQLSTATE 23514)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[8] CHECK: sesión prerrequisito de sí misma (ck_prerreq_no_autorreferencia)';
    INSERT INTO prerrequisito_sesion (id_sesion, id_sesion_prerrequisito)
    VALUES (1, 1);
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 8: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 9. EXCLUDE USING gist: dos sesiones superpuestas en la misma sala y fecha
--    La sesión 1 usa la sala 1 el 2025-11-12 de 09:00 a 10:00; esta va de 09:30 a 10:30.
--    -> ex_sesion_sala_sin_solape (SQLSTATE 23P01)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[9] EXCLUDE: solapamiento de horario en la misma sala (ex_sesion_sala_sin_solape)';
    INSERT INTO sesion (id_edicion, id_sala, tipo_sesion, titulo, resumen, fecha, hora_inicio, hora_fin)
    VALUES (1, 1, 'charla', 'Charla que choca con otra', 'Sesión de prueba con horario en conflicto.',
            '2025-11-12', '09:30', '10:30');
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 9: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 10. CHECK temporal: hora final menor o igual a la inicial
--     -> ck_sesion_horas (SQLSTATE 23514)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[10] CHECK: hora_fin <= hora_inicio (ck_sesion_horas)';
    INSERT INTO sesion (id_edicion, id_sala, tipo_sesion, titulo, resumen, fecha, hora_inicio, hora_fin)
    VALUES (1, 2, 'charla', 'Charla con horas invertidas', 'Sesión de prueba con rango horario inválido.',
            '2025-11-13', '15:00', '14:00');
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 10: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 11. Jerarquía DISJUNTA: la sesión 1 es una charla y se intenta registrar también como taller
--     La FK compuesta (id_sesion, tipo_sesion) exige tipo 'taller' en sesion.
--     -> fk_taller_discriminador (SQLSTATE 23503)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[11] FOREIGN KEY compuesta: sesión charla registrada también como taller (fk_taller_discriminador)';
    INSERT INTO taller (id_sesion, cupo_practico, requisitos_materiales)
    VALUES (1, 10, 'Laptop');
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 11: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 12. Jerarquía SOLAPADA TOTAL: participación sin ningún rol
--     El CONSTRAINT TRIGGER es diferido; SET CONSTRAINTS ALL IMMEDIATE fuerza su
--     evaluación dentro del bloque (normalmente se evaluaría al COMMIT).
--     -> trg_participacion_rol_total (SQLSTATE 23000)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[12] Trigger diferido: participación sin rol de asistente ni ponente (trg_participacion_rol_total)';
    INSERT INTO participacion_edicion (id_persona, id_edicion) VALUES (2, 2);   -- Bruno en la edición 2, sin rol
    SET CONSTRAINTS ALL IMMEDIATE;
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 12: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

-- ---------------------------------------------------------------------
-- 13. Regla de cupo: taller sin cupos disponibles
--     Se reduce temporalmente el cupo del taller 2 a 2 (ya tiene 2 inscritos activos)
--     y se intenta inscribir a Carla. El bloque revierte todo al terminar.
--     -> trg_inscripcion_validar (SQLSTATE 23514)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '[13] Trigger de cupo: taller completo (trg_inscripcion_validar)';
    UPDATE taller SET cupo_practico = 2 WHERE id_sesion = 2;
    INSERT INTO inscripcion_sesion (id_participacion, id_sesion, estado)
    VALUES (3, 2, 'confirmada');
    RAISE EXCEPTION 'La inserción fue aceptada' USING ERRCODE = 'XX999';
EXCEPTION
    WHEN SQLSTATE 'XX999' THEN RAISE NOTICE 'FALLO DE LA PRUEBA 13: PostgreSQL aceptó datos inválidos';
    WHEN OTHERS THEN RAISE NOTICE 'Rechazo esperado: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
END $$;

\echo
\echo '#### Verificación: ninguna prueba dejó datos (conteos idénticos a la semilla) ####'
SELECT (SELECT COUNT(*) FROM persona)              AS personas,        -- esperado 6
       (SELECT COUNT(*) FROM sesion)               AS sesiones,        -- esperado 6
       (SELECT COUNT(*) FROM inscripcion_sesion)   AS inscripciones,   -- esperado 8
       (SELECT COUNT(*) FROM acuerdo_patrocinio)   AS acuerdos,        -- esperado 3
       (SELECT cupo_practico FROM taller WHERE id_sesion = 2) AS cupo_taller_2;  -- esperado 4
