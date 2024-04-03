Import-Module ServerManager

function Install-ServiceAccountIfNotInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)] [string]$ServiceAccount 
    )  

    if (!(Test-ADServiceAccount $ServiceAccount) ) {
        Get-ADServiceAccount $ServiceAccount | Install-ADServiceAccount      
    }

    $output = Test-ADServiceAccount $ServiceAccount;
    Write-Host "ServiceAccount exists: $output"
}