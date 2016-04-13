  $spfilecontainername = "sppayload"
  $sppackagecontainername = "spmigrationpackage"
  $spazurequeuename = “spspomigration”
  $spazureaccountname = "hobiblob"
  $spazurestoragekey ="1GXSdrSrMQtQ+mlUyY/ZYa/f8yx8ex16mXtEJA8VeEdYFAnk8mzyFVkU4B57szdLuBH/DdQ04N7Y3RgP9A5+hw=="
  $spuploadresult = Set-SPOMigrationPackageAzureSource –SourceFilesPath $spsourcefilepath –SourcepackagePath $sppackageoutputpath –FileContainerName $spfilecontainername –PackageContainerName $sppackagecontainername –AccountName $spazureaccountname -AccountKey $spazurestoragekey –AzureQueueName $spazurequeuename 
