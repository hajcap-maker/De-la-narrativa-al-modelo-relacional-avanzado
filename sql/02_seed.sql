-- =====================================================================
-- ConectaTech · 02_seed.sql
-- Datos semilla. Se ejecuta sobre la base recién creada por 01_schema.sql.
-- Los identificadores GENERATED ALWAYS parten de 1 en una base vacía; por eso
-- las referencias numéricas de abajo son deterministas (ver comentarios).
-- Todo va en UNA transacción porque las reglas de jerarquía total
-- (rol obligatorio, subtipo obligatorio, transmisión obligatoria) se validan al COMMIT.
-- =====================================================================

BEGIN;

-- Sede 1 y salas 1..3 ----------------------------------------------------
INSERT INTO sede (nombre, direccion, ciudad, pais) VALUES
    ('Centro de Convenciones Tikal Futura', 'Calzada Roosevelt 22-43, zona 11', 'Ciudad de Guatemala', 'Guatemala');

INSERT INTO sala (id_sede, nombre, capacidad) VALUES
    (1, 'Sala Quetzal',         120),   -- id_sala 1
    (1, 'Sala Jade',             40),   -- id_sala 2
    (1, 'Laboratorio Atitlán',   20);   -- id_sala 3

-- Ediciones: 1 híbrida (finalizada, con sede) y 2 virtual (en preparación, sin sede) --
INSERT INTO edicion (id_sede, nombre, anio, ciudad, modalidad, fecha_inicio, fecha_fin, estado) VALUES
    (1,    'ConectaTech Guatemala',    2025, 'Ciudad de Guatemala', 'hibrida', '2025-11-12', '2025-11-13', 'finalizada'),     -- id_edicion 1
    (NULL, 'ConectaTech Latam Virtual', 2027, 'En línea',           'virtual', '2027-03-09', '2027-03-10', 'en_preparacion');  -- id_edicion 2

-- Catálogo de acreditaciones (ids 1..4) -----------------------------------
INSERT INTO tipo_acreditacion (nombre, descripcion) VALUES
    ('General',    'Acceso a las sesiones del programa general'),
    ('VIP',        'Acceso general, sala preferente y actividades de networking'),
    ('Estudiante', 'Tarifa reducida con credencial estudiantil vigente'),
    ('Prensa',     'Acceso para medios de comunicación acreditados');

-- Empresas (ids 1..3) -------------------------------------------------------
INSERT INTO empresa (nombre, pais, sitio_web) VALUES
    ('TechNova S.A.',   'Guatemala', 'https://technova.example.com'),     -- id_empresa 1
    ('DataBridge Corp', 'México',    'https://databridge.example.com'),   -- id_empresa 2
    ('CloudAndes',      'Colombia',  NULL);                               -- id_empresa 3 (sin acuerdos aún)

-- Personas (ids 1..6) -------------------------------------------------------
INSERT INTO persona (nombre, correo, pais) VALUES
    ('Ana Morales',  'ana.morales@example.com',  'Guatemala'),   -- 1  solo asistente
    ('Bruno Díaz',   'bruno.diaz@example.com',   'México'),      -- 2  solo ponente
    ('Carla Méndez', 'carla.mendez@example.com', 'Colombia'),    -- 3  asistente y ponente (ambos roles)
    ('Diego Fuentes','diego.fuentes@example.com','Guatemala'),   -- 4  solo asistente
    ('Elena Rojas',  'elena.rojas@example.com',  'Chile'),       -- 5  solo ponente
    ('Franco Silva', 'franco.silva@example.com', 'Brasil');      -- 6  solo asistente

-- Participaciones (supertipo solapado) -------------------------------------
-- id_participacion: 1 Ana-E1, 2 Bruno-E1, 3 Carla-E1, 4 Diego-E1, 5 Elena-E1, 6 Franco-E1,
--                   7 Ana-E2, 8 Carla-E2, 9 Elena-E2
INSERT INTO participacion_edicion (id_persona, id_edicion, fecha_registro) VALUES
    (1, 1, '2025-09-15'),
    (2, 1, '2025-09-10'),
    (3, 1, '2025-09-12'),
    (4, 1, '2025-09-20'),
    (5, 1, '2025-09-11'),
    (6, 1, '2025-10-01'),
    (1, 2, '2026-10-05'),
    (3, 2, '2026-10-06'),
    (5, 2, '2026-10-02');

-- Subtipo ASISTENTE: participaciones 1, 3, 4, 6, 7, 8 --------------------------
INSERT INTO asistente (id_participacion, id_tipo_acreditacion) VALUES
    (1, 1), (3, 2), (4, 3), (6, 1), (7, 1), (8, 2);

-- Subtipo PONENTE: participaciones 2, 3, 5, 8, 9 (la 3 y la 8 son también asistentes) --
INSERT INTO ponente (id_participacion, biografia) VALUES
    (2, 'Arquitecto de datos con 12 años de experiencia en plataformas analíticas y modelado dimensional.'),
    (3, 'Ingeniera de software e instructora de bases de datos relacionales, especialista en PostgreSQL.'),
    (5, 'Consultora en observabilidad y confiabilidad de sistemas distribuidos en entornos de nube.'),
    (8, 'Ingeniera de software e instructora de bases de datos relacionales, especialista en PostgreSQL.'),
    (9, 'Investigadora aplicada en inteligencia artificial generativa y analítica avanzada de datos.');

-- Sesiones (ids 1..6) ---------------------------------------------------------
INSERT INTO sesion (id_edicion, id_sala, tipo_sesion, titulo, resumen, fecha, hora_inicio, hora_fin) VALUES
    (1, 1,    'charla', 'Arquitecturas de datos modernas',
        'Panorama de arquitecturas de datos para equipos que migran a plataformas unificadas.',
        '2025-11-12', '09:00', '10:00'),                                   -- 1
    (1, 3,    'taller', 'PostgreSQL avanzado: índices y particiones',
        'Taller práctico de diseño de índices, particionamiento y lectura de planes de ejecución.',
        '2025-11-12', '10:30', '12:30'),                                   -- 2
    (1, 2,    'taller', 'Modelado relacional en la práctica',
        'Del diagrama conceptual al esquema físico con restricciones declarativas.',
        '2025-11-13', '09:00', '11:00'),                                   -- 3
    (1, NULL, 'charla', 'Observabilidad en producción',
        'Métricas, trazas y registros para operar sistemas de datos; transmitida en línea.',
        '2025-11-13', '11:30', '12:15'),                                   -- 4 (virtual dentro de edición híbrida)
    (2, NULL, 'charla', 'IA generativa aplicada a datos',
        'Casos de uso reales de modelos generativos sobre datos empresariales.',
        '2027-03-09', '10:00', '11:00'),                                   -- 5
    (2, NULL, 'taller', 'SQL analítico en vivo',
        'Funciones de ventana, CTE recursivas y análisis exploratorio con SQL.',
        '2027-03-10', '10:00', '12:00');                                   -- 6

-- Subtipos: charlas (1, 4, 5) y talleres (2, 3, 6) ---------------------------
INSERT INTO charla (id_sesion, minutos_preguntas) VALUES
    (1, 15), (4, 10), (5, 10);

INSERT INTO taller (id_sesion, cupo_practico, requisitos_materiales) VALUES
    (2, 4,  'Laptop con Docker y cliente psql instalados'),
    (3, 25, 'Laptop con navegador moderno y herramienta de diagramación'),
    (6, 30, 'Laptop con Docker y cliente psql instalados');

-- Relación 1:1 con info_transmision: obligatoria para sesiones sin sala (4, 5, 6) --
INSERT INTO info_transmision (id_sesion, plataforma, url_transmision, codigo_acceso, grabacion_disponible) VALUES
    (4, 'YouTube Live',  'https://live.example.com/conectatech/observabilidad', NULL,        true),
    (5, 'Zoom Webinars', 'https://zoom.example.com/j/111222333',                'CT-2027-A', false),
    (6, 'Zoom Meetings', 'https://zoom.example.com/j/444555666',                'CT-2027-B', false);

-- Prerrequisitos (relación recursiva): la sesión 3 exige la 1 y la 2; la 4 exige la 1; la 6 exige la 5 --
INSERT INTO prerrequisito_sesion (id_sesion, id_sesion_prerrequisito) VALUES
    (3, 1), (3, 2), (4, 1), (6, 5);

-- Inscripciones (8): asistentes -> sesiones ----------------------------------
INSERT INTO inscripcion_sesion (id_participacion, id_sesion, fecha_inscripcion, estado, asistio) VALUES
    (1, 1, '2025-10-20', 'confirmada', true),
    (3, 1, '2025-10-21', 'confirmada', true),
    (4, 1, '2025-10-22', 'confirmada', false),
    (1, 2, '2025-10-20', 'confirmada', true),
    (4, 2, '2025-10-22', 'confirmada', true),
    (6, 2, '2025-10-25', 'cancelada',  NULL),
    (7, 5, '2026-10-08', 'confirmada', NULL),
    (8, 6, '2026-10-09', 'pendiente',  NULL);

-- Asignaciones de ponentes (4): conservan rol y orden en el programa ----------
INSERT INTO asignacion_ponente (id_sesion, id_participacion, rol_ponente, orden_programa) VALUES
    (1, 2, 'principal',   1),   -- Bruno en la charla 1
    (2, 3, 'facilitador', 1),   -- Carla facilita el taller 2
    (2, 5, 'co_ponente',  2),   -- Elena co-presenta el taller 2
    (5, 9, 'principal',   1);   -- Elena en la charla virtual 5

-- Acuerdos de patrocinio (3) ---------------------------------------------------
INSERT INTO acuerdo_patrocinio (id_empresa, id_edicion, categoria, monto, moneda, fecha_confirmacion, estado) VALUES
    (1, 1, 'platino', 15000.00, 'USD', '2025-08-15', 'vigente'),
    (2, 1, 'oro',      8000.00, 'USD', '2025-09-01', 'vigente'),
    (1, 2, 'oro',      9000.00, 'USD', '2026-09-20', 'vigente');

COMMIT;

-- Verificación rápida del contenido cargado ------------------------------------
SELECT 'edicion' AS tabla, COUNT(*) AS filas FROM edicion
UNION ALL SELECT 'persona', COUNT(*) FROM persona
UNION ALL SELECT 'participacion_edicion', COUNT(*) FROM participacion_edicion
UNION ALL SELECT 'asistente', COUNT(*) FROM asistente
UNION ALL SELECT 'ponente', COUNT(*) FROM ponente
UNION ALL SELECT 'sesion', COUNT(*) FROM sesion
UNION ALL SELECT 'prerrequisito_sesion', COUNT(*) FROM prerrequisito_sesion
UNION ALL SELECT 'inscripcion_sesion', COUNT(*) FROM inscripcion_sesion
UNION ALL SELECT 'asignacion_ponente', COUNT(*) FROM asignacion_ponente
UNION ALL SELECT 'acuerdo_patrocinio', COUNT(*) FROM acuerdo_patrocinio;
