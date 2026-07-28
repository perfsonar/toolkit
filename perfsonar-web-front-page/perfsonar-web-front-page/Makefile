#
# Makefile for perfSONAR web server front page
#

FILES := \
	index.html \
	perfsonar-logo-white-full.svg


default:
	@echo Nothing to do.


install:
ifndef DESTDIR
	@echo No DESTDIR specified for installation
	@false
endif
	mkdir -p $(DESTDIR)
	install -m 555 $(FILES) $(DESTDIR)


clean:
	rm -f $(TO_CLEAN) *~
