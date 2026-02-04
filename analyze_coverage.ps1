$lcov = Get-Content coverage/lcov.info
$file = ""
$lf = 0
$lh = 0
$res = @()

foreach($line in $lcov) {
    if($line -match '^SF:(.*)') {
        $file = $Matches[1]
    }
    elseif($line -match '^LF:(\d+)') {
        $lf = [int]$Matches[1]
    }
    elseif($line -match '^LH:(\d+)') {
        $lh = [int]$Matches[1]
        
        # Calculate percentage only if there are lines found
        if ($lf -gt 0) {
            $pct = ($lh / $lf) * 100
            
            # Filter criteria: < 80% coverage and not a generated file
            if ($pct -lt 80 -and $file -notmatch '\.g\.dart$') {
                $roundedPct = [Math]::Round($pct, 2)
                $res += "$roundedPct% : $file ($lh/$lf)"
            }
        }
    }
}

$res | Sort-Object { [double]($_ -split '%')[0] }
