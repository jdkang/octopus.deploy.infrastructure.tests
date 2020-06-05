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
Describe "Octopus Active Tasks" -Tags @('tasks') {
    $activeTasks = $repo.Tasks.GetAllActive()
    Context "Executing Tasks" {
        $maxInterruptedHours = 4
        $envNames = @('ProdEnv1','ProdEnv2','ProdEnv3')
        $envs = @( $envNames | % { $repo.Environments.FindByname($_) } )
        $envIds = @($envs.Id)
        $dtNowOffset = [System.DateTimeOffset](get-date)
        
        $executingInterruptedTasks = $activeTasks | where-object { $_.HasPendingInterruptions -and ($_.State -eq 'Executing') } 
        foreach ($task in $executingInterruptedTasks) {
            $deploy = $repo.Deployments.Get($task.Arguments['DeploymentId'])
            if($envIds -notcontains $deploy.EnvironmentId) { continue }
            $taskInterruptTime = ($dtNowOffset - $task.QueueTime.ToLocalTime())
            It "Should Not Be Executing and Interrupted Longer than $($maxInterruptedHours)h: $($task.Description)" {
                write-host $taskInterruptTime.TotalSeconds
                $taskInterruptTime.TotalHours | Should Not BeGreaterThan $maxInterruptedHours
            }
        }
    }
}