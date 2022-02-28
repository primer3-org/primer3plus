SHELL := /bin/bash

# Targets
TARGETS = .conda .channels .install
PBASE=$(shell pwd)

all:   	$(TARGETS)

.conda:
	wget 'https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh' && bash Miniconda3-latest-Linux-x86_64.sh -b -p ${PBASE}/conda && rm -f Miniconda3-latest-Linux-x86_64.sh && touch .conda

.channels: .conda
	export PATH=${PBASE}/conda/bin:${PATH} && conda config --add channels defaults && conda config --add channels conda-forge && conda config --add channels bioconda && touch .channels

.install: .conda .channels
	export PATH=${PBASE}/conda/bin:${PATH} && conda install -y gunicorn flask flask_cors && touch .install

clean:
	rm -rf $(TARGETS) $(TARGETS:=.o) conda/
