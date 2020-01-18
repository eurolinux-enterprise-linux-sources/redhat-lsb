NAME := redhat-lsb
SPECFILE = $(NAME).spec

SCRIPTS=lsb_start_daemon lsb_killproc lsb_pidofproc lsb_log_message

redhat-lsb.spec: redhat-lsb.spec.in mkredhat-lsb
	@[ -f redhat-lsb.spec ] && mv redhat-lsb.spec redhat-lsb.spec.old || :
	./mkredhat-lsb
	@[ -f redhat-lsb.spec.old ] && diff -u redhat-lsb.spec.old redhat-lsb.spec || :

dist: clean redhat-lsb.spec
	@VERSION=`awk '/^Version: / { print $$2 }' redhat-lsb.spec`; \
	mkdir redhat-lsb-$$VERSION; \
	find -type f -maxdepth 1 -exec cp {} redhat-lsb-$$VERSION \; ; \
	tar cjf redhat-lsb-$$VERSION.tar.bz2 redhat-lsb-$$VERSION; \
	rm -rf redhat-lsb-$$VERSION

clean:
	@rm -rf *~ .#* lsb-release* *.bz2 redhat-lsb.spec.old

install:
	mkdir -p -m 755 $(DESTDIR)/etc/redhat-lsb
	mkdir -p -m 755 $(DESTDIR)/lib/lsb
	for script in $(SCRIPTS) ; do \
	  install -m 755 $$script $(DESTDIR)/etc/redhat-lsb ;\
	done
	install -m 755 init-functions $(DESTDIR)/lib/lsb
