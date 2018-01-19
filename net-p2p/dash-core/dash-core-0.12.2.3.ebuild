# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit autotools bash-completion-r1 git-r3 gnome2-utils systemd user xdg-utils

DESCRIPTION="A peer-to-peer privacy-centric digital currency"
HOMEPAGE="https://www.dash.org"
EGIT_REPO_URI="https://github.com/dashpay/dash.git"
EGIT_COMMIT="refs/tags/v${PV}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~x86"
IUSE="daemon dbus +gui hardened libressl +qrcode reduce-exports system-univalue test upnp utils +wallet zeromq"
LANGS="bg de en es fi fr it ja pl pt ru sk sv vi zh_CN zh_TW"

for X in ${LANGS}; do
	IUSE="${IUSE} linguas_${X}"
done

CDEPEND="dev-libs/boost:0=[threads(+)]
	dev-libs/libevent
	gui? (
		dev-libs/protobuf
		dev-qt/qtgui:5
		dev-qt/qtnetwork:5
		dev-qt/qtwidgets:5
		dbus? ( dev-qt/qtdbus:5 )
		qrcode? ( media-gfx/qrencode )
	)
	!libressl? ( dev-libs/openssl:0=[-bindist] )
	libressl? ( dev-libs/libressl:0= )
	system-univalue? ( dev-libs/univalue )
	upnp? ( net-libs/miniupnpc )
	wallet? ( sys-libs/db:4.8[cxx] )
	zeromq? ( net-libs/zeromq )"
DEPEND="${CDEPEND}
	gui? ( dev-qt/linguist-tools )"
RDEPEND="${CDEPEND}"

REQUIRED_USE="dbus? ( gui ) qrcode? ( gui )"
RESTRICT="mirror"

S="${WORKDIR}/dash-core-${PV}"

pkg_setup() {
	if use daemon; then
		enewgroup dash
		enewuser dash -1 -1 /var/lib/dash dash
	fi
}

src_prepare() {
	if use gui; then
		local filt= yeslang= nolang= lan ts x

		# Fix compatibility with LibreSSL
		eapply "${FILESDIR}"/${PN}-0.12.1-libressl.patch

		for lan in $LANGS; do
			if [ ! -e src/qt/locale/dash_$lan.ts ]; then
				die "Language '$lan' no longer supported. Ebuild needs update."
			fi
		done

		for ts in $(ls src/qt/locale/*.ts)
		do
			x="${ts/*dash_/}"
			x="${x/.ts/}"
			if ! use "linguas_$x"; then
				nolang="$nolang $x"
				rm "$ts" || die
				filt="$filt\\|$x"
			else
				yeslang="$yeslang $x"
			fi
		done
		filt="dash_\\(${filt:2}\\)\\.\(qm\|ts\)"
		sed "/${filt}/d" -i 'src/qt/dash_locale.qrc' || die
		sed "s/locale\/${filt}/dash.qrc/" -i 'src/Makefile.qt.include' || die
		einfo "Languages -- Enabled:$yeslang -- Disabled:$nolang"
	fi

	default
	eautoreconf
}

src_configure() {
	econf \
		--without-libs \
		--disable-bench \
		--disable-ccache \
		--disable-maintainer-mode \
		$(usex gui "--with-gui=qt5" --without-gui) \
		$(use_with daemon) \
		$(use_with qrcode qrencode) \
		$(use_with upnp miniupnpc) \
		$(use_with utils) \
		$(use_enable hardened hardening) \
		$(use_enable reduce-exports) \
		$(use_enable test tests) \
		$(use_enable wallet) \
		$(use_enable zeromq zmq) \
		|| die "econf failed"
}

src_test() {
	emake -C src dash_test_check
}

src_install() {
	default

	if use daemon; then
		newinitd "${FILESDIR}"/${PN}.initd-r2 ${PN}
		newconfd "${FILESDIR}"/${PN}.confd-r2 ${PN}
		systemd_newunit "${FILESDIR}"/${PN}.service-r1 ${PN}.service
		systemd_newtmpfilesd "${FILESDIR}"/${PN}.tmpfilesd-r1 ${PN}.conf

		insinto /etc/dash
		newins "${FILESDIR}"/${PN}.conf dash.conf
		fowners dash:dash /etc/dash/dash.conf
		fperms 600 /etc/dash/dash.conf
		newins contrib/debian/examples/dash.conf dash.conf.example
		doins share/rpcuser/rpcuser.py

		doman contrib/debian/manpages/{dashd.1,dash.conf.5}
		newbashcomp contrib/dashd.bash-completion dashd

		insinto /etc/logrotate.d
		newins "${FILESDIR}"/${PN}.logrotate ${PN}
	fi

	if use gui; then
		local X
		for X in 16 32 64 128 256; do
			newicon -s ${X} "share/pixmaps/dash${X}.png" dash.png
		done
		make_desktop_entry "dash-qt %u" "Dash Core" "dash" \
			"Qt;Network;P2P;Office;Finance;" "MimeType=x-scheme-handler/dash;\nTerminal=false"

		doman contrib/debian/manpages/dash-qt.1
		use daemon || doman contrib/debian/manpages/dash.conf.5
	fi

	use utils && doman contrib/debian/manpages/dash-cli.1
}

pkg_preinst() {
	use gui && gnome2_icon_savelist
}

update_caches() {
	gnome2_icon_cache_update
	xdg_desktop_database_update
}

pkg_postinst() {
	use gui && update_caches
}

pkg_postrm() {
	use gui && update_caches
}
