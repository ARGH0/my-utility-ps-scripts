param(
	[string]$setParametersFile
)

Write-Verbose -Verbose "Start replace parameters"
Write-Verbose -Verbose ("Path to SetParametersFile: {0}" -f $setParametersFile)

Write-Verbose -Verbose "Environment variables listed below:"
Get-ChildItem Env:

# Get the environment variables
$vars = Get-ChildItem -path env:*

# Read the setParameters file
$contents = Get-Content -Path $setParametersFile

# Create a variable to copy the (new) content
$newContents = "";

# Loop through the lines of the Parameters.xml
$contents | % {
	$line = $_

	# For every line with name="[parametername]" we check if an environment setting exists
	if ($_ -match 'name="(.+?)"') {
		
		# Fetch the setting from the environment
		$setting = Get-ChildItem -path env:* | ? { $_.Name -eq $Matches[1] }

		# If the setting exists, set the value of it in the line from the Parameters.xml
		if ($setting) {
			Write-Verbose -Verbose ("Replacing key {0} with value ""$($setting.Value)"" from environment" -f $setting.Name)

			# Overwrite the line with a line including the replaced variable
			$line = $_ -replace 'value=".+?"', "value=""$($setting.Value)"""
		}
	}

	# Add the line to the new content
	$newContents += $line + [Environment]::NewLine
}

# Overwrite the .xml file with the new content
Write-Verbose -Verbose "Overwriting SetParameters file with new values"
sc $setParametersFile -Value $newContents

Write-Verbose -Verbose "End replace parameters"