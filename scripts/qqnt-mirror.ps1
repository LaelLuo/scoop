# qq-nt GitHub 镜像 workflow 的检测+下载脚本（Actions 与本地通用）
# 逻辑：抓腾讯 windowsConfig.js 最新版 -> 与清单版本比较 -> 新版则 GetSign 签名下载并算 sha256。
# 输出（GITHUB_OUTPUT 或 stdout）：
#   skip=true            无新版
#   version=<ver>        新版本号（9.9.36.260xxx 形态）
#   hash=<sha256>        安装包哈希
#   file=<路径>          下载的安装包路径（workdir/qqnt-mirror/qqnt-<ver>-x64.exe）
# 失败原则：脚本严禁 throw（挂 Actions run），失败输出 skip=true 并打错误到 stderr。

param([string]$Root = "$PSScriptRoot/..")

$ErrorActionPreference = 'Continue'
$out = @{}
function Emit($k, $v) {
    $out[$k] = $v
    if ($env:GITHUB_OUTPUT) { Add-Content $env:GITHUB_OUTPUT "$k=$v" }
    else { Write-Host "$k=$v" }
}

function Get-WindowsConfig {
    # 优先源站：海外 runner 直连 cdn-go.cn 会拿到陈旧缓存（2026-11 实测停在 9.9.35），
    # 源站 cdn-go.cn.cloud.tc.qq.com + Host: cdn-go.cn 可取最新（Scoop Extras qq-nt 用过同一做法）。
    # 源站证书是 weixin.qq.com，与域名不符：curl -k 只作用于这一次请求，不改全局校验；
    # 取回内容仍须匹配下方 qqdl.gtimg.cn 链接正则，并受防降级保护。源站失败则回退 cdn-go.cn。
    $curl = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($curl) {
        $content = (& $curl.Source -sSk --max-time 30 -H 'Host: cdn-go.cn' -H 'Accept-Encoding: gzip' --compressed 'https://cdn-go.cn.cloud.tc.qq.com/qq-web/im.qq.com_new/latest/rainbow/windowsConfig.js' 2>$null) -join "`n"
        if ($LASTEXITCODE -eq 0 -and $content -match 'qqdl\.gtimg\.cn/qqfile/QQNT') { return $content }
        Write-Warning "源站 windowsConfig 请求失败（curl exit=$LASTEXITCODE），回退 cdn-go.cn"
    }
    $headers = @{ 'Accept-Encoding' = 'gzip' }
    (Invoke-WebRequest -Uri 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsConfig.js' -UseBasicParsing -Headers $headers).Content
}

try {
    $content = Get-WindowsConfig
    $m = [regex]::Match($content, 'https://qqdl\.gtimg\.cn/qqfile/QQNT(?:V2)?/[\d\.]+/release/[0-9a-f]+/QQ_(?<ver3>[\d\.]+)_(?<ver4>[\d]+)_x86_01\.exe')
    if (-not $m.Success) { Write-Error 'windowsConfig 无 QQNT 链接'; Emit 'skip' 'true'; exit 0 }
    $latest = "$($m.Groups['ver3'].Value).$($m.Groups['ver4'].Value)"

    $manifestPath = Join-Path $Root 'src/bucket/qq-nt.json'
    $current = (Get-Content $manifestPath -Raw | ConvertFrom-Json).version
    if ($latest -eq $current) { Emit 'skip' 'true'; exit 0 }

    # 防降级：windowsConfig.js 的 CDN 会间歇返回陈旧缓存（2026-09-18 实测返回过老版本 9.9.33），
    # 检测结果比清单还旧时视为脏数据，跳过本轮等下个周期。
    try {
        if ([version]$latest -lt [version]$current) {
            Write-Warning "检测版本 $latest 低于清单版本 $current，判定为 CDN 陈旧缓存，跳过"
            Emit 'skip' 'true'; exit 0
        }
    } catch [System.Management.Automation.RuntimeException] {
        # 四段版本号解析失败的极端形态不拦（按有新版处理）
    }

    $bare = $m.Value -replace '_x86_', '_x64_'
    $sign = Invoke-RestMethod -Uri 'https://im.qq.com/http2rpc/gotrpc/noauth/trpc.qqntv2.urlsign.UrlSign/GetSign' `
        -Method Post -ContentType 'application/json' `
        -Headers @{ 'x-oidb' = '{"uint32_command":"0x9b8e","uint32_service_type":1}' } `
        -Body (@{ url = $bare } | ConvertTo-Json -Compress)
    if ($sign.retcode -ne 0 -or -not $sign.data.url) { Write-Error "GetSign 失败 retcode=$($sign.retcode)"; Emit 'skip' 'true'; exit 0 }

    $dir = Join-Path $Root 'workdir/qqnt-mirror'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $file = Join-Path $dir "qqnt-$latest-x64.exe"
    Invoke-WebRequest -Uri $sign.data.url -OutFile $file -UseBasicParsing

    Emit 'version' $latest
    Emit 'hash' ((Get-FileHash $file -Algorithm SHA256).Hash.ToLower())
    Emit 'file' $file
} catch {
    Write-Error "qqnt-mirror 检测下载失败: $_"
    Emit 'skip' 'true'
    exit 0
}
