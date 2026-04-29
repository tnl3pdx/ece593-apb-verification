# ==============================================================================
# Class-Based Testbench Targets
# ==============================================================================
# Add Coverage flags to compile and run
VCS_FLAGS = -sverilog -debug_access+all -kdb -cm line+cond+fsm+tgl+branch
SIM_FLAGS = -l run.log -cm line+cond+fsm+tgl+branch

# Update the target to include 'report_cov'
class_2step_ng: clean build_class run_class report_cov
class_2step: clean build_class run_class report_cov gui

build_class:
	vcs $(VCS_FLAGS) +incdir+. rtl/APB/*.sv CLASS_TB/APB_TOP.sv -top APB_TOP -l comp_class.log

# Separate run target to include simulation flags
run_class:
	./simv $(SIM_FLAGS)

# Generate HTML Coverage Reports
report_cov:
	urg -dir simv.vdb -format both -report urgReport

build_2step:
	vcs $(VCS_FLAGS) rtl/APB/*.sv CLASS_TB/APB_TOP.sv -top $(VCS_TB) -l comp.log

build_3step:
	vlogan -sverilog -kdb *.sv -l vlogan.log
	vcs $(VCS_FLAGS) $(VCS_TB) -l comp.log

run:
	./simv -l run.log
                
gui:
	verdi -ssf novas.fsdb -sswr signal.rc -simcmd "./simv" &

clean:
	rm -rf AN.DB *.vcd simv* csrc* *.log ucli.key verdi* novas* work* *.fsdb 


