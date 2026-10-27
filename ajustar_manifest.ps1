$p = Join-Path $PSScriptRoot 'app\android\app\src\main\AndroidManifest.xml'
$x = Get-Content $p -Raw
if ($x -notmatch 'android.permission.INTERNET') {
  $perm = '    <uses-permission android:name="android.permission.INTERNET"/>' + "`r`n" +
          '    <uses-permission android:name="android.permission.NFC"/>' + "`r`n" +
          '    <uses-feature android:name="android.hardware.nfc" android:required="false"/>' + "`r`n"
  $x = $x -replace '<application', ($perm + '    <application')
}
if ($x -notmatch 'usesCleartextTraffic') {
  $x = $x -replace '<application', '<application android:usesCleartextTraffic="true"'
}
Set-Content -Path $p -Value $x -Encoding UTF8
Write-Host 'AndroidManifest.xml ajustado.'
