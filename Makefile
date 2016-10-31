PACKAGE=perfsonar-toolkit
ROOTPATH=/usr/lib/perfsonar
CONFIGPATH=/etc/perfsonar/toolkit
VERSION=4.0
RELEASE=0.10.rc2

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	mkdir -p /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch --exclude=*.git* -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/LICENSE LICENSE
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/INSTALL INSTALL
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/README README
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE).tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)

install:
	mkdir -p ${ROOTPATH}
	mkdir -p ${CONFIGPATH}
	tar ch --exclude '*.git*' --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}

