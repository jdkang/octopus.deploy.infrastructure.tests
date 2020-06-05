param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias('url')]
    [string]
    $OctopusUrl,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias('apikey')]
    [string]
    $OctopusApiKey
)
#-----------------------------------------------------------
# init
#-----------------------------------------------------------
$basePath = (Resolve-Path "$PsScriptRoot\.." -ea 1).Path
. (Join-Path $basePath 'packages.ps1')
if(!(Load-PackagesJson -Path "$basePath\packages.json")) { throw "Could not load packages" }
#-----------------------------------------------------------
# main
#-----------------------------------------------------------
write-host "Connecting to $OctopusUrl" -f yellow
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl,$OctopusApiKey
$repo = new-object Octopus.Client.OctopusRepository $endpoint
if($repo) {
    write-host "Returning Repo Object" -f yellow
    return $repo
} else {
    throw "Error constructing Octopus Repoistory"
}