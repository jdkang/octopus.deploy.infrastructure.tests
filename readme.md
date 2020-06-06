Test the state and functinoality of your Octopus Deploy instance in Powershell and Pester. Uses the powerful `Octopus.Client` .NET library to make writing tests easier.

As your org relies on Octopus Deploy more and more as an integral CI tool, it can become hard to:
- Enforce conventions
- Perform care-and-feeding tasks (e.g. "Are there any deploys in Guided Failure or never had prompts answered last night?")
- Check compliance (e.g. "Do projects have this mandatory compliance step?")
- Check for corner-cases that can really be a headache (e.g. hostnames as IPs, missing DNS records, etc) that can throw a wrench into otherwise smooth deployments.
- Alert on business-critical "overnight jobs" that may have failed.

Some featured integrations:
- Supports alerting to PagerDuty
- Exports `NUnit` compliant XML through pester which can be consumed by your build server, e.g. TeamCity, Jenkins, etc.
  - **TEAMCITY NOTE:** The TC automagic Build Feature might throw an error. In this case, you might have to use the [service messages](https://www.jetbrains.com/help/teamcity/build-script-interaction-with-teamcity.html) `importData` with `parseOutOfDate='true'`

**TOC**
- [Setup](#Setup)
  - [Environment / Requirements](#Environment--Requirements)
  - [Required Values](#Required-Values)
  - [Optional Values](#Optional-Values)
- [Build](#Build)
  - [Special Pester Tags](#Special-Pester-Tags)
  - [Sending PagerDuty Alerts](#Sending-PagerDuty-Alerts)
- [Development](#Development)
  - [Setting Up A Local Environment](#Setting-Up-A-Local-Environment)
  - [Obtaining a "repository object"](#Obtaining-a-%22repository-object%22)
  - [Pester](#Pester)
  - [Design Principles](#Design-Principles)
  - [Test Suite File Structure](#Test-Suite-File-Structure)
  - [Test Suite Layout](#Test-Suite-Layout)
- [Maintenance](#Maintenance)
  - [Updating Depedencies](#Updating-Depedencies)

# Setup
**Required Values** should be set EITHER as a(n):
- PS variable (`$var`) within scope
- Environment Variable (e.g. `setx`, `$ENV:`, TeamCity params, etc) 
  - Locally set with `.\devenv\Set-OctopusApiTestEnv.ps1`

## Environment / Requirements
Tested with:
- Powershell `5.1` (though Pester may work with PS Core)
- Windows + .NET 4.5+ (though one _could_ try swapping out the `Octopus.Client` to the .ENT Core version)
  - Right now the DLLs are hard-coded to `net45/*` in `packages.json`
- [Paket](https://fsprojects.github.io/Paket/installation.html) for dependencies, which `build.ps1` will attempt to bootstrap/locate by one of the (2) ways:
  - `.NET SDK 3.0` - will attempt to [restore](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-tool-restore) the local tool
  - `.NET SDK 2.1` - will attempt to install the global tool
  - `paket.exe` in `PATH` - for example, you could add a [TeamCity Agent Tool](https://www.jetbrains.com/help/teamcity/installing-agent-tools.html) and update `$ENV:PATH += ';%teamcity.tool.<installed_tool_ID>%` before execution.

It's very possible this might work with Dotnet Core and Linux/MacOS -- but it has not been tested.

## Required Values
 - `OctopusUrl`
- `OctopusApiKey` - [How To Create An API Key](https://octopus.com/docs/how-to/how-to-create-an-api-key)

## Optional Values
- `PdServiceKey` - The [PagerDuty Events API 1.0 API](https://v2.developer.pagerduty.com/docs/events-api) Integration Service Key. This is used when running the tests with `-Squawk`

# Build
1. Ensure the **Required Values** are populated in the session
  * [interactive sessions] You can use `devenv\Set-OctopusApiTestEnv.ps1` with a SPLAT value from your `$PROFILE` to quickly set values locally.
2. Run `build.ps1` and all dependencies will be downloaded/etc.

You can also filter a subset of tests using:
* `-TestTags @('foo')` - Filter based on specific `Describe` block tags
* `-TestFilePattern 'lifecycles*'` - Filter based on pattern appended to end of the path. The default value is `*`

## Special Pester Tags
* `noci` - will not be run by `build.ps1`
* `pagerduty` - used to denote tests that should go to pagerduty

## Sending PagerDuty Alerts
First, edit `SquawkPdMap.json` with the "matching rules" to the Pester Description/Context block names.
```
{
    "Describe": {
        "Context": {
            "PdExtraTest": "Please see wiki http://wiki.abccorp.com/p/12345"
        }
    },
```

Make sure you set `ENV:PdServiceKey`

Then run with `-Squawk` and `-TestFilePattern <pattern>`


```
 .\build.ps1 -Squawk -TestFilePattern 'PD_Squawk_AM_SEV1*'
```



**NOTE THAT**:
- Due to the way Pester runs tests, it's **advised** to use `-TestFilterPattern` which is usually set to `*` by default but will run ALL tests with such behavior regardless if their results are reported.
- `-Squawk` will use the value of `$ENV:PdServiceKey`
- Alerts will be grouped by Describe+Context block names
- **All** non-filtered, non-passing tests will generate alerts

# Development
The unit tests interact with the Octopus API using the *Octopus Client* .NET API Wrapper. You can see examples here: [Octopus Client examples in Powershell](https://github.com/OctopusDeploy/OctopusDeploy-Api/tree/master/Octopus.Client/PowerShell)

## Setting Up A Local Environment
You **should installa local version** (with **matching version** to Prod).

https://octopus.com/downloads/previous

In your `$PROFILE` you can setup hashtables to make connecting to instances easier.
```
$octopusLocal = @{
    apiKey = 'API-xxxxxxxxxxxxxxxxxxxxxxxxxx'
    url = 'http://localhost'
}
$octopusProd = @{
    apiKey = 'API-xxxxxxxxxxxxxxxxxxxxxxxxxx'
    url = 'https://octopus.contoso.local'
}

```
Remember that you have to *reload your profile into the session* after any updates
```
. $PROFILE
```

Both `devenv\Get-OctopusRepoistory.ps1` and `devenv\Set-OctopusApiTestEnv.ps1` will accept these hashtables as a [SPLAT](https://msdn.microsoft.com/en-us/powershell/reference/5.0/microsoft.powershell.core/about/about_splatting), e.g.:
```
Get-OctopusRepoistory.ps1 @octopusLocal
Set-OctopusApiTestEnv.ps1 @octopusLocal
```

## Obtaining a "repository object"
1. Ensure you have run at least `build.ps1 -PreambleOnly`
2. Obtain a repository object
```
$repo = .\devenv\Get-OctopusRepoistory.ps1 @octopusLocal
# PsReadLine 'tab' keyhandler set to 'Complete' (unix style)
λ  $repo.
Accounts                  Events                    RetentionPolicies
ActionTemplates           FeaturesConfiguration     Schedulers
Artifacts                 Feeds                     ServerStatus
Backups                   Interruptions             Subscriptions
BuiltInPackageRepository  LibraryVariableSets       TagSets
Certificates              Lifecycles                Tasks
Channels                  MachinePolicies           Teams
Client                    MachineRoles              Tenants
CommunityActionTemplates  Machines                  UserRoles
DashboardConfigurations   OctopusServerNodes        Users
Dashboards                ProjectGroups             VariableSets
Defects                   Projects                  Equals
DeploymentProcesses       ProjectTriggers           GetHashCode
Deployments               Proxies                   GetType
Environments              Releases                  ToString
```

## Pester
Tests are written in [Pester](https://github.com/pester/Pester/wiki/Pester)

## Design Principles
1. NEVER WRITE ANY DATA TO OCTOPUS
2. **Avoid** multiple heavy API calls (e.g. `.GetAll()`). Most of your tests should be in a "fetch once" and "iterate in memory" approach
3. **Avoid** `.Find()` functions as these simply iterate over entire sets using a delegate function to handle return output.

## Test Suite File Structure
Tests are structured as such:
```
tests\Octopus API Driven\
    {API Repoistory}.Tests.ps1
```
For example, tests revolving around the `$repo.machines` repoistory would be in test `Machines.Tests.ps1`

## Test Suite Layout
Tests are structured as such:
```
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
# main
#-----------------------------------------------------------
Describe "Octopus Thing" {

}
```

An example of the `Machines.Tests.ps1` main portion looks like such:
```
Describe "Octopus Machines" {
    # Note 1 API Call
    $machines = $repo.Machines.GetAll()
    Context "Machines" {
        It "Should Have Machines" {
            ($machines | measure).count | Should BeGreaterThan 0
        }
    }
    Context "Machine Health" {
        foreach($m in $machines) {
            It "Should Not Be Offline: $($m.Name)" {
                $m.status | Should Not Be "Offline"
            }
        }
    }
}
```

# Maintenance
## Updating Depedencies
1. Update the [paket.depdencies](https://fsprojects.github.io/Paket/dependencies-file.html)
2. `build\Update-PaketDeps.ps1`