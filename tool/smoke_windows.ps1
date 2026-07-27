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
$restoreRoot = Join-Path $repositoryRoot (
    'build\smoke-restore-{0}' -f [DateTime]::UtcNow.Ticks
)
$backupPath = Join-Path $repositoryRoot (
    'build\smoke-backup-{0}.backup' -f [DateTime]::UtcNow.Ticks
)
$endpointPath = Join-Path $smokeRoot 'runtime\endpoint.json'
$restoreEndpointPath = Join-Path $restoreRoot 'runtime\endpoint.json'

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

    return Invoke-CliJsonForProfile `
        -ProfileRoot $smokeRoot `
        -Arguments $Arguments
}

function Invoke-CliJsonForProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ProfileRoot,
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    $json = (
        & $cli --profile-root $ProfileRoot --json @Arguments
    ) | Out-String
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
    $workspace = Invoke-CliJson @(
        'workspace',
        'rename',
        $workspace.workspace_id,
        'SmokeRenamed'
    )
    $document = Invoke-CliJson @(
        'document',
        'create',
        $workspace.workspace_id,
        'OfflineNote'
    )
    $attachmentSource = Join-Path $smokeRoot 'offline-attachment.txt'
    [System.IO.File]::WriteAllText(
        $attachmentSource,
        'Available without an external server',
        [System.Text.UTF8Encoding]::new($false)
    )
    $attachment = Invoke-CliJson @(
        'attachment',
        'add',
        $document.document_id,
        $attachmentSource,
        'text/plain'
    )
    $attachmentsBefore = @(
        Invoke-CliJson @(
            'attachment',
            'list',
            $document.document_id
        )
    )
    if ($attachmentsBefore.Count -ne 1) {
        throw 'Managed attachment was not listed after upload.'
    }
    $child = Invoke-CliJson @(
        'document',
        'create',
        $workspace.workspace_id,
        'NestedNote'
    )
    $null = Invoke-CliJson @(
        'document',
        'move',
        $child.document_id,
        $document.document_id
    )
    $null = Invoke-CliJson @(
        'document',
        'delete',
        $document.document_id
    )
    $null = Invoke-CliJson @(
        'document',
        'restore',
        $document.document_id
    )
    $null = Invoke-CliJson @(
        'document',
        'restore',
        $child.document_id
    )
    $null = Invoke-CliJson @(
        'workspace',
        'archive',
        $workspace.workspace_id
    )
    $null = Invoke-CliJson @(
        'workspace',
        'restore',
        $workspace.workspace_id
    )
    $searchBefore = @(
        Invoke-CliJson @(
            'search',
            $workspace.workspace_id,
            'OfflineNote'
        )
    )
    if ($searchBefore.Count -ne 1) {
        throw 'Local search did not find the restored document.'
    }

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
    $searchAfter = @(
        Invoke-CliJson @(
            'search',
            $workspace.workspace_id,
            'OfflineNote'
        )
    )
    if ($searchAfter.Count -ne 1) {
        throw 'Local search projection did not survive cold restart.'
    }
    $attachmentsAfter = @(
        Invoke-CliJson @(
            'attachment',
            'list',
            $document.document_id
        )
    )
    if ($attachmentsAfter.Count -ne 1 -or
        $attachmentsAfter[0].attachment_id -ne $attachment.attachment_id) {
        throw 'Managed attachment metadata did not survive cold restart.'
    }
    $attachmentDownload = Join-Path $smokeRoot 'downloaded-attachment.txt'
    $null = Invoke-CliJson @(
        'attachment',
        'download',
        $attachment.attachment_id,
        $attachmentDownload
    )
    if ([System.IO.File]::ReadAllText($attachmentDownload) -ne
        'Available without an external server') {
        throw 'Managed attachment bytes did not round trip.'
    }
    $searchStatus = Invoke-CliJson @('search-index', 'status')
    $rebuilt = Invoke-CliJson @('search-index', 'rebuild')
    if (-not $searchStatus.is_current -or -not $rebuilt.is_current) {
        throw 'Local search index is not current.'
    }
    $backup = Invoke-CliJson @('backup', 'export', $backupPath)
    if ($backup.size -le 0 -or -not (Test-Path -LiteralPath $backupPath)) {
        throw 'Packaged backup export did not create a bounded archive.'
    }
    $backupRestore = Invoke-CliJsonForProfile `
        -ProfileRoot $restoreRoot `
        -Arguments @('backup', 'restore', $backupPath)
    if ($backupRestore.format_version -ne 1) {
        throw 'Packaged backup restore returned an unexpected version.'
    }
    $restoredSearch = @(
        Invoke-CliJsonForProfile `
            -ProfileRoot $restoreRoot `
            -Arguments @(
                'search',
                $workspace.workspace_id,
                'OfflineNote'
            )
    )
    if ($restoredSearch.Count -ne 1) {
        throw 'Backup restore did not rebuild local search.'
    }
    $restoredAttachments = @(
        Invoke-CliJsonForProfile `
            -ProfileRoot $restoreRoot `
            -Arguments @(
                'attachment',
                'list',
                $document.document_id
            )
    )
    if ($restoredAttachments.Count -ne 1 -or
        $restoredAttachments[0].attachment_id -ne
        $attachment.attachment_id) {
        throw 'Backup restore did not preserve attachment metadata.'
    }
    $restoredAttachmentDownload = Join-Path `
        $restoreRoot `
        'restored-attachment.txt'
    $null = Invoke-CliJsonForProfile `
        -ProfileRoot $restoreRoot `
        -Arguments @(
            'attachment',
            'download',
            $attachment.attachment_id,
            $restoredAttachmentDownload
        )
    if ([System.IO.File]::ReadAllText($restoredAttachmentDownload) -ne
        'Available without an external server') {
        throw 'Backup restore did not preserve attachment bytes.'
    }
    $restoreEndpoint = Get-Content -Raw `
        $restoreEndpointPath | ConvertFrom-Json
    Stop-SmokeDaemon $restoreEndpoint.process_id
    Stop-SmokeDaemon $secondEndpoint.process_id

    [pscustomobject]@{
        Health = $health.status
        Workspace = $workspace.name
        Document = $restored.title
        TreeRecycle = $true
        WorkspaceLifecycle = $true
        LocalSearch = $true
        SearchRebuild = $true
        ManagedAttachments = $true
        BackupCleanRestore = $true
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
    if (Test-Path -LiteralPath $restoreEndpointPath) {
        $lastRestoreEndpoint = Get-Content -Raw `
            $restoreEndpointPath | ConvertFrom-Json
        Stop-SmokeDaemon $lastRestoreEndpoint.process_id
    }
}
