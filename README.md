# packet_generator_window11

아래 bat,ps1파일을 동일 폴더에 넣은 다음 bat를 실행.

# arp-generator.bat arp-generator.ps1
<사용예시>
1) ARP request할 IP 지정
========================================
       IPv4 ARP Generator
========================================

Target IP:

2) 송신 간격 지정
Interval (ms):

3) 테스트 시작
Target IP : 172.16.0.99
Interval  : 100 ms

Press Ctrl+C to stop.

ARP -> 172.16.0.99
ARP -> 172.16.0.99
ARP -> 172.16.0.99
ARP -> 172.16.0.99
ARP -> 172.16.0.99
ARP -> 172.16.0.99


# ipv6-multicast.bat ipv6-multicast.ps1
<사용예시>
1) 패킷 송신할 인터페이스 선택
========================================
 IPv6 MLDv2 Multicast Test
========================================

Available IPv6 interfaces:

[21] 이더넷 2

Enter interface index:

2) 송신 간격 지정
Selected interface:
Name     : 이더넷 2
ifIndex  : 21
Group    : ff02::1234

Enter interval in milliseconds: 100

3) 테스트 시작
========================================
 Test started
========================================
Interface : 이더넷 2
ifIndex   : 21
Group     : ff02::1234
Interval  : 100 ms
========================================

Press Ctrl+C to stop.

MLD Join  #1
MLD Leave #1
MLD Join  #2
MLD Leave #2
MLD Join  #3
MLD Leave #3
MLD Join  #4

# ipv4_ipv6_mdns-generator.bat ipv4_ipv6_mdns-generator.ps1

1) 패킷 송신할 인터페이스 선택
========================================
 IPv4 / IPv6 mDNS Generator
========================================

Available interfaces:

[21] 이더넷 2

Enter interface index:

2) 송신 간격 지정
Selected interface:
  Name      : 이더넷 2
  ifIndex   : 21
  IPv4      : 172.16.0.4
  IPv6      : fe80::56fd:6150:e6eb:6cb9

Enter interval in milliseconds:

3) 테스트 시작
4) 
========================================
 mDNS Generator Started
========================================
Interface : 이더넷 2
IPv4      : 172.16.0.4
IPv6      : fe80::56fd:6150:e6eb:6cb9

IPv4 : 172.16.0.4 -> 224.0.0.251:5353
IPv6 : fe80::56fd:6150:e6eb:6cb9 -> ff02::fb:5353

Interval : 100 ms

Press Ctrl+C to stop.

Sent #1  IPv4=172.16.0.4  IPv6=fe80::56fd:6150:e6eb:6cb9
Sent #2  IPv4=172.16.0.4  IPv6=fe80::56fd:6150:e6eb:6cb9
Sent #3  IPv4=172.16.0.4  IPv6=fe80::56fd:6150:e6eb:6cb9
Sent #4  IPv4=172.16.0.4  IPv6=fe80::56fd:6150:e6eb:6cb9
Sent #5  IPv4=172.16.0.4  IPv6=fe80::56fd:6150:e6eb:6cb9
Sent #6  IPv4=172.16.0.4  IPv6=fe80::56fd:6150:e6eb:6cb9
Sent #7  IPv4=172.16.0.4  IPv6=fe80::56fd:6150:e6eb:6cb9
Sent #8  IPv4=172.16.0.4  IPv6=fe80::56fd:6150:e6eb:6cb9
