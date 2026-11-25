# Instala la carga diaria del dolar divisa BNA en un servidor que quede siempre prendido.
# Ejecutar como administrador en el servidor:
#   powershell -ExecutionPolicy Bypass -File .\instalar_en_servidor.ps1
# Con -SoloVerificar revisa los requisitos sin copiar ni crear nada.
param(
    [string]$Destino = 'C:\Scripts\dolar_divisa_bna',
    [switch]$SoloVerificar
)
$ErrorActionPreference = 'Stop'
$ps32 = "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
$nombreTarea = 'Dolar divisa BNA a caja_cambio'
$ok = $true
function Check($desc, [scriptblock]$prueba) {
    try { $r = & $prueba; Write-Host "[OK]    $desc $r" -ForegroundColor Green }
    catch { Write-Host "[FALLA] $desc - $($_.Exception.Message)" -ForegroundColor Red; $script:ok = $false }
}

Check 'Salida a internet hacia www.bna.com.ar' {
    $html = (Invoke-WebRequest -Uri 'https://www.bna.com.ar/Personas' -UseBasicParsing -UserAgent 'Mozilla/5.0' -TimeoutSec 30).Content
    if ($html -notmatch 'id="divisas"') { throw 'La pagina no tiene la seccion de divisas' }
}

Check 'DSN de sistema LodiserIA con usuario y contrasena guardados' {
    # Get-OdbcDsn no muestra UID/PWD, por eso se lee el registro (DSN de sistema de 32 bits o compartido 32/64)
    $clave = 'HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBC.INI\LodiserIA', 'HKLM:\SOFTWARE\ODBC\ODBC.INI\LodiserIA' |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $clave) { throw 'No existe como DSN de sistema. Crearlo con C:\Windows\SysWOW64\odbcad32.exe, pestana DSN de sistema' }
    $props = (Get-ItemProperty $clave).PSObject.Properties.Name
    if (-not ($props | Where-Object { $_ -match '^(UID|UserID)$' })) { throw 'El DSN no tiene el usuario guardado' }
    if (-not ($props | Where-Object { $_ -match '^(PWD|Password|ENP|EncryptedPassword)$' })) { throw 'El DSN no tiene la contrasena guardada' }
}

Check 'Conexion a la base con permisos sobre usuarios.caja_cambio' {
    $out = & $ps32 -NoProfile -Command "try { `$cn = New-Object System.Data.Odbc.OdbcConnection 'DSN=LodiserIA'; `$cn.Open(); `$c = `$cn.CreateCommand(); `$c.CommandText = 'select current user, (select count(*) from usuarios.caja_cambio where moneda = ''DIV'')'; `$r = `$c.ExecuteReader(); [void]`$r.Read(); 'OK usuario=' + `$r[0]; `$cn.Close() } catch { 'ERR ' + `$_.Exception.Message }"
    if ($out -notmatch '^OK') { throw $out }
    "($($out -replace '^OK ', ''))"
}

if (-not $ok) { Write-Host "`nHay requisitos que fallan. Corregirlos y volver a ejecutar." -ForegroundColor Yellow; exit 1 }
if ($SoloVerificar) { Write-Host "`nTodo listo para instalar." -ForegroundColor Green; exit 0 }

New-Item -ItemType Directory -Force -Path $Destino | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'cargar_dolar_divisa.ps1') -Destination $Destino -Force
$script = Join-Path $Destino 'cargar_dolar_divisa.ps1'

# Corre como SYSTEM: no depende de que alguien tenga la sesion iniciada ni de contrasenas que venzan
$action = New-ScheduledTaskAction -Execute $ps32 -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 15:30
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $nombreTarea -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force `
    -Description 'Inserta el dolar divisa venta de BNA en usuarios.caja_cambio (Lodiser), moneda DIV' | Out-Null

Write-Host "`nInstalado en $Destino. Proxima ejecucion: $((Get-ScheduledTask -TaskName $nombreTarea | Get-ScheduledTaskInfo).NextRunTime)" -ForegroundColor Green
Write-Host "Log: $(Join-Path $Destino 'cargar_dolar_divisa.log')"
Write-Host "Acordate de deshabilitar la tarea '$nombreTarea' en tu notebook para que no corran las dos." -ForegroundColor Yellow
