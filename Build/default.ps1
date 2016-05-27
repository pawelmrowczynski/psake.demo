Include ".\Helpers.ps1"
set-psbreakpoint -script default.ps1 -variable testAssemblies
properties {
	$cleanMessage = "Cleaned!"
	$compileMessage = "Compile done"
	$testMessage = "Tests done!"
	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory = "..\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$publishedxUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedxUnitTests"
	$publishedMSTestTestsDirectory = "$temporaryOutputDirectory\_PublishedMSTestTests"



	$testResultsDirectory = "$outputDirectory\TestResults"
	$NunitTestResultsDirectory = "$testResultsDirectory\NUnit"
	$xunitTestResultsDirectory = "$testResultsDirectory\xUnit"
	$MSTestTestResultsDirectory = "$testResultsDirectory\MSTest"




	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"


	$packagesPath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagesPath "Nunit.Runners" )  + "\tools\nunit-console-x86.exe"
	$xUnitExe = (Find-PackagePath $packagesPath "xunit.runner.console" )  + "\tools\xunit.console.exe"
	$vsTestExe = (Get-ChildItem ("C:\Program Files (x86)\Microsoft Visual Studio*\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe")).FullName | Sort-Object $_ | Select -Last 1
	}  


FormatTaskName "`r`n`r`n-------Executing {0} Task ----------"

task default -depends Test

task Init -description "Initialises the build by removing previous artifacts and creating output directories"`
			-requiredVariables outputDirectory, temporaryOutputDirectory {
	Assert ("Debug", "Release" -contains $buildConfiguration) `
	"Invalid build configuration '$buildConfiguration'. Valid values are Debug or Release" `

	Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
	"Invalid build platform'$buildPlatform'. Valid values are 'x86', 'x64' and 'Any CPU'"

	#Check that all tools are available
	Write-Host "Checking that all required tools are available"
	
	Assert (Test-Path $NUnitExe) "NUnit Console could not be found"
	Assert (Test-Path $xUnitExe) "xUnit Console could not be found"
	Assert (Test-Path $vsTestExe) "vsTest Console could not be found"

	# Remove previous build results
	if (Test-Path $outputDirectory)
	{
		Write-Host "Removing output directory located at $outputDirectory"
		Remove-Item $outputDirectory -Force -Recurse
	}

	Write-Host "Creating output directory located at ..\.build"
	New-Item $outputDirectory -ItemType Directory | Out-Null

	Write-Host "Creating temporary directory located at $temporaryOutputDirectory"
	New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null
}


task Clean -description "Remove temporary files" {
	Write-Host $cleanMessage
	}


task Compile `
	-depends Init `
	-description "Compile the code" `
	-requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory {
	Write-Host "Building solution $solutionFile"
	Exec{
		msbuild $solutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"

	}
	}

task TestNunit `
	-depends Compile `
	-description "Run NUnit tests" `
	-precondition {return Test-Path $publishedNUnitTestsDirectory} `
	{

		$testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
										-publishedTestsDirectory $publishedNUnitTestsDirectory `
										-testResultsDirectory $NUnitTestResultsDirectory

		Exec { &$NUnitExe $testAssemblies /xml:$NUnitTestResultsDirectory\NUnit.xml /nologo /noshadow}

		Write-Host  $NUnitTestResultsDirectory
		
	}

task TestXunit `
	-depends Compile `
	-description "Run xUnit tests" `
	-precondition {return Test-Path $publishedxUnitTestsDirectory} `
	{
		$testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
										-publishedTestsDirectory $publishedxUnitTestsDirectory `
										-testResultsDirectory $xUnitTestResultsDirectory

		Exec { &$xUnitExe $testAssemblies -xml $xUnitTestResultsDirectory\xUnit.xml -nologo -noshadow}

		Write-Host  $xUnitTestResultsDirectory
	}
task TestMSTest `
	-depends Compile `
	-description "Run MSTest tests" `
	-precondition {return Test-Path $publishedMSTestTestsDirectory }`
	{
		$testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
										-publishedTestsDirectory $publishedMSTestTestsDirectory `
										-testResultsDirectory $MSTestTestResultsDirectory

		#vs test doesn't have any optio to change the output directory so we need to change working dir for a while
		Push-Location $MSTestTestResultsDirectory
		Exec {&$vsTestExe $testAssemblies /Logger:trx}
		Pop-Location

		#move the .trx file bak to $MSTestTestResultsDirectory
		Move-Item -Path $MSTestTestResultsDirectory\TestResults\*.trx -Destination $MSTestTestResultsDirectory\TestResults
	}



task Test `
	-depends Compile, TestNunit, TestXunit, TestMSTest `
	-description "Run unit tests"{
	Write-Host $testMessage
	}