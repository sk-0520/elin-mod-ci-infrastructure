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
        if(!(Test-Path -Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory
        }
        Copy-Item -Path $libItem.FullName -Destination $destDir
    }

}