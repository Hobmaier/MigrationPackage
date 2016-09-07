# Version 1.1
# Author: Dennis Hobmaier
# Author Twitter: @DHobmaier
# This script can be used to migrate fileshares to SharePoint Online
# It requires SharePoint Online PowerShell and Office Online Sign In PowerShell http://powershell.office.com

$creds = Get-Credential "dennis.hobmaier@contoso.com" 
$sourcefilepath =   “\\smbserver\data\Management\Solutions2Share\Folder”
$packageoutputpath = “\\smbserver\data\Management\Solutions2Share\_Migration\Package” #Temp
$packageoutputpathout = “\\smbserver\data\Management\Solutions2Share\_Migration\OutputPackage” #Temp


$targetweburl = “https://contoso.sharepoint.com/sites/Management/”
$targetdoclib = "Produkte"
#Optional - if needed provide a subfolder name - otherwise just comment the next line using #
$targetsubfolder = "Collaboration Manager/365"

# No spaces are allowed in contain and queue names. Only low case characters allowed
$filecontainername = "cm365payload"
$packagecontainername = "cm365migrationpackage"
$azurequeuename = “cm365spomigration”

# Wanted to do it dynamic, but library names can contain spaces - so quick and dirty
<#
$filecontainername = $targetdoclib.ToLower() + "payload"
$packagecontainername = $targetdoclib.ToLower() + "migrationpackage"
$azurequeuename = $targetdoclib.ToLower() + “spomigration”
#>

$azureaccountname = "contosostorage"
$azurestoragekey ="0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue

write-host 'New Package'
$pkg = New-SPOMigrationPackage -SourceFilesPath $sourcefilepath -OutputPackagePath $packageoutputpath -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib -TargetDocumentLibrarySubFolderPath $targetsubfolder –NoADLookup -ErrorAction Stop
write-host 'Convert Package'
$tpkg = ConvertTo-SPOMigrationTargetedPackage -SourceFilesPath $sourcefilepath -SourcePackagePath $packageoutputpath -OutputPackagePath $packageoutputpathout -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib -TargetDocumentLibrarySubFolderPath $targetsubfolder -Credentials $creds -ErrorAction stop
write-host 'Upload package'
$uploadresult = Set-SPOMigrationPackageAzureSource –SourceFilesPath $sourcefilepath –SourcepackagePath $packageoutputpathout –FileContainerName $filecontainername –PackageContainerName $packagecontainername –AzureQueueName $azurequeuename –AccountName $azureaccountname -AccountKey $azurestoragekey -ErrorAction Stop
write-host 'FileContainerUri' $uploadresult.FileContainerUri
write-host 'FileContainerUploadUri' $uploadresult.FileContainerUploadUri
write-host 'Start Migration'
$jobresult = Submit-SPOMigrationJob –TargetwebUrl $targetweburl –MigrationPackageAzureLocations $uploadresult –Credentials $creds -ErrorAction Stop
write-host $jobresult
Write-host 'Done'