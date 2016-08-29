PACKAGE=perfsonar-toolkit
ROOTPATH=/usr/lib/perfsonar
CONFIGPATH=/etc/perfsonar/toolkit
VERSION=4.0
RELEASE=0.3.a1

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	mkdir -p /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch --exclude=*.git* --exclude=web/* -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar c --exclude=*.git* web | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/LICENSE LICENSE
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/INSTALL INSTALL
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/README README
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE).tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)

install:
	mkdir -p ${ROOTPATH}
	mkdir -p ${CONFIGPATH}
	tar ch --exclude '*.git*' --exclude=web/* --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	tar c --exclude '*.git*' web | tar x -C ${ROOTPATH}
	tar xzf ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz -C ${ROOTPATH}/web/root/content/
	rm -f ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz

test:
	PERL_DL_NONLAZY=1 /usr/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" t/*.t

test_jenkins:
	mkdir -p tap_output
	PERL5OPT=-MDevel::Cover prove t/ --archive tap_output/
