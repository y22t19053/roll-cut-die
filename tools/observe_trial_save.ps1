# Run BEFORE opening a trial scene. This observer launches no game and never writes a save.
[CmdletBinding()]
param([ValidatePattern('^P[0-9]{3,5}$')][Parameter(Mandatory)][string]$Participant,
      [ValidateSet('A','B')][Parameter(Mandatory)][string]$Condition,
      [ValidateSet('first','second')][Parameter(Mandatory)][string]$Order,
      [string]$SavePath = (Join-Path $env:APPDATA 'Godot/app_userdata/roll cut die/rcd/save.json'))
$ErrorActionPreference='Stop'
function Stamp { if (Test-Path -LiteralPath $SavePath -PathType Leaf) { (Get-FileHash -LiteralPath $SavePath -Algorithm SHA256).Hash } else { 'ABSENT' } }
$initial=Stamp
$started=[DateTimeOffset]::UtcNow
$root=Join-Path $env:LOCALAPPDATA 'RCD-Research/guards'
[void][IO.Directory]::CreateDirectory($root)
$file=Join-Path $root (('{0}-{1}-{2}.json' -f $Participant,$Condition,[guid]::NewGuid().ToString('N')))
$state='INTERRUPTED'; $last=$initial
function Save-Receipt { [ordered]@{participant=$Participant;condition=$Condition;order=$Order;start_utc=$started.ToString('o');checked_utc=[DateTimeOffset]::UtcNow.ToString('o');before=$initial;last_observed=$last;status=$state} | ConvertTo-Json | Set-Content -LiteralPath $file -Encoding UTF8 }
Save-Receipt
Write-Host "Guard ready ($initial). Launch only the assigned QA scene. In this terminal press Q after the game closes."
try {
    while ($true) {
        $last=Stamp
        if ($last -ne $initial) { $state='INVALID_SAVE_CHANGED'; throw 'STOP trial immediately; close the test normally. Do not restore or overwrite the save.' }
        if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Q') { $last=Stamp; if ($last -ne $initial) { $state='INVALID_SAVE_CHANGED'; throw 'STOP: final save digest differs.' }; $state='UNCHANGED'; break }
        Start-Sleep -Milliseconds 250
    }
} finally { Save-Receipt; Write-Host "Receipt: $file ($state)" }
