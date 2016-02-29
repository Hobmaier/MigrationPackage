  $filecontainername = "payload"
  $packagecontainername = "migrationpackage"
  $azurequeuename = “spomigration”
  $azureaccountname = "azureaccountname"
  $azurestoragekey ="azurestorageaccountkey=="
  $uploadresult = Set-SPOMigrationPackageAzureSource –SourceFilesPath $sourcefilepath –SourcepackagePath $packageoutputpathout –FileContainerName $filecontainername –PackageContainerName $packagecontainername –AzureQueueName $azurequeuename –AccountName $azureaccountname -AccountKey $azurestoragekey

 