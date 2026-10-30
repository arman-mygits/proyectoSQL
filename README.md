<div align="center">

# Proyecto BBDD — Escuela de Bootcamps

**Base de datos relacional normalizada en 3FN, desplegada en la nube.**

Diseñada a partir de los datos sin normalizar de alumnos y claustro
de una escuela de bootcamps (Data Science y Full Stack).

<br>

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18.6-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Render](https://img.shields.io/badge/Render-Cloud-46E3B7?style=for-the-badge&logo=render&logoColor=black)
![pgAdmin](https://img.shields.io/badge/pgAdmin-4-326690?style=for-the-badge&logo=postgresql&logoColor=white)

<br>

![Tablas](https://img.shields.io/badge/Tablas-9-informational?style=flat-square)
![Alumnos](https://img.shields.io/badge/Alumnos-52-success?style=flat-square)
![Docentes](https://img.shields.io/badge/Docentes-10-success?style=flat-square)
![Calificaciones](https://img.shields.io/badge/Calificaciones-260-success?style=flat-square)
![Normalización](https://img.shields.io/badge/Normalizaci%C3%B3n-3FN-blueviolet?style=flat-square)

</div>

---

## Contenidos

| | Sección |
|---|---|
| 1 | [Decisiones de modelado](#decisiones-de-modelado) · [*English*](#data-modeling-decisions) |
| 2 | [Estructura del repositorio](#estructura-del-repositorio) |
| 3 | [Diagramas](#diagramas) |
| 4 | [Modelo de datos](#modelo-de-datos) |
| 5 | [Normalización](#normalización) |
| 6 | [Datos cargados](#datos-cargados) |
| 7 | [Puesta en marcha](#puesta-en-marcha) |
| 8 | [Consultas de demostración](#consultas-de-demostración) |
| 9 | [Escalabilidad](#escalabilidad) |
| 10 | [Bugfix — errores y soluciones](bugfix/) |

---

## Decisiones de modelado

> Esta fue la **primera** fase del proyecto y la que condicionó todo lo demás:
> los scripts, las consultas y la escalabilidad salen directamente de aquí.

### El punto de partida

Los datos de entrada eran **una sola tabla plana**, una fila por alumno:

| Nombre | Email | Promoción | Fecha_comienzo | Campus | Proyecto_HLF | Proyecto_EDA | … |
|---|---|---|---|---|---|---|---|
| Jafet Casals | Jafet_Casals@gmail.com | Septiembre | 18/09/2023 | Madrid | Apto | No Apto | … |
| Jorge Manzanares | Jorge_Manzanares@gmail.com | Septiembre | 18/09/2023 | Madrid | Apto | No Apto | … |

Tres problemas evidentes:

1. **Redundancia.** `Septiembre`, `18/09/2023` y `Madrid` se repiten en cada una de las 52 filas.
2. **Grupos repetidos.** Las 5 columnas `Proyecto_*` son la misma información repetida cinco veces.
3. **Anomalías de actualización.** Corregir la fecha de una promoción obligaría a tocar decenas de filas, y un fallo en una sola dejaría la base de datos incoherente.

A partir de ahí se tomaron siete decisiones.

### Visión general del modelo

```mermaid
erDiagram
    ESPECIALIDAD ||--o{ CLASE : "1:N"
    PROMO ||--o{ CLASE : "1:N"
    CAMPUS ||--o{ CLASE : "1:N"
    CLASE ||--o{ ALUMNO : "1:N"
    ESPECIALIDAD ||--o{ PROYECTO : "1:N"
    ALUMNO }o--o{ PROYECTO : "N:M via hace"
    DOCENTE }o--o{ CLASE : "N:M via asignado"

    ESPECIALIDAD {
        int id_especialidad PK
        varchar nombre
    }
    PROMO {
        int id_promo PK
        varchar nombre
        date fecha_comienzo
    }
    CAMPUS {
        int id_campus PK
        varchar nombre
    }
    CLASE {
        int id_clase PK
        int id_especialidad FK
        int id_promo FK
        int id_campus FK
    }
    ALUMNO {
        int id_alumno PK
        varchar nombre
        varchar email
        int id_clase FK
    }
    PROYECTO {
        int id_proyecto PK
        varchar nombre
        int id_especialidad FK
    }
    DOCENTE {
        int id_docente PK
        varchar nombre
    }
    HACE {
        int id_proyecto PK_FK
        int id_alumno PK_FK
        varchar apto
    }
    ASIGNADO {
        int id_clase PK_FK
        int id_docente PK_FK
        varchar rol
        varchar modalidad
    }
```

<br>

### 1 · `clase` como entidad central

La decisión más importante del modelo.

En los datos originales, cada alumno arrastraba su **especialidad**, su **promoción** y su **campus**. Pero esos tres valores no describen al alumno de forma independiente: lo que realmente identifica a un alumno es **el grupo al que pertenece**, y ese grupo *es* la combinación de los tres.

Por eso no se pusieron tres claves foráneas en `alumno`, sino que se creó `clase`:

```mermaid
flowchart LR
    subgraph "❌ Sin clase — 3 FK en alumno"
        A1[alumno] -->|id_especialidad| E1[especialidad]
        A1 -->|id_promo| P1[promo]
        A1 -->|id_campus| C1[campus]
    end
```

```mermaid
flowchart LR
    subgraph "✅ Con clase — 1 FK en alumno"
        E2[especialidad] --> CL[clase]
        P2[promo] --> CL
        C2[campus] --> CL
        CL -->|id_clase| A2[alumno]
    end
```

Consecuencias:

- `alumno` guarda **una sola** clave foránea, `id_clase`, en lugar de tres.
- Los docentes se asignan a **clases**, no a alumnos uno por uno.
- Mover una clase entera de campus es **un `UPDATE`**, no 15.
- `clase` se convierte en el eje del modelo: todo lo organizativo pasa por ella.

<br>

### 2 · Catálogos como tablas, no como texto

`especialidad`, `promo` y `campus` podrían haber sido simples columnas de texto, o un tipo `ENUM`. Se descartaron ambas opciones.

El enunciado exigía que la base de datos **pudiera crecer** en campus, verticales, promociones y modalidades. Con texto libre aparecen `"Madrid"`, `"madrid"` y `"MADRID"` como valores distintos; con `ENUM`, añadir un campus obliga a un `ALTER TYPE`, es decir, a una migración de esquema.

Como tablas, un campus nuevo es **un `INSERT`**:

```sql
INSERT INTO campus (nombre) VALUES ('Bilbao');
```

<br>

### 3 · `fecha_comienzo` vive en `promo`

En el CSV, `Fecha_comienzo` estaba junto a cada alumno. Pero la fecha no depende del alumno: depende de **su promoción**.

```mermaid
flowchart LR
    A[alumno] -->|depende de| P[promoción] -->|depende de| F[fecha_comienzo]
    style A fill:#4a90d9,color:#fff
    style P fill:#f5a623,color:#fff
    style F fill:#d0021b,color:#fff
```

> **Dependencia transitiva:** alumno → promoción → fecha_comienzo.
> La 3FN exige eliminarla. La fecha se guarda **una sola vez** en `promo`.

<br>

### 4 · De columnas a filas: la tabla `hace`

Las 5 columnas `Proyecto_HLF`, `Proyecto_EDA`, `Proyecto_BBDD`, `Proyecto_ML`, `Proyecto_Deployment` son un **grupo repetido**, lo que incumple la 1FN.

Además tenían un defecto de diseño grave: **añadir un sexto proyecto exigiría añadir una columna**, y reescribir todas las consultas.

La solución fue girar esa información 90°. Cada celda pasa a ser una fila:

```mermaid
flowchart TD
    subgraph "❌ ANTES — columnas fijas"
        T1["| Alumno | Proyecto_HLF | Proyecto_EDA | Proyecto_BBDD | Proyecto_ML | Proyecto_Deploy |"]
    end

    subgraph "✅ DESPUÉS — filas dinámicas en hace"
        T2["| id_alumno | id_proyecto | apto |
        | 1 | HLF | Apto |
        | 1 | EDA | No Apto |
        | 1 | BBDD | Apto |
        | ... | ... | ... |"]
    end

    T1 -->|"Normalización 1FN"| T2
```

52 alumnos × 5 proyectos = **260 filas** en `hace`. Ahora un proyecto nuevo es un `INSERT`, no un `ALTER TABLE`.

La clave primaria es **compuesta** — `(id_proyecto, id_alumno)` — lo que garantiza por diseño que un alumno no pueda tener dos calificaciones del mismo proyecto.

<br>

### 5 · `apto` pertenece a la relación, no al alumno

Consecuencia directa de la anterior, y la justificación de 2FN del modelo.

La calificación no es un atributo del alumno ni del proyecto: **solo existe cuando se juntan los dos**. «Apto» no significa nada sin saber *apto en qué*.

```mermaid
flowchart LR
    A[alumno] --- H{hace}
    P[proyecto] --- H
    H -->|apto| R["Apto / No Apto"]
    style H fill:#f5a623,color:#fff
    style R fill:#7ed321,color:#fff
```

> `apto` depende de la clave compuesta `(id_alumno, id_proyecto)` **completa** — no de una parte. Eso es exactamente lo que exige la **2FN**.

<br>

### 6 · `proyecto` pertenece a una especialidad

Los proyectos no son comunes a toda la escuela:

| Especialidad | Proyectos |
|:---|:---|
| **DS** | HLF · EDA · BBDD · ML · Deployment |
| **FS** | WebDev · FrontEnd · Backend · React · FullSatck |

Por eso `proyecto` lleva `id_especialidad`. Esto documenta el currículo de cada vertical dentro del propio esquema y permite detectar incoherencias, como una calificación de un proyecto de DS asignada a un alumno de FS.

<br>

### 7 · `rol` y `modalidad` describen la asignación, no al docente

La segunda relación N:M del modelo, y la decisión más sutil.

Un docente aparece en los datos con un rol (**TA** o **LI**) y una modalidad (**Presencial** u **Online**). La tentación es guardarlos en `docente`. El modelo los pone en `asignado`, la tabla que une docente y clase.

El motivo: esos valores describen **cómo participa un docente en una clase concreta**, no cómo es el docente.

```mermaid
flowchart LR
    D[docente] --- AS{asignado}
    CL[clase] --- AS
    AS -->|rol| R["TA / LI"]
    AS -->|modalidad| M["Presencial / Online"]
    style AS fill:#f5a623,color:#fff
```

Puestos en `asignado`, el mismo docente puede ser TA presencial en una clase y LI online en otra, sin duplicar su ficha.

> En los datos actuales cada docente aparece en una sola clase, así que esta flexibilidad aún no se usa. Es una decisión deliberada de diseño para que el modelo no tenga que rehacerse cuando ocurra.

<br>

### Las relaciones

```
  especialidad ──┐                        ┌──→ proyecto
                 │                        │       ▲
      promo ─────┼──→  clase  ──→  alumno │       │
                 │       │           │    │     hace
     campus ─────┘       │           └────┴──→ (apto)
                         │
                     asignado  ──→  docente
                  (rol, modalidad)
```

| Relación | Tipo | Lectura |
|:---|:---:|:---|
| `especialidad` → `clase` | 1:N | Una especialidad se imparte en muchas clases |
| `promo` → `clase` | 1:N | Una promoción agrupa varias clases |
| `campus` → `clase` | 1:N | Un campus alberga varias clases |
| `clase` → `alumno` | 1:N | Una clase tiene muchos alumnos; cada alumno, una sola clase |
| `especialidad` → `proyecto` | 1:N | Cada proyecto pertenece a una especialidad |
| `alumno` ↔ `proyecto` | **N:M** | Vía `hace`. Un alumno hace varios proyectos; un proyecto lo hacen varios alumnos. El atributo de la relación es `apto` |
| `docente` ↔ `clase` | **N:M** | Vía `asignado`. Un docente puede dar varias clases; una clase tiene varios docentes. Los atributos son `rol` y `modalidad` |

**Resultado:** 4 catálogos + 3 entidades + 2 tablas de relación = **9 tablas en 3FN**, sin un solo dato repetido.

<br>

---

<details>
<summary><h2>Data modeling decisions</h2><i>English version — click to expand</i></summary>

<br>

> This was the **first** phase of the project and the one that shaped everything else:
> the scripts, the queries and the scalability all follow from here.

### The starting point

The input data was **a single flat table**, one row per student:

| Nombre | Email | Promoción | Fecha_comienzo | Campus | Proyecto_HLF | Proyecto_EDA | … |
|---|---|---|---|---|---|---|---|
| Jafet Casals | Jafet_Casals@gmail.com | Septiembre | 18/09/2023 | Madrid | Apto | No Apto | … |
| Jorge Manzanares | Jorge_Manzanares@gmail.com | Septiembre | 18/09/2023 | Madrid | Apto | No Apto | … |

Three obvious problems:

1. **Redundancy.** `Septiembre`, `18/09/2023` and `Madrid` repeat on all 52 rows.
2. **Repeating groups.** The five `Proyecto_*` columns are the same piece of information five times over.
3. **Update anomalies.** Fixing one promotion's start date would mean editing dozens of rows, and missing one would leave the database inconsistent.

From there, seven decisions followed.

### Overview of the model

```mermaid
erDiagram
    ESPECIALIDAD ||--o{ CLASE : "1:N"
    PROMO ||--o{ CLASE : "1:N"
    CAMPUS ||--o{ CLASE : "1:N"
    CLASE ||--o{ ALUMNO : "1:N"
    ESPECIALIDAD ||--o{ PROYECTO : "1:N"
    ALUMNO }o--o{ PROYECTO : "N:M via hace"
    DOCENTE }o--o{ CLASE : "N:M via asignado"

    ESPECIALIDAD { varchar nombre }
    PROMO { varchar nombre___ date fecha_comienzo }
    CAMPUS { varchar nombre }
    CLASE { int id_especialidad_FK int id_promo_FK int id_campus_FK }
    ALUMNO { varchar nombre varchar email int id_clase_FK }
    PROYECTO { varchar nombre int id_especialidad_FK }
    DOCENTE { varchar nombre }
    HACE { int id_alumno_PK_FK int id_proyecto_PK_FK varchar apto }
    ASIGNADO { int id_clase_PK_FK int id_docente_PK_FK varchar rol varchar modalidad }
```

<br>

### 1 · `clase` as the central entity

The single most important decision in the model.

In the raw data, every student carried their own **specialty**, **promotion** and **campus**. But those three values don't describe the student independently — what actually identifies a student is **the group they belong to**, and that group *is* the combination of the three.

So instead of putting three foreign keys on `alumno`, we created `clase`:

```mermaid
flowchart LR
    subgraph "❌ Without clase — 3 FKs on student"
        A1[student] -->|id_especialidad| E1[specialty]
        A1 -->|id_promo| P1[promotion]
        A1 -->|id_campus| C1[campus]
    end
```

```mermaid
flowchart LR
    subgraph "✅ With clase — 1 FK on student"
        E2[specialty] --> CL[clase]
        P2[promotion] --> CL
        C2[campus] --> CL
        CL -->|id_clase| A2[student]
    end
```

Consequences:

- `alumno` holds **one** foreign key, `id_clase`, instead of three.
- Teachers are assigned to **classes**, not to students one by one.
- Moving a whole class to another campus is **one `UPDATE`**, not 15.
- `clase` becomes the hub of the model: everything organizational routes through it.

<br>

### 2 · Catalogs as tables, not as text

`especialidad`, `promo` and `campus` could have been plain text columns, or an `ENUM` type. Both were rejected.

The brief required the database to **be able to grow** in campuses, verticals, promotions and modalities. With free text you end up with `"Madrid"`, `"madrid"` and `"MADRID"` as three distinct values; with `ENUM`, adding a campus requires an `ALTER TYPE` — a schema migration.

As tables, a new campus is **one `INSERT`**:

```sql
INSERT INTO campus (nombre) VALUES ('Bilbao');
```

<br>

### 3 · `fecha_comienzo` lives in `promo`

In the CSV, `Fecha_comienzo` sat next to every student. But the date doesn't depend on the student — it depends on **their promotion**.

```mermaid
flowchart LR
    A[student] -->|depends on| P[promotion] -->|depends on| F[start date]
    style A fill:#4a90d9,color:#fff
    style P fill:#f5a623,color:#fff
    style F fill:#d0021b,color:#fff
```

> **Transitive dependency:** student → promotion → start date.
> 3NF requires eliminating it. The date is stored **once** in `promo`.

<br>

### 4 · From columns to rows: the `hace` table

The five columns `Proyecto_HLF`, `Proyecto_EDA`, `Proyecto_BBDD`, `Proyecto_ML`, `Proyecto_Deployment` are a **repeating group**, which breaks 1NF.

They also had a serious design flaw: **adding a sixth project would mean adding a column**, and rewriting every query against the table.

The fix was to rotate that information 90°. Each cell becomes a row:

```mermaid
flowchart TD
    subgraph "❌ BEFORE — fixed columns"
        T1["| Student | Proyecto_HLF | Proyecto_EDA | Proyecto_BBDD | Proyecto_ML | Proyecto_Deploy |"]
    end

    subgraph "✅ AFTER — dynamic rows in hace"
        T2["| id_alumno | id_proyecto | apto |
        | 1 | HLF | Apto |
        | 1 | EDA | No Apto |
        | 1 | BBDD | Apto |
        | ... | ... | ... |"]
    end

    T1 -->|"1NF normalization"| T2
```

52 students × 5 projects = **260 rows** in `hace`. A new project is now an `INSERT`, not an `ALTER TABLE`.

The primary key is **composite** — `(id_proyecto, id_alumno)` — which guarantees by design that a student cannot hold two grades for the same project.

<br>

### 5 · `apto` belongs to the relationship, not to the student

A direct consequence of the previous decision, and the model's 2NF justification.

The grade is not an attribute of the student, nor of the project: **it only exists when the two meet**. "Pass" means nothing without knowing *pass at what*.

```mermaid
flowchart LR
    A[student] --- H{hace}
    P[project] --- H
    H -->|apto| R["Pass / Fail"]
    style H fill:#f5a623,color:#fff
    style R fill:#7ed321,color:#fff
```

> `apto` depends on the composite key `(id_alumno, id_proyecto)` **in full** — not on either part alone. That is precisely what **2NF** requires.

<br>

### 6 · `proyecto` belongs to a specialty

Projects are not shared across the whole school:

| Specialty | Projects |
|:---|:---|
| **DS** | HLF · EDA · BBDD · ML · Deployment |
| **FS** | WebDev · FrontEnd · Backend · React · FullSatck |

Hence `proyecto` carries `id_especialidad`. This documents each vertical's curriculum inside the schema itself and makes it possible to catch inconsistencies, such as a DS project grade attached to an FS student.

<br>

### 7 · `rol` and `modalidad` describe the assignment, not the teacher

The model's second N:M relationship, and the subtlest decision.

A teacher appears in the data with a role (**TA** or **LI**) and a modality (**on-site** or **online**). The temptation is to store them on `docente`. The model puts them on `asignado`, the table joining teacher and class.

The reason: those values describe **how a teacher participates in one particular class**, not what the teacher is.

```mermaid
flowchart LR
    D[teacher] --- AS{asignado}
    CL[class] --- AS
    AS -->|role| R["TA / LI"]
    AS -->|modality| M["On-site / Online"]
    style AS fill:#f5a623,color:#fff
```

Placed on `asignado`, the same teacher can be an on-site TA in one class and an online LI in another, without duplicating their record.

> In the current data each teacher appears in only one class, so this flexibility isn't exercised yet. It is a deliberate design choice so the model won't need reworking when it is.

<br>

### The relationships

```
    specialty ────┐                        ┌──→ project
                  │                        │       ▲
    promotion ────┼──→  class  ──→ student │       │
                  │       │           │    │     hace
       campus ────┘       │           └────┴──→ (pass)
                          │
                      asignado  ──→  teacher
                   (role, modality)
```

| Relationship | Type | Reading |
|:---|:---:|:---|
| `especialidad` → `clase` | 1:N | One specialty is taught in many classes |
| `promo` → `clase` | 1:N | One promotion groups several classes |
| `campus` → `clase` | 1:N | One campus hosts several classes |
| `clase` → `alumno` | 1:N | A class has many students; each student has exactly one class |
| `especialidad` → `proyecto` | 1:N | Each project belongs to one specialty |
| `alumno` ↔ `proyecto` | **N:M** | Via `hace`. A student does several projects; a project is done by several students. The relationship attribute is `apto` |
| `docente` ↔ `clase` | **N:M** | Via `asignado`. A teacher can teach several classes; a class has several teachers. The attributes are `rol` and `modalidad` |

**Result:** 4 catalogs + 3 entities + 2 relationship tables = **9 tables in 3NF**, with no duplicated data.

</details>

---

## Estructura del repositorio

```
proyectoSQL/
│
├── sql/                        Scripts SQL
│   ├── create_tables.sql         → 9 tablas + claves foráneas
│   ├── insert_data.sql           → carga completa de datos
│   └── demo_queries.sql          → 5 consultas de demostración
│
├── scripts/
│   └── upload_to_render.ps1    Despliegue automático a Render
│
├── imagenes/
│   ├── Diagrama_ER.png         Modelo Entidad-Relación
│   ├── Diagrama_ML.png         Modelo Lógico
│   └── demos/                  Capturas de las consultas
│
├── docs/
│   └── Proyecto BBDD.pptx      Presentación técnica
│
├── bugfix/
│   └── README.md               Errores encontrados y cómo se resolvieron
│
├── requirements.md             Enunciado del proyecto
└── README.md
```

---

## Diagramas

### Modelo Entidad-Relación (E/R)

<div align="center">

![Diagrama E/R](imagenes/Diagrama_ER.png)

</div>

### Modelo Lógico

<div align="center">

![Modelo Lógico](imagenes/Diagrama_ML.png)

</div>

---

## Modelo de datos

**9 tablas** organizadas en tres capas:

| Capa | Tablas | Rol |
|:---|:---|:---|
| **Catálogos** | `especialidad` · `promo` · `campus` · `docente` | Valores maestros, crecen con un `INSERT` |
| **Entidades** | `clase` · `proyecto` · `alumno` | Núcleo del dominio |
| **Relaciones N:M** | `hace` · `asignado` | Unen entidades y guardan el dato de la relación |

### Relaciones clave

```
   especialidad ─┐
       promo ────┼──→  clase  ──→  alumno  ──→  hace  ──→  proyecto
      campus ────┘       │                   (apto)
                         │
                      asignado  ──→  docente
                   (rol, modalidad)
```

| Relación | Une | Atributo propio |
|:---|:---|:---|
| `hace` | alumno × proyecto | `apto` — la calificación (Apto / No Apto) |
| `asignado` | docente × clase | `rol` (TA / LI) y `modalidad` |

---

## Normalización

```mermaid
flowchart LR
    CSV["CSV plano
    52 filas × 12 columnas"]
    -->|"1FN: eliminar
    grupos repetidos"| S1["Columnas Proyecto_*
    → filas en hace"]
    -->|"2FN: dependencia
    de clave completa"| S2["apto depende de
    (alumno + proyecto)"]
    -->|"3FN: eliminar
    transitivas"| S3["fecha_comienzo
    → solo en promo"]
    -->|Resultado| FINAL["9 tablas en 3FN
    sin datos repetidos"]

    style CSV fill:#d0021b,color:#fff
    style FINAL fill:#7ed321,color:#fff
```

<table>
<tr><th width="90">Forma</th><th>Aplicación en este modelo</th></tr>
<tr>
<td align="center"><b>1FN</b></td>
<td>Las columnas <code>Proyecto_HLF</code>, <code>Proyecto_EDA</code>… del CSV original dejan de ser columnas y pasan a ser <b>filas</b> de la tabla <code>hace</code>.</td>
</tr>
<tr>
<td align="center"><b>2FN</b></td>
<td>En las tablas con clave compuesta, cada atributo depende de la <b>clave completa</b>. Ej.: <code>apto</code> depende del alumno <b>y</b> del proyecto, no de uno solo.</td>
</tr>
<tr>
<td align="center"><b>3FN</b></td>
<td>Sin dependencias transitivas. Ej.: <code>fecha_comienzo</code> se guarda una sola vez en <code>promo</code>; el alumno únicamente referencia <code>id_clase</code>.</td>
</tr>
</table>

---

## Datos cargados

### Alumnos por clase

| Especialidad | Promoción | Campus | Alumnos |
|:---|:---|:---|---:|
| DS | Septiembre | Madrid | 15 |
| DS | Febrero | Madrid | 10 |
| FS | Septiembre | Madrid | 14 |
| FS | Febrero | Valencia | 13 |
| | | **Total** | **52** |

### Tasa de aprobados por proyecto

| Proyecto | Especialidad | Aptos | Total | % |
|:---|:---:|---:|---:|---:|
| ML | DS | 22 | 25 | 88.0 |
| Deployment | DS | 22 | 25 | 88.0 |
| HLF | DS | 19 | 25 | 76.0 |
| BBDD | DS | 18 | 25 | 72.0 |
| EDA | DS | 14 | 25 | 56.0 |
| FullSatck | FS | 20 | 27 | 74.1 |
| React | FS | 19 | 27 | 70.4 |
| FrontEnd | FS | 17 | 27 | 63.0 |
| Backend | FS | 17 | 27 | 63.0 |
| WebDev | FS | 16 | 27 | 59.3 |

---

## Puesta en marcha

### Datos de conexión

| Campo | Valor |
|:---|:---|
| **Host** | `dpg-dbi687jbc2fs73a7se4g-a.ohio-postgres.render.com` |
| **Port** | `5432` |
| **Database** | `db_equopo_d_yzob` |
| **Username** | `db_equipo_d` |
| **SSL Mode** | `require` *(obligatorio en Render)* |

<br>

### Opción A — Despliegue automático

Desde la raíz del proyecto, con `psql` instalado:

```powershell
.\scripts\upload_to_render.ps1
```

Crea las 9 tablas y carga todos los datos en un solo paso.
El script pide la contraseña por consola (no se guarda en el repositorio).

<br>

### Opción B — Línea de comandos

```powershell
$env:PGPASSWORD = "<password>"
$env:PGSSLMODE  = "require"

psql -h dpg-dbi687jbc2fs73a7se4g-a.ohio-postgres.render.com -p 5432 `
     -U db_equipo_d -d db_equopo_d_yzob -f sql/create_tables.sql

psql -h dpg-dbi687jbc2fs73a7se4g-a.ohio-postgres.render.com -p 5432 `
     -U db_equipo_d -d db_equopo_d_yzob -f sql/insert_data.sql
```

> [!WARNING]
> En Windows, la forma con URI (`postgresql://usuario:pass@host/db`) hace que `psql`
> **ignore silenciosamente** el flag `-f`. Usar siempre los flags sueltos `-h -p -U -d`.

<br>

### Opción C — pgAdmin

1. Clic derecho en **Servers** → **Register** → **Server**
2. **General** → *Name*: `Render`
3. **Connection** → rellenar con la tabla de conexión de arriba
4. **Parameters** → añadir `SSL mode` = `require`
5. **Save** → navegar a `db_equopo_d_yzob` → **Schemas** → **public** → **Tables**

> [!TIP]
> En *Host name/address* va **solo el hostname**, nunca la URL completa.
> Pegar la URI entera provoca el error `'idna' codec can't encode characters`.

<br>

### Opción D — DBeaver

1. **Database** → **New Database Connection** → **PostgreSQL**
2. Rellenar *Host*, *Port*, *Database*, *Username*, *Password*
3. Pestaña **SSL** → marcar **Use SSL** → *SSL mode*: `require`
4. **Test Connection** → **Finish**

---

## Consultas de demostración

Las 5 consultas están en [`sql/demo_queries.sql`](sql/demo_queries.sql).
En pgAdmin: clic derecho en la base de datos → **Query Tool** → abrir el archivo → **F5**.

<br>

<details>
<summary><b>1 · Alumnos con su clase, especialidad, campus y promoción</b></summary>

```sql
SELECT
    a.nombre AS alumno,
    e.nombre AS especialidad,
    p.nombre AS promocion,
    c.nombre AS campus
FROM alumno a
JOIN clase cl        ON a.id_clase        = cl.id_clase
JOIN especialidad e  ON cl.id_especialidad = e.id_especialidad
JOIN promo p         ON cl.id_promo       = p.id_promo
JOIN campus c        ON cl.id_campus      = c.id_campus
ORDER BY especialidad, campus, alumno;
```

Reconstruye la vista desnormalizada original a partir de las tablas en 3FN.

</details>

<details>
<summary><b>2 · Tasa de aprobados por proyecto</b></summary>

```sql
SELECT
    pr.nombre AS proyecto,
    e.nombre  AS especialidad,
    COUNT(*)  AS total,
    SUM(CASE WHEN h.apto = 'Apto' THEN 1 ELSE 0 END) AS aptos,
    ROUND(
        SUM(CASE WHEN h.apto = 'Apto' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1
    ) AS pct_aptos
FROM hace h
JOIN proyecto pr     ON h.id_proyecto      = pr.id_proyecto
JOIN especialidad e  ON pr.id_especialidad = e.id_especialidad
GROUP BY pr.nombre, e.nombre
ORDER BY especialidad, proyecto;
```

Agregación sobre la relación N:M con porcentaje calculado.

</details>

<details>
<summary><b>3 · Alumnos con al menos un proyecto no apto</b></summary>

```sql
SELECT DISTINCT
    a.nombre AS alumno,
    e.nombre AS especialidad
FROM hace h
JOIN alumno a        ON h.id_alumno       = a.id_alumno
JOIN clase cl        ON a.id_clase        = cl.id_clase
JOIN especialidad e  ON cl.id_especialidad = e.id_especialidad
WHERE h.apto = 'No Apto'
ORDER BY especialidad, alumno;
```

Filtrado sobre el atributo de la relación, con `DISTINCT` para no repetir alumnos.

</details>

<details>
<summary><b>4 · Docentes por clase con rol y modalidad</b></summary>

```sql
SELECT
    d.nombre AS docente,
    e.nombre AS especialidad,
    p.nombre AS promocion,
    c.nombre AS campus,
    a.rol,
    a.modalidad
FROM asignado a
JOIN docente d       ON a.id_docente      = d.id_docente
JOIN clase cl        ON a.id_clase        = cl.id_clase
JOIN especialidad e  ON cl.id_especialidad = e.id_especialidad
JOIN promo p         ON cl.id_promo       = p.id_promo
JOIN campus c        ON cl.id_campus      = c.id_campus
ORDER BY especialidad, campus;
```

Recorre la segunda relación N:M y sus atributos propios.

</details>

<details>
<summary><b>5 · Número de alumnos por clase</b></summary>

```sql
SELECT
    e.nombre AS especialidad,
    p.nombre AS promocion,
    c.nombre AS campus,
    COUNT(a.id_alumno) AS num_alumnos
FROM clase cl
JOIN especialidad e  ON cl.id_especialidad = e.id_especialidad
JOIN promo p         ON cl.id_promo       = p.id_promo
JOIN campus c        ON cl.id_campus      = c.id_campus
LEFT JOIN alumno a   ON a.id_clase        = cl.id_clase
GROUP BY e.nombre, p.nombre, c.nombre
ORDER BY especialidad, campus;
```

`LEFT JOIN` para que una clase recién creada y aún sin alumnos aparezca con `0`.

</details>

<br>

### Resultados

<div align="center">

![Demo 1](imagenes/demos/demostracion1.png)

![Demo 2](imagenes/demos/demostracion2.png)

![Demo 3](imagenes/demos/demostracion3.png)

</div>

---

## Escalabilidad

> Todo lo que puede crecer es un **dato**, no una columna.

Un campus, una especialidad, una promoción o un docente nuevos se añaden con un `INSERT`,
sin tocar la estructura ni migrar nada:

```sql
INSERT INTO campus       (nombre) VALUES ('Bilbao');
INSERT INTO especialidad (nombre) VALUES ('Ciberseguridad');
INSERT INTO promo        (nombre, fecha_comienzo) VALUES ('Octubre', '2026-10-01');
```

Una clase nueva es simplemente una combinación de los tres:

```sql
INSERT INTO clase (id_especialidad, id_promo, id_campus) VALUES (3, 3, 3);
```

| Dimensión | Crece con | Cambios de esquema |
|:---|:---|:---:|
| Campus | `INSERT INTO campus` | ninguno |
| Especialidad / vertical | `INSERT INTO especialidad` | ninguno |
| Promoción | `INSERT INTO promo` | ninguno |
| Modalidad | columna en `asignado` | ninguno |
| Aulas | `INSERT INTO clase` | ninguno |

---

<div align="center">

### Tecnologías

**PostgreSQL** · **Render** · **pgAdmin 4** · **DBeaver** · **draw.io** · **Python (pandas)**

</div>

---

## Equipo D

| Nombre | Vertical |
|:---|:---:|
| Isaías | DS |
| Maxi | DS |
| Sheila | DS |
| Arman | DS |
| Daniel Xabier Lopez Garcia | FS |
| Yosra Ben-Messoud Tarfous | FS |
