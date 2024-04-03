<#

.SYNOPSIS
ServiceManager.ps1

Manage services on a (remote) computer.

List of usable arguments:
-server   : Server machine name. (Required)
-command  : Command to run. (Required)
    Example:
        ServiceManager.ps1 -server <MachineName> -command <Command>

List of usable commands:
GET     : Search for the service
    Parameters:
        -filter           : filter to search Services with (Optional)
    Example:
        ServiceManager.ps1 -server <MachineName> -command GET -filter <filtertext>

START   : Start the service
    Parameters:
        -name           : Service Name to be used and searched on if service already exists. (Required)
    Example:
        ServiceManager.ps1 -server <MachineName> -command START -name <serviceName>

STOP    : Stop the service
    Parameters:
        -name           : Service Name to be used and searched on if service already exists. (Required)
    Example:
        ServiceManager.ps1 -server <MachineName> -command STOP -name <serviceName>

RESTART : Restart the service
    Parameters:
        -name           : Service Name to be used and searched on if service already exists. (Required)
    Example:
        ServiceManager.ps1 -server <MachineName> -command RESTART -name <serviceName>

NEW     : Create a new service
    Parameters:
        -name           : Service Name to be used and searched on if service already exists. (Required)
        -binaryPathName : The binary path to the executable to start the application with. (Required)
        -dependsOn      : Any dependencies that are needed (Optional)
        -displayName    : Display Name to show in the Services table. (Required)
        -startupType    : Choose one of the following StartupTypes: Manual, Automatic, Automatic(Delayed Start), Disabled. (Required)
        -description    : Description of the service that is being configured (Required)
        -Username       : UserAccount to run the service with.(Required)
        -UserPassword   : UserAccount password to run the service with.(Required)
    Example:
        ServiceManager.ps1 -server <MachineName> -command NEW -name <serviceName>

REMOVE  : Remove the service
    Parameters:
        -name           : Service Name to be used and searched on if service already exists. (Required)
    Example:
        ServiceManager.ps1 -server <MachineName> -command REMOVE -name <serviceName>

.DESCRIPTION
Manage services on a (remote) computer.

#>

# Get parameters
param([string]$server, [string]$command, [string]$filter, [string]$name, [string]$binaryPathName, [string]$dependsOn, [string]$displayName, [string]$startupType, [string]$description, [string]$userAccount, [string]$userPassword)

# Load ServiceController assembly, if it is not already loaded
if (-not ([appdomain]::CurrentDomain.getassemblies() |? {$_.ManifestModule -like "system.serviceprocess"})) {[void][System.Reflection.Assembly]::LoadWithPartialName('system.serviceprocess')}

# Check if a servicename is given and if the service exists
function checkServiceExists([string]$serviceName, [string]$continueWhenExists)
{
    if($serviceName -like '')
    {
        "Please provide service name."
        exit
    }

    $svcexists = 0
    $svcs = [System.ServiceProcess.ServiceController]::GetServices($server);
    foreach($svc in $svcs)
    {
        if($svc.Name -like $serviceName) {$svcexists = 1; break;}
    }
    if(!$svcexists)
    {
        "Service $serviceName does not exist on remote machine."
        if($continueWhenExists -like 'false')
        {
            exit
        }
    }
    else
    {
        "Service $serviceName does exist on remote machine."
        if($continueWhenExists -like 'true')
        {
            exit
        }
    }
}

# Start the service, if it is not already running
function startService()
{
    checkServiceExists -serviceName $name -continueWhenExists 'false'
    $serviceController = (new-Object System.ServiceProcess.ServiceController($name,$server))
    if($serviceController.Status -notlike 'Running')
    {
        $serviceController.Start()
        $name + " is starting.."
        $serviceController.WaitForStatus('Running',(new-timespan -minutes 1))
        $name + " is " + $serviceController.Status
    }
    else {"$name is already Running."}
}

# Stop the service, if it is not already stopped
function stopService()
{
    checkServiceExists -serviceName $name -continueWhenExists 'false'
    $serviceController = (new-Object System.ServiceProcess.ServiceController($name,$server))
    if($serviceController.Status -notlike 'Stopped')
    {
        $serviceController.Stop()
        $name + " is stopping.."
        $serviceController.WaitForStatus('Stopped',(new-timespan -minutes 1))
        $name + " is " + $serviceController.Status
    }
    else {"$name is already Stopped."}
}

# Create a new service, if it is not already existing
function newService()
{
    checkServiceExists -serviceName $name -continueWhenExists 'true'

    if($name -like "")
    {
        "Parameter -name is not filled."
        exit
    }
    if($binaryPathName -like "")
    {
        "Parameter -binaryPathName is not filled."
        exit
    }
    if($displayName -like "")
    {
        "Parameter -displayName is not filled."
        exit
    }
    if($startupType -like "")
    {
        "Parameter -startupType is not filled."
        exit
    }
    if($description -like "")
    {
        "Parameter -description is not filled."
        exit
    }
    if($userAccount -like "")
    {
        "Parameter -userAccount is not filled."
        exit
    }
    if($userPassword -like "")
    {
        "Parameter -userPassword is not filled."
        exit
    }

    $password = ConvertTo-SecureString $userPassword -AsPlainText -Force

    $params = @{
        Name = $name
        BinaryPathName = $binaryPathName 
        DependsOn = $dependsOn
        DisplayName = $displayName
        StartupType = $startupType
        Description = $description
        Credential = New-Object System.Management.Automation.PSCredential ($userAccount, $password)
    }

    New-Service @params
}

# Create a service without credentials
function newServiceWithoutCredentials()
{
    if($name -like "")
    {
        "Parameter -name is not filled."
        exit
    }
    if($binaryPathName -like "")
    {
        "Parameter -binaryPathName is not filled."
        exit
    }
    if($displayName -like "")
    {
        "Parameter -displayName is not filled."
        exit
    }
    if($startupType -like "")
    {
        "Parameter -startupType is not filled."
        exit
    }
    if($description -like "")
    {
        "Parameter -description is not filled."
        exit
    }

    if($userAccount -like "")
    {
        "Parameter -userAccount is not filled."
        exit
    }

    sc.exe create $name binpath= $binaryPathName type= own displayname= $displayName start= $startupType obj= $userAccount
    sc.exe description $name $description 
}

# Create a new service, if it is not already existing
function removeService()
{
    checkServiceExists -serviceName $name -continueWhenExists 'false'
    sc.exe delete $name
}

function helptext(){
    ""
    "List of usable arguments:"
    "-server   : Server machine name. (Required)"
    "-command  : Command to run. (Required)" 
    "    Example:"
    "        ServiceManager.ps1 -server <MachineName> -command <Command>"
    ""
    "List of usable commands:"
    "GET     : Search for the service"
    "    Parameters:"
    "        -filter           : filter to search Services with (Optional)"
    "    Example:"
    "        ServiceManager.ps1 -server <MachineName> -command GET -filter <filtertext>"
    ""
    "START   : Start the service"
    "    Parameters:"
    "        -name           : Service Name to be used and searched on if service already exists. (Required)"
    "    Example:"
    "        ServiceManager.ps1 -server <MachineName> -command START -name <serviceName>"
    ""
    "STOP    : Stop the service"
    "    Parameters:"
    "        -name           : Service Name to be used and searched on if service already exists. (Required)"
    "    Example:"
    "        ServiceManager.ps1 -server <MachineName> -command STOP -name <serviceName>"
    ""
    "RESTART : Restart the service"
    "    Parameters:"
    "        -name           : Service Name to be used and searched on if service already exists. (Required)"
    "    Example:"
    "        ServiceManager.ps1 -server <MachineName> -command RESTART -name <serviceName>"
    ""
    "NEW     : Create a new service"
    "    Parameters:"
    "        -name           : Service Name to be used and searched on if service already exists. (Required)"
    "        -binaryPathName : The binary path to the executable to start the application with. (Required)"
    "        -dependsOn      : Any dependencies that are needed (Optional)"
    "        -displayName    : Display Name to show in the Services table. (Required)"
    "        -startupType    : Choose one of the following StartupTypes: Manual, Automatic, Automatic(Delayed Start), Disabled. (Required)"
    "        -description    : Description of the service that is being configured (Required)"
    "        -Username       : UserAccount to run the service with.(Required)"
    "        -UserPassword   : UserAccount password to run the service with.(Required)"
    "    Example:"
    "        ServiceManager.ps1 -server <MachineName> -command NEW -name <serviceName>"
    ""
    "NEWMSA     : Create a new service and runs it as a managed service account"
    "    Parameters:"
    "        -name           : Service Name to be used and searched on if service already exists. (Required)"
    "        -binaryPathName : The binary path to the executable to start the application with. (Required)"
    "        -dependsOn      : Any dependencies that are needed (Optional)"
    "        -displayName    : Display Name to show in the Services table. (Required)"
    "        -startupType    : Choose one of the following StartupTypes: Manual, Automatic, Automatic(Delayed Start), Disabled. (Required)"
    "        -description    : Description of the service that is being configured (Required)"
    "        -Username       : UserAccount to run the service with.(Required)"
    "    Example:"
    "        ServiceManager.ps1 -server <MachineName> -command NEWMSA -name <serviceName>"
    ""    
    "REMOVE  : Remove the service"
        "    Parameters:"
    "        -name           : Service Name to be used and searched on if service already exists. (Required)"
    "    Example:"
    "        ServiceManager.ps1 -server <MachineName> -command REMOVE -name <serviceName>"
    ""
}

# Check the command parameter to determine the action to be undertaken
if($command -like '') {
    helptext
}
elseif($command -like 'GET')
{
    [System.ServiceProcess.ServiceController]::GetServices($server) | Where-Object {$_.Name -match $filter}
}
elseif($command -like 'START')
{
    startService
}
elseif($command -like 'STOP')
{
    stopService
}
elseif($command -like 'RESTART')
{
    stopService
    startService
}
elseif($command -like 'NEW')
{
    newService
    Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'"
}
elseif($command -like 'NEWMSA')
{
    newServiceWithoutCredentials
    Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'"
}
elseif($command -like 'REMOVE')
{
    removeService
    Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'"
}
elseif($command -like 'HELP')
{
    helptext
}
else
{
    "'$command' is an invalid command.";
}
