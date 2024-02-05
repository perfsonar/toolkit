PACKAGE=perfsonar-toolkit
ROOTPATH=/usr/lib/perfsonar
CONFIGPATH=/etc/perfsonar/toolkit
PERFSONAR_AUTO_VERSION=5.0.8
PERFSONAR_AUTO_RELNUM=1
VERSION=${PERFSONAR_AUTO_VERSION}
RELEASE=${PERFSONAR_AUTO_RELNUM}
DC_CMD_BASE=docker-compose
DC_CMD=${DC_CMD_BASE} -p ${PACKAGE}

default:
	@echo No need to build the package. Just run \"make install\"

centos7:
	mkdir -p ./artifacts/centos7
	${DC_CMD} -f docker-compose.yml up --build --no-start centos7
	docker cp ${PACKAGE}_centos7_1:/root/rpmbuild/SRPMS ./artifacts/centos7/SRPMS
	docker cp ${PACKAGE}_centos7_1:/root/rpmbuild/RPMS/noarch ./artifacts/centos7/RPMS

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
