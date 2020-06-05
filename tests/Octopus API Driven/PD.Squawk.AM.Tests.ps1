param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $OctopusUrl,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $OctopusApiKey
)
#-----------------------------------------------------------
# init
#-----------------------------------------------------------
$basePath = (Resolve-Path "$PsScriptRoot\..\.." -ea 1).Path
. (Join-Path $basePath 'packages.ps1')
if(!(Load-PackagesJson -Path "$basePath\packages.json")) { throw "Could not load packages" }
$sharedState = @{}
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl,$OctopusApiKey
$repo = new-object Octopus.Client.OctopusRepository $endpoint

#-----------------------------------------------------------
# tests
#-----------------------------------------------------------
Describe "Octopus API" -Tags @('api','pagerduty') {
    Context "Connectivity" {
        It "Should be able to connect to API" {
            $endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl,$OctopusApiKey
            $repo = new-object Octopus.Client.OctopusRepository $endpoint
            $repo | Should Not Be $null
        }
        It "Should be able to get server status" {
            $repo.ServerStatus.GetServerStatus() | Should Not Be $null
        }
    }
}
