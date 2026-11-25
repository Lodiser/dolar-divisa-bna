# Toma el Dolar U.S.A divisa (venta) de BNA y lo inserta en usuarios.caja_cambio (base Lodiser) con moneda 'DIV'.
# Se conecta con el DSN LodiserIA (usuario ia). Corre con PowerShell de 32 bits.
$ErrorActionPreference = 'Stop'
$log = Join-Path $PSScriptRoot 'cargar_dolar_divisa.log'
function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Out-File -FilePath $log -Append -Encoding UTF8 }

try {
    $hoy = (Get-Date).Date
    $html = (Invoke-WebRequest -Uri 'https://www.bna.com.ar/Personas' -UseBasicParsing -UserAgent 'Mozilla/5.0').Content

    $seccion = ($html -split 'id="divisas"')[1]
    $fechaPagina = [regex]::Match($seccion, 'class="fechaCot">([^<]+)<').Groups[1].Value.Trim()
    $m = [regex]::Match($seccion, 'Dolar U\.S\.A</td>\s*<td>([\d.]+)</td>\s*<td>([\d.]+)</td>')
    if (-not $m.Success) { throw 'No se encontro el dolar divisa en la pagina de BNA' }
    $venta = [decimal]::Parse($m.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)

    # Feriados: BNA sigue mostrando la cotizacion del ultimo dia habil.
    # BNA escribe los dias de un digito sin cero (2/11/2026), por eso se compara como fecha y no como texto.
    $dia, $mes, $anio = $fechaPagina.Split('/') | ForEach-Object { [int]$_ }
    $fechaCot = New-Object datetime $anio, $mes, $dia
    if ($fechaCot -ne $hoy) {
        Log "Sin cotizacion de hoy (BNA muestra $fechaPagina). No se inserta."
        exit 0
    }

    $cn = New-Object System.Data.Odbc.OdbcConnection 'DSN=LodiserIA'
    $cn.Open()
    try {
        $existe = $cn.CreateCommand()
        $existe.CommandText = "select count(*) from usuarios.caja_cambio where moneda = 'DIV' and fecha = ?"
        $existe.Parameters.Add('fecha', [System.Data.Odbc.OdbcType]::Date).Value = $hoy
        if ([int]$existe.ExecuteScalar() -gt 0) {
            Log "Ya existe DIV para $($hoy.ToString('dd/MM/yyyy')). No se inserta."
            exit 0
        }

        $ins = $cn.CreateCommand()
        $ins.CommandText = "insert into usuarios.caja_cambio (moneda, fecha, valor) values ('DIV', ?, ?)"
        $ins.Parameters.Add('fecha', [System.Data.Odbc.OdbcType]::Date).Value = $hoy
        $ins.Parameters.Add('valor', [System.Data.Odbc.OdbcType]::Numeric).Value = $venta
        [void]$ins.ExecuteNonQuery()
        $commit = $cn.CreateCommand(); $commit.CommandText = 'commit'; [void]$commit.ExecuteNonQuery()
        Log "Insertado DIV $($hoy.ToString('dd/MM/yyyy')) = $venta"
    }
    finally { $cn.Close() }
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
