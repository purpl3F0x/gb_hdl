VERILATOR ?= verilator

VERILATOR_FLAGS =
VERILATOR_FLAGS += -cc --exe
VERILATOR_FLAGS += -O3 --x-assign fast --x-initial fast --no-assert
VERILATOR_FLAGS += -Wno-UNUSED -Wno-LATCH -Wno-UNDRIVEN -Wno-COMBDLY -Wno-ALWCOMBORDER -Wno-WIDTHEXPAND
VERILATOR_FLAGS += --build -j
# Uncomment to enable VCD dumping support in the runner
VERILATOR_FLAGS += --trace

TOP_MODULE = top_verilator_bridge
RTL_DIR = ../../rtl
CPU_DIR = $(RTL_DIR)/cpu

VERILATOR_FLAGS += --top-module $(TOP_MODULE)

RTL_SRCS = \
	$(RTL_DIR)/boy_pkg.sv \
	$(RTL_DIR)/bus.sv \
	$(RTL_DIR)/dma.sv \
	$(CPU_DIR)/alu_pkg.sv \
	$(CPU_DIR)/cpu_pkg.sv \
	$(CPU_DIR)/idu.sv \
	$(CPU_DIR)/alu.sv \
	$(CPU_DIR)/register_file.sv \
	$(CPU_DIR)/control.sv \
	$(CPU_DIR)/cpu.sv \
	$(RTL_DIR)/top.sv

VERILATOR_INPUT = -f input.vc $(RTL_SRCS) $(TOP_MODULE).sv main.cpp

default: run

build:
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_INPUT)

run: build
	./obj_dir/V$(TOP_MODULE)

clean:
	-rm -rf obj_dir *.log *.dmp *.vpd core
