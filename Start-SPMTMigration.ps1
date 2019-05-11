#Define SPO target#
$Global:SPOUrl = "https://contoso.sharepoint.com/sites/SPSCGN2019SPMT"
#$Global:UserName = "admin@contoso.onmicrosoft.com"
#$Global:PassWord = ConvertTo-SecureString -String "YourSPOPassword" -AsPlainText -Force
#$Global:SPOCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Global:UserName, $Global:PassWord
$Global:SPOCredential = Get-Credential -Message 'Please provide O365 Admin account'
#Define SPO target#
$Global:TargetListName = "Files"
$Global:SourceListName = "SourceListName"
[string]$ExludeFileExtensions = 'pst' #separate with : e.g. 'pst:exe'

#Import SPMT Migration Module#
#Import-Module Microsoft.SharePoint.MigrationTool.PowerShell -ErrorAction Stop
Import-module $env:userprofile\Documents\WindowsPowerShell\Modules\Microsoft.SharePoint.MigrationTool.PowerShell\microsoft.sharepoint.migrationtool.powershell.psd1

#Register the SPMT session with SPO credentials#
Register-SPMTMigration -SPOCredential $Global:SPOCredential -Force `
    -MigrateOneNoteFolderAsOneNoteNoteBook $true `
    -SkipFilesWithExtension $ExludeFileExtensions `
    -MigrateHiddenFiles $true `
    -CustomAzureAccessKey 'yourkey' `
    -CustomAzureStorageAccount 'spmtmigration' `
    -UseCustomAzureStorage $true `
    -MigrateFilesAndFoldersWithInvalidChars $true `
    -ErrorAction Stop

#Define SharePoint 2013 data source#

$Global:SourceSiteUrl = "https://portal.contoso.com/sites/MigrationSource"

$Global:SPCredential = Get-Credential -Message 'Please provide farm admin account'


#Define File Share data source#
$Global:FileshareSource = "\\contoso-sql\tools\"

#Add two tasks into the session. One is SharePoint migration task, and another is File Share migration task.#
Add-SPMTTask -SharePointSourceCredential $Global:SPCredential -SharePointSourceSiteUrl $Global:SourceSiteUrl  -TargetSiteUrl $Global:SPOUrl -MigrateAll 
Add-SPMTTask -FileShareSource $Global:FileshareSource -TargetSiteUrl $Global:SPOUrl -TargetList $Global:TargetListName

#Start Migration in the console.#
Start-SPMTMigration

Show-SPMTMigration