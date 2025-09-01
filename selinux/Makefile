# selinux/Makefile
MODNAME ?= cloud-hypervisor

all: $(MODNAME).pp

$(MODNAME).pp: $(MODNAME).te $(MODNAME).fc $(MODNAME).if
	checkmodule -M -m -o $(MODNAME).mod $(MODNAME).te
	semodule_package -o $(MODNAME).pp -m $(MODNAME).mod -f $(MODNAME).fc

clean:
	rm -f $(MODNAME).mod $(MODNAME).pp
