param(
    $OctopusUrl = (property OctopusUrl),
    $OctopusApiKey = (property OctopusApiKey),
    $TestFilePattern = '*',
    $TestTags = @(),
    [switch]$Squawk,
    [string]$PdServiceKey = (property PdServiceKey '')
)

$basePath = (Resolve-Path "$PsScriptRoot\.." -ea 1).Path
$buildArtifactsPath = "$basePath\buildartifacts"
$isNonInteractiveMode = [bool]([Environment]::GetCommandLineArgs() -match '-noni')

task 'Clean' {
    # create empty directory
    $emptyDirPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    mkdir $emptyDirPath -ea 0 -force | out-null
    # clean build artifacts
    if(!(Test-Path $buildArtifactsPath)) {
        mkdir $buildArtifactsPath -ea 0 -force | out-null
    } else {
        exec { & robocopy.exe $emptyDirPath $buildArtifactsPath /MIR /MT /W:5 /R:5 } @(0,2)
    }
    # remove empty directory
    remove-item -path $emptyDirPath -recurse -force -ea 0
}
task 'Octopus API Pester' {
    $outputFilePath = Join-Path $buildArtifactsPath "OctopusApi.TestResults.xml"
    $pesterSplat = @{
        script = @{
            Path = "$basePath\Tests\Octopus API Driven\$($TestFilePattern)"
            Parameters = @{
                OctopusUrl = $OctopusUrl
                OctopusApiKey = $OctopusApiKey
            }
        }
        OutputFile = $outputFilePath
        OutputFormat = 'NUnitXml'
        ExcludeTag = @('noci')
        PassThru = $True
    }
    if($TestTags.Count -gt 0) {
        $pesterSplat.Add('Tag',$TestTags)
    }
    $script:pesterResults = Invoke-Pester @pesterSplat
    Assert (Test-Path $outputFilePath) "NUnit XML File Generated"
}
task 'Squawk' {
    $pdEventsApi = "https://events.pagerduty.com/generic/2010-04-15/create_event.json"
    if([string]::IsNullOrEmpty($PdServiceKey)) {
        write-warning "PdServiceKey is empty, skipping"
        return
    }
    $squawkMap = $null
    $squawkMapPath = Join-Path $basePath 'SquawkPdMap.json'
    if(Test-Path -LiteralPath $squawkMapPath) {
        $json = (Get-Content -LiteralPath $squawkMapPath -Raw | ConvertFrom-Json)
        if($json) { $squawkMap = $json }
    }

    $failedTests = @()
    $pesterResults.TestResult |
        where-object { $_.Passed -eq $False } |
        foreach-object { $failedTests += $_ }
    write-host "$($failedTests.Count) Failed Tests"
    if($failedTests.Count -eq 0) {
        write-host "No Failed Tests"
        return
    }
    $failedGroups = $failedTests | Group-Object -Property 'Describe','Context'
    foreach($grp in $failedGroups) {
        $describe = $grp.Group[0].Describe
        $context = $grp.Group[0].Context
        $squawkObj = $null

        $pesterKey = "$($describe)::$($context)"
        $incidentDescription = "$($pesterKey) has $($grp.Group.Count) failed tests"
        $incidentKey = "$($grp.Group[0].Describe)-$($grp.Group[0].Context)-$(get-date -f 'yyyyMMddHHmmss')".Replace(' ','-')
        $finalServiceKey = $PdServiceKey
        if($squawkMap -and $squawkMap."$($describe)"."$($context)") {
            $squawkObj = $squawkMap."$($describe)"."$($context)"
            if($squawkObj.PdExtraTest) {
                $incidentDescription = "$($squawkObj.PdExtraTest) | $($incidentDescription)"
            }
            if($squawkObj.AltPdServiceKey) {
                $finalServiceKey = $squawkObj.AltPdServiceKey
            }
        }
        $alertBody = @{
            service_key = $finalServiceKey
            incident_key = $incidentKey
            event_type  = 'trigger'
            description  = $incidentDescription
            client = 'pester'
            details = $grp.Group
        }
        $alertBodyJson = $alertBody | ConvertTo-Json
        write-host "Sending Incident $($incidentKey)"
        $resp = Invoke-RestMethod -Uri $pdEventsApi -Method POST -Body $alertBodyJson -ContentType "application/json"
        $resp | fl
    }
} -If ($Squawk)

Task . 'Clean','Octopus API Pester','Squawk'