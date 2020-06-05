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
$octopusAuthHeader = @{ 'X-Octopus-ApiKey' = $OctopusApiKey }
$sharedState['originalcertpolicy'] = [System.Net.ServicePointManager]::CertificatePolicy
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@


#-----------------------------------------------------------
# tests
#-----------------------------------------------------------
Describe "Octopus ServerNodes" -Tags @('server') {
    $octopusServerNodes = $repo.OctopusServerNodes.GetAll()
    $domain = (gwmi win32_computersystem).domain
    Context "HA Cluster" {
        It "Should Have 1 Leader" {
            ($octopusServerNodes.Rank | where { $_ -eq 'leader' } | measure).count | Should Be 1
        }
    }
    Context "Server State" {
        $ignoreNodeNames = @('NODEFOOBAR4')
        foreach ($sn in $octopusServerNodes) {
            if($ignoreNodeNames -notcontains $sn.Name) {
                It "Should Not Be Offline: $($sn.name)" {
                    $sn.IsOffline | Should Be $false
                }
                It "Should Not Be In Maintenance Mode: $($sn.name)" {
                    $sn.IsInMaintenanceMode | Should Be $false
                }
                It "Should Have Been Seen within 30m: $($sn.name)" {
                    $lastSeenDt = (get-date $sn.LastSeen)
                    $lastSeenDelta = (get-date) - $lastSeenDt
                    $lastSeenDelta.TotalMinutes | Should Not BeGreaterThan 30
                }
            }
        }
    }
}
