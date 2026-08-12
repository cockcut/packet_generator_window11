$ip = Read-Host "Target IP"
$interval = [int](Read-Host "Interval(ms)")

while ($true) {
    arp.exe -d $ip 2>$null
    ping.exe -4 -n 1 -w 1 $ip >$null
    Write-Host "ARP -> $ip"
    Start-Sleep -Milliseconds $interval
}