$root = Split-Path $PSScriptRoot -Parent

$pgHost = "dpg-dbi687jbc2fs73a7se4g-a.ohio-postgres.render.com"
$port   = "5432"
$user   = "db_equipo_d"
$dbname = "db_equopo_d_yzob"

if (-not $env:PGPASSWORD) {
    $secure = Read-Host "Password de la base de datos" -AsSecureString
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    )
}
$env:PGSSLMODE = "require"

Write-Host "Creating tables..." -ForegroundColor Cyan
psql -h $pgHost -p $port -U $user -d $dbname -f "$root\sql\create_tables.sql"

Write-Host "Inserting data..." -ForegroundColor Cyan
psql -h $pgHost -p $port -U $user -d $dbname -f "$root\sql\insert_data.sql"

Write-Host "Done!" -ForegroundColor Green
