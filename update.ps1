param(
    [Parameter(Mandatory)][string] $ElinPath,
    [Parameter(Mandatory)][string] $Out
)

# 出力先が無けりゃ作っとく
if (!(Test-Path -Path $Out)) {
    New-Item -Path $Out -ItemType Directory
}

# 出力先を空にする
Remove-Item -Path (Join-Path -Path $Out -ChildPath "*") -Recurse -Force

$xmlFile = Join-Path -Path $PSScriptRoot -ChildPath "source.xml"
[xml]$xml = Get-Content -Path $xmlFile

$includes = @()
foreach ($item in $xml.SelectNodes("//ItemGroup/Reference")) {
    $include = $item.Include
    $includes += $include
}

$stubs = @()
foreach ($item in $xml.SelectNodes("//stub/assembly")) {
    $name = $item.name
    $stubs += $name
}

foreach ($include in $includes) {
    $marker = "`$(ElinPath)"
    $index = $include.indexOf($marker) # これは絶対あるの！
    $markerPath = $include.Substring(0, $index + $marker.Length)
    # 正確にはワイルドカードだけど、まぁ大丈夫でしょ
    $targetBlob = $include.Substring($index + $marker.Length).TrimStart("\", "/")

    $blobPath = Join-Path -Path ($markerPath.Replace($marker, $ElinPath)) -ChildPath $targetBlob
    $libItems = Get-Item -Path $blobPath
    $destBaseDir = Split-Path -Parent $targetBlob
    foreach ($libItem in $libItems) {
        $destDir = Join-Path -Path $Out -ChildPath $destBaseDir
        if (!(Test-Path -Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory | Out-Null
        }
        Copy-Item -Path $libItem.FullName -Destination $destDir
    }
}

$stubItems = Get-ChildItem -Path $Out -Recurse | Where-Object { $stubs -contains $_.Name }

if ($stubItems) {
    Write-Output "Stub targets found:"
    $stubItems | ForEach-Object { Write-Output $_.FullName }

    $stubberProj = Join-Path -Path $PSScriptRoot -ChildPath "tools\stubber\Stubber.csproj"
    $paths = $stubItems | ForEach-Object { $_.FullName }

    Write-Output "Running stubber..."
    & dotnet run --project $stubberProj -- $paths
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Stubber failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Output "Stubber finished."
    # .dll.stub を元ファイルに置き換え
    foreach ($path in $paths) {
        $stubbed = $path + ".stub"

        Write-Output "Attempting to replace $path with $stubbed"
        Move-Item -Path $stubbed -Destination $path -Force
        Write-Output "Replaced: $path"
    }
}
else {
    Write-Output "No stub targets found."
}