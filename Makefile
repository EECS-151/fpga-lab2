SHELL                   := $(shell which bash) -o pipefail
ABS_TOP                 := $(subst /cygdrive/c/,C:/, $(shell pwd))
SCRIPTS                 := $(ABS_TOP)/scripts
VIVADO                  ?= vivado # this should be sourced by default 
VIVADO_OPTS             ?= -nolog -nojournal -mode batch
FPGA_PART               ?= xczu3eg-sfvc784-2-e
RTL                     += $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/src -type f \( -name "*.v" -o -name "*.sv" \)))
CONSTRAINTS             += $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/src -type f -name "*.xdc"))
TOP                     ?= zu3top
VCS                     := $(VCS_HOME)/bin/vcs -full64
VCS_OPTS     			:= -notice -line +lint=all,noVCDE,noNS,noSVA-UA -sverilog -kdb -timescale=1ns/10ps -debug_access+all -ignore initializer_driver_checks
SIM_RTL                 := $(subst /cygdrive/c/,C:/, $(shell find $(ABS_TOP)/sim -type f \( -name "*.v" -o -name "*.sv" \)))
VVP                     := vvp
VERDI                   ?= $(VERDI_HOME)/bin/verdi

sim/%.tb: sim/%.sv $(RTL)
	cd sim && $(VCS) $(VCS_OPTS) -o $*.tb \
	    -y $(ABS_TOP)/src +libext+.sv+.v \
	    $*.sv -top $*

sim/%.fsdb: sim/%.tb
	cd sim && ./$*.tb +verbose=1 +fsdbfile+$*.fsdb
	

# Open Verdi with FSDB and VCS dbdir. Usage: make verdi [TB=led_controller_tb]
verdi: sim/$(TB).fsdb
	$(VERDI) -dbdir sim/$(TB).tb.daidir -ssf sim/$(TB).fsdb &

build/target.tcl: $(RTL) $(CONSTRAINTS)
	mkdir -p build
	truncate -s 0 $@
	echo "set ABS_TOP                        $(ABS_TOP)"    >> $@
	echo "set TOP                            $(TOP)"    >> $@
	echo "set FPGA_PART                      $(FPGA_PART)"  >> $@
	echo "set_param general.maxThreads       4"    >> $@
	echo "set_param general.maxBackupLogs    0"    >> $@
	echo -n "set RTL { " >> $@
	FLIST="$(RTL)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@
	echo -n "set CONSTRAINTS { " >> $@
	FLIST="$(CONSTRAINTS)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@

setup: build/target.tcl

elaborate: build/target.tcl $(SCRIPTS)/elaborate.tcl
	mkdir -p ./build
	cd ./build && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/elaborate.tcl |& tee elaborate.log

build/synth/$(TOP).dcp: build/target.tcl $(SCRIPTS)/synth.tcl
	mkdir -p ./build/synth/
	cd ./build/synth/ && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/synth.tcl |& tee synth.log

synth: build/synth/$(TOP).dcp

build/impl/$(TOP).bit: build/synth/$(TOP).dcp $(SCRIPTS)/impl.tcl
	mkdir -p ./build/impl/
	cd ./build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/impl.tcl |& tee impl.log

impl: build/impl/$(TOP).bit
all: build/impl/$(TOP).bit

program: build/impl/$(TOP).bit $(SCRIPTS)/program.tcl
	@rm -f $(SCRIPTS)/assign_board_log.tmp $(SCRIPTS)/port.tmp $(SCRIPTS)/serial.tmp; \
	if ! assign-fpga-board > $(SCRIPTS)/assign_board_log.tmp 2>&1 & then \
		sleep 1; \
	fi; \
	if grep -q "already have an instance" $(SCRIPTS)/assign_board_log.tmp; then \
		PID=$$(grep -oP '\d+' $(SCRIPTS)/assign_board_log.tmp | tail -n 1); \
		echo "Stale instance found (PID: $$PID). Clearing process tree..."; \
		SUDO_PID=$$(pstree -p -s $$PID | grep -oP 'sudo\([0-9]+\)' | head -n 1 | grep -oP '\d+'); \
		if [ -n "$$SUDO_PID" ]; then \
			kill $$SUDO_PID; \
			sleep 1; \
		fi; \
		assign-fpga-board > $(SCRIPTS)/assign_board_log.tmp 2>&1 & \
	fi; \
	echo "Waiting for board assignment..."; \
	while ! grep -q "Vivado hw_server port:" $(SCRIPTS)/assign_board_log.tmp; do \
		sleep 0.2; \
	done; \
	PORT=$$(grep -oP 'Vivado hw_server port: \K\d+' $(SCRIPTS)/assign_board_log.tmp); \
	SERIAL=$$(grep -oP 'serial \K[A-Z0-9]+' $(SCRIPTS)/assign_board_log.tmp); \
	echo "BOARD SERIAL: $$SERIAL"; \
	/share/instsww/xilinx/2025.2/Vivado/bin/hw_server -stcp:localhost:$$PORT > /dev/null 2>&1 & \
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/program.tcl -tclargs $$PORT

program-force:
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/program.tcl

vivado: build
	cd build && nohup $(VIVADO) </dev/null >/dev/null 2>&1 &

lint:
	verilator --lint-only --top-module $(TOP) $(RTL)

sim_build/compile_simlib/synopsys_sim.setup:
	mkdir -p sim_build/compile_simlib
	cd build/sim_build/compile_simlib && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/compile_simlib.tcl

compile_simlib: sim_build/compile_simlib/synopsys_sim.setup

clean:
	rm -rf ./build $(junk) *.daidir sim/output.txt \
	sim/*.tb sim/*.daidir sim/csrc \
	sim/ucli.key sim/*.vpd sim/*.vcd sim/*.fsdb \
	sim/*.tbi sim/*.fst sim/*.jou sim/*.log sim/*.out \
	novas.* \
	verdiLog 

.PHONY: setup synth impl program program-force vivado all clean verdi %.tb
.PRECIOUS: sim/%.tb sim/%.tbi sim/%.fst sim/%.vpd