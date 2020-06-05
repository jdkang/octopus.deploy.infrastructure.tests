param(
    [Parameter(Mandatory=$true)]
    [alias('url')]
    [string]
    $OctopusUrl,
    [Parameter(Mandatory=$true)]
    [alias('apikey')]
    [string]$OctopusApiKey
)
    Get-Variable -Name 'OctopusUrl' -Scope 'global' -ea 0 | Remove-Variable -Force -ea 0
    Get-Variable -Name 'OctopusApiKey' -Scope 'global' -ea 0 | Remove-Variable -Force -ea 0
    write-host "Setting Up $($OctopusUrl)" -f yellow
    $ENV:OctopusUrl = $OctopusUrl
    $ENV:OctopusApiKey = $OctopusApiKey