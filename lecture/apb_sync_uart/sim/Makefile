testcase:=tx_hello

compile:
	vcs -full64 -sverilog +v2k -debug_access+all +define+$(testcase) -f uart.vc -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab \
	$(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a \
	-LDFLAGS -Wl,--no-as-needed

sim:
	./simv

run: compile sim

verdi:
	verdi -f uart.vc +define+$(testcase) &

clean:
	find * | grep -v Makefile | grep -v uart.vc | xargs rm -rf