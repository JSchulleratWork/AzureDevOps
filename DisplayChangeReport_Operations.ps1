# Adds Change Report, Errors and Warnings and Change Script to the Summary in a build step in Azure DevOps

# Requires Build Variables of DbName and Instance for comparision
# Requires DacPac to have been created and renamed to include build number with

<#
Write-Output "Rename The DacPac to have the Build Number"
Set-Location $(build.artifactstagingdirectory)

$NewName = "DATABASE NAME.$env:BUILD_BUILDNUMBER.dacpac"

Write-Output "The New Name is $NewName "
Rename-Item -Path DBAStack.dacpac -NewName $NewName
#>
$SystemArtifactDirectory = $ENV:Build_ArtifactStagingDirectory
$SystemDefaultWorkingDirectory = $ENV:System_DefaultWorkingDirectory

$Instance = $ENV:Instance
$DBName = $Env:DBName

$BuildNumber = $env:BUILD_BUILDNUMBER
$dacpacpath = $SystemArtifactDirectory + $DBName + '.' + $BuildNumber + '.dacpac'

# path to FindSqlPackagePath
$FindSqlPackagePath =  "$SystemDefaultWorkingDirectory\Database\Deploy\FindSqlPackagePath.ps1"

Write-Output "Loading the functions from $FindSqlPackagePath"
. $FindSqlPackagePath

$SqlPackagePath = Get-SqlPackagePath

Write-Output "Using SQL Package at $SqlPackagePath "


try {
Write-Output "Generating the Change Script using the dacpac $dacpacpath against Instance $Instance and database $DBName"
& $SqlPackagePath /a:Script /sf:"$dacpacpath" /tsn:"$Instance" /tdn:"$DBNAme" /op:"$SystemArtifactDirectory\ChangeScript.sql"

Write-Output "Generating the Deploy Report using the dacpac $dacpacpath against Instance $Instance and database $DBName"
& $SqlPackagePath /a:DeployReport /sf:"$dacpacpath" /tsn:"$Instance" /tdn:"$DBNAme" /op:"$SystemArtifactDirectory\DeployReport.xml"
}
catch {
    $_ | Format-List -Force
    Write-Error "Failed to generate Scripts and Report"
}

try{
    Write-Output "Generating information for the summary in Azure Devops"
    [xml]$xml = Get-Content $SystemArtifactDirectory\DeployReport.xml

    $Type = @{Name = 'Type' ; Expression = {($_.Type -creplace  '([A-Z\W_]|\d+)(?<![a-z])',' $&').Replace('Sql','').trim()}}
    $Schema = @{Name = 'Schema' ; Expression = {$_.Value.Split('.')[0]}}
    $Object = @{Name = 'Object' ; Expression = {$_.Value.Split('.')[1..9] -join '.'}}
    
    $Operations = foreach($Operation in $xml.DeploymentReport.Operations.Operation ) {
        $Action = @{Name = 'Operation' ; Expression = {$Operation.Name}}
        foreach($Item in $Operation.Item){
            $item | Select-Object $Action,$Schema, $Object,$Type
        }
    }
    
    $Errors =  foreach($Err in $xml.DeploymentReport.Errors.Error ) {
        $Info = @{Name = 'Type' ; Expression = {"Error"}}
        foreach($Item in $Err.Item){
            $item | Select-Object $Info, *
        }
    }
    
    $Warnings =  foreach($War in $xml.DeploymentReport.Warnings.Warning ) {
        $Info = @{Name = 'Type' ; Expression = {"Warning"}}
        foreach($Item in $War.Item){
            $item | Select-Object $Info, *
        }
    }
    
    $Alerts =  foreach($Ale in $xml.DeploymentReport.Alerts.Alert ) {
        $Info = @{Name = 'Type' ; Expression = {"Error"}}
        foreach($Item in $Ale.Item){
            $item | Select-Object $Info, *
        }
    }
}
catch{
    Write-Warning "Failed when generating information for the summary"
}


$TempFile = [System.IO.Path]::GetTempFileName()
$EWA = $Errors + $Warnings + $Alerts
if($EWA.length -gt 0){
$EWA  | ConvertTo-Html -Fragment | Set-Content $Tempfile
}
else{
    "No Errors, Warnings or Alerts" | Set-Content $Tempfile
}

Write-Host "##vso[task.addattachment type=Distributedtask.Core.Summary;name="01 - Deployment Report Errors Warnings and Alerts";]$Tempfile"

$TempFile1 = [System.IO.Path]::GetTempFileName()
if($Operations.length -gt 1){
    $Operations | ConvertTo-Html -Fragment | Set-Content $Tempfile1
}
else{
    "Schema is the same, nothing to do here" | Set-Content $Tempfile1
}
Write-Host "##vso[task.addattachment type=Distributedtask.Core.Summary;name="02 - Deployment Report Actions";]$Tempfile1"

$TempFile2 = [System.IO.Path]::GetTempFileName()
Get-Content $SystemArtifactDirectory\ChangeScript.sql | set-content $Tempfile2
Write-Host "##vso[task.addattachment type=Distributedtask.Core.Summary;name="03 - Deployment Change Script";]$Tempfile2"
