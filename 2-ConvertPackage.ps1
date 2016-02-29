  $creds = Get-Credential "admin@tenant.onmicrosoft.com" 
    
  $tpkg = ConvertTo-SPOMigrationTargetedPackage -SourceFilesPath $sourcefilepath -SourcePackagePath $packageoutputpath -OutputPackagePath $packageoutputpathout -TargetWebUrl $targetweburl -TargetDocumentLibraryPath $targetdoclib -TargetDocumentLibrarySubFolderPath $targetsubfolder -Credentials $creds