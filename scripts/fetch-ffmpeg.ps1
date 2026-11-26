<#
.SYNOPSIS
    下载 ffmpeg 到 windows/tools/，供下载合并功能使用。

.DESCRIPTION
    仓库不携带二进制。脚本下载官方 release essentials 构建，解出 ffmpeg.exe 放到
    windows/tools/；windows/CMakeLists.txt 的 install 规则会在下次构建时把它装到
    exe 同级。

.PARAMETER Url
    ffmpeg 压缩包地址，默认取 gyan.dev 的 release essentials。

.PARAMETER ExpectedSha256
    可选的 SHA256 校验值。填了就校验，不匹配直接失败。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/fetch-ffmpeg.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/fetch-ffmpeg.ps1 -ExpectedSha256 <hash>
#>
param(
    [string]$Url = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip',
    [string]$ExpectedSha256 = '',
    [string]$Dest = (Join-Path $PSScriptRoot '..\windows\tools')
)

$ErrorActionPreference = 'Stop'

$zip = Join-Path $env:TEMP 'videohub-ffmpeg.zip'
$extract = Join-Path $env:TEMP 'videohub-ffmpeg-extract'

Write-Host "下载: $Url"
Invoke-WebRequest -Uri $Url -OutFile $zip

if ($ExpectedSha256) {
    $actual = (Get-FileHash $zip -Algorithm SHA256).Hash
    if ($actual -ne $ExpectedSha256.ToUpperInvariant()) {
        throw "SHA256 不匹配`n  期望: $ExpectedSha256`n  实际: $actual"
    }
    Write-Host "SHA256 校验通过"
} else {
    Write-Host "未提供 -ExpectedSha256，跳过校验（SHA256: $((Get-FileHash $zip -Algorithm SHA256).Hash)）"
}

if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $extract -Force

$exe = Get-ChildItem $extract -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
if (-not $exe) { throw '压缩包里没找到 ffmpeg.exe' }

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Copy-Item $exe.FullName (Join-Path $Dest 'ffmpeg.exe') -Force
Write-Host "已放到: $(Join-Path $Dest 'ffmpeg.exe')"

& (Join-Path $Dest 'ffmpeg.exe') -hide_banner -version | Select-Object -First 1