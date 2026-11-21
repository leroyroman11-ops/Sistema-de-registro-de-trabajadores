$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Instale Docker Desktop para Windows, abra Docker Desktop y vuelva a iniciar el registro.'
    }
    docker info --format '{{.ServerVersion}}'
    if ($LASTEXITCODE -ne 0) { throw 'Abra Docker Desktop, espere a que el motor Linux este listo y vuelva a iniciar.' }
    $carpeta = Join-Path $env:LOCALAPPDATA 'RegistroTrabajadoresDockerMySQL'
    [IO.Directory]::CreateDirectory($carpeta) | Out-Null
    $config = Join-Path $carpeta 'conexion.env'
    if (-not (Test-Path -LiteralPath $config)) {
        $clave = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        $bytes = [Text.Encoding]::ASCII.GetBytes("REGISTRO_CLAVE=$clave")
        $archivo = [IO.File]::Open($config, 'CreateNew', 'Write', 'None')
        try { $archivo.Write($bytes, 0, $bytes.Length) } finally { $archivo.Close() }
    }
    Write-Host 'Preparando la aplicacion y su base de datos. La primera vez se descargan los componentes...'
    # Compose construye la imagen local en el primer uso y la reutiliza al abrir.
    docker compose --env-file $config up -d --build
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar. Revise el mensaje anterior, la conexion a Internet y el puerto 8766.' }
    $url = 'http://127.0.0.1:8766'
    for ($i = 0; $i -lt 60; $i++) {
        try { $estado = Invoke-RestMethod "$url/api/estado" -TimeoutSec 3; if ($estado.listo -eq $true) { Start-Process $url; exit 0 } } catch {}
        Start-Sleep -Seconds 2
    }
    docker compose --env-file $config logs --tail 15 aplicacion
    throw 'El programa no pudo verificar que la base este lista.'
} catch {
    Write-Host $_ -ForegroundColor Red
    Read-Host 'Presione Enter para cerrar'
    exit 1
}
