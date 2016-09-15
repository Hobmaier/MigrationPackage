# Version 1.2
# Author: Dennis Hobmaier
# Author Twitter: @DHobmaier
# This script can be used to migrate fileshares to SharePoint Online
# It requires SharePoint Online PowerShell and Office Online Sign In PowerShell http://powershell.office.com

$creds = Get-Credential "admin@tenant.onmicrosoft.com" 
$spsourcesite = "https://portal.contoso.com/projects/Hardware"
$spsourcelib = 'SharePointOnPrem'
$packageoutputpath = '\\contoso-sql\migration\package' #Temp
$spexport = '\\contoso-sql\migration\export' #Temp

$targetweburl = 'https://tenant.sharepoint.com/sites/PreDemo/'
$targetspadminurl = 'https://tenant-admin.sharepoint.com'
$targetdoclib = "MVPFusionLiveSharePoint"
#Optional - if needed provide a subfolder name - otherwise just comment the next line using #
#$targetsubfolder = "Collaboration Manager/365"

# No spaces are allowed in contain and queue names. Only low case characters allowed
$filecontainername = "mvpfusionlivesppayload"
$packagecontainername = "mvpfusionlivespmigrationpackage"
$azurequeuename = 'mvpfusionlivespspomigration'

# Wanted to do it dynamic, but library names can contain spaces - so quick and dirty
<#
$filecontainername = $targetdoclib.ToLower() + "payload"
$packagecontainername = $targetdoclib.ToLower() + "migrationpackage"
$azurequeuename = $targetdoclib.ToLower() + 'spomigration'
#>

$azureaccountname = "s2smvpfusion"
$azurestoragekey ="0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue
Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

write-host 'New Package'
# Run this on SharePoint Server
# You can run this specific line on SharePoint (or 1-SPMakePackage.ps1), comment it an proceed with the rest
$pkg = Export-spweb -Identity $spsourcesite -Path $spexport -NoFileCompression -ItemUrl $spsourcelib -verbose

#From here SharePoint on prem isn't needed 
write-host 'Convert Package'
Connect-SPOService -Credential $creds -Url $targetspadminurl
$pkg = ConvertTo-SPOMigrationTargetedPackage -SourceFilesPath $spexport -SourcePackagePath $spexport -OutputPackagePath $packageoutputpath -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib -Credentials $creds

write-host 'Upload package'
$uploadresult = Set-SPOMigrationPackageAzureSource –SourceFilesPath $spexport –SourcepackagePath $packageoutputpath –FileContainerName $filecontainername –PackageContainerName $packagecontainername –AzureQueueName $azurequeuename –AccountName $azureaccountname -AccountKey $azurestoragekey -ErrorAction Stop
write-host 'FileContainerUri' $uploadresult.FileContainerUri
write-host 'FileContainerUploadUri' $uploadresult.FileContainerUploadUri
write-host 'Start Migration'
$jobresult = Submit-SPOMigrationJob –TargetwebUrl $targetweburl –MigrationPackageAzureLocations $uploadresult –Credentials $creds -ErrorAction Stop
write-host $jobresult
Write-host 'Done'