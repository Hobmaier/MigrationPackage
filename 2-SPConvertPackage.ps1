  $spcreds = Get-Credential "admin@tenant.onmicrosoft.com" 

Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue

  Connect-SPOService -Credential $spcreds -Url https://tenant-admin.sharepoint.com
  $sptpkg = ConvertTo-SPOMigrationTargetedPackage -SourceFilesPath $spsourcefilepath -SourcePackagePath $spsourcefilepath -OutputPackagePath $sppackageoutputpath -TargetWebUrl $sptargetweburl -TargetDocumentLibraryPath $sptargetdoclib

 