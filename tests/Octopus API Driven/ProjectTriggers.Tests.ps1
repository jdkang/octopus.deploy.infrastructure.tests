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

Describe "Project Triggers" -Tags @('triggers') {
    $projects = $repo.Projects.GetAll()
    $environments = $repo.Environments.GetAll()
    $ignoredEnvs = @()
    $ignoredEnvs += $repo.Environments.FindByName('Electrum')
    $ignoredEnvsIds = @($ignoredEnvs.Id)

    Context 'Project with Triggers' {
        foreach($project in $projects) {
            if($project.IsDisabled) { continue }
            $projTriggers = @($repo.ProjectTriggers.FindAll($project.Links.Triggers))
            if($projTriggers.Count -eq 0) { continue }
            $filteredEnvIds = @()
            foreach($projTrigger in $projTriggers) {
                $environments |
                    where-object {
                        ($_.ignoredEnvsIds -notcontains $_.Id) -and
                        ($filteredEnvIds -notcontains $_.Id) -and
                        (($projTrigger.EnvironmentIds.Count -eq 0) -or $projTrigger.EnvironmentIds.Contains($_.Id))
                    } |
                    foreach-object { $filteredEnvIds += $_.Id }
            }
            $dashboard = $repo.Dashboards.GetDynamicDashboard($project.Id, $filteredEnvIds)
            foreach($deploy in $dashboard.Items) {
                $env = $environments | where-object { $_.Id -eq $deploy.EnvironmentId }
                It "Should Have Successful Latest Deploy: $($project.Name) $($env.Name)" {
                    $deploy.State | Should Be 'Success'
                }
            }
        }
    }
}