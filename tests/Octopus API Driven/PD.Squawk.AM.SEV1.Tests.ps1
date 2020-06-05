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
Describe "Deploys" -Tags @('deploys','pagerduty') {
    Context "OverNight Deploys" {
        $projectNames = @('Overnight Deploy 1', 'Overnight Deploy 2')
        $targetEnvName = 'Prod-Internal'
        [array]$projIds = $projectNames `
            | ForEach-Object { $repo.Projects.Get($_) } `
            | Select-Object -ExpandProperty Id

        $targetEnv = $repo.Environments.FindByName($targetEnvName)
        $envIds = @()
        $envIds += $targetEnv.Id

        $dashboard = $repo.Dashboards.GetDynamicDashboard($projIds, $envIds)
        foreach($deployItem in $dashboard.Items) {
            It "Should Be Completed and Successful" {
                $deployItem.IsCompleted -and ($deployItem.State -eq 'Success') | Should Be $True
            }
            It "Should Not Have Interruptions" {
                $deployItem.HasPendingInterruptions | Should Be $False
            }
        }
    }
}
