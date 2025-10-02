<# 
Configura-SSH.ps1
Uso:
  # executa para o usuário atual
  .\Configura-SSH.ps1

  # ou especifique um usuário alvo (ex.: "Laboratório" ou "imale")
  .\Configura-SSH.ps1 -UserName "Laboratório"

O script:
- Usa id_rsa.pub no MESMO diretório do script
- Porta 2313 / 0.0.0.0
- Ajusta sshd_config + firewall
- Copia a chave para administrators_authorized_keys SE o usuário pertencer a Administradores; senão para ~/.ssh/authorized_keys
#>

[CmdletBinding()]
param(
  [string]$UserName = $env:USERNAME,
  [int]$Port = 2313
)

# ===== Verificações básicas =====
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
   ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Error "Abra o PowerShell com **Executar como Administrador**."
  exit 1
}

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$pubKeySrc = Join-Path $scriptDir "id_rsa.pub"
$privateKeySrc = Join-Path $scriptDir "id_rsa"
if (-not (Test-Path $pubKeySrc)) {
  Write-Error "id_rsa.pub não encontrado em: $pubKeySrc. Gere com 'ssh-keygen' e coloque aqui."
  exit 1
}

# ===== Helpers =====
function Test-IsUserInAdmins([string]$U){
  try {
    $adminsLocal = @("Administradores","Administrators")
    foreach($grp in $adminsLocal){
      if ((Get-LocalGroupMember -Group $grp -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*\$U" -or $_.Name -like "*$U" })) {
        return $true
      }
    }
  } catch {}
  return $false
}

function Set-StrictAcl-AdminsOnly([string]$Path){
  if (-not (Test-Path $Path)){ New-Item -ItemType File -Path $Path -Force | Out-Null }
  icacls $Path /inheritance:r | Out-Null
  # Dono = Administradores/Administrators
  $set = $false
  try { icacls $Path /setowner Administradores  | Out-Null; $set = $true } catch {}
  if (-not $set){ icacls $Path /setowner Administrators | Out-Null }
  # Permissões
  icacls $Path /grant:r "Administradores:(F)" "NT AUTHORITY\SYSTEM:(F)" 2>$null | Out-Null
  icacls $Path /grant:r "Administrators:(F)" "NT AUTHORITY\SYSTEM:(F)" 2>$null | Out-Null
  foreach($sid in @('Todos','Usuários','Users','Authenticated Users','INTERACTIVE','Everyone')){
    icacls $Path /remove:g $sid 2>$null | Out-Null
  }
}

function Set-StrictAcl-UserOnly([string]$Path,[string]$User){
  if (-not (Test-Path $Path)){ New-Item -ItemType File -Path $Path -Force | Out-Null }
  icacls $Path /inheritance:r | Out-Null
  icacls $Path /setowner "$User" | Out-Null
  icacls $Path /grant:r "${User}:(F)" "NT AUTHORITY\SYSTEM:(F)" | Out-Null
  foreach($sid in @('Administradores','Administrators','Todos','Usuários','Users','Authenticated Users','INTERACTIVE','Everyone')){
    icacls $Path /remove:g $sid 2>$null | Out-Null
  }
}

# ===== Instalar/ativar OpenSSH Server (checagem rápida) =====
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
  Write-Host "Instalando OpenSSH.Server..." -ForegroundColor Cyan
  Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"
} else { Write-Host "OpenSSH Server já instalado." -ForegroundColor DarkGray }

Set-Service -Name sshd -StartupType Automatic
Set-Service -Name ssh-agent -StartupType Automatic
if ((Get-Service ssh-agent).Status -ne "Running"){ Start-Service ssh-agent }
if ((Get-Service sshd).Status -ne "Running"){ Start-Service sshd }

# ===== Caminhos =====
$sshProgData = "C:\ProgramData\ssh"
New-Item -ItemType Directory -Path $sshProgData -Force | Out-Null
$sshdConfig  = Join-Path $sshProgData "sshd_config"
$authAdmin   = Join-Path $sshProgData "administrators_authorized_keys"

# Perfil do usuário alvo
# Tenta achar o perfil exato; se não achar, assume C:\Users\<UserName>
$userProfile = (Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPath -match "\\Users\\$([Regex]::Escape($UserName))$" } |
  Select-Object -First 1).LocalPath
if (-not $userProfile){ $userProfile = "C:\Users\$UserName" }

$userSshDir  = Join-Path $userProfile ".ssh"
$userAuth    = Join-Path $userSshDir "authorized_keys"

# ===== Copiar chave pública =====
$keyLine = (Get-Content -LiteralPath $pubKeySrc -Raw).Trim()

$targetIsAdminsFile = Test-IsUserInAdmins -U $UserName
if ($targetIsAdminsFile) {
  Write-Host "Usuário '$UserName' é membro de Administradores → usando administrators_authorized_keys." -ForegroundColor Green
  Set-Content -LiteralPath $authAdmin -Value $keyLine -Encoding ascii -NoNewline
  Set-StrictAcl-AdminsOnly -Path $authAdmin
} else {
  Write-Host "Usuário '$UserName' NÃO é administrador → usando ~/.ssh/authorized_keys." -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null
  Set-Content -LiteralPath $userAuth -Value $keyLine -Encoding ascii -NoNewline
  Set-StrictAcl-UserOnly -Path $userAuth -User $UserName
}

# (opcional) “endurece” a própria id_rsa.pub do diretório
try {
  icacls $privateKeySrc /inheritance:r | Out-Null
  $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  icacls $privateKeySrc /setowner "$me" | Out-Null
  icacls $privateKeySrc /grant:r "${me}:(R)" "NT AUTHORITY\SYSTEM:(F)" | Out-Null
  foreach($sid in @('Todos','Usuários','Users','Authenticated Users','INTERACTIVE','Everyone','Administradores','Administrators')){
    icacls $privateKeySrc /remove:g $sid 2>$null | Out-Null
  }
} catch { }

# ===== Ajustar sshd_config =====
if (-not (Test-Path $sshdConfig)){ New-Item -ItemType File -Path $sshdConfig -Force | Out-Null }
$config = Get-Content -LiteralPath $sshdConfig -Raw

# limpa diretivas antigas (modo multiline via (?m))
$config = $config -replace '(?m)^[#\s]*Port\s+\d+.*$', ''
$config = $config -replace '(?m)^[#\s]*AddressFamily\s+\w+.*$', ''
$config = $config -replace '(?m)^[#\s]*ListenAddress\s+.*$', ''
$config = $config -replace '(?m)^[#\s]*AuthorizedKeysFile\s+.*$', ''
$config = $config -replace '(?m)^\s*Match\s+Group\s+administrators\b[\s\S]*?(?=^\s*Match\b|^\s*$)', ''

$head = @(
  "Port $Port"
  "AddressFamily any"
  "ListenAddress 0.0.0.0"
  "PubkeyAuthentication yes"
  "AuthorizedKeysFile .ssh/authorized_keys"
) -join "`r`n"

$matchBlock = @(
  ""
  "Match Group administrators"
  "       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys"
  ""
) -join "`r`n"

$newConfig = $head + "`r`n" + $config.Trim() + $matchBlock
Set-Content -LiteralPath $sshdConfig -Value ($newConfig.Trim() + "`r`n") -Encoding ascii

# ===== Firewall =====
$fwRuleName = "OpenSSH Server (sshd) - TCP $Port"
$old = Get-NetFirewallRule -DisplayName $fwRuleName -ErrorAction SilentlyContinue
if ($old){ $old | Remove-NetFirewallRule }
New-NetFirewallRule -DisplayName $fwRuleName -Direction Inbound -Action Allow `
  -Protocol TCP -LocalPort $Port -Profile Any | Out-Null

# ===== Aplicar e validar =====
Restart-Service sshd

# Sanity check: confirmar AuthorizedKeysFile efetivo
$authList = & 'C:\Windows\System32\OpenSSH\sshd.exe' -T 2>$null | Select-String -Pattern 'authorizedkeysfile'
Write-Host "`nAuthorizedKeysFile efetivo:" -ForegroundColor Cyan
$authList | ForEach-Object { $_.ToString() } | Write-Host

# ===== Inventory Ansible =====
$nic = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } | Select-Object -First 1
$localIP = $nic.IPv4Address.IPAddress
if (-not $localIP) {
  $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
}
$inventory = @"
[windows]
winhost ansible_host=$localIP ansible_port=$Port ansible_user=$UserName ansible_connection=ssh

[windows:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_shell_type=powershell
"@
$inventoryPath = Join-Path $scriptDir "inventory.ini"
Set-Content -LiteralPath $inventoryPath -Value $inventory -Encoding ascii

Write-Host "`nPronto! ✅" -ForegroundColor Green
Write-Host "Teste local:" -ForegroundColor Cyan
Write-Host "  ssh -p $Port `"$UserName`"@localhost -vvv" -ForegroundColor Gray
Write-Host "Inventory criado em: $inventoryPath" -ForegroundColor Gray
