PACKAGE=perfSONAR_PS-Toolkit
ROOTPATH=/opt/perfsonar_ps/toolkit
VERSION=3.4.2
RELEASE=8

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	mkdir -p /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch --exclude=*.svn* --exclude=web/* -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar c --exclude=*.svn* web | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
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
	tar ch --exclude '*.svn*' --exclude=web/* --exclude=etc/* --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	tar c --exclude '*.svn*' web | tar x -C ${ROOTPATH}
	for i in `cat MANIFEST | grep ^etc`; do  mkdir -p `dirname $(ROOTPATH)/$${i}`; if [ -e $(ROOTPATH)/$${i} ]; then install -m 640 -c $${i} $(ROOTPATH)/$${i}.new; else install -m 640 -c $${i} $(ROOTPATH)/$${i}; fi; done
	tar xzf ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz -C ${ROOTPATH}/web/root/content/
	rm -f ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz

install:
	for i in `ls ./scripts`; do sed -i "s|/opt/perfsonar_ps/toolkit|${ROOTPATH}|g" ./scripts/$${i}; done
	for i in `ls ./init_scripts`; do sed -i "s|/opt/perfsonar_ps/toolkit|${ROOTPATH}|g" ./init_scripts/$${i}; done
	mkdir -p ${ROOTPATH}
	tar ch --exclude '*.svn*' --exclude=web/* --exclude=etc/* --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	tar c --exclude '*.svn*' web | tar x -C ${ROOTPATH}
	for i in `cat MANIFEST | grep ^etc`; do  mkdir -p `dirname $(ROOTPATH)/$${i}`; if [ -e $(ROOTPATH)/$${i} ]; then install -m 640 -c $${i} $(ROOTPATH)/$${i}.new; else install -m 640 -c $${i} $(ROOTPATH)/$${i}; fi; done
	tar xzf ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz -C ${ROOTPATH}/web/root/content/
	rm -f ${ROOTPATH}/web/root/content/dojo-release-ps-toolkit.tar.gz
