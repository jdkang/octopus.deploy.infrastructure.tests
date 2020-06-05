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
$machines = $repo.Machines.GetAll()
$ignoreMachineRegex = "^(UnstableEnv|TestingEnv)"

Describe "Octopus Machines" -Tags @('machines') {
    Context "Machines" {
        It "Should Have Machines" {
            ($machines | measure).count | Should BeGreaterThan 0
        }
    }
    Context "Machine Deployability" {
        foreach($m in $machines) {
            $disabledDaysThreshold = 7
            $hostName = $m.Uri | Select-String -Pattern 'https:\/\/([^/]+)' | % { $_.Matches.Groups[1].Value.split(':') } | Select-Object -First 1
            if($hostName -match $ignoreMachineRegex) {
                continue
            }
            [datetimeoffset]$fromDtOffset = get-date
            $connStatus = $repo.Machines.GetConnectionStatus($m)
            $dtOffsetDelta = $fromDtOffset - $connStatus.LastChecked

            $machineNameNoDots = $m.Name.Replace(".","_")
            It "Should Not Be Offline: $($machineNameNoDots)" {
                $m.status | Should Not Be "Offline"
            }
            It "Should Not Be Disabled > $($disabledDaysThreshold) days: $($machineNameNoDots)" {
                !$m.IsDisabled -or ($dtOffsetDelta.TotalDays -lt $disabledDaysThreshold) | Should Be $True
            }
        }
    }
}
Describe "Octopus Machine State" -tags @('thumbprints') {
    Context "Thumbprints" {
        $thumbprintMap = @{}
        foreach($machine in $machines) {
            if(!$thumbprintMap.ContainsKey($machine.thumbprint)) {
                $thumbprintMap[$machine.thumbprint] = @()
            }
            $thumbprintMap[$machine.thumbprint] += $machine
        }
        foreach($key in $thumbprintMap.Keys) {
            It "Should Be Unique: $($key)" {
                $val = $thumbprintMap[$key]
                if($val.Count -gt 1) {
                    write-host "$($key) -> $($val.Name -join ',')"
                }
                $val.Count | Should Be 1
            }
        }
    }
}

Describe "Octopus Machines Nag" -Tags @('noci','machines') {
    Context "Machine Tentacle" {
        foreach($m in $machines) {
            $machineNameNoDots = $m.Name.Replace(".","_")
            It "Should Not Suggest or Require Upgrade: $($machineNameNoDots)" {
                (!$m.Endpoint.TentacleVersionDetails.UpgradeRequired -and
                 !$m.Endpoint.TentacleVersionDetails.UpgradeSuggested) |
                Should Be $True
            }
        }
    }
}
