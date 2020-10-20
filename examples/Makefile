# Makefile to build p4 program

.DEFAULT_GOAL := build

build:
	@echo "make <target>"

01:
	@echo ">>> make 01"
	p4c --std p4_16 -b bmv2 --p4runtime-files build.bmv2/example01.p4info.txt -o build.bmv2 example01.p4
02:
	@echo ">>> make 02"
	p4c --std p4_16 -b bmv2 --p4runtime-files build.bmv2/example02.p4info.txt -o build.bmv2 example02.p4
run02:
	sudo simple_switch_grpc --no-p4 -i 1@vtap1 -i 2@vtap2 --log-console -L trace \
	-- --grpc-server-addr 0.0.0.0:50051 --cpu-port 192
