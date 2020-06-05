#Requires -Version 4
[CmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [string]
    $TestFilePattern = '',
    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $TestTags = @(),
    [switch]$PreambleOnly,
    [switch]$Squawk
)
# **********************************************************
# This is a simple bootstrapper for pulling down paket
# which serves to handle nuget dependencies -- including
# Invoke-Build, Pester, and any 'build' tools required
#
# If you need to modify the location of paket.exe:
#   build/Ensure-Paket.ps1
# Updating NuGet Depedencies:
#   1) update paket.dependencies - https://fsprojects.github.io/Paket/dependencies-file.html
#   2) build/Update-PaketDeps.ps1
# **********************************************************
$packagesPath = Join-Path $PsScriptRoot 'packages'
$psBuildPath = Join-Path $packagesPath 'psbuild'
$buildPath = Join-Path $PsScriptRoot 'build'
if (!(Test-Path $buildPath)) { throw "build directory not found" }
$buildFile = Join-Path $buildPath 'main.build.ps1'
$isNonInteractiveMode = [bool]([Environment]::GetCommandLineArgs() -match '-noni')
# ----------------------------------------------------------
# func
# ----------------------------------------------------------
function Import-ModuleFromNugetPackage {
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({ (Test-Path $_) -and ((gi $_).name -eq 'packages') })]
    [string]
    $PackagesPath,
    [Parameter(Mandatory=$true)]
    $Module,
    [Parameter(Mandatory=$false)]
    [string]
    $FileName = '',
    [switch]$ReturnPath
)
    if(!$FileName) { $FileName = "$($Module).psm1" }
    $modulePathFmt = "$($PackagesPath)\{0}\tools\{1}"
    $modulePath = $modulePathFmt -f $Module,$FileName
    if (!(Test-Path $modulePath)) { throw "Cannot find file $modulePath" }
    if($ReturnPath) {
        write-host "Verified Path for $Module $FileName" -f gray
        return $modulePath
    }
    write-host "Loading $Module $FileName" -f gray
    switch -wildcard ($FileName) {
        "*.psm1" {
            write-verbose "Importing Module $modulePath"
            Import-Module $modulePath
        }
        "*.ps1" {
            write-verbose "Dot Sourcing $modulePath"
            . $modulePath
        }
        default { throw "Unknown filetype $FileName" }
    }
}
function Write-SectionTitle {
param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Title,
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Seperator = '-',
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]
    $SeperatorLength = 24,
    [Parameter(Mandatory=$false)]
    [consolecolor]
    $ConsoleColor = 'cyan'
)
    $seperatorStr = $Seperator*$SeperatorLength
    write-host $seperatorStr -f $ConsoleColor
    write-host $Title -f $ConsoleColor
    write-host $seperatorStr -f $ConsoleColor
}
# ----------------------------------------------------------
# main
# ----------------------------------------------------------
# --- Preamble ---
Write-SectionTitle 'Preamble'
# paket restore
write-host "[+] Restoring Paket Depedencies" -f green
& $buildPath\Restore-PaketDeps.ps1
# import modules
write-host "[+] Importing Modules" -f green
#$invokeBuild = Import-ModuleFromNugetPackage -PackagesPath $packagesPath -Module 'Invoke-Build' -FileName 'Invoke-Build.ps1' -ReturnPath
#Import-ModuleFromNugetPackage -PackagesPath $packagesPath -Module 'pester'
Import-Module (Join-Path $psBuildPath 'Pester') -Force
Import-Module (Join-Path $psBuildPath 'InvokeBuild') -Force

if($PreambleOnly) { return }

# --- build ---
Write-SectionTitle 'Build'

# Required Values
if(!(Test-Path env:\OctopusUrl)) {
    if(!$isNonInteractiveMode) {
        write-warning "Use devenv\Set-OctopusApiTestEnv.ps1 to setup required env variables in an interactive session"
    }
    throw "Environment Variable 'OctopusUrl' Required for Tests"
}
if(!(Test-Path env:\OctopusApiKey)) {
    if(!$isNonInteractiveMode) {
        write-warning "Use devenv\Set-OctopusApiTestEnv.ps1 to setup required env variables in an interactive session"
    }
    throw "Environment Variable 'OctopusApiKey' Required for TEsts"
}
# extra args
$extraArgs = @{}
if(![string]::IsNullOrEmpty($TestFilePattern)) {
    $extraArgs.Add('TestFilePattern',$TestFilePattern)
}
if($TestTags.Count -gt 0) {
    $extraArgs.Add('TestTags',$TestTags)
}
if($Squawk) {
    $extraArgs.Add('Squawk',$True)
}
# Run
& Invoke-Build -File $buildFile @extraArgs