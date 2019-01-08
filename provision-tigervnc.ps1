
choco install -y tigervnc

# install vncpassword into the TigerVNC directory.
$vncpasswordHome = 'C:\Program Files\TigerVNC'
$archiveUrl = 'https://github.com/rgl/vncpassword/releases/download/v1.0/vncpassword.zip'
$archiveHash = 'ff5b701420e9bb4e4642137f40e41fabcb935ebd22a0a866a8e7c2795c3fec63'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading vncpassword...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing vncpassword...'
Expand-Archive $archivePath -DestinationPath $vncpasswordHome
Remove-Item $archivePath

function ToVncPassword($password) {
    if ($password.Length -ne 8) {
        throw 'password length must be exactly 8 bytes'
    }
    $r = @()
    $hex = &"$vncpasswordHome\vncpassword.exe" (([System.Text.Encoding]::ASCII.GetBytes($password) | ForEach-Object ToString x2) -join '')
    for ($i = 0; $i -lt $hex.Length; $i += 2) {
		$r += [byte]::Parse($hex.Substring($i, 2), 'HexNumber')
    }
    $r
}

# configure TigerVNC.
# see https://github.com/TigerVNC/tigervnc/tree/8c6c584377feba0e3b99eecb3ef33b28cee318cb/win/vncconfig
Write-Host 'Configuring TigerVNC...'

$configPath = 'HKLM:\SOFTWARE\TigerVNC\WinVNC4'

# reset configuration.
mkdir -Force $configPath | Out-Null
Remove-Item "$configPath\*" -Force

# configure ports.
Set-ItemProperty -Path $configPath -Name LocalHost -Value 0         # Only accept connections from the local machine (default 1; use 1 to enable).
Set-ItemProperty -Path $configPath -Name PortNumber -Value 5900     # VNC port (default is 5900).
Set-ItemProperty -Path $configPath -Name HTTPPortNumber -Value 5800 # VNC Java Applet port (default is 5800; use 0 to disable).

# configure password.
# NB the password must be exactly 8 bytes.
Set-ItemProperty -Path $configPath -Name Password -Value ([byte[]](ToVncPassword "vagrant`0"))

# configure TLS.
$certificateFilenamePrefix = "$($env:COMPUTERNAME.ToLower()).example.com"
$dataPath = 'C:\ProgramData\TigerVNC'
mkdir -Force $dataPath | Out-Null
Disable-AclInheritance $dataPath
Grant-Permission $dataPath SYSTEM FullControl
Grant-Permission $dataPath Administrators FullControl
Copy-Item "C:\vagrant\shared\tigervnc-example-ca\$certificateFilenamePrefix-*" $dataPath
Set-ItemProperty -Path $configPath -Name X509Cert -Value "$dataPath\$certificateFilenamePrefix-crt.pem"
Set-ItemProperty -Path $configPath -Name X509Key -Value "$dataPath\$certificateFilenamePrefix-key.pem"
Set-ItemProperty -Path $configPath -Name SecurityTypes -Value 'VeNCrypt,X509Vnc'

# (re)start the service to apply the configuration.
Restart-Service TigerVNC

# open the firewall.
Write-Host 'Creating the firewall rule to allow inbound TCP/IP access to the TigerVNC port 5900 and 5800...'
New-NetFirewallRule `
    -Name 'TIGERVNC-In-TCP' `
    -DisplayName 'TigerVNC (TCP-In)' `
    -Direction Inbound `
    -Enabled True `
    -Protocol TCP `
    -LocalPort 5800,5900 `
    | Out-Null
