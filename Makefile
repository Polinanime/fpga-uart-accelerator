.PHONY: clean simulate quartus synth upload

VFLAGS = -O3 --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

help:
	$(info make help    - show this message(default))
	$(info make clean   - delete synth folder)
	$(info make quartus - open project in Quartus Prime)
	$(info make synth   - synthesize project in Quartus)
	$(info make upload  - upload project to the FPGA board)
	@true

# ------------------------------------------------------------------------------
# Generation and project creation
# ------------------------------------------------------------------------------

gen_font:
	python3 scripts/bdf_font_to_hex_mem.py

gen:
	scripts/run_scripts.bash

# ------------------------------------------------------------------------------
# Simulation
# ------------------------------------------------------------------------------

simulate: sim-clean build run

build: rtl/common_top.sv
	verilator ${VFLAGS} -Irtl -Iinclude/basics-graphics-music/labs/common -cc $< --exe sim/verilator/simulate.cpp -o common_top.out \
		-CFLAGS "${SDL_CFLAGS}" -LDFLAGS "${SDL_LDFLAGS}" --Mdir sim/verilator/output_files \
		--timescale 1ns/1ps -Wno-fatal # -Wno-MULTIDRIVEN -Wno-LATCH
	make -C ./sim/verilator/output_files -f Vcommon_top.mk

run:
	./sim/verilator/output_files/common_top.out

sim-clean:
	rm -rf ./sim/verilator/output_files/

# ------------------------------------------------------------------------------
# Synthesis
# ------------------------------------------------------------------------------

CABLE_NAME   ?= "USB-Blaster"
PROJECT_DIR  ?= ./fpga/labs/uart/run
PROJECT_NAME ?= "fpga_project"

QUARTUS     := cd $(PROJECT_DIR) && quartus
QUARTUS_SH  := cd $(PROJECT_DIR) && quartus_sh
QUARTUS_PGM := cd $(PROJECT_DIR) && quartus_pgm

# when we run quartus bins from WSL it can be installed on host W10
# it this case we have to add .exe to the executed binary name
ifdef WSL_DISTRO_NAME
 ifeq (, $(shell which $(QUARTUS)))
  QUARTUS     := $(QUARTUS).exe
  QUARTUS_SH  := $(QUARTUS_SH).exe
  QUARTUS_PGM := $(QUARTUS_PGM).exe
 endif
endif

# make open
#  cd project && quartus <projectname> &
#     cd project            - go to project folder 
#	  &&                    - if previous command was successfull
#     quartus <projectname> - open <projectname> in quartus 
#     &                     - run previous command in shell background
quartus:
	$(QUARTUS) $(PROJECT_NAME) &

# make build
#  cd project && quartus_sh --flow compile <projectname>
#     cd project                              - go to project folder 
#     &&                                      - if previous command was successfull
#     quartus_sh --flow compile <projectname> - run quartus shell & perform basic compilation 
#                                               of <projectname> project
synth:
	$(QUARTUS_SH) --no_banner --flow compile $(PROJECT_NAME)
	make upload

# make load
#  cd project && quartus_pgm -c "USB-Blaster" -m JTAG -o "p;<projectname>.sof"
#     cd project               - go to project folder 
#	  &&                       - if previous command was successfull
#     quartus_pgm              - launch quartus programmer
#     -c "USB-Blaster"         - connect to "USB-Blaster" cable
#     -m JTAG                  - in JTAG programming mode
#     -o "p;<projectname>.sof" - program (configure) FPGA with <projectname>.sof file
upload:
	$(QUARTUS_PGM) --no_banner -c $(CABLE_NAME) -m JTAG -o "p;output_files/$(PROJECT_NAME).sof"