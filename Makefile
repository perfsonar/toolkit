PACKAGE=perfsonar-toolkit
ROOTPATH=/usr/lib/perfsonar
CONFIGPATH=/etc/perfsonar/toolkit
PERFSONAR_AUTO_VERSION=4.4.6
PERFSONAR_AUTO_RELNUM=0.a1.0
VERSION=${PERFSONAR_AUTO_VERSION}
RELEASE=${PERFSONAR_AUTO_RELNUM}

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	mkdir -p /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch --exclude=*.git* -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE).tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)

install:
	mkdir -p ${ROOTPATH}
	mkdir -p ${CONFIGPATH}
	tar ch --exclude '*.git*' --exclude=*spec --exclude=MANIFEST --exclude=LICENSE --exclude=LICENSE --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}

test:
	PERL_DL_NONLAZY=1 /usr/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(0)" t/*.t

cover:
	cover -test

test_jenkins:
	mkdir -p tap_output
	PERL5OPT=-MDevel::Cover prove t/ --archive tap_output/
