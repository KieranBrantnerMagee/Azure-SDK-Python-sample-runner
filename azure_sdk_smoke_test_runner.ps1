param ($package, $pythonPath, $smoketestText, $samplePath)
# 
# This is a script for automatically setting up an env, installing a package, and running a smoketest on it.
#
# Package should be the name or location of the package.
# Python path is literally the path to the version of python to use; otherwise falls back to system python.
# smoketestText is for providing a one-off snippet of python to test. (e.g. -smoketestText="import azure-servicebus;print(azure-servicebus);")
# samplePath is for providing the filepath to a samples folder to attempt and run in the created environment. (Assumes only one layer deep.)
# 
# Improvements for the future:
# - A flag to optionally delete env when done
#
# Example call pattern: .\azure_sdk_smoke_test_runner.ps1 -package azure-servicebus -samplePath C:\Users\kibrantn\source\repos\azure-sdk-for-python\sdk\servicebus\azure-servicebus\samples\sync_samples
#


# Ensure args are properly populated, fall back to system python if one was not given.
if ( $package -eq $null) {
	echo "ERROR, PACKAGE MUST BE SPECIFIED BY NAME OR PATH"
	exit 1
}

if ( $pythonPath -eq $null) {
	$python=(get-command python).Path
	
	if ( ! $? ) {
		echo "ERROR UNABLE TO FIND DEFAULT PYTHON EXECUTABLE PATH"
		exit 1
	}

} else {
	$python=$pythonPath
}

# Populate what eversion of python we're testing, for use in file names.
$pyvers_cmd=$python+' --version'
$pyvers=Invoke-Expression $pyvers_cmd

if ( ! $? ) {
	echo "ERROR FETCHING VERSION OF SPECIFIED PYTHON EXECUTABLE"
	exit 1
}

# remove spaces from python version, make venv path.
$pyvers=$pyvers -replace ' ','-'
$venv='smoketestvenv_'+$package+'_'+$pyvers

# Set up the venv, installing the package.
echo "Creating environment $venv"
$venv_cmd=$python+' -m venv '+$venv
Invoke-Expression $venv_cmd

if ( ! $? ) {
	echo "ERROR WHILE CREATING ENVIRONMENT"
	exit 1
}

echo "Activating environment $venv"
$activate_cmd=$venv+'\Scripts\activate'
Invoke-Expression $activate_cmd

if ( ! $? ) {
	echo "ERROR WHILE ACTIVATING ENVIRONMENT"
	exit 1
}

echo "Installing package $package"
pip install $package --upgrade | Out-Null #Note: Remove the out-null if you want to see what's going on.

if ( ! $? ) {
	echo "ERROR WHILE INSTALLING PACKAGE"
	deactivate
	exit 1
}

# in leiu of that, let us provide a trivial snippet to run. (e.g. import package)
if ( ! ($smoketestText -eq $null) ) {

	# Smoketest the specified package in the specified python version.
	echo "Running smoketest text"
	$basic_import_test_cmd='python -c "'+$smoketestText+'" 2>&1' # the 2>&1 is so output redirects to stdout and we can check for error.
	$out=Invoke-Expression $basic_import_test_cmd
	if ( ! ($out -eq $null) ) {
		echo "ERROR WHEN IMPORTING PACKAGE:"
		echo $out
		deactivate
		exit 1
	}
}

if ( ! ($samplePath -eq $null) ) {

	echo "Running samples"
	
	if ( Test-Path $samplePath ) {
		if ( (Get-Item $samplePath) -is [System.IO.DirectoryInfo] ) {
			# samplePath points to a directory, run the files within it.
			# NOTE: assumes all samples are directly within the target folder.
			Get-ChildItem $samplePath -Filter *.py | Foreach-Object { 

				$sample_cmd='python '+$_.FullName+' 2>&1'
				$out=Invoke-Expression $sample_cmd
				if ( ! ($out -eq $null) ) {
					echo "ERROR WHEN RUNNING SAMPLE $_ :"
					echo $out
					deactivate
					exit 1
				}
			}
		} else {
			# samplePath points to a single file, run only it.
			$sample_cmd='python '+$samplePath+' 2>&1'
			$out=Invoke-Expression $sample_cmd
			if ( ! ($out -eq $null) ) {
				echo "ERROR WHEN RUNNING SAMPLE $samplePath :"
				echo $out
				deactivate
				exit 1
			}
		}
	} else {
		echo "ERROR ACCESSING PROVIDED SAMPLE PATH: $samplePath"
		deactivate
		exit 1
	}
	
}

# Clean up and exit.
deactivate

echo "SUCCESS"

exit 0