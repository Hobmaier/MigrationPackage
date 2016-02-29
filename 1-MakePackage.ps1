
$sourcefilepath =   “\\v-sp-2013\Demodata”
$packageoutputpath = “\\v-sp-2013\Migration\Package”
$packageoutputpathout = “\\v-sp-2013\Migration\OutputPackage”
$targetweburl = “https://tenant.sharepoint.com/sites/Dennis”
$targetdoclib = "Live"
$targetsubfolder = "Office365Konferenz"
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue

$pkg = New-SPOMigrationPackage -SourceFilesPath $sourcefilepath -OutputPackagePath $packageoutputpath -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib -TargetDocumentLibrarySubFolderPath $targetsubfolder –NoADLookup