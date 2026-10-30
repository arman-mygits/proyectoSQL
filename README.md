# Proyecto BBDD 

Base de datos relacional en **PostgreSQL**, alojada en **Supabase**, creada a partir de los datos sin normalizar de los alumnos y el claustro de una escuela de bootcamps (Data Science y Full Stack).


## Entregables

- Diagrama entidad-relación
- Diagrama del modelo lógico
- Script de creación de tablas
- Script de carga de datos
- Consultas de demostración

## Datos de entrada

En [`data/`](data/) están los 5 CSV originales (separador `;`):

- `clase_1.csv` … `clase_4.csv`: 52 alumnos, con el resultado (Apto / No Apto) de sus 5 proyectos.
- `claustro.csv`: 10 docentes, con su rol (TA / LI), vertical (especialidad), promoción (promo), campus y modalidad.

## Modelo de datos

**9 tablas** normalizadas en 3FN:

| Tipo | Tablas |
|---|---|
| Catálogos | `especialidad`, `promo`, `campus` |
| Entidades | `clase` (especialidad + promo + campus), `proyecto`, `alumno`, `docente` |
| Relaciones N:M | `hace` (alumno × proyecto → `apto`) · `asignado` (docente × clase → `rol`, `modalidad`) |

### Normalización

- **1FN:** las columnas `Proyecto_*` de los CSV pasan a ser filas de la tabla `hace`.
- **2FN:** en las tablas con clave compuesta, cada dato depende de la clave completa. Por ejemplo, `apto` depende del alumno **y** del proyecto.
- **3FN:** sin dependencias transitivas. Por ejemplo, fecha_comienzo depende de la promoción, no del alumno, así que se guarda una sola vez en `promo` y el alumno solo guarda `id_clase`.

## Cómo crear la base de datos

1. Crear un proyecto PostgreSQL en [Supabase](https://supabase.com) (también vale Render u otro servidor PostgreSQL).
2. En el **SQL Editor**, ejecutar en este orden:
   1. `querysCreateTables.sql`
   2. `querysInsertData.sql`
3. Probar las consultas de demostración (capturas `demostracion1.png`, `demostracion2.png` y `demostracion3.png`).

Para conectarse desde aplicaciones de terceros (pgAdmin, DBeaver, Python), usar los datos de **Connect** en Supabase con `SSL mode = require`.

> ⚠️ Las credenciales de la base de datos **no se suben a este repositorio**. 

## Escalabilidad

Todo lo que puede crecer es un **dato**, no una columna. Un campus, una especialidad, una promoción o un docente nuevos se añaden con un `INSERT`, sin cambiar la estructura:

```sql
INSERT INTO campus (nombre) VALUES ('Bilbao');
```

## Tecnologías

PostgreSQL · Supabase · pgAdmin 4 · draw.io · Python (pandas) para el análisis de los CSV
