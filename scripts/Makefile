TEST ?= bringup_test
VERB ?= UVM_LOW
CM    = line+cond+fsm+tgl+branch
OUT   = ./out
BUILD = $(OUT)/build
# Abhi sirf bringup_test hai; UVM tests banne par yahan add hongi
TESTS = bringup_test

.PHONY: compile sim run regress gui code_covg func_covg coverage clean

# To compile the testbench --> make compile
compile:
	mkdir -p $(OUT)
	vcs -sverilog -f build.flist -ntb_opts uvm -timescale=1ns/1ps -cm $(CM) -cm_hier cov.cfg -full64 -debug_all -l compile.log
	rm -rf $(BUILD)
	mkdir -p $(BUILD)
	@for f in csrc simv.daidir simv simv.vdb vc_hdrs.h ucli.key compile.log; do \
	    if [ -e $$f ]; then mv $$f $(BUILD)/; fi; \
	done


# To run one simulation --> make sim TEST=<test_name>
sim:
	cd $(BUILD) && ./simv -cm $(CM) -cm_name $(TEST) +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERB) +UVM_NO_RELNOTES +UVM_NO_RELNOTES -l $(TEST).log
	@grep -E "SMOKE|TEST PASSED|TEST FAILED|Functional coverage|UVM_ERROR :|UVM_FATAL :" $(BUILD)/$(TEST).log


# compile + one test --> make run TEST=<test_name>
run: compile sim


# All tests, then coverage --> make regress
regress: compile
	@for t in $(TESTS); do \
	    echo "===== $$t ====="; \
	    $(MAKE) --no-print-directory sim TEST=$$t; \
	done
	$(MAKE) --no-print-directory coverage


# To open waveform --> make gui TEST=<test_name> (pehle make sim TEST=<test_name>)
gui:
	cd $(BUILD) && vcd2vpd dump.vcd waveform.vpd && dve -full64 -vpd waveform.vpd


# Code coverage report (line, cond, fsm, toggle, branch)
code_covg:
	urg -full64 -dir $(BUILD)/simv.vdb -metric $(CM) -format both -report $(OUT)/code_coverage_report


# Functional coverage report (covergroups)
func_covg:
	urg -full64 -dir $(BUILD)/simv.vdb -metric group -format both -report $(OUT)/functional_coverage_report


coverage: code_covg func_covg


# Clean
clean:
	rm -rf $(OUT) csrc simv simv.daidir simv.vdb vc_hdrs.h ucli.key *.log urgReport
