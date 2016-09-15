# Version 1.2
# Author: Dennis Hobmaier
# Author Twitter: @DHobmaier
# This script can be used to migrate fileshares to SharePoint Online
# It requires SharePoint Online PowerShell and Office Online Sign In PowerShell http://powershell.office.com

$creds = Get-Credential "admin@tenant.onmicrosoft.com" 
$sourcefilepath =   "\\contoso-sql\Tools"
$packageoutputpath = '\\contoso-sql\migration\package' #Temp
$packageoutputpathout = '\\contoso-sql\migration\outputpackage' #Temp


$targetweburl = 'https://tenant.sharepoint.com/sites/PreDemo/'
$targetdoclib = "MVPFusionLive"
#Optional - if needed provide a subfolder name - otherwise just comment the next line using #
#$targetsubfolder = "Collaboration Manager/365"

# No spaces are allowed in contain and queue names. Only low case characters allowed
$filecontainername = "mvpfusionlivepayload"
$packagecontainername = "mvpfusionlivemigrationpackage"
$azurequeuename = 'mvpfusionlivespomigration'

# Wanted to do it dynamic, but library names can contain spaces - so quick and dirty
<#
$filecontainername = $targetdoclib.ToLower() + "payload"
$packagecontainername = $targetdoclib.ToLower() + "migrationpackage"
$azurequeuename = $targetdoclib.ToLower() + 'spomigration'
#>

$azureaccountname = "mvpfusionlive"
$azurestoragekey ="0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue

write-host 'New Package'
$pkg = New-SPOMigrationPackage -SourceFilesPath $sourcefilepath -OutputPackagePath $packageoutputpath -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib –NoAzureADLookup -ErrorAction Stop
# For Subfolder
#$pkg = New-SPOMigrationPackage -SourceFilesPath $sourcefilepath -OutputPackagePath $packageoutputpath -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib -TargetDocumentLibrarySubFolderPath $targetsubfolder –NoADLookup -ErrorAction Stop
write-host 'Convert Package'
$tpkg = ConvertTo-SPOMigrationTargetedPackage -SourceFilesPath $sourcefilepath -SourcePackagePath $packageoutputpath -OutputPackagePath $packageoutputpathout -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib -Credentials $creds -ErrorAction stop
#subfolder $tpkg = ConvertTo-SPOMigrationTargetedPackage -SourceFilesPath $sourcefilepath -SourcePackagePath $packageoutputpath -OutputPackagePath $packageoutputpathout -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib -TargetDocumentLibrarySubFolderPath $targetsubfolder -Credentials $creds -ErrorAction stop
write-host 'Upload package'
$uploadresult = Set-SPOMigrationPackageAzureSource –SourceFilesPath $sourcefilepath –SourcepackagePath $packageoutputpathout –FileContainerName $filecontainername –PackageContainerName $packagecontainername –AzureQueueName $azurequeuename –AccountName $azureaccountname -AccountKey $azurestoragekey -ErrorAction Stop
write-host 'FileContainerUri' $uploadresult.FileContainerUri
write-host 'FileContainerUploadUri' $uploadresult.FileContainerUploadUri
write-host 'Start Migration'
$jobresult = Submit-SPOMigrationJob –TargetwebUrl $targetweburl –MigrationPackageAzureLocations $uploadresult –Credentials $creds -ErrorAction Stop
write-host $jobresult
Write-host 'Done'