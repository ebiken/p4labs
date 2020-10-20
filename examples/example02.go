/*
 * Copyright 2020 Toyota Motor Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Kentaro Ebisawa <ebisawa@toyota-tokyo.tech>
 *
 */

// Example of Golang P4Runtime Client to receive PacketIn from P4 dataplane

package main

import (
	"context"
	"encoding/hex"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net"
	"time"

	"google.golang.org/grpc"
	v1 "github.com/p4lang/p4runtime/go/p4/v1"
	config_v1 "github.com/p4lang/p4runtime/go/p4/config/v1"
	"github.com/golang/protobuf/proto"
	"github.com/pkg/errors"
)

// main -----------------------------------------------------------------------
func main() {
	var (
		p4infoFilePath    = "./build.bmv2/example02.p4info.txt"
		devconfigFilePath = "./build.bmv2/example02.json"
		grpcAddr          = "127.0.0.1:50051"
	)
	log.Println("p4info file:", p4infoFilePath)
	log.Println("BMv2 device config file:", devconfigFilePath)
	log.Println("gRPC addr:", grpcAddr)

	// Start P4Runtime process ------------------------------------------------
	var p4rtc P4RuntimeClient
	err := p4rtc.run(&grpcAddr, &devconfigFilePath, &p4infoFilePath)
	if err != nil {
		log.Printf("P4Runtime error: %v\n", err)
	}
	log.Printf("End of main()\n")
}

// P4RuntimeClient ------------------------------------------------------------
type P4RuntimeClient struct {
	client             v1.P4RuntimeClient
	stream             v1.P4Runtime_StreamChannelClient
	deviceid           uint64
	electionid         v1.Uint128
	sendStreamMessages chan interface{}
	recvStreamMessages chan interface{}
}

var streamChErrors = make(chan error)

func (p P4RuntimeClient) run(grpcAddr *string, devconfigFilePath *string, p4infoFilePath *string) error {
	var (
		err  error
		conn *grpc.ClientConn
	)
	log.Println("------ P4RuntimeClinet run(): start ---------------------------------")

	// P4RuntimeClient Initialization -----------------------------------------
	// gRPC: connect to P4Runtime port
	conn, err = grpc.Dial(*grpcAddr, grpc.WithInsecure())
	if err != nil {
		log.Printf("| gRPC connection error: %v\n", err)
	}
	log.Printf("| gRPC connection sucess\n")
	defer conn.Close()

	p.client = v1.NewP4RuntimeClient(conn)
	p.deviceid = 0
	p.electionid = v1.Uint128{High: 0, Low: 1}

	stream, err := p.client.StreamChannel(context.TODO())
	p.stream = stream
	if err != nil {
		return errors.WithStack(err)
	}
	log.Println("| NewP4RuntimeClient: created")

	// runStreamChannel (to kick go routine for send/recv stream)
	p.sendStreamMessages = make(chan interface{}, 10)
	p.recvStreamMessages = make(chan interface{}, 10)
	p.runStreamChannel(streamChErrors)
	time.Sleep(time.Millisecond * 300)

	// masterArbitrationUpdate
	p.masterArbitrationUpdate() // returns nil, exits on Fatal
	log.Println("| masterArbitrationUpdate done")
	time.Sleep(time.Millisecond * 100)

	// setForwardPipelineConfig
	err = p.setForwardPipelineConfig(devconfigFilePath, p4infoFilePath)
	if err != nil {
		return err
	}
	log.Println("| setForwardPipelineConfig done")
	time.Sleep(time.Millisecond * 100)

	log.Println("| P4RuntimeClinet Init: done")

	// Send/Recive Loop -------------------------------------------------------
	log.Println("-- Start Send/Receive Loop --------------------------------------")

	// PacketIn
	go func() {
		for {
			respmess := <-p.recvStreamMessages
			if packetIn, ok := respmess.(*v1.PacketIn); ok {
				log.Printf("PacketIn: Packet from switch.\n")
				log.Printf("| Metadata: %v\n", packetIn.Metadata)
				//log.Printf("| Payload Dump:\n%v", hex.Dump(packetIn.Payload))
				printFrame(packetIn.Payload)
			}
			//time.Sleep(time.Second) //DEBUG
		}
	}()

	for {
		time.Sleep(time.Second)
	} //DEBUG

	return nil
}

func printFrame(frame []byte) {
	dmac := net.HardwareAddr(frame[0:6])
	smac := net.HardwareAddr(frame[6:12])
	ethtype := frame[12:14]
	log.Printf("| Dst: %s\n", dmac.String())
	log.Printf("| Src: %s\n", smac.String())
	log.Printf("| Ethertype: %x\n", ethtype)
	log.Printf("| Packet Dump:\n%s", hex.Dump(frame))
}

func (p P4RuntimeClient) masterArbitrationUpdate() error {
	upArbtration := v1.MasterArbitrationUpdate{
		DeviceId:   p.deviceid,
		ElectionId: &p.electionid,
	}
	message := &v1.StreamMessageRequest{
		Update: &v1.StreamMessageRequest_Arbitration{
			Arbitration: &upArbtration,
		},
	}
	// send/recv is inside p.runStreamChannel as Goroutine
	p.sendStreamMessages <- message
	updatemessage := <-p.recvStreamMessages
	log.Printf("masterArbitrationUpdate: %v", updatemessage)

	return nil
}

func (p P4RuntimeClient) setForwardPipelineConfig(p4dev *string, p4info *string) error {
	devconfig, err := ioutil.ReadFile(*p4dev)
	if err != nil {
		return errors.WithStack(err)
	}
	p4helper, err := p4infoHelperBuild(p4info)
	if err != nil {
		return err
	}
	p4infoconfig := p4helper.getP4infoProto()

	config := &v1.ForwardingPipelineConfig{
		P4Info:         &p4infoconfig,
		P4DeviceConfig: devconfig,
	}
	log.Printf("devconfig len%v\n", len(devconfig))
	message := &v1.SetForwardingPipelineConfigRequest{
		DeviceId:   p.deviceid,
		ElectionId: &v1.Uint128{High: 0, Low: 1},
		Action:     v1.SetForwardingPipelineConfigRequest_VERIFY_AND_COMMIT,
		Config:     config,
	}
	resReadc, err := p.client.SetForwardingPipelineConfig(context.TODO(), message)
	log.Println("SetForwardingPipelineConfig:")
	log.Printf("| result:%#v \n", resReadc)
	log.Printf("| error::%#v \n", err)
	if err != nil {
		return errors.WithStack(err)
	}
	return nil
}

func (p P4RuntimeClient) runStreamChannel(errch chan error) {
	go func() {
		for {
			in, err := p.stream.Recv()
			if err == io.EOF {
				errch <- err
				goto L
			}
			if err != nil {
				log.Fatalf("Failed to receive a note : %v", err)
			}
			update := in.GetUpdate()
			switch update.(type) {
			case *v1.StreamMessageResponse_Arbitration:
				//log.Printf("GetArbitration message %s", in.GetArbitration())
				p.recvStreamMessages <- in.GetArbitration()
			case *v1.StreamMessageResponse_Digest:
				//log.Printf("GetDigest message %s", in.GetDigest())
				p.recvStreamMessages <- in.GetDigest()
			case *v1.StreamMessageResponse_Error:
				//log.Printf("GetError message %s", in.GetError())
				p.recvStreamMessages <- in.GetError()
			case *v1.StreamMessageResponse_IdleTimeoutNotification:
				//log.Printf("GetIdleTimeoutNotification message %s", in.GetIdleTimeoutNotification())
				p.recvStreamMessages <- in.GetIdleTimeoutNotification()
			case *v1.StreamMessageResponse_Other:
				//log.Printf("GetOther message %s", in.GetOther())
				p.recvStreamMessages <- in.GetOther()
			case *v1.StreamMessageResponse_Packet:
				//log.Printf("GetPacket message %s", in.GetPacket())
				p.recvStreamMessages <- in.GetPacket()
			default:
				errch <- fmt.Errorf("has unexpected type %T", in)
				goto L
			}
		}
	L:
		p.stream.CloseSend()
		return
	}()

	go func() {
		for {
			sendmess := <-p.sendStreamMessages
			//log.Println("DEBUG: sendmess := <-p.sendStreamMessages")
			mess := sendmess.(*v1.StreamMessageRequest)
			if err := p.stream.Send(mess); err != nil {
				errch <- err
				goto L
			}
		}
	L:
		//log.Println("DEBUG: sendmess p.stream.CloseSend()")
		p.stream.CloseSend()
		return
	}()
	return
}

// P4InfoHelper ----------------------------------------------------------------
type P4InfoHelper struct {
	p4info config_v1.P4Info
}

func p4infoHelperBuild(filepath *string) (P4InfoHelper, error) {
	var helper P4InfoHelper
	info, err := helper.p4infoBuild(filepath)
	if err != nil {
		return P4InfoHelper{}, errors.WithStack(err)
	}
	helper.p4info = info

	return helper, nil
}

func (h *P4InfoHelper) p4infoBuild(filepath *string) (config_v1.P4Info, error) {
	p4info := config_v1.P4Info{}
	//buf, err := utils.FileOpen(filepath)
	buf, err := ioutil.ReadFile(*filepath)
	if err != nil {
		return config_v1.P4Info{}, errors.WithStack(err)
	}
	err = proto.UnmarshalText(string(buf), &p4info)
	if err != nil {
		return config_v1.P4Info{}, errors.WithStack(err)
	}

	return p4info, nil
}

func (h *P4InfoHelper) getP4infoProto() config_v1.P4Info {
	return h.p4info
}
