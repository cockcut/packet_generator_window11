# ==========================================
# Raw Ethernet ARP Generator
# Windows 11 + Npcap
# ==========================================

$ErrorActionPreference = "Stop"

# ------------------------------------------
# Find Npcap
# ------------------------------------------

$npcapDll = $null
$npcapDir = $null

$candidates = @(
    "$env:WINDIR\System32\Npcap\wpcap.dll",
    "$env:WINDIR\System32\wpcap.dll"
)

foreach ($path in $candidates) {
    if (Test-Path $path) {
        $npcapDll = $path
        $npcapDir = Split-Path $path -Parent
        break
    }
}

if ($null -eq $npcapDll) {
    Write-Host ""
    Write-Host "Npcap wpcap.dll was not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Npcap first."
    Write-Host ""
    pause
    exit
}

Write-Host ""
Write-Host "Npcap:"
Write-Host "  DLL : $npcapDll"
Write-Host ""

# ------------------------------------------
# Load Npcap native API
# ------------------------------------------

if (-not ("PcapNative" -as [type])) {

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class PcapNative
{
    [DllImport("kernel32.dll",
        CharSet = CharSet.Unicode,
        SetLastError = true)]
    public static extern bool SetDllDirectory(
        string lpPathName
    );

    [DllImport("wpcap.dll",
        CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr pcap_open_live(
        [MarshalAs(UnmanagedType.LPStr)] string device,
        int snaplen,
        int promisc,
        int to_ms,
        IntPtr errbuf
    );

    [DllImport("wpcap.dll",
        CallingConvention = CallingConvention.Cdecl)]
    public static extern int pcap_sendpacket(
        IntPtr p,
        IntPtr buf,
        int size
    );

    [DllImport("wpcap.dll",
        CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr pcap_geterr(
        IntPtr p
    );

    [DllImport("wpcap.dll",
        CallingConvention = CallingConvention.Cdecl)]
    public static extern void pcap_close(
        IntPtr p
    );
}
"@
}

# Make sure Npcap DLL directory is searched first
[PcapNative]::SetDllDirectory($npcapDir) | Out-Null

# ------------------------------------------
# Find IPv4 interfaces
# ------------------------------------------

$interfaces = @(
    Get-NetIPInterface -AddressFamily IPv4 |
    Where-Object {
        $_.ConnectionState -eq "Connected" -and
        $_.InterfaceAlias -notmatch "Loopback"
    } |
    Sort-Object ifIndex
)

if ($interfaces.Count -eq 0) {

    Write-Host "No connected IPv4 interface found." -ForegroundColor Red
    pause
    exit
}

Write-Host "========================================"
Write-Host " Raw Ethernet ARP Generator"
Write-Host "========================================"
Write-Host ""
Write-Host "Available interfaces:"
Write-Host ""

foreach ($item in $interfaces) {
    Write-Host ("[{0}] {1}" -f `
        $item.ifIndex,
        $item.InterfaceAlias)
}

Write-Host ""

# ------------------------------------------
# Select interface
# ------------------------------------------

while ($true) {

    $inputIndex = Read-Host "Enter interface index"

    if ($inputIndex -match '^\d+$') {

        $selected = @(
            $interfaces |
            Where-Object {
                $_.ifIndex -eq [int]$inputIndex
            }
        )

        if ($selected.Count -eq 1) {

            $ifIndex = [int]$selected[0].ifIndex
            $interfaceName = $selected[0].InterfaceAlias

            break
        }
    }

    Write-Host "Invalid interface index." -ForegroundColor Yellow
}

# ------------------------------------------
# Get adapter
# ------------------------------------------

$adapter = Get-NetAdapter -InterfaceIndex $ifIndex -ErrorAction Stop

$interfaceGuid = $adapter.InterfaceGuid.ToString()

if ($interfaceGuid -notmatch '^\{.*\}$') {
    $interfaceGuid = "{" + $interfaceGuid + "}"
}

# Npcap device name
$npcapDevice = "\Device\NPF_$interfaceGuid"

# ------------------------------------------
# Get IPv4 address
# ------------------------------------------

$ipv4Info = @(
    Get-NetIPAddress `
        -AddressFamily IPv4 `
        -InterfaceIndex $ifIndex `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*"
    }
)

if ($ipv4Info.Count -eq 0) {

    Write-Host ""
    Write-Host "No usable IPv4 address found." -ForegroundColor Red
    pause
    exit
}

$sourceIP = $ipv4Info[0].IPAddress

# ------------------------------------------
# Get actual MAC
# ------------------------------------------

$actualMac = $adapter.MacAddress

if ([string]::IsNullOrWhiteSpace($actualMac)) {

    Write-Host ""
    Write-Host "Could not get adapter MAC address." -ForegroundColor Red
    pause
    exit
}

# ------------------------------------------
# Get actual MAC
# ------------------------------------------

$actualMac = $adapter.MacAddress

if ([string]::IsNullOrWhiteSpace($actualMac)) {

    Write-Host ""
    Write-Host "Could not get adapter MAC address." -ForegroundColor Red
    pause
    exit
}

# Normalize MAC format
$macParts = ($actualMac -replace '-', ':').Split(':')

if ($macParts.Count -ne 6) {

    Write-Host ""
    Write-Host "Invalid MAC address: $actualMac" -ForegroundColor Red
    pause
    exit
}

$actualMacBytes = New-Object byte[] 6

for ($i = 0; $i -lt 6; $i++) {

    try {
        $actualMacBytes[$i] = [Convert]::ToByte(
            $macParts[$i],
            16
        )
    }
    catch {

        Write-Host ""
        Write-Host "Failed to parse MAC address: $actualMac" `
            -ForegroundColor Red

        pause
        exit
    }
}
# ------------------------------------------
# Target IP
# ------------------------------------------

while ($true) {

    $targetIP = Read-Host "Enter target IPv4 address"

    try {

        $targetBytes = [System.Net.IPAddress]::Parse($targetIP).GetAddressBytes()

        if ($targetBytes.Length -eq 4) {
            break
        }

    }
    catch {
    }

    Write-Host "Invalid IPv4 address." -ForegroundColor Yellow
}

# ------------------------------------------
# Interval
# ------------------------------------------

while ($true) {

    $intervalInput = Read-Host "Enter interval in milliseconds"

    if ($intervalInput -match '^\d+$') {

        $intervalMs = [int]$intervalInput

        if ($intervalMs -ge 1) {
            break
        }
    }

    Write-Host "Enter a value of 1 or greater." -ForegroundColor Yellow
}

# ------------------------------------------
# MAC mode
# ------------------------------------------

Write-Host ""
Write-Host "Source MAC mode:"
Write-Host "[1] Random MAC for every packet"
Write-Host "[2] Actual interface MAC"
Write-Host ""

while ($true) {

    $macMode = Read-Host "Select MAC mode (1/2)"

    if ($macMode -eq "1" -or $macMode -eq "2") {
        break
    }

    Write-Host "Enter 1 or 2." -ForegroundColor Yellow
}

# ------------------------------------------
# Open Npcap adapter
# ------------------------------------------

$errBuf = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(256)

try {

    for ($i = 0; $i -lt 256; $i++) {
        [System.Runtime.InteropServices.Marshal]::WriteByte(
            $errBuf,
            $i,
            0
        )
    }

    # snaplen = 65535
    # promisc = 0
    # timeout = 1ms
    $pcap = [PcapNative]::pcap_open_live(
        $npcapDevice,
        65535,
        0,
        1,
        $errBuf
    )

    if ($pcap -eq [IntPtr]::Zero) {

        $errorText =
            [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi(
                $errBuf
            )

        Write-Host ""
        Write-Host "Failed to open Npcap adapter." -ForegroundColor Red
        Write-Host ""
        Write-Host "Device : $npcapDevice"
        Write-Host "Error  : $errorText"
        Write-Host ""

        pause
        exit
    }

}
finally {

    [System.Runtime.InteropServices.Marshal]::FreeHGlobal(
        $errBuf
    )
}

# ------------------------------------------
# Random generator
# ------------------------------------------

$random = New-Object System.Random

# ------------------------------------------
# Create ARP packet
# ------------------------------------------

$packet = New-Object byte[] 60

# Ethernet destination
# ff:ff:ff:ff:ff:ff

for ($i = 0; $i -lt 6; $i++) {
    $packet[$i] = 0xff
}

# Ethernet source will be filled later
# bytes 6-11

# EtherType = ARP 0x0806

$packet[12] = 0x08
$packet[13] = 0x06

# ------------------------------------------
# ARP header
# ------------------------------------------

# Hardware type = Ethernet (1)
$packet[14] = 0x00
$packet[15] = 0x01

# Protocol type = IPv4 (0x0800)
$packet[16] = 0x08
$packet[17] = 0x00

# Hardware address length = 6
$packet[18] = 0x06

# Protocol address length = 4
$packet[19] = 0x04

# Operation = Request (1)
$packet[20] = 0x00
$packet[21] = 0x01

# Sender MAC = bytes 22-27
# Sender IP  = bytes 28-31
# Target MAC = bytes 32-37
# Target IP  = bytes 38-41

# Sender IP
$sourceBytes = (
    [System.Net.IPAddress]::Parse($sourceIP).GetAddressBytes()
)

for ($i = 0; $i -lt 4; $i++) {
    $packet[28 + $i] = $sourceBytes[$i]
}

# Target MAC = 00:00:00:00:00:00
for ($i = 0; $i -lt 6; $i++) {
    $packet[32 + $i] = 0x00
}

# Target IP
for ($i = 0; $i -lt 4; $i++) {
    $packet[38 + $i] = $targetBytes[$i]
}

# ------------------------------------------
# Pin packet buffer
# ------------------------------------------

$handle = [System.Runtime.InteropServices.GCHandle]::Alloc(
    $packet,
    [System.Runtime.InteropServices.GCHandleType]::Pinned
)

$packetPtr = $handle.AddrOfPinnedObject()

# ------------------------------------------
# High resolution timer
# ------------------------------------------

$frequency = [System.Diagnostics.Stopwatch]::Frequency

$intervalTicks = [int64](
    $frequency * ($intervalMs / 1000.0)
)

if ($intervalTicks -lt 1) {
    $intervalTicks = 1
}

$nextTick = [System.Diagnostics.Stopwatch]::GetTimestamp()

# ------------------------------------------
# Start
# ------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host " ARP Generator Started"
Write-Host "========================================"
Write-Host "Interface : $interfaceName"
Write-Host "ifIndex   : $ifIndex"
Write-Host "IPv4      : $sourceIP"
Write-Host "Target    : $targetIP"
Write-Host "Interval  : $intervalMs ms"
Write-Host ""

if ($macMode -eq "1") {
    Write-Host "MAC       : Random per packet"
}
else {
    Write-Host "MAC       : $actualMac"
}

Write-Host ""
Write-Host "ARP Request:"
Write-Host "$sourceIP -> $targetIP"
Write-Host ""
Write-Host "Press Ctrl+C to stop."
Write-Host ""

$count = 0
$success = 0
$errors = 0

$statWatch = [System.Diagnostics.Stopwatch]::StartNew()
$statCount = 0

try {

    while ($true) {

        # ----------------------------------
        # Source MAC
        # ----------------------------------

        if ($macMode -eq "1") {

            $srcMac = New-Object byte[] 6

            for ($i = 0; $i -lt 6; $i++) {
                $srcMac[$i] = [byte]$random.Next(0, 256)
            }

            # Locally administered + unicast
            $srcMac[0] = [byte](
                (($srcMac[0] -band 0xFC) -bor 0x02)
            )

        }
        else {

            $srcMac = $actualMacBytes
        }

        # Ethernet Source MAC
        for ($i = 0; $i -lt 6; $i++) {
            $packet[6 + $i] = $srcMac[$i]
        }

        # ARP Sender MAC
        for ($i = 0; $i -lt 6; $i++) {
            $packet[22 + $i] = $srcMac[$i]
        }

        # ----------------------------------
        # Send raw Ethernet frame
        # ----------------------------------

        $result = [PcapNative]::pcap_sendpacket(
            $pcap,
            $packetPtr,
            60
        )

        $count++
        $statCount++

Write-Host "$sourceIP -> ARP -> $targetIP"

        if ($result -eq 0) {
            $success++
        }
        else {

            $errors++

            $errorPtr = [PcapNative]::pcap_geterr($pcap)

            if ($errorPtr -ne [IntPtr]::Zero) {

                $errorText =
                    [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi(
                        $errorPtr
                    )

                Write-Host ""
                Write-Host "Npcap send error: $errorText" `
                    -ForegroundColor Red
            }
        }

        # ----------------------------------
        # Statistics every second
        # ----------------------------------

if ($statWatch.Elapsed.TotalSeconds -ge 1) {

    $actualPps =
        $statCount / $statWatch.Elapsed.TotalSeconds

    Write-Host (
        "{0} -> ARP -> {1} | Packets: {2:N0} | PPS: {3:N0} | Errors: {4:N0}" -f `
        $sourceIP,
        $targetIP,
        $count,
        $actualPps,
        $errors
    )

    $statWatch.Restart()
    $statCount = 0
}
        # ----------------------------------
        # High resolution interval
        # ----------------------------------

        $nextTick += $intervalTicks

        while (
            [System.Diagnostics.Stopwatch]::GetTimestamp() `
            -lt $nextTick
        ) {

            # For longer intervals, sleep most of the remaining time
            $remaining =
                $nextTick -
                [System.Diagnostics.Stopwatch]::GetTimestamp()

            if ($remaining -gt ($frequency / 2000)) {

                Start-Sleep -Milliseconds 1
            }
            else {

                [System.Threading.Thread]::SpinWait(50)
            }
        }
    }
}
catch {

    Write-Host ""
    Write-Host "Stopped." -ForegroundColor Yellow
}
finally {

    if ($handle.IsAllocated) {
        $handle.Free()
    }

    if ($pcap -ne [IntPtr]::Zero) {
        [PcapNative]::pcap_close($pcap)
    }

    Write-Host ""
    Write-Host "========================================"
    Write-Host " ARP Generator Stopped"
    Write-Host "========================================"
    Write-Host "Total packets : $count"
    Write-Host "Successful    : $success"
    Write-Host "Errors        : $errors"
    Write-Host ""
}