# Dados básicos
$UserName  = $env:USERNAME
$nic       = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } | Select-Object -First 1
$localIP   = $nic.IPv4Address.IPAddress
$Port      = 2313
$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$inventoryPath = Join-Path $scriptDir "inventory.ini"

# Nome do host = winhost + último octeto do IP (ex.: 192.168.0.105 -> winhost105)
$suffix = ($localIP -split '\.')[-1]
$node   = "winhost$suffix"   # NÃO usar $host (variável interna do PowerShell)
$line   = "$node ansible_host=$localIP ansible_port=$Port ansible_user=$UserName ansible_connection=ssh"

if (-not (Test-Path $inventoryPath)) {
    # Cria do zero com a seção [windows] e a linha completa
    Set-Content -LiteralPath $inventoryPath -Value @("[windows]", $line) -Encoding utf8
} else {
    $content     = Get-Content -LiteralPath $inventoryPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    $hasHeader   = $content -match '(?mi)^\[windows\]\s*$'
    $patternNode = "(?mi)^\s*$([regex]::Escape($node))\b.*$"  # linha do host exato (winhost###)
    $patternBare = "(?mi)^\s*winhost\b(?!\d).*?$"            # 'winhost' sem número (legado)

    if ($content -match $patternNode) {
        # Atualiza a linha existente do host winhost###
        $newContent = [regex]::Replace($content, $patternNode, $line)
    } elseif ($content -match $patternBare) {
        # Renomeia/atualiza 'winhost' puro para o numerado winhost###
        $newContent = [regex]::Replace($content, $patternBare, $line)
    } else {
        # Garante a seção [windows] e acrescenta a nova linha completa
        $newContent = $content
        if (-not $hasHeader) { $newContent += "`r`n[windows]" }
        $newContent += "`r`n$line"
    }

    Set-Content -LiteralPath $inventoryPath -Value $newContent -Encoding utf8
}

Write-Host "`nPronto! ✅" -ForegroundColor Green
Write-Host "Teste local:" -ForegroundColor Cyan
Write-Host "  ssh -p $Port `"$UserName`"@$localIP -vvv" -ForegroundColor Gray
Write-Host "Inventory criado/atualizado em: $inventoryPath" -ForegroundColor Gray
