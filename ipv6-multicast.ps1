# ==========================================
# IPv6 MLDv2 Multicast Test
# ==========================================

$group = [System.Net.IPAddress]::Parse("ff02::1234")

# Find connected IPv6 interfaces
$interfaces = @(Get-NetIPInterface -AddressFamily IPv6 |
    Where-Object {
        $_.ConnectionState -eq "Connected" -and
        $_.InterfaceAlias -notmatch "Loopback"
    } |
    Sort-Object ifIndex)

if ($interfaces.Count -eq 0) {
    Write-Host ""
    Write-Host "No connected IPv6 interface found." -ForegroundColor Red
    pause
    exit
}

Write-Host ""
Write-Host "========================================"
Write-Host " IPv6 MLDv2 Multicast Test"
Write-Host "========================================"
Write-Host ""
Write-Host "Available IPv6 interfaces:"
Write-Host ""

foreach ($item in $interfaces) {
    Write-Host ("[{0}] {1}" -f $item.ifIndex, $item.InterfaceAlias)
}

Write-Host ""

# Select interface
while ($true) {

    $inputIndex = Read-Host "Enter interface index"

    if ($inputIndex -match '^\d+$') {

        $selected = @(
            $interfaces |
            Where-Object { $_.ifIndex -eq [int]$inputIndex }
        )

        if ($selected.Count -eq 1) {
            $if = [int]$selected[0].ifIndex
            $interfaceName = $selected[0].InterfaceAlias
            break
        }
    }

    Write-Host "Invalid interface index." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Selected interface:"
Write-Host ("Name     : {0}" -f $interfaceName)
Write-Host ("ifIndex  : {0}" -f $if)
Write-Host ("Group    : ff02::1234")
Write-Host ""

# Select interval
while ($true) {

    $intervalInput = Read-Host "Enter interval in milliseconds"

    if ($intervalInput -match '^\d+$') {

        $interval = [int]$intervalInput

        if ($interval -ge 1) {
            break
        }
    }

    Write-Host "Enter a value of 1 or greater." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================"
Write-Host " Test started"
Write-Host "========================================"
Write-Host ("Interface : {0}" -f $interfaceName)
Write-Host ("ifIndex   : {0}" -f $if)
Write-Host ("Group     : ff02::1234")
Write-Host ("Interval  : {0} ms" -f $interval)
Write-Host "========================================"
Write-Host ""
Write-Host "Press Ctrl+C to stop."
Write-Host ""

$groupAddress = [System.Net.IPAddress]::Parse("ff02::1234")

$count = 0

while ($true) {

    $u = New-Object System.Net.Sockets.UdpClient(
        [System.Net.Sockets.AddressFamily]::InterNetworkV6
    )

    try {

        # Join multicast group
        $u.JoinMulticastGroup($if, $groupAddress)

        $count++

        Write-Host ("MLD Join  #{0}" -f $count)

        Start-Sleep -Milliseconds $interval

        # Leave multicast group
        $u.DropMulticastGroup($groupAddress)

        Write-Host ("MLD Leave #{0}" -f $count)

    }
    catch {

        Write-Host ""
        Write-Host ("ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host ""

    }
    finally {

        $u.Close()

    }

    Start-Sleep -Milliseconds $interval
}