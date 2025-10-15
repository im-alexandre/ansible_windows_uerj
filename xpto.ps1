param(
  [string]$Path = 'C:\choco_repo',
  [string]$ShareName = 'ChocoRepo',
  [switch]$AllowAnonymous = $false
)

$ErrorActionPreference = 'Stop'
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'

# Resolve nomes a partir dos SIDs (independente de idioma)
$Everyone = (New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0').Translate([System.Security.Principal.NTAccount]).Value

# 1) Pasta
New-Item -Path $Path -ItemType Directory -Force | Out-Null

# 2) Share SMB com acesso irrestrito (Full para Everyone)
$share = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if (-not $share) {
  New-SmbShare -Name $ShareName -Path $Path -CachingMode None -FullAccess $Everyone -Confirm:$false | Out-Null
} else {
  # limpar ACEs do share e dar Full a Everyone
  Get-SmbShareAccess -Name $ShareName -ErrorAction SilentlyContinue | ForEach-Object {
    Revoke-SmbShareAccess -Name $ShareName -AccountName $_.Name -Force -Confirm:$false -ErrorAction SilentlyContinue
  }
  Grant-SmbShareAccess -Name $ShareName -AccountName $Everyone -AccessRight Full -Force -Confirm:$false | Out-Null
  Set-SmbShare -Name $ShareName -CachingMode None -Confirm:$false | Out-Null
}

# 3) NTFS: Controle Total para Everyone (herdado)
icacls "$Path" /grant *S-1-1-0:(OI)(CI)F /T /Q | Out-Null

# 4) Firewall SMB (TCP/445)
if (-not (Get-NetFirewallRule -DisplayName 'ChocoRepo SMB 445' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName 'ChocoRepo SMB 445' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 445 | Out-Null
}

# 5) (Opcional) Acesso anônimo (INSEGURO) se solicitado
if ($AllowAnonymous.IsPresent) {
  # Permitir que "Todos" inclua anônimos
  Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'everyoneincludesanonymous' -Type DWord -Value 1 -Force
  # Permitir clientes guest inseguros
  New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Force | Out-Null
  New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'AllowInsecureGuestAuth' -Type DWord -Value 1 -Force | Out-Null
  try { Set-SmbServerConfiguration -RejectUnencryptedAccess $false -Force | Out-Null } catch {}
}

Write-Host "Share '\\$($env:COMPUTERNAME)\$ShareName' pronto em '$Path'. Acesso: Everyone=Full. Firewall SMB liberado. Anônimo: $($AllowAnonymous.IsPresent)."
