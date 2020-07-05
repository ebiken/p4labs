# example: hostip

How to create host interface with a Golang agent.
Packet will be received by host OS interface to resolve ARP, respond to ping etc.

## How to create/send/receive packets on tap interface

Check [gotap.go](gotap.go) for an example Golang code to create/send/receive packets on tap interface.

* Run `gotap.go` and packet received on the tap interface will be shown as below.
* You can check tap interface by `ip a show tap00`
* Use tcpdump to check `gotap.go` is sending ARP request to tap00 (and it's responding)
* tap interface will be removed after stopping (Ctrl+c) the program.

```
$ sudo go run gotap.go
2020/07/06 01:40:51 Starting gotap ... tapname: tap00 | addr: 192.168.0.100/24
2020/07/06 01:40:51 len(tap.Fds): 1
2020/07/06 01:40:51 Dst: 02:03:04:05:06:f0
2020/07/06 01:40:51 Src: 66:6b:bd:e1:72:d7
2020/07/06 01:40:51 Ethertype: 0806
2020/07/06 01:40:51 Packet Dump:
00000000  02 03 04 05 06 f0 66 6b  bd e1 72 d7 08 06 00 01  |......fk..r.....|
00000010  08 00 06 04 00 02 66 6b  bd e1 72 d7 c0 a8 00 64  |......fk..r....d|
00000020  02 03 04 05 06 f0 c0 a8  00 fe                    |..........|
2020/07/06 01:40:51 Dst: 33:33:00:00:00:16
2020/07/06 01:40:51 Src: 66:6b:bd:e1:72:d7
2020/07/06 01:40:51 Ethertype: 86dd
2020/07/06 01:40:51 Packet Dump:
00000000  33 33 00 00 00 16 66 6b  bd e1 72 d7 86 dd 60 00  |33....fk..r...`.|
00000010  00 00 00 24 00 01 00 00  00 00 00 00 00 00 00 00  |...$............|
00000020  00 00 00 00 00 00 ff 02  00 00 00 00 00 00 00 00  |................|
00000030  00 00 00 00 00 16 3a 00  05 02 00 00 01 00 8f 00  |......:.........|
00000040  fb d1 00 00 00 01 04 00  00 00 ff 02 00 00 00 00  |................|
00000050  00 00 00 00 00 01 ff e1  72 d7                    |........r.|
... snip ...

$ ip a show tap00
89: tap00: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UNKNOWN group default qlen 1000
    link/ether 56:1e:2b:27:79:38 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.100/24 brd 192.168.0.255 scope global tap00
       valid_lft forever preferred_lft forever
    inet6 fe80::541e:2bff:fe27:7938/64 scope link
       valid_lft forever preferred_lft forever

$ sudo tcpdump -i tap00 -xxx -vvv -n
tcpdump: listening on tap00, link-type EN10MB (Ethernet), capture size 262144 bytes
01:47:21.840864 ARP, Ethernet (len 6), IPv4 (len 4), Request who-has 192.168.0.100 tell 192.168.0.254, length 28
        0x0000:  ffff ffff ffff 0203 0405 06f0 0806 0001
        0x0010:  0800 0604 0001 0203 0405 06f0 c0a8 00fe
        0x0020:  0000 0000 0000 c0a8 0064
01:47:21.840883 ARP, Ethernet (len 6), IPv4 (len 4), Reply 192.168.0.100 is-at e6:4b:32:09:10:b6, length 28
        0x0000:  0203 0405 06f0 e64b 3209 10b6 0806 0001
        0x0010:  0800 0604 0002 e64b 3209 10b6 c0a8 0064
        0x0020:  0203 0405 06f0 c0a8 00fe
... snip ...
```
