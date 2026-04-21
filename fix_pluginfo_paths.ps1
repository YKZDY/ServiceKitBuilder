# fix_pluginfo_paths.ps1
# Rewrites LibraryPath in all plugInfo.json files under the given directory
# so that each DLL path points to ../../bin/<dll> (or ../../../../bin/<dll>
# when Root is ".").
#
# Usage: powershell -File fix_pluginfo_paths.ps1 <plugin_usd_dir>

param(
    [Parameter(Mandatory=$true)]
    [string]$Dir
)

Get-ChildItem -Path $Dir -Filter 'plugInfo.json' -Recurse | ForEach-Object {
    $f = $_.FullName
    $txt = [System.IO.File]::ReadAllText($f)

    # Skip files that don't contain a LibraryPath key
    if ($txt -notmatch '"LibraryPath"') { return }

    # Detect if Root is "." (e.g. omni_usd_live) vs ".." (everything else)
    $isRootDot = ($txt -match '"Root"\s*:\s*"\."')

    # Replace the LibraryPath value: extract the DLL filename and prepend
    # the correct relative path to the bin/ directory.
    #
    # Directory layout:
    #   servicekit/bin/<dll>
    #   servicekit/plugin/usd/<module>/resources/plugInfo.json
    #
    # Root=".." => Root resolves to plugin/usd/<module>/
    #   From there, ../../../bin/<dll> => servicekit/bin/<dll>  (3 levels up)
    # Root="."  => Root resolves to plugin/usd/<module>/resources/
    #   From there, ../../../../bin/<dll> => servicekit/bin/<dll>  (4 levels up)
    $newTxt = [regex]::Replace($txt, '("LibraryPath"\s*:\s*")([^"]+\.dll)(")', {
        param($m)
        $oldPath = $m.Groups[2].Value
        $dll = ($oldPath -split '/')[-1]
        if ($isRootDot) {
            $newPath = '../../../../bin/' + $dll
        } else {
            $newPath = '../../../bin/' + $dll
        }
        return $m.Groups[1].Value + $newPath + $m.Groups[3].Value
    })

    if ($newTxt -ne $txt) {
        [System.IO.File]::WriteAllText($f, $newTxt)
        $rel = $f.Replace($Dir + '\', '')
        Write-Host "  [FIXED] $rel"
    }
}
