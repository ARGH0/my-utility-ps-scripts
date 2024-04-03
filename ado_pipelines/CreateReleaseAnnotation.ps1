<#
.SYNOPSIS
    See https://docs.microsoft.com/en-us/azure/azure-monitor/app/annotations

.DESCRIPTION
    This function adds a release annotation using Azure CLI.

    .PARAMETER $aiResourceId
    The Resource ID to the target Application Insights resource.
    
    .PARAMETER $releaseName
    The name to give the created release annotation.

    .PARAMETER $releaseProperties
    Used to attach custom metadata to the annotation.
#>

function CreateReleaseAnnotation() {
    param(
        [parameter(Mandatory = $true)][string]$aiResourceId,
        [parameter(Mandatory = $true)][string]$releaseName,
        [parameter(Mandatory = $false)]$releaseProperties = @() 
    ) 
        
    $annotation = @{         
        Id             = [GUID]::NewGuid();
        AnnotationName = $releaseName;
        EventTime      = (Get-Date).ToUniversalTime().GetDateTimeFormats("s")[0];
        Category       = "Deployment";
        Properties     = ConvertTo-Json $releaseProperties -Compress
    }        
    $body = (ConvertTo-Json $annotation -Compress) -replace '(\\+)"', '$1$1"' -replace "`"", "`"`"" 

    az rest --method put --uri $aiResourceId --body "$($body)"
    
    if (-not $?) {
        throw "Failed to create release annotation."
    }

}