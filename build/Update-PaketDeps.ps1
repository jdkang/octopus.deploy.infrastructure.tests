[CmdletBinding()]
param()
. $PSScriptRoot\paket-helpers.ps1
$paket = Find-Paket
$paket.Exec(@('update','--force','--verbose')) | foreach-object { write-verbose $_ }
if(@(0) -notcontains $LASTEXITCODE) {
    write-host "paket: $($LASTEXITCODE)"
    throw "paket update returned bad exit code"
}