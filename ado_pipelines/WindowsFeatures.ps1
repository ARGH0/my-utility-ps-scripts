Import-Module ServerManager

function Install-WindowsFeatureIfNotInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)] [string]$FeatureName 
    )  

    if ((Get-WindowsOptionalFeature -FeatureName $FeatureName -Online).State -ne "Enabled") {
        Add-WindowsFeature -Name $FeatureName  –IncludeAllSubFeature
    }

    $output = (Get-WindowsOptionalFeature -FeatureName $FeatureName -Online).State -ne "Enabled";
    Write-Host "WindowsFeature enabled: $output"
}