# ==============================================================================
# Class-Based Testbench Targets
# ==============================================================================
# Add Coverage flags to compile and run
VCS_FLAGS = -sverilog -debug_access+all -kdb -cm line+cond+fsm+tgl+branch -ntb_opts uvm
SIM_FLAGS = -l run.log -cm line+cond+fsm+tgl+branch

sim_ng: clean build run 
sim: clean build run gui
cov: clean build run cov

build:
	vcs $(VCS_FLAGS) +incdir+. rtl/APB/*.sv UVM_TB/APB_TOP.sv -top apb_top -l comp_class.log

run:
	./simv $(SIM_FLAGS) -l run.log
                
gui:
	verdi -ssf novas.fsdb -sswr signal.rc -simcmd "./simv" &

cov:
	verdi -cov -covdir simv.vdb -elfile cov_exclude.el

clean:
	rm -rf AN.DB *.vcd simv* csrc* *.log ucli.key verdi* novas* work* *.fsdb vc_hdrs.h .fsm.*


