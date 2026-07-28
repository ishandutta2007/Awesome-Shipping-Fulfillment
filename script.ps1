$repos = @(
    @{ name = "Karrio"; url = "https://github.com/karrioapi/karrio"; path = "karrioapi/karrio" },
    @{ name = "Fleetbase"; url = "https://github.com/fleetbase/fleetbase"; path = "fleetbase/fleetbase" },
    @{ name = "Openship"; url = "https://github.com/openshiporg/openship"; path = "openshiporg/openship" },
    @{ name = "OpenOMS"; url = "https://github.com/openoms-org/openoms"; path = "openoms-org/openoms" },
    @{ name = "KubeRiva"; url = "https://www.kuberiva.com/"; path = "" },
    @{ name = "Sentry WMS"; url = "https://github.com/hightower-systems/sentry-wms"; path = "hightower-systems/sentry-wms" },
    @{ name = "Shippy"; url = "https://github.com/verbb/shippy"; path = "verbb/shippy" },
    @{ name = "LibreTrack"; url = "https://github.com/proninyaroslav/libretrack"; path = "proninyaroslav/libretrack" },
    @{ name = "Courier (self-hosted tracker)"; url = "https://github.com/tborychowski/courier"; path = "tborychowski/courier" },
    @{ name = "Cargomint"; url = "https://github.com/Scriptwall/cargomint"; path = "Scriptwall/cargomint" },
    @{ name = "LoadPartner TMS"; url = "https://github.com/loadpartner/tms"; path = "loadpartner/tms" }
)

$starsDict = @{}

foreach ($repo in $repos) {
    if ($repo.path -ne "") {
        try {
            $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$($repo.path)" -Headers @{ "User-Agent" = "PowerShell" }
            $starsDict[$repo.name] = $response.stargazers_count
        } catch {
            $starsDict[$repo.name] = 0
            Write-Host "Failed to fetch $($repo.path)"
        }
    } else {
        $starsDict[$repo.name] = -1
    }
}

$lines = Get-Content -Path "README.md" -Raw
$linesArray = $lines -split "`n"

$startIndex = -1
$endIndex = -1

for ($i = 0; $i -lt $linesArray.Count; $i++) {
    if ($linesArray[$i] -match "^## Open-Source GitHub Projects") {
        $startIndex = $i
    }
    if ($startIndex -ne -1 -and $linesArray[$i] -match "^### Additional Strong Open-Source Options") {
        $endIndex = $i
        break
    }
}

$sectionLines = $linesArray[($startIndex+1)..($endIndex-1)]
$items = @()
$currentItem = @()

foreach ($line in $sectionLines) {
    if ($line.Trim() -match "^- \*\*\[") {
        if ($currentItem.Count -gt 0) {
            $items += @($currentItem -join "`n")
        }
        $currentItem = @($line)
    } elseif ($currentItem.Count -gt 0) {
        $currentItem += $line
    }
}
if ($currentItem.Count -gt 0) {
    $items += @($currentItem -join "`n")
}

$parsedItems = @()
foreach ($item in $items) {
    if ($item -match "- \*\*\[(.*?)\]\((.*?)\)\*\*(.*)") {
        $name = $matches[1]
        $url = $matches[2]
        $rest = $matches[3]
        $rest = $rest -replace "\r", ""
        $rest = $rest -replace "\n", " "
        $stars = $starsDict[$name]
        
        $matchRepo = $repos | Where-Object { $_.name -eq $name }
        if ($stars -ge 0 -and $matchRepo -and $matchRepo.path -ne "") {
            $path = $matchRepo.path
            $badge = "[![GitHub stars](https://img.shields.io/github/stars/$path?style=social&color=white)](https://github.com/$path/stargazers)"
            
            # The regex matched the first line, so $rest only has the first line's remainder.
            # We need a robust way. Let's just do regex replace on the original string
            
            $newItem = $item -replace "- \*\*\[(.*?)\]\((.*?)\)\*\*", "- **[`$1`](`$2`)** $badge"
            $parsedItems += @{ stars = $stars; text = $newItem }
        } else {
            $parsedItems += @{ stars = -1; text = $item }
        }
    } else {
         $parsedItems += @{ stars = -1; text = $item }
    }
}

$sortedItems = $parsedItems | Sort-Object stars -Descending

$newLines = @($linesArray[0..$startIndex], "")
foreach ($item in $sortedItems) {
    $newLines += $item.text
}
$newLines += ""
$newLines += $linesArray[$endIndex..($linesArray.Count-1)]

$newLines -join "`n" | Set-Content -Path "README.md"
