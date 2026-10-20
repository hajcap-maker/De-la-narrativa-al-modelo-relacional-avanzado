# ConectaTech · De la narrativa al modelo relacional avanzado

Proyecto académico de modelado relacional para administrar ediciones presenciales, virtuales e híbridas de un congreso. Incluye el esquema en PostgreSQL 18, datos de ejemplo, consultas y pruebas de integridad. El entorno se ejecuta con Docker Compose; no hace falta instalar PostgreSQL en el equipo.

## Requisitos

- Git, para clonar el repositorio.
- Docker Desktop en Windows/macOS, o Docker Engine en Linux, con Docker Compose v2. Docker debe estar iniciado antes de ejecutar los comandos.
- Comprueba la instalación desde una terminal:

  ```text
  docker --version
  docker compose version
  ```

No necesitas instalar PostgreSQL, `psql`, Node.js ni Python en el equipo anfitrión.

## Clonar y configurar por primera vez

Clona el repositorio y entra en la carpeta del proyecto:

```bash
git clone <URL-DEL-REPOSITORIO>
cd conectatech
```

En PowerShell de Windows, crea el archivo local `.env` a partir de la plantilla:

```powershell
Copy-Item .env.example .env
notepad .env
```

En macOS/Linux o una terminal Bash:

```bash
cp .env.example .env
nano .env
```

En `.env`, cambia `POSTGRES_PASSWORD` por una contraseña local segura. Este archivo es solo para la máquina: está excluido de Git mediante `.gitignore`; **no lo subas al repositorio**. Comparte únicamente `.env.example`, que no contiene una contraseña real.

Variables disponibles:

| Variable | Uso | Valor de ejemplo |
|---|---|---|
| `POSTGRES_DB` | Nombre de la base de datos | `conectatech` |
| `POSTGRES_USER` | Usuario administrador de la base | `conectatech_admin` |
| `POSTGRES_PASSWORD` | Contraseña local del usuario | Sustituir el valor de plantilla |
| `POSTGRES_PORT` | Puerto del equipo anfitrión | `5432` |

Si el puerto `5432` ya está ocupado, asigna otro puerto libre, por ejemplo `5433`. No cambies el puerto interno `5432` de PostgreSQL.

## Iniciar y comprobar el proyecto

Desde la carpeta que contiene `compose.yaml`:

```bash
docker compose up -d
docker compose ps
```

La primera vez, Docker descarga la imagen `postgres:18.0-alpine`. Espera a que el servicio `db` indique `healthy`; la inicialización puede tardar un poco. Revisa el proceso y cualquier error con:

```bash
docker compose logs --tail 100 db
```

Al iniciar por primera vez con un volumen de datos vacío, la imagen oficial ejecuta automáticamente los archivos `.sql` montados en `/docker-entrypoint-initdb.d`, en orden alfabético:

1. `01_schema.sql`: crea la extensión, tablas, restricciones, índices, funciones y triggers.
2. `02_seed.sql`: carga los datos de ejemplo.
3. `03_queries.sql`: ejecuta las consultas de demostración.
4. `04_invalid_tests.sql`: comprueba que PostgreSQL rechaza 13 operaciones inválidas.

La salida de las consultas y de las pruebas se puede consultar con `docker compose logs db`. Las pruebas inválidas deben mostrar `Rechazo esperado` y ninguna línea `FALLO DE LA PRUEBA`.

La base queda disponible en `localhost` en el puerto definido por `POSTGRES_PORT` (por defecto, `5432`). El nombre de base y el usuario son los valores configurados en `POSTGRES_DB` y `POSTGRES_USER`; la contraseña es la de `.env`.

## Consultas y pruebas después de iniciar

En PowerShell, no uses la redirección de entrada `< archivo.sql`: PowerShell no la admite como Bash. Los scripts ya están montados dentro del contenedor, así que puedes ejecutarlos directamente con `psql -f`:

```powershell
docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -f /docker-entrypoint-initdb.d/03_queries.sql'
docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -f /docker-entrypoint-initdb.d/04_invalid_tests.sql'
```

Las pruebas están diseñadas para no dejar cambios persistentes. No vuelvas a ejecutar `01_schema.sql` ni `02_seed.sql` sobre una base ya inicializada: el esquema no está diseñado para repetirse y las referencias del seed dependen de una base vacía. La primera vez, Docker Compose ya los ejecuta automáticamente; para reconstruir desde cero, consulta la sección [Detener, reanudar y reiniciar](#detener-reanudar-y-reiniciar).

> En Bash/macOS/Linux sí se puede redirigir un archivo con `<`, pero aquí se recomienda `psql -f` para que el mismo método funcione desde PowerShell y no dependa de la shell.

| Consulta | Qué muestra |
|---|---|
| Q1 | Programa, ubicación o transmisión, ponentes y prerrequisitos |
| Q2 | Cupos de talleres, inscritos activos, disponibilidad y ocupación |
| Q3a / Q3b | Participación por persona y rol; resumen por edición |
| Q4 | Recaudación de patrocinios vigentes |
| Q5 | Cadena de prerrequisitos mediante CTE recursiva |
| Q6 | Asistencia real frente a inscripciones confirmadas |

Para abrir una consola `psql` interactiva:

```bash
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

Dentro de `psql`, usa `\dt` para listar tablas, `\d sesion` para ver la tabla de sesiones, `\dx` para revisar extensiones y `\q` para salir.

## Detener, reanudar y reiniciar

Detén el servicio sin borrar la base ni sus datos:

```bash
docker compose stop
```

Reanúdalo más tarde:

```bash
docker compose start
```

O detén y elimina el contenedor y la red del proyecto, conservando el volumen de datos:

```bash
docker compose down
```

Para reconstruir la base desde cero, elimina también el volumen persistente:

```bash
docker compose down -v
docker compose up -d
```

> **Atención:** `docker compose down -v` elimina permanentemente los datos guardados en el volumen `pgdata` de este proyecto. Los scripts de inicialización solo se ejecutan automáticamente cuando ese volumen está vacío.

## Estructura del repositorio

```text
.
├── README.md
├── narrativa-y-reglas.md        Hechos, supuestos, entidades y reglas de negocio
├── modelo-conceptual.mmd        Diagrama conceptual Mermaid
├── modelo-logico.mmd            Diagrama lógico Mermaid
├── diccionario-datos.md         Columnas, tipos, nulabilidad y restricciones
├── compose.yaml                 PostgreSQL 18, healthcheck y volumen persistente
├── .env.example                 Plantilla de configuración local sin secretos
├── .gitignore                   Excluye .env, datos locales y archivos de editor
└── sql/
    ├── 01_schema.sql            Esquema, restricciones, funciones y triggers
    ├── 02_seed.sql              Datos de ejemplo
    ├── 03_queries.sql           Consultas avanzadas Q1–Q6
    └── 04_invalid_tests.sql     13 pruebas de datos inválidos
```

## Diseño y cobertura de integridad

- Jerarquía disjunta y total `sesion → charla | taller`, mediante discriminador, FK compuesta y trigger diferido.
- Jerarquía solapada y total `participacion_edicion → asistente | ponente`, con claves compartidas y triggers diferidos para exigir al menos un rol.
- Relación 1:1 `sesion — info_transmision`, relación recursiva de prerrequisitos y relaciones asociativas para inscripciones, ponentes y patrocinios.
- Restricciones declarativas `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`, `NOT NULL`, índices parciales y `EXCLUDE USING gist`.
- La extensión `btree_gist` impide sesiones que se solapen en la misma sala. Los triggers cubren reglas que no se pueden expresar solo con `CHECK`, como cupos e integridad entre entidades.
- Los triggers diferidos se evalúan al confirmar la transacción; por eso el seed inserta los datos en una sola transacción.
- Las claves `GENERATED ALWAYS AS IDENTITY` y algunas referencias del seed presuponen una base vacía. Usa el reinicio con `down -v` antes de volver a cargar el esquema y el seed.
- En PostgreSQL 18, el volumen de datos de la imagen oficial se monta en `/var/lib/postgresql`.

## Preparar el repositorio para GitHub

La entrega requiere un repositorio público y al menos tres commits significativos. Si todavía no inicializaste Git, desde la carpeta del proyecto:

```bash
git init
```

Confirma que la configuración local está ignorada:

```bash
git check-ignore .env
```

El comando debe mostrar `.env`. Crea tres commits que separen el trabajo por etapas:

```bash
git add .gitignore .env.example compose.yaml README.md
git commit -m "chore: preparar entorno reproducible con Docker Compose"

git add narrativa-y-reglas.md modelo-conceptual.mmd modelo-logico.mmd diccionario-datos.md
git commit -m "docs: documentar análisis y modelos relacional y conceptual"

git add sql/01_schema.sql sql/02_seed.sql sql/03_queries.sql sql/04_invalid_tests.sql
git commit -m "feat: implementar esquema, datos, consultas y pruebas SQL"

git status --short
git log --oneline -3
```

Comprueba que el historial muestre los tres commits y que el árbol de trabajo esté limpio. `.env` no debe aparecer en `git status`; no publiques contraseñas, volcados de base de datos ni otros archivos privados. Crea un repositorio **público** en GitHub y configura su URL:

```bash
git branch -M main
git remote add origin <URL-DEL-REPOSITORIO>
git push -u origin main
```

Verifica en GitHub que la visibilidad sea pública, que los tres commits se hayan publicado y que `.env` no esté entre los archivos. Si el repositorio ya está inicializado o contiene commits, no repitas `git init` ni reemplaces su historial; integra estos cambios respetando el flujo de ese repositorio.

## Solución de problemas

| Síntoma | Causa probable y solución |
|---|---|
| `POSTGRES_PASSWORD` no está especificada o está vacía | Comprueba que `.env` exista junto a `compose.yaml` y que la línea `POSTGRES_PASSWORD=...` tenga un valor no vacío. No uses el marcador de posición de `.env.example` como contraseña publicada. |
| El servicio queda en `restarting` o `unhealthy` | Ejecuta `docker compose logs --tail 100 db`, corrige el error indicado y vuelve a iniciar con `docker compose up -d`. |
| `variable is not set` al arrancar | Crea `.env` desde `.env.example` y define las cuatro variables. Ejecuta Compose desde la carpeta del proyecto. |
| El puerto `5432` ya está en uso | Cambia `POSTGRES_PORT` en `.env`, por ejemplo a `5433`, y vuelve a ejecutar `docker compose up -d`. |
| Los scripts no vuelven a ejecutarse | Es el comportamiento normal con un volumen existente. Si necesitas regenerar toda la base, usa `docker compose down -v` y luego `docker compose up -d`. |
| Falla la creación de `btree_gist` | Usa el usuario administrador definido en `.env`; la imagen oficial lo crea como superusuario. Revisa también los logs de PostgreSQL. |
| Docker no responde o no puede descargar la imagen | Inicia Docker Desktop o el servicio de Docker y comprueba la conexión a Internet. |

## Material relacionado

- [Narrativa y reglas de negocio](narrativa-y-reglas.md)
- [Modelo conceptual](modelo-conceptual.mmd)
- [Modelo lógico](modelo-logico.mmd)
- [Diccionario de datos](diccionario-datos.md)
