$SystemArtifactDirectory = $ENV:SYSTEM_ARTIFACTSDIRECTORY 
$BuildNumber = $ENV:RELEASE_ARTIFACTS_ BUILD NAME _BUILDNUMBER
$dacpacpath = $SystemArtifactDirectory + SOMETHIGS + '.dacpac'

$DBName = $ENV:DBName
$Instance = $Env:Instance
 
Write-Output "Checking for dbatools"
if (!(Get-Module dbatools -ListAvailable)) {
    Write-Output "No dbatools so lets install it"
    Install-Module dbatools -Scope CurrentUser -Confirm:$False -Force
    Write-Output "Installed dbatools"
}
Write-Output "Importing dbatools"
Import-Module dbatools
     
try {
    Write-Output "Creating Publish Profile"
    $Publish = New-DbaPublishProfile -SqlInstance $Instance -Database $DBName -Path $SystemArtifactDirectory
}
catch {
    $_ | Format-List -Force
    Write-Error "Failed to create publish profile "
}
    
$PublishPath = $Publish.FileName

try {
    Write-Output "Publishing DACPAC using $DacpacPath and $PublishPath"
    Write-Output "Publish-DbaDacpac -SqlInstance $Instance -Database $DBName -Path '$($dacpacpath)'  -PublishXml $PublishPath -Verbose"
    $PublishResults = Publish-DbaDacPackage -SqlInstance $Instance -Database $DBName -Path $dacpacpath -PublishXml $PublishPath -Verbose
}
catch {
    $_ | Format-List -Force
    Write-Error "Failed to publish dacpac"
}
Write-Output "$($PublishResults.Result)"
    
if ($PublishResults.Result -like '*Failed*' ) {
    Write-Error "DacPac Publish failed"
}
else {
    Write-Output "Publish succeeded"
}
    
