PACKAGE=perfSONAR_PS-Toolkit
ROOTPATH=/opt/perfsonar_ps/toolkit
VERSION=3.5
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

upgrade:
	mkdir /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch --exclude=etc/* -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE)-upgrade.tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)

rpminstall:
	mkdir -p ${ROOTPATH}
	tar ch --exclude '*.git*' --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	tar xzf ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz -C ${ROOTPATH}/web/root/content/
	rm -f ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz

install:
	mkdir -p ${ROOTPATH}
	tar ch --exclude '*.git*' --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	tar xzf ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz -C ${ROOTPATH}/web/root/content/
	rm -f ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz
