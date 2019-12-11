SHELL := /bin/bash -o pipefail
.SILENT:
.DEFAULT_GOAL := help

# Local Configuration
TMP_OUTPUT	=	output
RPI_HOME	=	$(TMP_OUTPUT)/home/pi

# Raspberry PI host and IP configuration
RPI_NETWORK_TYPE 	?= eth0
RPI_ORIG_HOSTNAME	?= raspberrypi
RPI_HOSTNAME     	?= k8s-master-01
RPI_IP           	?= 192.168.1.100
RPI_DNS          	?= 192.168.1.1
RPI_TIMEZONE     	?= Australia/Melbourne

# Default Raspberry Pi password
RPI_SSH_SECRET	?= raspberry

# Kubernetes configuration
KUBE_NODE_TYPE    ?= master

SCP 	=	scp -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -o "LogLevel=ERROR"
SSH 	=	ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" -o "LogLevel=ERROR"

.PHONY: deploy
deploy: clean prepare ssh configure env scp install
	echo "Network:"
	echo "- Hostname: $(RPI_HOSTNAME)"
	echo "- Static IP: $(RPI_IP)"
	echo "- Gateway address: $(RPI_DNS)"
	echo "- Network adapter: $(RPI_NETWORK_TYPE)"
	echo "- Timezone: $(RPI_TIMEZONE)"
	echo "Kubernetes:"
	echo "- Node Type: $(KUBE_NODE_TYPE)"
	echo "- Control Plane Endpoint: $(RPI_IP)"

.PHONY: post-install
post-install:
ifeq ($(KUBE_NODE_TYPE),master)
	sshpass -p $(RPI_SSH_SECRET) $(SCP) -p -r pi@$(RPI_HOSTNAME).local:/home/pi/.kube/config $(RPI_HOME)/.kube/config
	sshpass -p $(RPI_SSH_SECRET) $(SCP) -p -r pi@$(RPI_HOSTNAME).local:/home/pi/connect.sh $(RPI_HOME)
	echo "Test Connection:"
	echo "kubectl get nodes --kubeconfig $(RPI_HOME)/.kube/config"
endif

.PHONY: install
install:
	sshpass -p "$(RPI_SSH_SECRET)" $(SSH)  pi@$(RPI_ORIG_HOSTNAME).local 'sudo bash ./bootstrap.sh' || exit 0

.PHONY: scp
scp:
	sshpass -p $(RPI_SSH_SECRET) $(SCP) -p -r $(RPI_HOME) pi@$(RPI_ORIG_HOSTNAME).local:/home/

.PHONY: env
env:
	echo "export RPI_HOSTNAME=$(RPI_HOSTNAME)" >> $(RPI_HOME)/config/env
	echo "export RPI_IP=$(RPI_IP)" >> $(RPI_HOME)/config/env
	echo "export RPI_DNS=$(RPI_DNS)" >> $(RPI_HOME)/config/env
	echo "export RPI_NETWORK_TYPE=$(RPI_NETWORK_TYPE)" >> $(RPI_HOME)/config/env
	echo "export RPI_TIMEZONE=$(RPI_TIMEZONE)" >> $(RPI_HOME)/config/env
	echo "export KUBE_NODE_TYPE=$(KUBE_NODE_TYPE)" >> $(RPI_HOME)/config/env
	echo "export KUBE_MASTER_IP_01=$(KUBE_MASTER_IP_01)" >> $(RPI_HOME)/config/env
	echo "export RPI_HOME=/home/pi" >> $(RPI_HOME)/config/env

.PHONY: configure
configure:
	cp -r ./raspbernetes/* $(RPI_HOME)/
	mv ./$(RPI_HOME)/.ssh/id_ed25519.pub $(RPI_HOME)/.ssh/authorized_keys

.PHONY: ssh
ssh:
	ssh-keygen -t ed25519 -b 4096 -C "pi@$(RPI_HOSTNAME)" -f ./$(RPI_HOME)/.ssh/id_ed25519 -q -N ""

.PHONY: prepare
prepare:
	mkdir -p $(RPI_HOME)/.ssh

.PHONY: clean
clean:
	sudo rm -rf ./$(TMP_OUTPUT)/

