function Get-DotnetPkgs {
    param(
        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [string]
        $PackageId = '',
        
        [switch]$Global
    )
        $dotnetArgs = @('tool','list')
        if($Global) {
            $dotnetArgs += '--global'
        }
        $strOutput = & dotnet $dotnetArgs
        for($i = 2; $i -lt $strOutput.Count; $i++) {
            if($strOutput[$i] -match '^(?<pkgId>[^\s]+)\s+(?<version>[\d\.]+)') {
                if(![string]::IsNullOrWhitespace($PackageId) -and ($matches['pkgId'] -ne $PackageId)) {
                    continue
                }
                [pscustomobject]([ordered]@{
                    PackageId = $matches['pkgId']
                    Version = [version]$matches['version']
                })
            }
        }
    }
    function Find-Paket {
    [cmdletbinding()]
    param(
        [switch]$NoEx
    )
        $retProps = ([ordered]@{
            dotnetcore = $False
            dotnettools = $False
            dotnetlocaltool = $False
            dotnetsdkversion = $null
            fromDotnetTool = $False
            fromPwd = $False
            paketVersion = $null
            paketBin = ''
            paketInitArgs = @()
        })
        
        # Check .NET SDK
        if(gcm 'dotnet' -ea 0) {
            write-verbose "[dotnet] dotnet sdk found"
            $retProps['dotnetcore'] = $True
            [version]$dotnetSdkVersion = & dotnet --version
            write-verbose "[dotnet] dotnet sdk version: $($dotnetSdkVersion)"
            $retProps['dotnetsdkversion'] = $dotnetsdkversion
            if($dotnetSdkVersion -ge ([version]'2.1')) {
                write-verbose "[dotnet] dotnet tools available (>= 2.1)"
                $retProps['dotnettools'] = $True
            } else {
                write-warning ".NET Version < 2.1 Core ($($dotnetSdkVersion))"
            }
        } else {
            write-warning "[dotnet] Missing dotnet sdk"
        }
        
        # Find Paket
        $foundPaket = $False
        if($retProps.dotnettools) {
            # Try to bootstrap via .net tools
            write-verbose "[.net tools] Attempting to install/restore paket"
            if((($dotnetsdkversion -ge ([version]'3.0'))) -and (Get-DotnetPkgs -PackageId 'paket')) {
                # .NET SDK 3.0+ support local tools
                write-verbose "[.net tools] Attempting to restore local tools"
                $retProps['dotnetlocaltool'] = $True
                & dotnet tool restore 2>&1 | foreach-object { write-verbose $_ }
            } elseif(!(Get-DotnetPkgs -Global -PackageId 'paket')) {
                # .NET SDK 2.1+ supports global tools
                write-verbose "[.net tools] Attempting to install global tool"
                & dotnet tool install --global Paket 2>&1 | foreach-object { write-verbose $_ }
            }
            $retProps['fromDotnetTool'] = $True
            $retProps['paketBin'] = 'dotnet'
            $retProps['paketInitArgs'] = @('tool','run','paket')
            $foundPaket = $True
        }
        if(!$foundPaket) {
            # As a final attempt, try to check if paket.exe is in PATH
            write-verbose "[no .net tools] searching PWD for paket.exe"
            if(gcm 'paket' -ea 0) {
                write-verbose "[no .net tools] FOUND paket.exe in PATH"
                $retProps['fromPwd'] = $True
                $retProps['paketBin'] = 'paket'
                $retProps['paketInitArgs'] = @()
                $foundPaket = $True
            } else {
                write-verbose "[no .net tools] CANNOT FIND paket.exe in PATH"
            }
        }
        
        # Get Paket Version
        if($foundPaket) {
            write-verbose "[paket found] Checking version"
            [string]$paketVersionStr = & $retProps['paketBin'] ($retProps['paketInitArgs'] + @('--version')) 2>&1
            if($paketVersionStr -match '^Cannot find a tool in the manifest file') {
                write-error "Unable to find paket version, potential issue install/restoring tool: $($paketVersionStr)"
            } elseif($paketVersionStr -match 'Paket\s+version\s+(?<version>[\d\.]+)') {
                $paketVersion = [version]$matches['version']
                write-verbose "[version found] Paket Version: $($paketVersion)"
                $retProps['paketVersion'] = $paketVersion
                $ret = [pscustomobject]$retProps
                # Wrapper method for executing paket commands
                $ret | Add-member -MemberType ScriptMethod -Name 'Exec' -Value {
                    [CmdletBinding()]
                    param(
                        [Parameter(Mandatory=$True)]
                        [ValidateNotNullOrEmpty()]
                        [string[]]
                        $PaketArgs
                    )
                    $cmdArgs = $this.paketInitArgs += $PaketArgs
                    $cmd = $this.paketBin
                    write-verbose "EXECUTING: $($cmd) $($cmdArgs -join ' ')"
                    & $cmd $cmdArgs
                }
                return $ret
            }
        }
        
        # We failed to find or bootstrap paket
        write-verbose "[paket not found] Unable to find paket!"
        if(!$NoEx) {
            throw "Unable to bootstrap paket from either dotnet tools or find in PATH"
        }
    }
    