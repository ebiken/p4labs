// Golang example to send/receive packets on tap interface //
package main

import (
	"os"
	"os/signal"
	"syscall"
	"log"
	"net"
	"encoding/hex"
	"time"

	"github.com/vishvananda/netlink"
)

const (
	tapname = "tap00"
	tapaddr = "192.168.0.100/24"
)

func main() {
	log.Printf("Starting gotap ... tapname: %v | addr: %v\n", tapname, tapaddr)
	// Call cleanup when interupted by Ctrl+C (SIGTERM)
	clean := make(chan os.Signal)
	signal.Notify(clean, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-clean
		cleanup()
		os.Exit(1)
	}()

	// main
	tapAttrs := netlink.NewLinkAttrs()
	tapAttrs.Name = tapname
	tap := &netlink.Tuntap{
		LinkAttrs: tapAttrs,
		Mode: netlink.TUNTAP_MODE_TAP,
		Queues: 1,
	}
	if err := netlink.LinkAdd(tap); err != nil {
		log.Fatal("Error: LinkAdd(%v) %v)", tapname, err)
	}
	defer cleanup() // cleanup after normal exit

	// set ip address link up
	addr, _ := netlink.ParseAddr(tapaddr)
	netlink.AddrAdd(tap, addr)
	netlink.LinkSetUp(tap)

	log.Printf("len(tap.Fds): %v\n", len(tap.Fds))

	// go routine: Receive packet
	go func() {
		frame := make([]byte, 9000)
		for {
			// Fds: fds []*os.File
			// use for loop if there are multiple queues (tap.Queues > 1)
			//for _, file := range tap.Fds {
			file := tap.Fds[0]
			n, err := file.Read(frame)
			if err != nil {
				log.Fatal(err)
			}
			dmac := net.HardwareAddr(frame[0:6])
			smac := net.HardwareAddr(frame[6:12])
			ethtype := frame[12:14]
			log.Printf("Dst: %s\n", dmac.String())
			log.Printf("Src: %s\n", smac.String())
			log.Printf("Ethertype: %x\n", ethtype)
			log.Printf("Packet Dump:\n%s",hex.Dump(frame[:n]))
			//}
		}
	}()

	// loop to Send packet
	// ARP, Ethernet (len 6), IPv4 (len 4), Request who-has 172.20.0.241 tell 172.20.0.240, length 28
    payload := []byte{
        255,255,255,255,255,255, // dmac
        2,3,4,5,6,240, // smac
        8,6,0,1,8,0,6,4,0,1, // arp hdr (request)
        2,3,4,5,6,240, // smac
        192,168,0,254, // src ipv4
        0,0,0,0,0,0, // dmac
        192,168,0,100, // dst ipv4
    }
	file := tap.Fds[0]
	for {
		file.Write(payload)
		time.Sleep(time.Second*1)
	}

	log.Println("End of main()")
}

func cleanup() {
	log.Println("Cleanup: netlink.LinkDel(tap)")
	tap, _ := netlink.LinkByName(tapname)
	netlink.LinkDel(tap)
}
