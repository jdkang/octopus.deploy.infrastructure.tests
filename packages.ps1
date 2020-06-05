<#
---- packages.json ----
{
    "packageRoot": ".\\packages",
    "packages": [
        {
            "typecheck": "Octopus.Client.OctopusServerEndpoint",
            "paths": [
                "Octopus.Client\\lib\\net45\\*.dll",
                "Newtonsoft.Json\\lib\\net45\\*.dll"
            ]
        }
    ]
}
-----------------------
PATH FORMAT is all relative to packages.json location
    <packages.json direcotry>\<packagesRoot>\<path>
#>

function Load-PackagesJson {
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({ ![string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) })]
    $Path,
    [Parameter(Mandatory=$false)]
    [string]
    $SpecificPackage,
    [switch]$Force
)
BEGIN {
    $ret = $false
    $packageSettings = $null
}
PROCESS {
    $packagesByTypecheck = @()
    $packagePathsHt = @{}
    
    # Serialize packages.json
    $packageSettings = (Get-Content -Path $Path -Raw) | ConvertFrom-Json
    if (!$packageSettings) {
        write-warning "Cannot process packages.json file"
        return
    }
    $packagesByTypecheck = $packageSettings.packages.typeCheck
    if (($packagesByTypecheck | measure).count -eq 0) {
        write-warning "No typechecks"
        return
    }
    
    # Validate packageRoot
    $packageRootIsVaild = $false
    $packageRootPath = ''
    if (![string]::IsNullOrWhiteSpace($packageSettings.packageRoot))
    {
        $packageJsonDirectory = (Get-Item -Path $Path).Directory
        write-verbose "package.json Direcotry: $packageJsonDirectory"
        write-verbose "Evaluating packageRoot $($packageSettings.packageRoot)"
        $packageRootPath = Resolve-Path (Join-Path $packageJsonDirectory $packageSettings.packageRoot) | Select -expand Path
        if ($packageRootPath -and (Test-Path $packageRootPath)) { 
            write-verbose "Resolved packageRoot: $packageRootPath"
            $packageRootIsVaild = $true
        } else {
            write-error "packageRoot $packageRootPath not valid"
        }
    }
    if (!$packageRootIsVaild) { return }
    
    # Resolve dll paths
    write-verbose "Verifying dll paths"
    $pathsCheckResult = $null
    foreach($package in $packageSettings.packages) {
        write-verbose "Package with TypeCheck $($package.typecheck)"
        foreach ($relativePath in $package.paths) {
            write-verbose "Evaluating (relative) path(s) $relativePath"
            $finalPath = Join-Path $packageRootPath $relativePath
            $dllToLoad = resolve-path $finalPath |
                         select -expand Path |
                         where-object { (Test-Path $_) -and ((gi $_).extension -eq '.dll') }
            $dllToLoad | foreach-object { write-verbose "DLL: $($_)" }
            if (($dllToLoad | measure).count -gt 0) {
                if (!$packagePathsHt.ContainsKey($package.typeCheck)) {
                    $packagePathsHt.Add($package.typeCheck,@(,$dllToLoad))
                } else {
                    $packagePathsHt[$package.typeCheck] += $dllToLoad
                }
            } else {
                write-warning "TypeCheck $($package.typecheck) Path $finalPath resolved 0 dll files to load"
                $pathsCheckResult = $false
            }
        }
    }
    if ($pathsCheckResult -eq $false) {
        write-error "Some paths did not resolve any binaries"
        return
    }
        
    # Load
    $results = $true
    $packagesByTypecheck | Foreach-Object {
        $loadBinResult = Load-Binaries -TypeNameCheck $_ -Path $packagePathsHt[$_] -Force:$Force
        $results = $results -and $loadBinResult
    }
    $ret = $results
}
END {
    $ret
}}
function Load-Binaries {
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $TypeNameCheck,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ (Test-Path $_) -and (gi $_).extension -eq '.dll' })]
    [string[]]
    $Path,
    [switch]$Force
)
BEGIN {
    $ret = $false
    $skipProcessBlock = $false             
}
PROCESS {
    if ($skipProcessBlock) { return }
    write-verbose "Checking for Type $TypeNameCheck"
    if ($Force -or !(Test-Type $TypeNameCheck)) {
        try {
            write-verbose "Loading DLLs"
            $Path |
                foreach-object {
                    write-verbose "Loading DLL: $($_)"
                    Add-Type -Path $_ -ea 0
                }
            if (Test-Type $TypeNameCheck) {
                $ret = $true
            } else {
                write-error "Cannot verify type $TypeNameCheck is loaded"
            }
        }
        catch {
            $ret = $false
            write-verbose "$($_.Exception.Message)"
        }
    } else {
        write-verbose "Type $TypeNameCheck already loaded, skipping dll import"
        $ret = $true
    }
}
END {
    $ret
}}
function Test-Type {
param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $typeName
)
    $result = try{
        $typeName -as [type]
    } catch{}
    if ($result) {
        return $true
    }
    return $false
}