RELEASE=5.0

VERSION=1.0
PACKAGE=librados2-perl
PKGREL=5

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

ARCH:=$(shell dpkg-architecture -qDEB_BUILD_ARCH)
GITVERSION:=$(shell git rev-parse HEAD)

DEB=${PACKAGE}_${VERSION}-${PKGREL}_${ARCH}.deb
DSC=${PACKAGE}_${VERSION}-${PKGREL}.dsc

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


.PHONY: deb
deb: ${DEB}
${DEB}:
	rm -rf build
	rsync -a * build
	sed -e "s|@PERLAPI@|perlapi-$(PERL_APIVER)|g" debian/control.in >build/debian/control
	echo "git clone git://git.proxmox.com/git/librados2-perl.git\\ngit checkout ${GITVERSION}" > build/debian/SOURCE
	cd build; dpkg-buildpackage -b -us -uc
	lintian ${DEB}

.PHONY: dsc
dsc: ${DSC}
${DSC}:
	rm -rf build
	rsync -a * build
	sed -e "s|@PERLAPI@|perlapi-$(PERL_APIVER)|g" debian/control.in >build/debian/control
	echo "git clone git://git.proxmox.com/git/librados2-perl.git\\ngit checkout ${GITVERSION}" > build/debian/SOURCE
	cd build; dpkg-buildpackage -S -us -uc -d -nc
	lintian ${DSC}

.PHONY: clean
clean: 	
	rm -rf *~ build *.deb *.changes *.buildinfo *.dsc *.tar.gz
	find . -name '*~' -exec rm {} ';'

.PHONY: distclean
distclean: clean


.PHONY: upload
upload: ${DEB}
	tar cf - ${DEB} | ssh repoman@repo.proxmox.com -- upload --product pve --dist stretch --arch ${ARCH}
