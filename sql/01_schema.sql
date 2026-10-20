-- =====================================================================
-- ConectaTech · 01_schema.sql
-- Esquema relacional avanzado para PostgreSQL 18
-- Ejecutar sobre una base VACÍA (docker compose lo hace automáticamente).
-- =====================================================================

BEGIN;

-- Extensión necesaria para combinar igualdad (=) con solapamiento (&&)
-- en una restricción EXCLUDE USING gist (regla R11).
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------------
-- 1. SEDES Y SALAS  (relación 1:N  Sede -> Sala)
-- ---------------------------------------------------------------------
CREATE TABLE sede (
    id_sede     integer GENERATED ALWAYS AS IDENTITY,
    nombre      varchar(120) NOT NULL,
    direccion   varchar(200) NOT NULL,
    ciudad      varchar(80)  NOT NULL,
    pais        varchar(60)  NOT NULL,
    CONSTRAINT pk_sede PRIMARY KEY (id_sede),
    CONSTRAINT uq_sede_nombre_ciudad UNIQUE (nombre, ciudad)
);

CREATE TABLE sala (
    id_sala     integer GENERATED ALWAYS AS IDENTITY,
    id_sede     integer      NOT NULL,
    nombre      varchar(80)  NOT NULL,
    capacidad   integer      NOT NULL,
    CONSTRAINT pk_sala PRIMARY KEY (id_sala),
    CONSTRAINT fk_sala_sede FOREIGN KEY (id_sede)
        REFERENCES sede (id_sede) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_sala_sede_nombre UNIQUE (id_sede, nombre),
    CONSTRAINT ck_sala_capacidad CHECK (capacidad > 0)                       -- R4
);

-- ---------------------------------------------------------------------
-- 2. EDICIONES  (relación 1:N  Sede -> Edicion, sede opcional)
-- ---------------------------------------------------------------------
CREATE TABLE edicion (
    id_edicion    integer GENERATED ALWAYS AS IDENTITY,
    id_sede       integer,
    nombre        varchar(120) NOT NULL,
    anio          smallint     NOT NULL,
    ciudad        varchar(80)  NOT NULL,
    modalidad     varchar(10)  NOT NULL,
    fecha_inicio  date         NOT NULL,
    fecha_fin     date         NOT NULL,
    estado        varchar(15)  NOT NULL DEFAULT 'borrador',
    CONSTRAINT pk_edicion PRIMARY KEY (id_edicion),
    CONSTRAINT fk_edicion_sede FOREIGN KEY (id_sede)
        REFERENCES sede (id_sede) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_edicion_nombre_anio UNIQUE (nombre, anio),
    CONSTRAINT ck_edicion_fechas CHECK (fecha_fin >= fecha_inicio),          -- R1
    CONSTRAINT ck_edicion_anio CHECK (anio = EXTRACT(YEAR FROM fecha_inicio)), -- R1
    CONSTRAINT ck_edicion_estado CHECK (estado IN
        ('borrador', 'en_preparacion', 'lista', 'en_curso', 'finalizada', 'cancelada')), -- R2
    CONSTRAINT ck_edicion_modalidad CHECK (modalidad IN ('presencial', 'virtual', 'hibrida')),
    -- R3: presencial/híbrida exigen sede; virtual no tiene sede.
    CONSTRAINT ck_edicion_sede_modalidad CHECK (
        (modalidad = 'virtual' AND id_sede IS NULL)
        OR (modalidad <> 'virtual' AND id_sede IS NOT NULL))
);

-- ---------------------------------------------------------------------
-- 3. CATÁLOGOS Y EMPRESAS
-- ---------------------------------------------------------------------
CREATE TABLE tipo_acreditacion (
    id_tipo_acreditacion integer GENERATED ALWAYS AS IDENTITY,
    nombre               varchar(40)  NOT NULL,
    descripcion          varchar(200) NOT NULL,
    CONSTRAINT pk_tipo_acreditacion PRIMARY KEY (id_tipo_acreditacion),
    CONSTRAINT uq_tipo_acreditacion_nombre UNIQUE (nombre)
);

CREATE TABLE empresa (
    id_empresa  integer GENERATED ALWAYS AS IDENTITY,
    nombre      varchar(120) NOT NULL,
    pais        varchar(60)  NOT NULL,
    sitio_web   varchar(200),
    CONSTRAINT pk_empresa PRIMARY KEY (id_empresa),
    CONSTRAINT uq_empresa_nombre UNIQUE (nombre),                            -- R21
    CONSTRAINT ck_empresa_sitio_web CHECK (sitio_web IS NULL OR sitio_web ~ '^https?://')
);

-- ---------------------------------------------------------------------
-- 4. PERSONAS Y PARTICIPACIÓN  (jerarquía SOLAPADA y TOTAL)
--    participacion_edicion (supertipo) -> asistente / ponente (subtipos)
-- ---------------------------------------------------------------------
CREATE TABLE persona (
    id_persona  integer GENERATED ALWAYS AS IDENTITY,
    nombre      varchar(120) NOT NULL,
    correo      varchar(150) NOT NULL,
    pais        varchar(60)  NOT NULL,
    CONSTRAINT pk_persona PRIMARY KEY (id_persona),
    CONSTRAINT uq_persona_correo UNIQUE (correo),                            -- R5
    CONSTRAINT ck_persona_correo_formato CHECK
        (correo ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT ck_persona_correo_minuscula CHECK (correo = lower(correo))    -- unicidad sin distinguir mayúsculas
);

CREATE TABLE participacion_edicion (
    id_participacion integer GENERATED ALWAYS AS IDENTITY,
    id_persona       integer NOT NULL,
    id_edicion       integer NOT NULL,
    fecha_registro   date    NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_participacion_edicion PRIMARY KEY (id_participacion),
    CONSTRAINT fk_participacion_persona FOREIGN KEY (id_persona)
        REFERENCES persona (id_persona) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_participacion_edicion FOREIGN KEY (id_edicion)
        REFERENCES edicion (id_edicion) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_participacion_persona_edicion UNIQUE (id_persona, id_edicion) -- R6
);

-- Subtipo ASISTENTE: la PK es a la vez FK hacia el supertipo (identidad compartida).
CREATE TABLE asistente (
    id_participacion     integer NOT NULL,
    id_tipo_acreditacion integer NOT NULL,                                   -- R8
    CONSTRAINT pk_asistente PRIMARY KEY (id_participacion),
    CONSTRAINT fk_asistente_participacion FOREIGN KEY (id_participacion)
        REFERENCES participacion_edicion (id_participacion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_asistente_acreditacion FOREIGN KEY (id_tipo_acreditacion)
        REFERENCES tipo_acreditacion (id_tipo_acreditacion) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Subtipo PONENTE: la PK es a la vez FK hacia el supertipo (identidad compartida).
CREATE TABLE ponente (
    id_participacion integer NOT NULL,
    biografia        text    NOT NULL,                                       -- R8
    CONSTRAINT pk_ponente PRIMARY KEY (id_participacion),
    CONSTRAINT fk_ponente_participacion FOREIGN KEY (id_participacion)
        REFERENCES participacion_edicion (id_participacion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_ponente_biografia CHECK (char_length(btrim(biografia)) >= 20)
);

-- ---------------------------------------------------------------------
-- 5. SESIONES  (jerarquía DISJUNTA y TOTAL: sesion -> charla | taller)
--    Relaciones 1:N  Edicion -> Sesion  y  Sala -> Sesion (sala opcional)
-- ---------------------------------------------------------------------
CREATE TABLE sesion (
    id_sesion    integer GENERATED ALWAYS AS IDENTITY,
    id_edicion   integer      NOT NULL,
    id_sala      integer,                      -- NULL = sesión virtual (sin sala)
    tipo_sesion  varchar(6)   NOT NULL,        -- discriminador de la jerarquía
    titulo       varchar(160) NOT NULL,
    resumen      text         NOT NULL,
    fecha        date         NOT NULL,
    hora_inicio  time         NOT NULL,
    hora_fin     time         NOT NULL,
    CONSTRAINT pk_sesion PRIMARY KEY (id_sesion),
    CONSTRAINT uq_sesion_id_tipo UNIQUE (id_sesion, tipo_sesion),            -- destino de la FK compuesta de los subtipos
    CONSTRAINT uq_sesion_edicion_titulo UNIQUE (id_edicion, titulo),
    CONSTRAINT fk_sesion_edicion FOREIGN KEY (id_edicion)
        REFERENCES edicion (id_edicion) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_sesion_sala FOREIGN KEY (id_sala)
        REFERENCES sala (id_sala) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_sesion_tipo CHECK (tipo_sesion IN ('charla', 'taller')),   -- R13
    CONSTRAINT ck_sesion_horas CHECK (hora_fin > hora_inicio),               -- R9
    -- R11: una sala no puede alojar dos sesiones con horarios superpuestos.
    -- Rango semiabierto [inicio, fin): una sesión puede empezar justo cuando otra termina.
    CONSTRAINT ex_sesion_sala_sin_solape EXCLUDE USING gist (
        id_sala WITH =,
        (tsrange(fecha + hora_inicio, fecha + hora_fin, '[)')) WITH &&
    ) WHERE (id_sala IS NOT NULL)
);

-- Subtipo CHARLA. Identidad compartida (PK = FK al supertipo) y disjunción
-- garantizada por la FK compuesta (id_sesion, tipo_sesion) con tipo fijo 'charla'.
CREATE TABLE charla (
    id_sesion         integer     NOT NULL,
    tipo_sesion       varchar(6)  NOT NULL DEFAULT 'charla',
    minutos_preguntas smallint    NOT NULL,                                  -- R14
    CONSTRAINT pk_charla PRIMARY KEY (id_sesion),
    CONSTRAINT fk_charla_supertipo FOREIGN KEY (id_sesion)
        REFERENCES sesion (id_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_charla_discriminador FOREIGN KEY (id_sesion, tipo_sesion)
        REFERENCES sesion (id_sesion, tipo_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_charla_tipo CHECK (tipo_sesion = 'charla'),
    CONSTRAINT ck_charla_minutos CHECK (minutos_preguntas BETWEEN 0 AND 120)
);

-- Subtipo TALLER (misma estrategia, discriminador fijo 'taller').
CREATE TABLE taller (
    id_sesion              integer    NOT NULL,
    tipo_sesion            varchar(6) NOT NULL DEFAULT 'taller',
    cupo_practico          integer    NOT NULL,                              -- R14, R18
    requisitos_materiales  text       NOT NULL,                              -- R14
    CONSTRAINT pk_taller PRIMARY KEY (id_sesion),
    CONSTRAINT fk_taller_supertipo FOREIGN KEY (id_sesion)
        REFERENCES sesion (id_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_taller_discriminador FOREIGN KEY (id_sesion, tipo_sesion)
        REFERENCES sesion (id_sesion, tipo_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_taller_tipo CHECK (tipo_sesion = 'taller'),
    CONSTRAINT ck_taller_cupo CHECK (cupo_practico > 0),
    CONSTRAINT ck_taller_requisitos CHECK (char_length(btrim(requisitos_materiales)) > 0)
);

-- Relación 1:1 (opcional del lado sesión): Sesion -> Info_Transmision.
-- La PK compartida garantiza como máximo una fila de transmisión por sesión.
CREATE TABLE info_transmision (
    id_sesion             integer      NOT NULL,
    plataforma            varchar(60)  NOT NULL,
    url_transmision       varchar(300) NOT NULL,
    codigo_acceso         varchar(40),
    grabacion_disponible  boolean      NOT NULL DEFAULT false,
    CONSTRAINT pk_info_transmision PRIMARY KEY (id_sesion),
    CONSTRAINT fk_info_transmision_sesion FOREIGN KEY (id_sesion)
        REFERENCES sesion (id_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_info_transmision_url CHECK (url_transmision ~ '^https://')
);

-- Relación recursiva N:M sobre sesion (entidad asociativa).
CREATE TABLE prerrequisito_sesion (
    id_sesion               integer NOT NULL,   -- sesión que exige el requisito
    id_sesion_prerrequisito integer NOT NULL,   -- sesión que debe completarse antes
    CONSTRAINT pk_prerrequisito_sesion PRIMARY KEY (id_sesion, id_sesion_prerrequisito),
    CONSTRAINT fk_prerreq_sesion FOREIGN KEY (id_sesion)
        REFERENCES sesion (id_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_prerreq_requerida FOREIGN KEY (id_sesion_prerrequisito)
        REFERENCES sesion (id_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_prerreq_no_autorreferencia CHECK (id_sesion <> id_sesion_prerrequisito) -- R15
);

-- ---------------------------------------------------------------------
-- 6. ENTIDADES ASOCIATIVAS N:M
-- ---------------------------------------------------------------------
-- Asistente <-> Sesion
CREATE TABLE inscripcion_sesion (
    id_participacion   integer     NOT NULL,   -- participación con rol de asistente
    id_sesion          integer     NOT NULL,
    fecha_inscripcion  date        NOT NULL DEFAULT CURRENT_DATE,
    estado             varchar(15) NOT NULL DEFAULT 'pendiente',
    asistio            boolean,                -- NULL hasta que ocurre el evento
    CONSTRAINT pk_inscripcion_sesion PRIMARY KEY (id_participacion, id_sesion), -- R16
    CONSTRAINT fk_inscripcion_asistente FOREIGN KEY (id_participacion)
        REFERENCES asistente (id_participacion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_inscripcion_sesion FOREIGN KEY (id_sesion)
        REFERENCES sesion (id_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_inscripcion_estado CHECK
        (estado IN ('pendiente', 'confirmada', 'cancelada', 'lista_espera')),   -- R17
    CONSTRAINT ck_inscripcion_asistio CHECK (asistio IS NULL OR estado = 'confirmada') -- R17
);

-- Ponente <-> Sesion (conserva rol y orden en el programa)
CREATE TABLE asignacion_ponente (
    id_sesion         integer     NOT NULL,
    id_participacion  integer     NOT NULL,    -- participación con rol de ponente
    rol_ponente       varchar(15) NOT NULL DEFAULT 'principal',
    orden_programa    smallint    NOT NULL,
    CONSTRAINT pk_asignacion_ponente PRIMARY KEY (id_sesion, id_participacion),
    CONSTRAINT fk_asignacion_sesion FOREIGN KEY (id_sesion)
        REFERENCES sesion (id_sesion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_asignacion_ponente FOREIGN KEY (id_participacion)
        REFERENCES ponente (id_participacion) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT uq_asignacion_orden UNIQUE (id_sesion, orden_programa)
        DEFERRABLE INITIALLY IMMEDIATE,                                      -- R19 (permite reordenar en una transacción)
    CONSTRAINT ck_asignacion_rol CHECK
        (rol_ponente IN ('principal', 'co_ponente', 'moderador', 'facilitador', 'panelista')),
    CONSTRAINT ck_asignacion_orden CHECK (orden_programa > 0)
);

-- Empresa <-> Edicion (con atributos propios del acuerdo)
CREATE TABLE acuerdo_patrocinio (
    id_acuerdo          integer GENERATED ALWAYS AS IDENTITY,
    id_empresa          integer       NOT NULL,
    id_edicion          integer       NOT NULL,
    categoria           varchar(10)   NOT NULL,
    monto               numeric(12,2) NOT NULL,
    moneda              char(3)       NOT NULL DEFAULT 'USD',
    fecha_confirmacion  date          NOT NULL,
    estado              varchar(10)   NOT NULL DEFAULT 'vigente',
    CONSTRAINT pk_acuerdo_patrocinio PRIMARY KEY (id_acuerdo),
    CONSTRAINT fk_acuerdo_empresa FOREIGN KEY (id_empresa)
        REFERENCES empresa (id_empresa) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_acuerdo_edicion FOREIGN KEY (id_edicion)
        REFERENCES edicion (id_edicion) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_acuerdo_categoria CHECK
        (categoria IN ('platino', 'oro', 'plata', 'bronce', 'aliado')),         -- R20
    CONSTRAINT ck_acuerdo_monto CHECK (monto > 0),                             -- R20
    CONSTRAINT ck_acuerdo_moneda CHECK (moneda ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_acuerdo_estado CHECK (estado IN ('vigente', 'cancelado', 'vencido'))
);

-- R20: un solo acuerdo VIGENTE por empresa y edición (el historial cancelado/vencido se conserva).
CREATE UNIQUE INDEX uq_acuerdo_vigente_empresa_edicion
    ON acuerdo_patrocinio (id_empresa, id_edicion)
    WHERE estado = 'vigente';

-- ---------------------------------------------------------------------
-- 7. ÍNDICES DE APOYO PARA CLAVES FORÁNEAS Y CONSULTAS FRECUENTES
-- ---------------------------------------------------------------------
CREATE INDEX idx_edicion_sede            ON edicion (id_sede);
CREATE INDEX idx_sala_sede               ON sala (id_sede);
CREATE INDEX idx_sesion_edicion_fecha    ON sesion (id_edicion, fecha, hora_inicio);
CREATE INDEX idx_participacion_edicion   ON participacion_edicion (id_edicion);
CREATE INDEX idx_asistente_acreditacion  ON asistente (id_tipo_acreditacion);
CREATE INDEX idx_inscripcion_sesion      ON inscripcion_sesion (id_sesion, estado);
CREATE INDEX idx_asignacion_ponente      ON asignacion_ponente (id_participacion);
CREATE INDEX idx_prerreq_requerida       ON prerrequisito_sesion (id_sesion_prerrequisito);
CREATE INDEX idx_acuerdo_edicion         ON acuerdo_patrocinio (id_edicion);

-- ---------------------------------------------------------------------
-- 8. REGLAS QUE NO SE PUEDEN EXPRESAR CON CHECK/UNIQUE/FK: FUNCIONES Y TRIGGERS
--    (los CONSTRAINT TRIGGER diferidos se evalúan al COMMIT, de modo que una
--     transacción puede insertar supertipo y subtipo en cualquier orden)
-- ---------------------------------------------------------------------

-- R10: la sesión cae dentro de las fechas de su edición y su sala pertenece
--      a la sede de esa edición (una edición virtual no admite salas).
CREATE FUNCTION fn_sesion_contexto() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_ini  date;
    v_fin  date;
    v_sede_edicion integer;
    v_sede_sala    integer;
BEGIN
    SELECT fecha_inicio, fecha_fin, id_sede
      INTO v_ini, v_fin, v_sede_edicion
      FROM edicion WHERE id_edicion = NEW.id_edicion;
    IF NOT FOUND THEN
        RETURN NEW;  -- la FOREIGN KEY informará la edición inexistente
    END IF;

    IF NEW.fecha < v_ini OR NEW.fecha > v_fin THEN
        RAISE EXCEPTION 'La sesión "%" (fecha %) queda fuera de las fechas de la edición (% a %)',
            NEW.titulo, NEW.fecha, v_ini, v_fin
            USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.id_sala IS NOT NULL THEN
        SELECT id_sede INTO v_sede_sala FROM sala WHERE id_sala = NEW.id_sala;
        IF FOUND AND v_sede_sala IS DISTINCT FROM v_sede_edicion THEN
            RAISE EXCEPTION 'La sala % no pertenece a la sede de la edición %', NEW.id_sala, NEW.id_edicion
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_sesion_contexto
    BEFORE INSERT OR UPDATE OF id_edicion, id_sala, fecha ON sesion
    FOR EACH ROW EXECUTE FUNCTION fn_sesion_contexto();

-- R13: jerarquía TOTAL. Toda sesión debe tener su fila en el subtipo que indica tipo_sesion.
CREATE FUNCTION fn_sesion_subtipo_total() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_id   integer;
    v_tipo varchar(6);
BEGIN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_sesion ELSE NEW.id_sesion END;
    SELECT tipo_sesion INTO v_tipo FROM sesion WHERE id_sesion = v_id;
    IF NOT FOUND THEN
        RETURN NULL;  -- la sesión ya no existe (borrado en cascada)
    END IF;
    IF v_tipo = 'charla' AND NOT EXISTS (SELECT 1 FROM charla WHERE id_sesion = v_id) THEN
        RAISE EXCEPTION 'La sesión % es una charla pero no tiene fila en la tabla charla (jerarquía total)', v_id
            USING ERRCODE = 'integrity_constraint_violation';
    ELSIF v_tipo = 'taller' AND NOT EXISTS (SELECT 1 FROM taller WHERE id_sesion = v_id) THEN
        RAISE EXCEPTION 'La sesión % es un taller pero no tiene fila en la tabla taller (jerarquía total)', v_id
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER trg_sesion_subtipo_total
    AFTER INSERT OR UPDATE ON sesion
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_sesion_subtipo_total();
CREATE CONSTRAINT TRIGGER trg_charla_subtipo_total
    AFTER DELETE ON charla
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_sesion_subtipo_total();
CREATE CONSTRAINT TRIGGER trg_taller_subtipo_total
    AFTER DELETE ON taller
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_sesion_subtipo_total();

-- R12: una sesión sin sala (virtual) necesita su información de transmisión (relación 1:1).
CREATE FUNCTION fn_sesion_requiere_transmision() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_id   integer;
    v_sala integer;
BEGIN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_sesion ELSE NEW.id_sesion END;
    SELECT id_sala INTO v_sala FROM sesion WHERE id_sesion = v_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    IF v_sala IS NULL AND NOT EXISTS (SELECT 1 FROM info_transmision WHERE id_sesion = v_id) THEN
        RAISE EXCEPTION 'La sesión % no tiene sala y por tanto requiere información de transmisión', v_id
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER trg_sesion_requiere_transmision
    AFTER INSERT OR UPDATE ON sesion
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_sesion_requiere_transmision();
CREATE CONSTRAINT TRIGGER trg_transmision_requerida_al_borrar
    AFTER DELETE ON info_transmision
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_sesion_requiere_transmision();

-- R7: jerarquía SOLAPADA y TOTAL. Toda participación necesita al menos un rol
--     (fila en asistente, en ponente o en ambas).
CREATE FUNCTION fn_participacion_rol_total() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_id integer;
BEGIN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_participacion ELSE NEW.id_participacion END;
    IF NOT EXISTS (SELECT 1 FROM participacion_edicion WHERE id_participacion = v_id) THEN
        RETURN NULL;  -- la participación ya no existe (borrado en cascada)
    END IF;
    IF NOT EXISTS (SELECT 1 FROM asistente WHERE id_participacion = v_id)
       AND NOT EXISTS (SELECT 1 FROM ponente WHERE id_participacion = v_id) THEN
        RAISE EXCEPTION 'La participación % no tiene rol: debe ser asistente, ponente o ambos', v_id
            USING ERRCODE = 'integrity_constraint_violation';
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER trg_participacion_rol_total
    AFTER INSERT ON participacion_edicion
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_participacion_rol_total();
CREATE CONSTRAINT TRIGGER trg_asistente_rol_total
    AFTER DELETE ON asistente
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_participacion_rol_total();
CREATE CONSTRAINT TRIGGER trg_ponente_rol_total
    AFTER DELETE ON ponente
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW EXECUTE FUNCTION fn_participacion_rol_total();

-- R15: prerrequisitos coherentes. Misma edición y la sesión requerida debe terminar
--      antes de que empiece la dependiente (esto además impide ciclos).
CREATE FUNCTION fn_prerrequisito_validar() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_ed_sesion integer;
    v_ed_previa integer;
    v_inicio    timestamp;
    v_fin_prev  timestamp;
BEGIN
    IF NEW.id_sesion = NEW.id_sesion_prerrequisito THEN
        RETURN NEW;  -- lo rechaza ck_prerreq_no_autorreferencia
    END IF;
    SELECT id_edicion, fecha + hora_inicio INTO v_ed_sesion, v_inicio
      FROM sesion WHERE id_sesion = NEW.id_sesion;
    IF NOT FOUND THEN RETURN NEW; END IF;
    SELECT id_edicion, fecha + hora_fin INTO v_ed_previa, v_fin_prev
      FROM sesion WHERE id_sesion = NEW.id_sesion_prerrequisito;
    IF NOT FOUND THEN RETURN NEW; END IF;

    IF v_ed_sesion <> v_ed_previa THEN
        RAISE EXCEPTION 'El prerrequisito % pertenece a otra edición que la sesión %',
            NEW.id_sesion_prerrequisito, NEW.id_sesion USING ERRCODE = 'check_violation';
    END IF;
    IF v_fin_prev > v_inicio THEN
        RAISE EXCEPTION 'El prerrequisito % termina (%) después del inicio de la sesión % (%)',
            NEW.id_sesion_prerrequisito, v_fin_prev, NEW.id_sesion, v_inicio
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_prerrequisito_validar
    BEFORE INSERT OR UPDATE ON prerrequisito_sesion
    FOR EACH ROW EXECUTE FUNCTION fn_prerrequisito_validar();

-- R16, R17, R18: inscripciones coherentes.
--   * asistente y sesión pertenecen a la misma edición
--   * la asistencia solo se registra cuando la sesión ya ocurrió
--   * no se supera el cupo práctico del taller ni el aforo de la sala
CREATE FUNCTION fn_inscripcion_validar() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_ed_sesion integer;
    v_ed_asist  integer;
    v_sala      integer;
    v_fecha     date;
    v_cupo      integer;
    v_aforo     integer;
    v_ocupados  integer;
BEGIN
    SELECT id_edicion, id_sala, fecha INTO v_ed_sesion, v_sala, v_fecha
      FROM sesion WHERE id_sesion = NEW.id_sesion;
    IF NOT FOUND THEN RETURN NEW; END IF;   -- la FK informará la sesión inexistente
    SELECT id_edicion INTO v_ed_asist
      FROM participacion_edicion WHERE id_participacion = NEW.id_participacion;
    IF NOT FOUND THEN RETURN NEW; END IF;

    IF v_ed_asist <> v_ed_sesion THEN
        RAISE EXCEPTION 'El asistente (participación %) no pertenece a la edición de la sesión %',
            NEW.id_participacion, NEW.id_sesion USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.asistio IS NOT NULL AND v_fecha > CURRENT_DATE THEN
        RAISE EXCEPTION 'No se puede registrar asistencia: la sesión % ocurre el % (futuro)',
            NEW.id_sesion, v_fecha USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.estado IN ('pendiente', 'confirmada') THEN
        -- Serializa inscripciones concurrentes a la misma sesión para evitar sobrecupo.
        PERFORM 1 FROM sesion WHERE id_sesion = NEW.id_sesion FOR NO KEY UPDATE;
        SELECT cupo_practico INTO v_cupo FROM taller WHERE id_sesion = NEW.id_sesion;
        SELECT capacidad INTO v_aforo FROM sala WHERE id_sala = v_sala;
        SELECT count(*) INTO v_ocupados
          FROM inscripcion_sesion
         WHERE id_sesion = NEW.id_sesion
           AND estado IN ('pendiente', 'confirmada')
           AND id_participacion <> NEW.id_participacion;
        IF v_cupo IS NOT NULL AND v_ocupados >= v_cupo THEN
            RAISE EXCEPTION 'Cupo agotado en el taller %: % de % cupos ocupados',
                NEW.id_sesion, v_ocupados, v_cupo USING ERRCODE = 'check_violation';
        END IF;
        IF v_aforo IS NOT NULL AND v_ocupados >= v_aforo THEN
            RAISE EXCEPTION 'Aforo agotado en la sala de la sesión %: % de % lugares ocupados',
                NEW.id_sesion, v_ocupados, v_aforo USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_inscripcion_validar
    BEFORE INSERT OR UPDATE ON inscripcion_sesion
    FOR EACH ROW EXECUTE FUNCTION fn_inscripcion_validar();

-- R19: la asignación de ponentes es coherente. Misma edición y sin dobles reservas
--      del ponente en horarios que se superponen.
CREATE FUNCTION fn_asignacion_validar() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_ed_sesion integer;
    v_ed_pon    integer;
    v_fecha     date;
    v_ini       time;
    v_fin       time;
BEGIN
    SELECT id_edicion, fecha, hora_inicio, hora_fin INTO v_ed_sesion, v_fecha, v_ini, v_fin
      FROM sesion WHERE id_sesion = NEW.id_sesion;
    IF NOT FOUND THEN RETURN NEW; END IF;
    SELECT id_edicion INTO v_ed_pon
      FROM participacion_edicion WHERE id_participacion = NEW.id_participacion;
    IF NOT FOUND THEN RETURN NEW; END IF;

    IF v_ed_pon <> v_ed_sesion THEN
        RAISE EXCEPTION 'El ponente (participación %) no pertenece a la edición de la sesión %',
            NEW.id_participacion, NEW.id_sesion USING ERRCODE = 'check_violation';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM asignacion_ponente a
          JOIN sesion s2 ON s2.id_sesion = a.id_sesion
         WHERE a.id_participacion = NEW.id_participacion
           AND a.id_sesion <> NEW.id_sesion
           AND s2.fecha = v_fecha
           AND s2.hora_inicio < v_fin
           AND s2.hora_fin > v_ini) THEN
        RAISE EXCEPTION 'El ponente (participación %) ya tiene otra sesión que se superpone con la sesión %',
            NEW.id_participacion, NEW.id_sesion USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_asignacion_validar
    BEFORE INSERT OR UPDATE ON asignacion_ponente
    FOR EACH ROW EXECUTE FUNCTION fn_asignacion_validar();

-- ---------------------------------------------------------------------
-- 9. COMENTARIOS DE CATÁLOGO (visibles con \dt+ y \d+)
-- ---------------------------------------------------------------------
COMMENT ON TABLE sede                  IS 'Lugar físico donde se realizan ediciones presenciales o híbridas.';
COMMENT ON TABLE sala                  IS 'Sala de una sede, con capacidad máxima.';
COMMENT ON TABLE edicion               IS 'Edición anual de un congreso (presencial, virtual o híbrida).';
COMMENT ON TABLE tipo_acreditacion     IS 'Catálogo de acreditaciones que puede elegir un asistente.';
COMMENT ON TABLE empresa               IS 'Empresa que puede patrocinar una o más ediciones.';
COMMENT ON TABLE persona               IS 'Persona registrada en la plataforma (correo único).';
COMMENT ON TABLE participacion_edicion IS 'Supertipo solapado y total: persona dentro de una edición.';
COMMENT ON TABLE asistente             IS 'Subtipo: participación con rol de asistente y su acreditación.';
COMMENT ON TABLE ponente               IS 'Subtipo: participación con rol de ponente y su biografía.';
COMMENT ON TABLE sesion                IS 'Supertipo disjunto y total del programa: charla o taller.';
COMMENT ON TABLE charla                IS 'Subtipo de sesión con minutos reservados para preguntas.';
COMMENT ON TABLE taller                IS 'Subtipo de sesión con cupo práctico y materiales requeridos.';
COMMENT ON TABLE info_transmision      IS 'Relación 1:1 con sesión: datos de transmisión en línea.';
COMMENT ON TABLE prerrequisito_sesion  IS 'Relación recursiva N:M: sesiones que deben completarse antes de otra.';
COMMENT ON TABLE inscripcion_sesion    IS 'Entidad asociativa N:M asistente-sesión con fecha, estado y asistencia.';
COMMENT ON TABLE asignacion_ponente    IS 'Entidad asociativa N:M ponente-sesión con rol y orden en el programa.';
COMMENT ON TABLE acuerdo_patrocinio    IS 'Entidad asociativa N:M empresa-edición con categoría, monto y confirmación.';

COMMIT;
