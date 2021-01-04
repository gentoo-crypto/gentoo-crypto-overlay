# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DB_VER="4.8"

inherit autotools db-use eutils gnome2-utils qmake-utils

MyPV="${PV/_/-}"
MyPN="litecoin"
MyP="${MyPN}-${MyPV}"

DESCRIPTION="P2P Internet currency based on Bitcoin but easier to mine"
HOMEPAGE="https://litecoin.org/"
SRC_URI="https://github.com/${MyPN}-project/${MyPN}/archive/v${MyPV}.tar.gz -> ${MyP}.tar.gz"

LICENSE="MIT ISC GPL-3 LGPL-2.1 public-domain || ( CC-BY-SA-3.0 LGPL-2.1 )"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="zmq qt5 +asm dbus kde knots +qrcode +system-leveldb test upnp +wallet zeromq"

RDEPEND="
	dev-libs/boost:=[threads(+)]
	dev-libs/openssl:0[-bindist]
	dev-libs/protobuf:=
	qrcode? (
		media-gfx/qrencode
	)
	upnp? (
		net-libs/miniupnpc
	)
	sys-libs/db:$(db_ver_to_slot "${DB_VER}")[cxx]
	>=dev-libs/leveldb-1.18-r1
	!qt5? (
		dev-qt/qtcore:4[ssl]
		dev-qt/qtgui:4
		dbus? (
			dev-qt/qtdbus:4
		)
	)
	qt5? (
		dev-qt/qtnetwork:5[ssl]
		dev-qt/qtgui:5
		dev-qt/qtwidgets:5
		dbus? (
			dev-qt/qtdbus:5
		)
	)
	zmq? ( net-libs/zeromq )
"
DEPEND="${RDEPEND}
	>=dev-libs/boost-1.52.0:=[threads(+)]
	>=app-shells/bash-4.1
	dev-libs/libevent
"

DOCS="doc/README.md"

S="${WORKDIR}/${MyP}"

src_prepare() {
    epatch "${FILESDIR}"/litecoind-0.18.1-memenv_h.patch
	eautoreconf
	rm -r src/leveldb

	cd src || die

	local filt= yeslang= nolang=

#	for ts in $(ls qt/locale/*.ts)
#	do
#		x="${ts/*litecoin_/}"
#		x="${x/.ts/}"
#		if ! use "linguas_$x"; then
#			nolang="$nolang $x"
#			#rm "$ts"
#			filt="$filt\\|$x"
#		else
#			yeslang="$yeslang $x"
#		fi
#	done

	filt="bitcoin_\\(${filt:2}\\)\\.\(qm\|ts\)"
	sed "/${filt}/d" -i 'qt/bitcoin_locale.qrc'
	einfo "Languages -- Enabled:$yeslang -- Disabled:$nolang"
	eapply_user
}

src_configure() {
	local my_econf=
	if use upnp; then
		my_econf="${my_econf} --with-miniupnpc --enable-upnp-default"
	else
		my_econf="${my_econf} --without-miniupnpc --disable-upnp-default"
	fi
	econf \
		--enable-wallet \
		--disable-ccache \
		--disable-static \
		--disable-tests \
		--with-system-leveldb \
		--with-system-libsecp256k1  \
		--without-libs \
		--without-utils \
		--without-daemon  \
		--with-gui=$(usex qt5 qt5 qt4) \
		$(use_with dbus qtdbus)  \
		$(use_with qrcode qrencode)  \
		$(use_enable zmq zmq) \
		${my_econf}
}

src_install() {
	default
	insinto /usr/share/pixmaps
	newins "share/pixmaps/bitcoin.ico" "${PN}.ico"

	make_desktop_entry "${PN} %u" "Litecoin-Qt" "/usr/share/pixmaps/${PN}.ico" "Qt;Network;P2P;Office;Finance;" "MimeType=x-scheme-handler/litecoin;\nTerminal=false"

	dodoc doc/assets-attribution.md doc/bips.md doc/tor.md
	use zmq && dodoc doc/zmq.md

	if use kde; then
		insinto /usr/share/kde4/services
		newins contrib/debian/litecoin-qt.protocol ${PN}.protocol
	fi
}

update_caches() {
	gnome2_icon_cache_update
	fdo-mime_desktop_database_update
	buildsycoca
}

pkg_postinst() {
	update_caches
}

pkg_postrm() {
	update_caches
}
