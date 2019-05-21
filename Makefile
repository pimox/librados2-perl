include /usr/share/dpkg/pkg-info.mk
include /usr/share/dpkg/architecture.mk

PACKAGE=librados2-perl

BUILDSRC := $(PACKAGE)-$(DEB_VERSION_UPSTREAM)

DESTDIR=
PREFIX=/usr
BINDIR=${PREFIX}/bin
LIBDIR=${PREFIX}/lib
SBINDIR=${PREFIX}/sbin
MANDIR=${PREFIX}/share/man
DOCDIR=${PREFIX}/share/doc/${PACKAGE}
MAN1DIR=${MANDIR}/man1/
PERLDIR=${PREFIX}/share/perl5

PERL_ARCHLIB := `perl -MConfig -e 'print $$Config{archlib};'`
PERL_INSTALLVENDORARCH := `perl -MConfig -e 'print $$Config{installvendorarch};'`
PERL_APIVER := `perl -MConfig -e 'print $$Config{debian_abi}//$$Config{version};'`

CFLAGS= -shared -fPIC -O2 -Wall -Wl,-z,relro -I$(PERL_ARCHLIB)/CORE -DXS_VERSION=\"1.0\"
CFLAGS= -shared -fPIC -O2 -Werror -Wtype-limits -Wall -Wl,-z,relro \
	-D_FORTIFY_SOURCE=2 -I$(PERL_ARCHLIB)/CORE -DXS_VERSION=\"1.0\"


PERLSODIR=$(PERL_INSTALLVENDORARCH)/auto

GITVERSION:=$(shell git rev-parse HEAD)

DEB=${PACKAGE}_${DEB_VERSION_UPSTREAM_REVISION}_${DEB_BUILD_ARCH}.deb
DSC=${PACKAGE}_${DEB_VERSION_UPSTREAM_REVISION}.dsc

all:

RADOS.c: RADOS.xs typemap
	xsubpp RADOS.xs -typemap typemap > RADOS.xsc
	mv RADOS.xsc RADOS.c

RADOS.so: RADOS.c
	gcc ${CFLAGS} -lrados -o RADOS.so RADOS.c


.PHONY: dinstall
dinstall: deb
	dpkg -i ${DEB}

.PHONY: install
install: PVE/RADOS.pm RADOS.so
	install -D -m 0644 PVE/RADOS.pm ${DESTDIR}${PERLDIR}/PVE/RADOS.pm
	install -D -m 0644 -s RADOS.so ${DESTDIR}${PERLSODIR}/PVE/RADOS/RADOS.so

.PHONY: $(BUILDSRC)
$(BUILDSRC):
	rm -rf $(BUILDSRC)
	rsync -a * $(BUILDSRC)
	sed -e "s|@PERLAPI@|perlapi-$(PERL_APIVER)|g" debian/control.in >$(BUILDSRC)/debian/control
	echo "git clone git://git.proxmox.com/git/librados2-perl.git\\ngit checkout ${GITVERSION}" > $(BUILDSRC)/debian/SOURCE

.PHONY: deb
deb: ${DEB}
${DEB}: $(BUILDSRC)
	cd $(BUILDSRC); dpkg-buildpackage -b -us -uc
	lintian ${DEB}

.PHONY: dsc
dsc: ${DSC}
${DSC}: $(BUILDSRC)
	cd $(BUILDSRC); dpkg-buildpackage -S -us -uc -d -nc
	lintian ${DSC}

.PHONY: clean
clean: 	
	rm -rf *~ build *.deb *.changes *.buildinfo *.dsc *.tar.gz
	find . -name '*~' -exec rm {} ';'

.PHONY: distclean
distclean: clean


.PHONY: upload
upload: ${DEB}
	tar cf - ${DEB} | ssh repoman@repo.proxmox.com -- upload --product pve --dist stretch --arch ${DEB_BUILD_ARCH}
