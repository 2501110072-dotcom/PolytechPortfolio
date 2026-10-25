# 사진과 석고상 3D 파일을 HTML 하나에 모두 넣어, 인트로가 다른 세 가지 파일을 만듭니다.
#   frame-beyond-v3-ticket.html : 티켓 빠각 → 길거리 포스터 → 포스터가 창이 되어 전시장으로
#   frame-beyond-v3-frame.html  : 길거리 포스터 → 포스터 창 너머 금색 액자 → 와장창 → 전시장
#   frame-beyond-v3-combo.html  : 티켓 빠각 → 길거리 포스터 → 금색 액자 → 와장창 → 전시장 (조금 더 빠르게, 저절로 넘어감)
# 사용법: html 폴더에서 PowerShell을 열고  .\build.ps1  (또는 powershell -ExecutionPolicy Bypass -File build.ps1)
# 수정은 src\index.html에서 하고, 다 고친 뒤 이 스크립트를 다시 돌리면 됩니다.
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'src'
$base = [IO.File]::ReadAllText((Join-Path $src 'index.html'), [Text.Encoding]::UTF8)
$mime = @{ '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.png' = 'image/png'; '.webp' = 'image/webp'; '.glb' = 'model/gltf-binary' }
$embed = [Text.RegularExpressions.MatchEvaluator] {
  param($m)
  $file = Join-Path $src $m.Groups[1].Value
  if (-not (Test-Path $file)) { throw "파일이 없습니다: $file" }
  $type = $mime[[IO.Path]::GetExtension($file).ToLower()]
  if (-not $type) { $type = 'application/octet-stream' }
  "'data:$type;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($file)) + "'"
}

foreach ($v in @(@{ mode = 'ticket'; out = 'frame-beyond-v3-ticket.html' }, @{ mode = 'frame'; out = 'frame-beyond-v3-frame.html' }, @{ mode = 'combo'; out = 'frame-beyond-v3-combo.html' })) {
  $html = $base.Replace("const INTRO_MODE = 'ticket';", "const INTRO_MODE = '$($v.mode)';")
  if ($v.mode -eq 'frame') {
    # 액자 버전에서는 티켓 사진을 쓰지 않으므로 넣지 않음 (파일 크기 절약)
    $html = [regex]::Replace($html, "(ticket|torn): 'assets/[^']+'", "`$1: ''")
  }
  $html = [regex]::Replace($html, "'(assets/[^']+)'", $embed)
  $out = Join-Path $PSScriptRoot $v.out
  [IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding $false))
  '{0} 만들었습니다 ({1:N1} MB)' -f $out, ((Get-Item $out).Length / 1MB)
}

# GitHub 배포용 (합친 버전): ..\beyond-the-frame 폴더에 index.html / css / js / assets 로 나눠서 만듭니다.
# README.md, .gitignore 같은 다른 파일은 지우지 않고 그대로 둡니다.
$gh = Join-Path (Split-Path $PSScriptRoot) 'beyond-the-frame'
foreach ($d in 'css', 'js', 'assets') { if (Test-Path (Join-Path $gh $d)) { Remove-Item (Join-Path $gh $d) -Recurse -Force } }
foreach ($d in 'css', 'js', 'assets\images', 'assets\models') { New-Item -ItemType Directory -Force (Join-Path $gh $d) | Out-Null }
$html = $base.Replace("const INTRO_MODE = 'ticket';", "const INTRO_MODE = 'combo';")
$style = [regex]::Match($html, '(?s)  <style>\r?\n(.*?)  </style>\r?\n')
$script = [regex]::Match($html, '(?s)<script>\r?\n(.*?)</script>\r?\n')
if (-not $style.Success -or -not $script.Success) { throw 'src\index.html에서 <style> 또는 <script>를 찾지 못했습니다' }
$css = $style.Groups[1].Value.TrimStart("`r", "`n")
$js = $script.Groups[1].Value.TrimStart("`r", "`n")
$js = [regex]::Replace($js, "'assets/models/(\d+)_[^']+\.glb'", "'assets/models/`$1.glb'")
$js = [regex]::Replace($js, "'assets/([^/']+)'", "'assets/images/`$1'")
# css/style.css 안에서 쓰는 이미지 주소라서 페이지 기준 전체 주소로 바꿔 둠 (그대로 두면 css 폴더 기준으로 찾음)
$js = $js.Replace('url("${ASSETS.gallery}")', 'url("${new URL(ASSETS.gallery, location.href)}")')
$html = $html.Remove($script.Index, $script.Length).Insert($script.Index, "<script src=`"js/main.js`"></script>`r`n")
$html = $html.Remove($style.Index, $style.Length).Insert($style.Index, "  <link rel=`"stylesheet`" href=`"css/style.css`">`r`n")
$utf8 = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $gh 'index.html'), $html, $utf8)
[IO.File]::WriteAllText((Join-Path $gh 'css\style.css'), $css, $utf8)
[IO.File]::WriteAllText((Join-Path $gh 'js\main.js'), $js, $utf8)
foreach ($f in Get-ChildItem (Join-Path $src 'assets') -File) { Copy-Item $f.FullName (Join-Path $gh 'assets\images') }
foreach ($f in Get-ChildItem (Join-Path $src 'assets\models') -Filter *.glb) { Copy-Item $f.FullName (Join-Path $gh ('assets\models\' + $f.Name.Substring(0, 2) + '.glb')) }
'{0} 만들었습니다 (index.html + css + js + assets)' -f $gh
