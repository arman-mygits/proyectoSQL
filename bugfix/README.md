# Bugfix — Conexión y carga en Render

Registro de los errores encontrados al desplegar la base de datos en Render
y cómo se resolvió cada uno.

---

## Resumen

| # | Error | Causa | Solución |
|:--:|:---|:---|:---|
| 1 | `psql no se reconoce...` | PostgreSQL no instalado / no en el PATH | Instalar *Command Line Tools* y añadir `bin` al PATH |
| 2 | `running scripts is disabled` | Política de ejecución de PowerShell | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| 3 | `extra command-line argument ignored` | Forma URI en Windows | Usar flags sueltos `-h -p -U -d` |
| 4 | `server closed the connection unexpectedly` | Render exige SSL | `$env:PGSSLMODE = "require"` |
| 5 | `'idna' codec can't encode characters` | URL completa en el campo *Host* de pgAdmin | Poner **solo** el hostname |
| 6 | `password authentication failed for user "postgres"` | DBeaver con valores por defecto | Reemplazar `localhost` / `postgres` por los de Render |
| 7 | `No such file or directory` | Carpeta `sql/` anidada dentro de `scripts/` | Mover `sql/` a la raíz del proyecto |

---

## 1 · `psql` no se reconoce

```
psql : The term 'psql' is not recognized as the name of a cmdlet...
```

**Causa.** pgAdmin incluye su propio `psql` interno, pero no lo expone en el PATH.
Tener pgAdmin instalado **no** significa tener `psql` disponible en la terminal.

**Solución.** Instalar PostgreSQL desde [postgresql.org](https://www.postgresql.org/download/windows/)
marcando *Command Line Tools*, y añadir la carpeta `bin` al PATH:

```powershell
$env:PATH += ";C:\Program Files\PostgreSQL\16\bin"
```

> Esto solo dura la sesión actual. Para que sea permanente, añadirlo en
> *Variables de entorno* de Windows.

---

## 2 · PowerShell bloquea el script

```
.\upload_to_render.ps1 : File ... cannot be loaded because running scripts
is disabled on this system.
```

**Causa.** Por defecto Windows no permite ejecutar scripts `.ps1`.

**Solución.**

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

---

## 3 · `psql` ignora el flag `-f`

```
psql: warning: extra command-line argument "sql/create_tables.sql" ignored
```

**Causa.** Al pasar la cadena de conexión como URI:

```powershell
psql "postgresql://user:pass@host:5432/db" -f sql/create_tables.sql
```

`psql` en Windows **descarta silenciosamente** el `-f`. Se conecta, no ejecuta
nada, y termina sin avisar de que el archivo no se ha cargado.

**Solución.** Usar los flags sueltos:

```powershell
psql -h <host> -p 5432 -U <user> -d <db> -f sql/create_tables.sql
```

> Este fue el error más engañoso: el script decía `Done!` en verde
> aunque no se hubiese ejecutado ni una sola sentencia.

---

## 4 · Render cierra la conexión

```
psql: error: connection to server at "dpg-...ohio-postgres.render.com"
(3.143.61.25), port 5432 failed: server closed the connection unexpectedly
```

**Causa.** Render **obliga** a usar SSL en las conexiones externas.
Sin SSL, el servidor acepta el TCP y cierra inmediatamente.

**Solución.**

```powershell
$env:PGSSLMODE = "require"
```

Verificación de que funciona:

```powershell
psql -h <host> -p 5432 -U <user> -d <db> -c "SELECT version();"
```

```
PostgreSQL 18.6 (Debian 18.6-1.pgdg12+2) on x86_64-pc-linux-gnu
```

---

## 5 · pgAdmin — error de codec

```
'idna' codec can't encode characters in position 0-83: label too long
```

**Causa.** Se pegó la URL completa (`postgresql://user:pass@host/db`)
en el campo *Host name/address*.

**Solución.** Ese campo admite **solo el hostname**:

```
dpg-dbi687jbc2fs73a7se4g-a.ohio-postgres.render.com
```

Usuario, contraseña y base de datos van en sus propios campos.

---

## 6 · DBeaver — autenticación fallida

```
FATAL: password authentication failed for user "postgres"
```

**Causa.** DBeaver trae `localhost` y `postgres` por defecto. Si no se
reemplazan, intenta conectar a un PostgreSQL local, no a Render.

**Solución.** Sustituir **los cuatro campos** por los de Render y, en la
pestaña **SSL**, marcar *Use SSL* con *SSL mode* = `require`.

---

## 7 · Rutas rotas tras reorganizar

```
psql: error: .../sql/create_tables.sql: No such file or directory
```

**Causa.** Al reorganizar el repositorio, `sql/` quedó anidada dentro de
`scripts/`, mientras el script la buscaba en la raíz.

**Solución.** Mover la carpeta a la raíz y resolver las rutas desde la
ubicación del script, no desde el directorio actual:

```powershell
$root = Split-Path $PSScriptRoot -Parent
psql ... -f "$root\sql\create_tables.sql"
```

> Así el script funciona igual tanto si se ejecuta desde la raíz
> como desde `scripts/`.

---

## Resultado final

```
BEGIN
CREATE TABLE  ×9
ALTER TABLE   ×9
COMMIT

BEGIN
INSERT 0 2    especialidad
INSERT 0 2    promo
INSERT 0 2    campus
INSERT 0 10   docente
INSERT 0 4    clase
INSERT 0 10   proyecto
INSERT 0 52   alumno
INSERT 0 8    asignado
INSERT 0 260  hace
COMMIT
```

Verificación:

```sql
SELECT COUNT(*) FROM alumno;   -- 52
SELECT COUNT(*) FROM hace;     -- 260
```

---

## Nota de seguridad

La contraseña estaba **escrita en texto plano** dentro de
`scripts/upload_to_render.ps1`, y este repositorio tiene remoto en GitHub.
Subirlo así habría publicado las credenciales.

El script ahora pide la contraseña por consola o la lee de `$env:PGPASSWORD`.
Nunca commitear credenciales.
