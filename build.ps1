cls

# '[p]sake' is the same as 'psake' but $Error is not polluted
Remove-Module [p]sake

$psakeModule = (Get-ChildItem (".\packages\psake*\tools\psake.psm1")).FullName | Sort-Object $_ | select -Last 1

Import-Module $psakeModule

# You can put arguments to task in multiple lines using.
Invoke-psake -buildFile .\Build\default.ps1 `
				-taskList Package `
				-framework 4.5.2 `
				-properties @{
					"buildConfiguration" = "Debug"
					"buildPlatform" = "Any CPU"
					"testMessage" = "What am I doing"} `
				-parameters @{"solutionFile" = "..\psake.sln"}

Write-Host "Build exit code: " $LastExitCode

#Propagating the exit code so that builds actually fail when there is a problem
exit $LastExitCode			