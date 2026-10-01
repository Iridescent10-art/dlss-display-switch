$ErrorActionPreference = "Stop"
$root = "C:\Users\17547\Desktop\DLSS显示开关"
$repoName = "dlss-display-switch"
$repoDescription = "Windows DLSS 超分显示开关软件与源代码"
$owner = "Iridescent10-art"

$lines = @("protocol=https", "host=github.com", "")
$cred = $lines | git credential fill 2>$null
if(-not $cred){ throw "No GitHub credential found" }
$map = @{}
foreach($line in $cred){ $kv = $line -split "=",2; if($kv.Count -eq 2){ $map[$kv[0]] = $kv[1] } }
if(-not $map["username"] -or -not $map["password"]){ throw "GitHub credential is incomplete" }
$headers = @{ Authorization = "Bearer $($map["password"])"; Accept = "application/vnd.github+json"; "X-GitHub-Api-Version" = "2022-11-28" }

try {
    $repo = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/$owner/$repoName" -Headers $headers
    Write-Output "REPO_EXISTS=$($repo.full_name)"
} catch {
    $body = @{ name = $repoName; description = $repoDescription; private = $true; auto_init = $false; has_issues = $true; has_projects = $false; has_wiki = $false } | ConvertTo-Json
    $repo = Invoke-RestMethod -Method Post -Uri "https://api.github.com/user/repos" -Headers $headers -ContentType "application/json" -Body $body
    Write-Output "REPO_CREATED=$($repo.full_name)"
}

$releaseDir = Join-Path $root "release"
$regDir = Join-Path $root "reg"
New-Item -ItemType Directory -Force -Path $releaseDir,$regDir | Out-Null
Copy-Item -LiteralPath (Join-Path $root "src\DLSS超分显示开关.exe") -Destination (Join-Path $releaseDir "DLSS超分显示开关.exe") -Force
Copy-Item -LiteralPath 'C:\Users\17547\Desktop\DLSS显示开关（点击直接运行）\打开超分显示.reg' -Destination (Join-Path $regDir "打开超分显示.reg") -Force
Copy-Item -LiteralPath 'C:\Users\17547\Desktop\DLSS显示开关（点击直接运行）\关闭超分显示.reg' -Destination (Join-Path $regDir "关闭超分显示.reg") -Force

$readme = @(
    '# DLSS 超分显示开关',
    '',
    '一个用于切换 NVIDIA DLSS 超分状态指示器的 Windows 小工具。',
    '',
    '## 使用方法',
    '',
    '1. 下载 `release/DLSS超分显示开关.exe`。',
    '2. 右键选择“以管理员身份运行”。',
    '3. 点击“打开超分显示”或“关闭超分显示”。',
    '4. 如果游戏正在运行，请重新启动游戏后查看效果。',
    '',
    '## 功能',
    '',
    '- 图形化显示当前状态',
    '- 一键写入注册表：`HKLM\\SOFTWARE\\NVIDIA Corporation\\Global\\NGXCore\\ShowDlssIndicator`',
    '- 无需分别导入两个注册表文件',
    '',
    '## 文件说明',
    '',
    '- `src/Program.cs`：C# WinForms 源代码',
    '- `release/DLSS超分显示开关.exe`：可直接运行的程序',
    '- `reg/`：原始注册表脚本'
) -join [Environment]::NewLine
Set-Content -LiteralPath (Join-Path $root "README.md") -Value $readme -Encoding UTF8

Set-Location $root
if(-not (Test-Path ".git")){ git init -b main | Out-Null }
git config user.name $owner
git config user.email "$owner@users.noreply.github.com"
git add .
git commit -m "Add DLSS indicator switcher" | Out-Null

git remote remove origin 2>$null
git remote add origin "https://github.com/$owner/$repoName.git"
$env:GIT_TERMINAL_PROMPT = "0"
git push -u origin main
if($LASTEXITCODE -ne 0){ throw "git push failed" }

try {
    $release = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/$owner/$repoName/releases/tags/v1.0.0" -Headers $headers
    Write-Output "RELEASE_EXISTS=$($release.html_url)"
} catch {
    $releaseBody = @{ tag_name = "v1.0.0"; name = "v1.0.0"; body = "DLSS 超分显示开关首个版本。"; draft = $false; prerelease = $false } | ConvertTo-Json
    $release = Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/$owner/$repoName/releases" -Headers $headers -ContentType "application/json" -Body $releaseBody
    Write-Output "RELEASE_CREATED=$($release.html_url)"
}

$assetPath = Join-Path $releaseDir "DLSS超分显示开关.exe"
$assetName = "DLSS超分显示开关.exe"
try {
    $asset = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/$owner/$repoName/releases/$($release.id)/assets" -Headers $headers | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if($asset){ Write-Output "ASSET_EXISTS=$($asset.browser_download_url)" }
    else {
        $bytes = [System.IO.File]::ReadAllBytes($assetPath)
        $uploadHeaders = $headers.Clone()
        $uploadHeaders["Content-Type"] = "application/octet-stream"
        $asset = Invoke-RestMethod -Method Post -Uri "https://uploads.github.com/repos/$owner/$repoName/releases/$($release.id)/assets?name=$([Uri]::EscapeDataString($assetName))" -Headers $uploadHeaders -Body $bytes
        Write-Output "ASSET_UPLOADED=$($asset.browser_download_url)"
    }
} catch {
    Write-Output "ASSET_ERROR=$($_.Exception.Message)"
}

Write-Output "REPO_URL=$($repo.html_url)"
Write-Output "RELEASE_URL=$($release.html_url)"
