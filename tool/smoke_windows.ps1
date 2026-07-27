$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bundleRoot = Join-Path $repositoryRoot 'dist\endless-windows-x64'
$cli = Join-Path $bundleRoot 'endless.exe'
$expectedLocald = [System.IO.Path]::GetFullPath(
    (Join-Path $bundleRoot 'locald.exe')
)
$smokeRoot = Join-Path $repositoryRoot (
    'build\smoke-profile-{0}' -f [DateTime]::UtcNow.Ticks
)
$endpointPath = Join-Path $smokeRoot 'runtime\endpoint.json'

function Stop-SmokeDaemon {
    param(
        [Parameter(Mandatory = $true)]
        [int] $ProcessId
    )

    $target = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $target) {
        return
    }
    $actualPath = [System.IO.Path]::GetFullPath($target.Path)
    if (-not $actualPath.Equals(
        $expectedLocald,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to stop unexpected process: $actualPath"
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction Stop
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if ($null -eq (Get-Process -Id $ProcessId `
            -ErrorAction SilentlyContinue)) {
            return
        }
        Start-Sleep -Milliseconds 100
    }
    throw "Daemon $ProcessId did not exit."
}

function Invoke-CliJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    $json = (& $cli --profile-root $smokeRoot --json @Arguments) | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "Bundled CLI failed: $($Arguments -join ' ')"
    }
    return $json | ConvertFrom-Json
}

if (-not (Test-Path -LiteralPath $cli) -or
    -not (Test-Path -LiteralPath $expectedLocald)) {
    throw 'Build the Windows bundle before running the smoke test.'
}

$env:HTTP_PROXY = 'http://127.0.0.1:9'
$env:HTTPS_PROXY = 'http://127.0.0.1:9'
$env:NO_PROXY = ''

try {
    $health = Invoke-CliJson @('health')
    $workspace = Invoke-CliJson @('workspace', 'create', 'Smoke')
    $document = Invoke-CliJson @(
        'document',
        'create',
        $workspace.workspace_id,
        'OfflineNote'
    )

    $firstEndpoint = Get-Content -Raw $endpointPath | ConvertFrom-Json
    Stop-SmokeDaemon $firstEndpoint.process_id

    $restored = Invoke-CliJson @(
        'document',
        'get',
        $document.document_id
    )
    $secondEndpoint = Get-Content -Raw $endpointPath | ConvertFrom-Json
    if ($secondEndpoint.process_id -eq $firstEndpoint.process_id) {
        throw 'Daemon PID did not change after forced restart.'
    }
    Stop-SmokeDaemon $secondEndpoint.process_id

    [pscustomobject]@{
        Health = $health.status
        Workspace = $workspace.name
        Document = $restored.title
        ColdRestart = $true
        ExternalProxyBlocked = $true
        Profile = $smokeRoot
    } | Format-List
}
finally {
    if (Test-Path -LiteralPath $endpointPath) {
        $lastEndpoint = Get-Content -Raw $endpointPath | ConvertFrom-Json
        Stop-SmokeDaemon $lastEndpoint.process_id
    }
}
