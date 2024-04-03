$loggerFullPath = $PSScriptRoot + '\..\shared\Logger.ps1'
Import-Module $loggerFullPath

<#
.SYNOPSIS
    Checks if the mandatory variables are filled in

.DESCRIPTION
    This function verifies if the variables are filled in. The SourceServer and the TargerServer should NOT be the production server.

.PARAMETER sourceDatabaseName
    Specifies the Source Database Name to create a backup from
.PARAMETER sourceServer
    Specifies the Source Database Server where the SourceDatabase is located
.PARAMETER targetDatabaseName
    Specifies the Target Database Name to create a backup from
.PARAMETER targetServer
    Specifies the Target Database Server where the TargetDatabaseName is located
#>

function CheckVariables([string] $sourceDatabaseName,[string] $sourceServer ,[string] $targetDatabaseName,[string] $targetServer) {

    Log "##[section] Start Checking Variables"

    $CheckErrors = 0

    Log "Checking sourceDatabaseName"
    if ($sourceDatabaseName -like '') {
        Log-Error "Variable [sourceDatabaseName] can't be empty."
        $CheckErrors++
    }

    Log "Checking sourceServer"
    if ($sourceServer -like '') {
        Log-Error "Variable [sourceServer] can't be empty"
        $CheckErrors++
    }

    Log "Checking targetDatabaseName"
    if ($targetDatabaseName -like '') {
        Log-Error "Variable [targetDatabaseName] can't be empty"
        $CheckErrors++
    }

    Log "Checking targetServer"
    if ($targetServer -like '') {
        Log-Error "Variable [targetServer] can't be empty"
        $CheckErrors++
    }

    if($targetServer -like 'DS055') {
        Log-Error "Variable [targetServer] cannot be production"
        $CheckErrors++
    }

    Log "##[section] Done Checking Variables"

    if($CheckErrors -gt 0){
        Log-Error "Not all Variables are filled"
        exit 1
	}
}

<#
.SYNOPSIS
    Tries to backup the database.

.DESCRIPTION
    Tries to backup the database on the given sourceserver with to the given local location on the sourceserver.

.PARAMETER sourceDatabaseName
    Specifies the Source Database Name to create a backup from.
.PARAMETER sourceServer
    Specifies the Source Database Server where the SourceDatabase is located.
.PARAMETER sourceServerBackupFilePath
    Specifies the Source Database backup location on the source server.
.PARAMETER sourceServerBackupNetworkFilePath
    Specifies the Source Server Database backup location seen from a different server.
#>


function BackupDatabase ([string] $sourceServer,[string] $sourcedatabaseName,[string] $sourceServerBackupFilePath,[string] $sourceServerBackupNetworkFilePath) {

    $CheckErrors = 0

    if ($sourceServer -like '') {
        Log-Error "Parameter [sourceServer] can't be empty"
        $CheckErrors++
    }

    if ($sourcedatabaseName -like '') {
        Log-Error "Parameter [sourcedatabaseName] can't be empty"
        $CheckErrors++
    }

    if ($sourceServerBackupFilePath -like '') {
        Log-Error "Parameter [sourceServerBackupFilePath] can't be empty"
        $CheckErrors++
    }

    if ($sourceServerBackupNetworkFilePath -like '') {
        Log-Error "Parameter [sourceServerBackupNetworkFilePath] can't be empty"
        $CheckErrors++
    }

    if($CheckErrors -gt 0){
        Log-Error "Not all parameters are filled"
        exit 1
	}

    # Delete any existing backup
    if (Test-Path -Path $sourceServerBackupFilePath) {
        Log "Deleting backup for '$sourcedatabaseName' from Build folder"
        Remove-Item -Force $sourceServerBackupNetworkFilePath
    }

    # Load assemblies
    Log "Load Assemblies Microsoft.SqlServer.Smo And Microsoft.SqlServer.ConnectionInfo"
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo')

    # Create the backup
    Log "##[section] Start Backup"
    Log "Backing up '$sourcedatabaseName' on $sourceServer to $sourceServerBackupFilePath"
    Backup-SqlDatabase -ServerInstance $sourceServer -Database $sourcedatabaseName -BackupFile "$sourceServerBackupFilePath" -CompressionOption On -CopyOnly
    Log "Backup done..."
    Log "##[section] End Backup"
}

<#
.SYNOPSIS
    Tries to Restore the database.

.DESCRIPTION
    Tries to Restore the database on the given targetserver with to the given local location on the targetserver.

.PARAMETER targetDatabaseName
    Specifies the target Database Name to create restore for.
.PARAMETER targetServer
    Specifies the Target Database Server where the database needs to be restored on.
.PARAMETER targetServerBackupFilePath
    Specifies the Database backup location on the target server.
#>


function RestoreDatabase([string] $targetServer,[string] $targetDatabaseName,[string] $targetServerBackupFilePath) {
    # Import SqlServer to load Microsoft.SqlServer.Management.Smo.Server types
    Import-Module -Name SqlServer

    if($targetServer -like '' ) {
	    throw "Parameter [targetServer] can't be empty"
    }

    if($targetServer -like 'DS055' ) {
	    throw "Parameter [targetServer] can't be production"
    }

    if($targetDatabaseName  -like '') {
	    throw "Parameter [targetDatabaseName] can't be empty"
    }

    if($targetServerBackupFilePath -like '') {
	    throw "Parameter [targetServerBackupFilePath] can't be empty"
    }

    $serverConnection = new-object Microsoft.SqlServer.Management.Common.ServerConnection
    $serverConnection.ServerInstance = $targetServer
    $serverManagementObject = New-Object Microsoft.SqlServer.Management.Smo.Server($serverConnection)
		
	$fileLocation = $serverManagementObject.Settings.DefaultFile
	$loglocation = $serverManagementObject.Settings.DefaultLog
	if ($fileLocation.Length -eq 0) {
	    $fileLocation = $serverManagementObject.Information.MasterDBPath
	}
	if ($loglocation.Length -eq 0) {
	    $loglocation = $serverManagementObject.Information.MasterDBLogPath
	}

    try {
        # Close all connections to the target database
        Log "Closing existing connection to '$targetDatabaseName' on $targetServer"
        $serverManagementObject.KillAllProcesses($targetDatabaseName)
    } catch {}

    Log "##[section] Start restore"
    # Create the restore object
    Log "Create restore object"
    $restoreObject = new-object('Microsoft.SqlServer.Management.Smo.Restore')
    $restoreObject.Database = $targetDatabaseName

    # Create a backup 'device' (we are restoring from a 'File' backup device
    Log "Create backup device for $targetServerBackupFilePath"
    $backupDevice = new-object ('Microsoft.SqlServer.Management.Smo.BackupDeviceItem') ($targetServerBackupFilePath, 'File')
    
    $restoreObject.Devices.Add($backupDevice)

    # Set the destination file name locations 
    Log "Setting destination file locations"
    $databaseFileName = $fileLocation + '\'+ $targetDatabaseName + '_Data.mdf'
    $logFileName = $loglocation + '\'+ $targetDatabaseName + '_Log.ldf'

    # Get the filelist from the backup, set the physical filenames to use (to support renaming)
    Log "Getting backup file list"
    $fileList = $restoreObject.ReadFileList($serverManagementObject)
    foreach ($fileList in $fileList) {
        $restoreObjectfile = new-object('Microsoft.SqlServer.Management.Smo.RelocateFile')
        $restoreObjectfile.LogicalFileName = $fileList.LogicalName
        if ($fileList.Type -eq 'D') {
            $restoreObjectfile.PhysicalFileName = $databaseFileName
        } else {
            $restoreObjectfile.PhysicalFileName = $logFileName
        }
        $restoreObject.RelocateFiles.Add($restoreObjectfile)
    } 

    # And finally: Restore the database
    Log "Restoring '$targetServerBackupFilePath' to $targetServer as $targetDatabaseName"
    $restoreObject.SqlRestore($targetServer)
    Log "Restoring done!"
    Log "##[section] End Restore"
}

<#
.SYNOPSIS
    Delete the database from an server.

.DESCRIPTION
    Tries to delete the database on the given server. If it is allowed on this server.

.PARAMETER databaseName
    Specifies the Database Name to delete.
.PARAMETER server
    Specifies the Database Server where the database needs to be deleted from.
#>

function DeleteDatabase ([string] $server,[string] $databaseName) {
    # Import SqlServer to load Microsoft.SqlServer.Management.Smo.Server types
    Import-Module -Name SqlServer

    if ($server.Equals("")) {
        Log-Error "Parameter [server] can't be empty"
        throw "Parameter [server] can't be empty"
    }

    if ($databaseName.Equals("")) {
        Log-Error "Parameter [databaseName] can't be empty"
        throw "Parameter [databaseName] can't be empty"
    }

    if($server -like 'DS055' ) {
        Log-Error "Can't delete databases on the production server"
        throw "Can't delete databases on the production server"
    }

    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo')

    Log "##[section] Start Deleting"
    Log "Deleting $databaseName on $server" 

    $smoServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') -argumentlist $server
    $smoServer.Databases | select Name, Size, DataSpaceUsage, IndexSpaceUsage

    if ($smoServer.Databases[$databaseName] -ne $null) { 
        $smoServer.KillAllProcesses($databaseName)
        $smoServer.Databases[$databaseName].drop()  

        Log "Database $databaseName deleted on $server"
    } 
    else {
        Log "Database $databaseName not found on $server"
    }
    Log "##[section] End Deleting"
}

<#
.SYNOPSIS
    Copies the database backup from source server to target server.

.DESCRIPTION
    Tries to copy a database backup from the source server backup path to the target server backup path.

.PARAMETER sourceServerBackupNetworkFilePath
    Specifies the Source Server Database backup location seen from a different server.
.PARAMETER targetServerBackupNetworkFilePath
    Specifies the Target Server Database backup location seen from a different server.
#>

function CopyDatabase([string] $sourceServerBackupNetworkFilePath,[string] $targetServerBackupNetworkFilePath) {

    $CheckErrors = 0

    if ($sourceServerBackupNetworkFilePath -like '') {
        Log-Error "Parameter [sourceServerBackupNetworkFilePath] can't be empty"
        $CheckErrors++
    }

    if ($targetServerBackupNetworkFilePath -like '') {
        Log-Error "Parameter [targetServerBackupNetworkFilePath] can't be empty"
        $CheckErrors++
    }

    if($CheckErrors -gt 0){
        Log-Error "Not all parameters are filled"
        exit 1
	}
    
    Log "##[section] Start Database Copy"
    Log "$sourceServerBackupNetworkFilePath is being copied to $targetServerBackupNetworkFilePath"
    Copy-Item $sourceServerBackupNetworkFilePath $targetServerBackupNetworkFilePath -force
    Log "Database has been copied to $targetServerBackupNetworkFilePath"
    Log "##[section] End Database Copy"
}

<#
.SYNOPSIS
    Clean the database backup files from the source server and the target server.

.DESCRIPTION
    Tries to clean a database backup from the source server backup path and the target server backup path.

.PARAMETER sourceServerBackupNetworkFilePath
    Specifies the Source Server Database backup location seen from a different server.
.PARAMETER targetServerBackupNetworkFilePath
    Specifies the Target Server Database backup location seen from a different server.
#>


function Cleanup([string] $sourceServerBackupNetworkFilePath,[string] $targetServerBackupNetworkFilePath) {
    $CheckErrors = 0

    if ($sourceServerBackupNetworkFilePath -like '') {
        Log-Error "Parameter [sourceServerBackupNetworkFilePath] can't be empty"
        $CheckErrors++
    }

    if ($targetServerBackupNetworkFilePath -like '') {
        Log-Error "Parameter [targetServerBackupNetworkFilePath] can't be empty"
        $CheckErrors++
    }

    if($CheckErrors -gt 0) {
        Log-Error "Not all parameters are filled"
        exit 1
	}

    Log "##[section] Start Cleanup"

    Log "removing file on $sourceServerBackupNetworkFilePath"
    Remove-Item $sourceServerBackupNetworkFilePath

    Log("Removing backup file on $targetServerBackupNetworkFilePath")
    Remove-Item $targetServerBackupNetworkFilePath

    Log "##[section] End Cleanup"
}

<#
.SYNOPSIS
    Execute a database sql script on the given database.

.DESCRIPTION
    Tries to execute a database SQL script file on the provided datase in the provided database instance.

.PARAMETER databaseInstance
    The database instance to run the script on.
.PARAMETER databaseName
    The datebase name to run the script on.
.PARAMETER filePathToSQLScript
    The path to the sql script you want to run on the database.
#>

function ExecuteSQLScriptOnDatabase([string] $databaseInstance,[string] $databaseName, [string] $filePathToSQLScript) {
    $CheckErrors = 0

    if ($databaseInstance -like '') {
        Log-Error "Parameter [databaseInstance] can't be empty"
        $CheckErrors++
    }

    if ($databaseName -like '') {
        Log-Error "Parameter [databaseName] can't be empty"
        $CheckErrors++
    }

    if ($filePathToSQLScript -like '') {
        Log-Error "Parameter [filePathToSQLScript] can't be empty"
        $CheckErrors++
    }

    if($databaseInstance -like 'DS055' ) {
        Log-Error "Can't execute script on the production server"
        throw "Can't execute script on the production server"
    }

    if($CheckErrors -gt 0) {
        Log-Error "Not all parameters are filled"
        exit 1
	}

    Log "##[section] Starting SqlScript Execution"
    Log "$filePathToSQLScript is going to be executed on Database: $databaseName in DatabaseInstance: $databaseInstance"

    Invoke-Sqlcmd -ServerInstance $databaseInstance -Database $databaseName -InputFile $filePathToSQLScript 

    Log "##[section] End SqlScript Execution"
}
