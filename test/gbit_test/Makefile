

VERILATOR ?= verilator
VERILATOR_FLAGS =
# Generate C++ in executable form
VERILATOR_FLAGS += -cc --exe
# Generate makefile dependencies (not shown as complicates the Makefile)
#VERILATOR_FLAGS += -MMD
# Optimize
VERILATOR_FLAGS += -O1 --x-assign fast --x-initial fast --no-assert -CFLAGS "-march=native"
# Warn abount lint issues; may not want this on less solid designs
VERILATOR_FLAGS += -Wno-UNUSED -Wno-LATCH -Wno-UNDRIVEN -Wno-UNUSED -Wno-COMBDLY -Wno-ALWCOMBORDER -Wno-WIDTHEXPAND
# Make waveforms
# VERILATOR_FLAGS += --trace
# Check SystemVerilog assertions
# VERILATOR_FLAGS += --assert
# Generate coverage analysis
VERILATOR_FLAGS += --coverage
# Run make to compile model, with as many CPUs as are free
VERILATOR_FLAGS += --build -j



# Top module and RTL inputs
TOP_MODULE = cpu_verilator_bridge
RTL_DIR = ../../rtl/cpu
VERILATOR_FLAGS += --top-module $(TOP_MODULE)
RTL_SRCS = $(RTL_DIR)/alu_pkg.sv \
		   $(RTL_DIR)/cpu_pkg.sv \
		   $(RTL_DIR)/idu.sv \
		   $(RTL_DIR)/alu.sv \
		   $(RTL_DIR)/register_file.sv \
		   $(RTL_DIR)/control.sv \
		   $(RTL_DIR)/cpu.sv

GBIT_SRCS =  $(wildcard ./gbit/lib/*.c)

# Input files for Verilator
VERILATOR_GBIT_INPUT = -f input.vc $(RTL_SRCS) $(TOP_MODULE).sv gbit_verilator_bridge.cpp $(GBIT_SRCS) main.cpp

######################################################################

# Create annotated source
VERILATOR_COV_FLAGS += --annotate logs/annotated
# A single coverage hit is considered good enough
VERILATOR_COV_FLAGS += --annotate-min 1
# Create LCOV info
VERILATOR_COV_FLAGS += --write-info logs/coverage.info
# Input file from Verilator
VERILATOR_COV_FLAGS += logs/coverage.dat

######################################################################
default: run_gbit


run_gbit: build_gbit
	./obj_dir/V$(TOP_MODULE)	


build_gbit:
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_GBIT_INPUT)

wave:
	surfer gbit_out.vcd


maintainer-copy::
clean mostlyclean distclean maintainer-clean::
	-rm -rf obj_dir logs *.log *.dmp *.vpd core