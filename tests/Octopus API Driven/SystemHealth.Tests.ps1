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
Describe "Tasks" -Tags @('tasks','pagerduty') {
    Context "QueuedTasks" {
        $envNames = @('Pre','DC1Demo','DC1Corp','DC1Prod','Carbon')
        $ignoreTaskDescription = '^$'
        $longQueueThresholdMin = 10
        $dtNowOffset = [System.DateTimeOffset](get-date)
        $tasks = @($repo.Tasks.GetAllActive())
        $envMap = @{}
        $repo.Environments.GetAll() | Foreach-Object { $envMap[$_.Id] = $_ }
        $queuedTasks = @($tasks |
                         where-object { !($_.Description -match $ignoreTaskDescription) -and ($_.State -eq 'Queued') } |
                         select-object *,@{N='DurationDt';E={ $dtNowOffset - $_.QueueTime }})
        $longQueuedTasks = @($queuedTasks |
                             where-object { $_.DurationDt.TotalMinutes -gt $longQueueThresholdMin } |
                             select-object *,@{N='Deployment';E={ $repo.Deployments.Get($_.Arguments['DeploymentId']) }} |
                             select-object *,@{N='Environment';E={ $envMap[$_.Deployment.EnvironmentId] }} |
                             where-object { $envNames -contains $_.Environment.Name })
        It "Should Not Have Tasks Queued > $($longQueueThresholdMin) min" {
            $longQueuedTasks.Count | Should Be 0 
        }
    }
}
Describe 'Tentacles' {
    $machines = @($repo.Machines.GetAll())
    $domain = (gwmi win32_computersystem).Domain
    Context 'DNS Records' {
        foreach($machine in $machines) {
            $hostName = $machine.Uri | Select-String -Pattern 'https:\/\/([^/]+)' | % { $_.Matches.Groups[1].Value.split(':') } | Select-Object -First 1
            $fqdn = "$($hostName)"
            if($hostName -notlike "*.$($domain)") {
                $fqdn += ".$($domain)"
            }
            It "Should Not Use IP URI: $($machine.Name)" {
                $hostName -match '^\d+\.\d+\.\d+\.\d+' | Should Be $False
            }
            It "Should have DNS Record: $($machine.Name) $($fqdn)" {
                $record = Resolve-DnsName -DnsOnly -Name $fqdn
                $record | Should Not Be $null
            }
        }
    }
}
