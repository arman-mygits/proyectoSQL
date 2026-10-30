-- Demo queries for db_equopo_d
-- Run after create_tables.sql and insert_data.sql

-- 1. All students with their class, specialty, campus and promotion
SELECT
    a.nombre AS alumno,
    e.nombre AS especialidad,
    p.nombre AS promocion,
    c.nombre AS campus
FROM alumno a
JOIN clase cl ON a.id_clase = cl.id_clase
JOIN especialidad e ON cl.id_especialidad = e.id_especialidad
JOIN promo p ON cl.id_promo = p.id_promo
JOIN campus c ON cl.id_campus = c.id_campus
ORDER BY especialidad, campus, alumno;

-- 2. Pass rate per project
SELECT
    pr.nombre AS proyecto,
    e.nombre AS especialidad,
    COUNT(*) AS total,
    SUM(CASE WHEN h.apto = 'Apto' THEN 1 ELSE 0 END) AS aptos,
    ROUND(
        SUM(CASE WHEN h.apto = 'Apto' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1
    ) AS pct_aptos
FROM hace h
JOIN proyecto pr ON h.id_proyecto = pr.id_proyecto
JOIN especialidad e ON pr.id_especialidad = e.id_especialidad
GROUP BY pr.nombre, e.nombre
ORDER BY especialidad, proyecto;

-- 3. Students who failed at least one project
SELECT DISTINCT
    a.nombre AS alumno,
    e.nombre AS especialidad
FROM hace h
JOIN alumno a ON h.id_alumno = a.id_alumno
JOIN clase cl ON a.id_clase = cl.id_clase
JOIN especialidad e ON cl.id_especialidad = e.id_especialidad
WHERE h.apto = 'No Apto'
ORDER BY especialidad, alumno;

-- 4. Teachers per class with their role and modality
SELECT
    d.nombre AS docente,
    e.nombre AS especialidad,
    p.nombre AS promocion,
    c.nombre AS campus,
    a.rol,
    a.modalidad
FROM asignado a
JOIN docente d ON a.id_docente = d.id_docente
JOIN clase cl ON a.id_clase = cl.id_clase
JOIN especialidad e ON cl.id_especialidad = e.id_especialidad
JOIN promo p ON cl.id_promo = p.id_promo
JOIN campus c ON cl.id_campus = c.id_campus
ORDER BY especialidad, campus;

-- 5. Number of students per class
SELECT
    e.nombre AS especialidad,
    p.nombre AS promocion,
    c.nombre AS campus,
    COUNT(a.id_alumno) AS num_alumnos
FROM clase cl
JOIN especialidad e ON cl.id_especialidad = e.id_especialidad
JOIN promo p ON cl.id_promo = p.id_promo
JOIN campus c ON cl.id_campus = c.id_campus
LEFT JOIN alumno a ON a.id_clase = cl.id_clase
GROUP BY e.nombre, p.nombre, c.nombre
ORDER BY especialidad, campus;

-- 6. Students who passed ALL their projects (perfect record)
SELECT
    a.nombre AS alumno,
    e.nombre AS especialidad
FROM alumno a
JOIN clase cl ON a.id_clase = cl.id_clase
JOIN especialidad e ON cl.id_especialidad = e.id_especialidad
WHERE NOT EXISTS (
    SELECT 1 FROM hace h
    WHERE h.id_alumno = a.id_alumno
    AND h.apto = 'No Apto'
)
ORDER BY especialidad, alumno;

-- 7. Most failed project per specialty
SELECT DISTINCT ON (especialidad)
    e.nombre AS especialidad,
    pr.nombre AS proyecto,
    SUM(CASE WHEN h.apto = 'No Apto' THEN 1 ELSE 0 END) AS suspensos
FROM hace h
JOIN proyecto pr ON h.id_proyecto = pr.id_proyecto
JOIN especialidad e ON pr.id_especialidad = e.id_especialidad
GROUP BY e.nombre, pr.nombre
ORDER BY especialidad, suspensos DESC;

-- 8. How many projects each student failed (only those who failed at least one)
SELECT
    a.nombre AS alumno,
    e.nombre AS especialidad,
    COUNT(*) AS proyectos_suspendidos
FROM hace h
JOIN alumno a ON h.id_alumno = a.id_alumno
JOIN clase cl ON a.id_clase = cl.id_clase
JOIN especialidad e ON cl.id_especialidad = e.id_especialidad
WHERE h.apto = 'No Apto'
GROUP BY a.nombre, e.nombre
ORDER BY proyectos_suspendidos DESC, alumno;

-- 9. Classes with no Lead Instructor (LI) assigned
SELECT
    cl.id_clase,
    e.nombre AS especialidad,
    p.nombre AS promocion,
    c.nombre AS campus
FROM clase cl
JOIN especialidad e ON cl.id_especialidad = e.id_especialidad
JOIN promo p ON cl.id_promo = p.id_promo
JOIN campus c ON cl.id_campus = c.id_campus
WHERE NOT EXISTS (
    SELECT 1 FROM asignado a
    WHERE a.id_clase = cl.id_clase
    AND a.rol = 'LI'
)
ORDER BY especialidad;

-- 10. Full report card: every student with every project result in one view
SELECT
    a.nombre AS alumno,
    c.nombre AS campus,
    p.nombre AS promocion,
    pr.nombre AS proyecto,
    h.apto AS resultado
FROM alumno a
JOIN clase cl ON a.id_clase = cl.id_clase
JOIN campus c ON cl.id_campus = c.id_campus
JOIN promo p ON cl.id_promo = p.id_promo
JOIN hace h ON h.id_alumno = a.id_alumno
JOIN proyecto pr ON h.id_proyecto = pr.id_proyecto
ORDER BY alumno, proyecto;
