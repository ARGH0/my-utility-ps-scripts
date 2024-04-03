<#
.SYNOPSIS
    Create an error type message in the log

.DESCRIPTION
    This creates a line in the log to be understood by azure devops as an error log line.

.PARAMETER message
    The message you want to log.
#>

function Log-Error([string] $message) {
    $dateString = Get-Date -Format g
    $totalMessage = '[' + $dateString + '] ' + $message

    Write-Host "##[error]##vso[task.LogIssue type=error;]" $totalMessage
}

<#
.SYNOPSIS
    Create a warning type message in the log

.DESCRIPTION
    This creates a line in the log to be understood by azure devops as a warning log line.

.PARAMETER message
    The message you want to log.
#>

function Log-Warning([string] $message) {
    $dateString = Get-Date -Format g
    $totalMessage = '[' + $dateString + '] ' + $message

    Write-Host "##[warning]##vso[task.LogIssue type=warning;]" $totalMessage
}

<#
.SYNOPSIS
    Create a message in the log

.DESCRIPTION
    This creates a line in the log.

.PARAMETER message
    The message you want to log.
#>

function Log([string] $message) {
    $dateString = Get-Date -Format g
    $totalMessage = '[' + $dateString + '] ' + $message

    Write-Verbose $totalMessage -verbose
}