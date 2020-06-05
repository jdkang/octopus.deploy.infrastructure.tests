[CmdletBinding()]
param()
. $PSScriptRoot\paket-helpers.ps1
$paket = Find-Paket
$paket.Exec(@('restore','--verbose')) | foreach-object { write-verbose $_ }
if(@(0) -notcontains $LASTEXITCODE) {
    write-host "paket: $($LASTEXITCODE)"
    throw "paket restore returned bad exit code"
}