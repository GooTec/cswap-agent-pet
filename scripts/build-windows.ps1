param([ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64')
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$Destination = Join-Path $ProjectRoot "build/windows/$Runtime"

dotnet run --project "$ProjectRoot/Windows/Checks/Checks.csproj" -c Release
if ($LASTEXITCODE -ne 0) { throw 'Windows logic checks failed.' }
dotnet publish "$ProjectRoot/Windows/ChiikawaPet.csproj" -c Release -r $Runtime --self-contained true -o $Destination
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
Copy-Item "$ProjectRoot/Windows/README.md" "$Destination/README.md" -Force
$Archive = Join-Path $ProjectRoot "build/windows/ChiikawaPet-$Runtime.zip"
Compress-Archive -Path "$Destination/*" -DestinationPath $Archive -Force
Write-Host "Windows app: $Destination/ChiikawaPet.exe"
Write-Host "Portable ZIP: $Archive"
