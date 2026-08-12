# ==========================================
# IPv4 / IPv6 mDNS Generator
# ==========================================

$interfaces = @(Get-NetIPInterface -AddressFamily IPv4 |
    Where-Object {
        $_.ConnectionState -eq "Connected" -and
        $_.InterfaceAlias -notmatch "Loopback"
    } |
    Sort-Object ifIndex)

if ($interfaces.Count -eq 0) {
    Write-Host "No connected network interface found." -ForegroundColor Red
    pause
    exit
}

Write-Host ""
Write-Host "========================================"
Write-Host " IPv4 / IPv6 mDNS Generator"
Write-Host "========================================"
Write-Host ""
Write-Host "Available interfaces:"
Write-Host ""

foreach ($item in $interfaces) {
    Write-Host ("[{0}] {1}" -f $item.ifIndex, $item.InterfaceAlias)
}

Write-Host ""

# Interface selection
while ($true) {

    $inputIndex = Read-Host "Enter interface index"

    if ($inputIndex -match '^\d+$') {

        $selected = @(
            $interfaces |
            Where-Object { $_.ifIndex -eq [int]$inputIndex }
        )

        if ($selected.Count -eq 1) {
            $ifIndex = [int]$selected[0].ifIndex
            $interfaceName = $selected[0].InterfaceAlias
            break
        }
    }

    Write-Host "Invalid interface index." -ForegroundColor Yellow
}

# Get IPv4 address
$ipv4 = Get-NetIPAddress `
    -AddressFamily IPv4 `
    -InterfaceIndex $ifIndex `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.PrefixOrigin -ne "WellKnown"
    } |
    Select-Object -First 1

if ($null -eq $ipv4) {
    Write-Host "No IPv4 address found." -ForegroundColor Red
    pause
    exit
}

$ipv4Address = $ipv4.IPAddress

# Get IPv6 link-local address
$ipv6 = Get-NetIPAddress `
    -AddressFamily IPv6 `
    -InterfaceIndex $ifIndex `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -like "fe80::*"
    } |
    Select-Object -First 1

if ($null -eq $ipv6) {
    Write-Host "No IPv6 link-local address found." -ForegroundColor Red
    pause
    exit
}

$ipv6Address = $ipv6.IPAddress.Split("%")[0]

Write-Host ""
Write-Host "Selected interface:"
Write-Host "  Name      : $interfaceName"
Write-Host "  ifIndex   : $ifIndex"
Write-Host "  IPv4      : $ipv4Address"
Write-Host "  IPv6      : $ipv6Address"
Write-Host ""

# Interval
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

# ==========================================
# Create mDNS DNS Query
# ==========================================

# DNS Header
# Transaction ID = 0000
# Flags         = 0000
# Questions     = 0001
# Answer        = 0000
# Authority     = 0000
# Additional    = 0000

$dnsHeader = [byte[]](
    0x00,0x00,
    0x00,0x00,
    0x00,0x01,
    0x00,0x00,
    0x00,0x00,
    0x00,0x00
)

# Query: _services._dns-sd._udp.local
$qname = [byte[]](
    0x09,
    0x5F,0x73,0x65,0x72,0x76,0x69,0x63,0x65,0x73,
    0x08,
    0x5F,0x64,0x6E,0x73,0x2D,0x73,0x64,
    0x04,
    0x5F,0x75,0x64,0x70,
    0x05,
    0x6C,0x6F,0x63,0x61,0x6C,
    0x00,

    # QTYPE PTR
    0x00,0x0C,

    # QCLASS IN
    0x00,0x01
)

$payload = $dnsHeader + $qname

# ==========================================
# IPv4 Socket
# ==========================================

$udp4 = New-Object System.Net.Sockets.UdpClient(
    [System.Net.Sockets.AddressFamily]::InterNetwork
)

$udp4.Client.Bind(
    (New-Object System.Net.IPEndPoint(
        [System.Net.IPAddress]::Parse($ipv4Address),
        0
    ))
)

# mDNS multicast TTL = 255
$udp4.Client.SetSocketOption(
    [System.Net.Sockets.SocketOptionLevel]::IP,
    [System.Net.Sockets.SocketOptionName]::MulticastTimeToLive,
    255
)

$endpoint4 = New-Object System.Net.IPEndPoint(
    [System.Net.IPAddress]::Parse("224.0.0.251"),
    5353
)

# ==========================================
# IPv6 Socket
# ==========================================

$udp6 = New-Object System.Net.Sockets.UdpClient(
    [System.Net.Sockets.AddressFamily]::InterNetworkV6
)

$udp6.Client.Bind(
    (New-Object System.Net.IPEndPoint(
        [System.Net.IPAddress]::Parse($ipv6Address),
        0
    ))
)

# IPv6 multicast interface
$udp6.Client.SetSocketOption(
    [System.Net.Sockets.SocketOptionLevel]::IPv6,
    [System.Net.Sockets.SocketOptionName]::MulticastInterface,
    $ifIndex
)

# Hop Limit = 255
$udp6.Client.SetSocketOption(
    [System.Net.Sockets.SocketOptionLevel]::IPv6,
    [System.Net.Sockets.SocketOptionName]::HopLimit,
    255
)

$endpoint6 = New-Object System.Net.IPEndPoint(
    [System.Net.IPAddress]::Parse("ff02::fb"),
    5353
)

$endpoint6.ScopeId = $ifIndex

# ==========================================
# Start
# ==========================================

Write-Host ""
Write-Host "========================================"
Write-Host " mDNS Generator Started"
Write-Host "========================================"
Write-Host ""
Write-Host "Interface : $interfaceName"
Write-Host "IPv4      : $ipv4Address"
Write-Host "IPv6      : $ipv6Address"
Write-Host ""
Write-Host "IPv4 : $ipv4Address -> 224.0.0.251:5353"
Write-Host "IPv6 : $ipv6Address -> ff02::fb:5353"
Write-Host ""
Write-Host "Interval : $interval ms"
Write-Host ""
Write-Host "Press Ctrl+C to stop."
Write-Host ""

$count = 0

try {

    while ($true) {

        # IPv4 mDNS
        [void]$udp4.Send(
            $payload,
            $payload.Length,
            $endpoint4
        )

        # IPv6 mDNS
        [void]$udp6.Send(
            $payload,
            $payload.Length,
            $endpoint6
        )

        $count++

        Write-Host (
            "Sent #{0}  IPv4={1}  IPv6={2}" -f
            $count,
            $ipv4Address,
            $ipv6Address
        )

        Start-Sleep -Milliseconds $interval
    }
}
catch {

    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {

    $udp4.Close()
    $udp6.Close()
}
