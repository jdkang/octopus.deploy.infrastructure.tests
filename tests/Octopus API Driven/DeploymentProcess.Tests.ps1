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
Describe "Octopus Deployment Process" -Tags @('deployprocess') {
    # Filter projects by name
    $projectNameRegex = '.*'

    # Ignore projects if in certain Project Groups
    $skipDeployAuditGroupRegex = '^(AdminProjects|SpecialProjects|IgnoreProjects)\.?'
    $projectGroupMap = @{}
    $projectDeployProcessMap = @{}
    $projects = $repo.Projects.GetAll()
    $repo.ProjectGroups.GetAll() | foreach-object { $projectGroupMap[$_.Id] = $_ }
    # cache the DP processes first
    # this will take quite a bit of memory but should reduce on duplicate API calls
    $projects | foreach-object { 
         $dp = $repo.DeploymentProcesses.Get( $_.Links.DeploymentProcess )
         $projectDeployProcessMap[$_.Id] = $dp
    }
    Context 'Ensure Deploy Compliance Step' {
        # Filter projects by name
        $deployComplianceStepTemplate = $repo.ActionTemplates.FindByName('Deployment Compliance Check')
        $projects = $projects | where Name -match $projectNameRegex
        foreach($project in $projects) {
            $dp = $projectDeployProcessMap[$project.Id]
            $complianceCheckSteps = @()
            $dp.Steps.Actions |
                Where-Object {
                    ($_.Properties -ne $null) -and
                    $_.Properties.ContainsKey('Octopus.Action.Template.Id') -and
                    ($_.Properties['Octopus.Action.Template.Id'].Value -eq $deployComplianceStepTemplate.Id)
                } | Foreach-Object { $complianceCheckSteps += $_ }
            It "Should Have Deployment Audit Enabled: $($project.Name)" {
                $complianceCheckSteps.Count | Should Be 1
                $complianceCheckSteps[0].IsDisabled | Should Be $False
            }
        }
    }
}
