all_2step: all_2step_ng gui
all_3step: all_3step_ng gui

all_2step_ng: clean build_2step run
all_3step_ng: clean build_3step run

VCS_FLAGS = -sverilog -debug_access+all -kdb
VCS_TB = APB_TB

build_2step:
	vcs $(VCS_FLAGS) rtl/APB/*.sv TRAD_TB/*.sv -top $(VCS_TB) -l comp.log

build_3step:
	vlogan -sverilog -kdb *.sv -l vlogan.log
	vcs $(VCS_FLAGS) $(VCS_TB) -l comp.log

run:
	./simv -l run.log
                
gui:
	verdi -ssf novas.fsdb -sswr signal.rc -simcmd "./simv" &

clean:
	rm -rf AN.DB *.vcd simv* csrc* *.log ucli.key verdi* novas* work* *.fsdb 


