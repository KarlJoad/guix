;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2015, 2023 Andreas Enge <andreas@enge.fr>
;;; Copyright © 2016, 2019, 2020, 2022, 2023 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2016-2019 Hartmut Goebel <h.goebel@crazy-compilers.com>
;;; Copyright © 2016 David Craven <david@craven.ch>
;;; Copyright © 2017 Thomas Danckaert <post@thomasdanckaert.be>
;;; Copyright © 2018, 2019 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2019 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2020 Vincent Legoll <vincent.legoll@gmail.com>
;;; Copyright © 2020 Marius Bakke <mbakke@fastmail.com>
;;; Copyright © 2021 Alexandros Theodotou <alex@zrythm.org>
;;; Copyright © 2022 Brendan Tildesley <mail@brendan.scot>
;;; Copyright © 2022 Petr Hodina <phodina@protonmail.com>
;;; Copyright © 2023 Zheng Junjie <873216071@qq.com>
;;; Copyright © 2024 Maxim Cournoyer <maxim.cournoyer@gmail.com>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages kde-frameworks)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system python)
  #:use-module (guix build-system qt)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu packages acl)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages aidc)
  #:use-module (gnu packages aspell)
  #:use-module (gnu packages attr)
  #:use-module (gnu packages avahi)
  #:use-module (gnu packages base)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages calendar)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages docbook)
  #:use-module (gnu packages ebook)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages gperf)
  #:use-module (gnu packages graphics)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages gstreamer)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages hunspell)
  #:use-module (gnu packages image)
  #:use-module (gnu packages iso-codes)
  #:use-module (gnu packages kerberos)
  #:use-module (gnu packages kde)
  #:use-module (gnu packages kde-plasma)
  #:use-module (gnu packages libcanberra)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages mp3)
  #:use-module (gnu packages openbox)
  #:use-module (gnu packages pdf)
  #:use-module (gnu packages pcre)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages photo)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages polkit)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages textutils)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages text-editors)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages video)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages web)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg)
  #:use-module (srfi srfi-1))

(define-public extra-cmake-modules
  (package
    (name "extra-cmake-modules")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "067qb9w8dj5z094yklc9b1jx5k29my5zf1gzkr05liswm7xzhs0k"))))
    (build-system cmake-build-system)
    (native-inputs
     ;; Add test dependency, except on armhf where building it is too
     ;; expensive.
     (if (and (not (%current-target-system))
              (string=? (%current-system) "armhf-linux"))
         '()
         (list qtbase-5)))               ;for tests (needs qmake)
    (arguments
     (list
      #:tests? (and (not (%current-target-system))
                    (not (null? (package-native-inputs this-package))))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-lib-and-libexec-path
            (lambda _
              (substitute* "kde-modules/KDEInstallDirsCommon.cmake"
                ;; Always install into /lib and not into /lib64.
                (("\"lib64\"") "\"lib\"")
                ;; Install into /libexec and not into /lib/libexec.
                (("LIBDIR \"libexec\"") "EXECROOTDIR \"libexec\""))

              ;; Determine the install path by the major version of Qt.
              ;; TODO: Base the following on values taken from Qt
              ;; Install plugins into lib/qt5/plugins
              ;; TODO: Check if this is okay for Android, too
              ;; (see comment in KDEInstallDirs.cmake)
              (substitute* '("kde-modules/KDEInstallDirs5.cmake"
                             "kde-modules/KDEInstallDirs6.cmake")
                ;; Fix the installation path of Qt plugins.
                (("_define_relative\\(QTPLUGINDIR \"\\$\\{_pluginsDirParent}\" \"plugins\"")
                 "_define_relative(QTPLUGINDIR \"${_pluginsDirParent}\" \"qt${QT_MAJOR_VERSION}/plugins\"")
                ;; Fix the installation path of QML files.
                (("_define_relative\\(QMLDIR LIBDIR \"qml\"")
                 "_define_relative(QMLDIR LIBDIR \"qt${QT_MAJOR_VERSION}/qml\""))

              ;; Qt Quick Control 1 is no longer available in Qt 6.
              (substitute* '("kde-modules/KDEInstallDirs5.cmake")
                (("_define_relative\\(QTQUICKIMPORTSDIR QTPLUGINDIR \"imports\"")
                 "_define_relative(QTQUICKIMPORTSDIR LIBDIR \"qt5/imports\""))

              (substitute* "modules/ECMGeneratePriFile.cmake"
                ;; Install pri-files into lib/qt${QT_MAJOR_VERSION}/mkspecs
                (("set\\(ECM_MKSPECS_INSTALL_DIR mkspecs/modules")
                 "set(ECM_MKSPECS_INSTALL_DIR lib/qt${QT_MAJOR_VERSION}/mkspecs/modules"))))
          ;; Work around for the failed test KDEFetchTranslations.
          ;; It complains that the cmake project name is not
          ;; ".*/extra-cmake-modules".
          ;; TODO: Fix it upstream.
          (add-after 'unpack 'fix-test
            (lambda _
              (substitute* "tests/KDEFetchTranslations/CMakeLists.txt"
                (("\\.\\*/extra-cmake-modules") "extra-cmake-modules"))))
          ;; install and check phase are swapped to prevent install from failing
          ;; after testsuire has run
          (add-after 'install 'check-post-install
            (assoc-ref %standard-phases 'check))
          (delete 'check))))
    ;; optional dependencies - to save space, we do not add these inputs.
    ;; Sphinx > 1.2:
    ;;   Required to build Extra CMake Modules documentation in Qt Help format.
    ;; Qt5LinguistTools , Qt5 linguist tools. , <http://www.qt.io/>
    ;;   Required to run tests for the ECMPoQmTools module.
    ;; Qt5Core
    ;;   Required to run tests for the ECMQtDeclareLoggingCategory module,
    ;;   and for some tests of the KDEInstallDirs module.
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "CMake module files for common software used by KDE")
    (description "The Extra CMake Modules package, or ECM, adds to the
modules provided by CMake to find common software.  In addition, it provides
common build settings used in software produced by the KDE community.")
    (license license:bsd-3)))

(define-public kquickcharts
  (package
    (name "kquickcharts")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/frameworks/"
                                  (version-major+minor version)
                                  "/" name "-" version ".tar.xz"))
              (sha256
               (base32
                "1iwgxlzplpb1ngc2q3jv5v5a2dq3l9wc6kizfvrb6j5zvwm543i5"))))
    (build-system qt-build-system)
    (arguments (list #:qtbase qtbase))
    (native-inputs (list extra-cmake-modules glslang pkg-config))
    (inputs (list qtdeclarative qtshadertools))
    (home-page "https://api.kde.org/frameworks/kquickcharts/html/index.html")
    (synopsis "QtQuick plugin providing high-performance charts")
    (description
     "The Quick Charts module provides a set of charts that can be
used from QtQuick applications for both simple display of data as well as
continuous display of high-volume data.")
    (license (list license:lgpl2.1 license:lgpl3))))

(define-public kquickcharts-5
  (package
    (inherit kquickcharts)
    (name "kquickcharts")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/frameworks/"
                                  (version-major+minor version)
                                  "/" name "-" version ".tar.xz"))
              (sha256
               (base32
                "1bd20kpypji6053fwn5a1b41rjf7r1b3wk85swb0xlmm2kji236j"))))
    (build-system cmake-build-system)
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (replace 'check
                          (lambda* (#:key tests? #:allow-other-keys)
                            (when tests?
                              (system "Xvfb :1 -screen 0 640x480x24 &")
                              (setenv "DISPLAY" ":1")
                              (setenv "QT_QPA_PLATFORM" "offscreen")
                              (invoke "ctest")))))))
    (inputs (list qtbase-5 qtdeclarative-5 qtquickcontrols2-5
                  xorg-server-for-tests))))

(define-public phonon
  (package
    (name "phonon")
    (version "4.12.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/phonon"
                    "/" version "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "16pk8g5rx00x45gnxrqg160b1l02fds1b7iz6shllbfczghgz1rj"))))
    (build-system cmake-build-system)
    (native-inputs
     (list appstream extra-cmake-modules pkg-config qttools))
    (inputs (list qtbase qt5compat glib qtbase-5 pulseaudio))
    (arguments
     (list #:configure-flags
           #~(list "-DCMAKE_CXX_FLAGS=-fPIC")))
    (home-page "https://community.kde.org/Phonon")
    (synopsis "KDE's multimedia library")
    (description "KDE's multimedia library.")
    (license license:lgpl2.1+)))

(define-public phonon-backend-gstreamer
  (package
    (name "phonon-backend-gstreamer")
    (version "4.10.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/phonon/"
                    name "/" version "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1wk1ip2w7fkh65zk6rilj314dna0hgsv2xhjmpr5w08xa8sii1y5"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules pkg-config qttools-5))
    (inputs
     (list phonon
           qtbase-5
           qtx11extras
           gstreamer
           gst-plugins-base
           libxml2))
    (arguments
     `(#:configure-flags
       '( "-DPHONON_BUILD_PHONON4QT5=ON")))
    (home-page "https://community.kde.org/Phonon")
    (synopsis "Phonon backend which uses GStreamer")
    (description "Phonon makes use of backend libraries to provide sound.
Phonon-GStreamer is a backend based on the GStreamer multimedia library.")
    ;; license: source files mention "either version 2.1 or 3"
    (license (list license:lgpl2.1 license:lgpl3))))

(define-public phonon-backend-vlc
  (package
    (name "phonon-backend-vlc")
    (version "0.12.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/phonon/"
                    name "/" version "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "19f9wzff4nr36ryq18i6qvsq5kqxfkpqsmsvrarr8jqy8pf7k11k"))))
    (build-system cmake-build-system)
    (arguments
     (list #:configure-flags
           #~(list "-DPHONON_BUILD_QT6=OFF")))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (inputs
     (list phonon qtbase-5 vlc))
    (home-page "https://community.kde.org/Phonon")
    (synopsis "Phonon backend which uses VLC")
    (description "Phonon makes use of backend libraries to provide sound.
Phonon-VLC is a backend based on the VLC multimedia library.")
    (license license:lgpl2.1)))


;; Tier 1
;;
;; Tier 1 frameworks depend only on Qt (and possibly a small number of other
;; third-party libraries), so can easily be used by an Qt-based project.

(define-public attica
  (package
    (name "attica")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1varrhc08799avraaln5sa844mwcz4h519x36n25sb80788kmbxb"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs (list qtbase))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'disable-network-tests
            (lambda _
              ;; These tests require network access.
              (substitute* "autotests/CMakeLists.txt"
                ((".*providertest.cpp") "")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Open Collaboration Service client library")
    (description "Attica is a Qt library that implements the Open
Collaboration Services API version 1.6.

It grants easy access to the services such as querying information about
persons and contents.  The library is used in KNewStuff3 as content provider.
In order to integrate with KDE's Plasma Desktop, a platform plugin exists in
kdebase.

The REST API is defined here:
http://freedesktop.org/wiki/Specifications/open-collaboration-services/")
    (license (list license:lgpl2.1+ license:lgpl3+))))

(define-public attica-5
  (package
    (inherit attica)
    (name "attica")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1shzs985fimd15w2d9cxpcbq7by33v05hb00rp79k6cqvp20f4b8"))))
    (inputs (list qtbase-5))))

(define-public bluez-qt
  (package
    (name "bluez-qt")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1p52sk0rpf75dhmwcxbiwnpprm8giy80qav92d1dhchhmqzvhs1v"))))
    (build-system cmake-build-system)
    (native-inputs
     (list dbus extra-cmake-modules))
    (inputs
     (list qtdeclarative
           qtbase))
    (arguments
     (list #:configure-flags
           #~(list (string-append
                    "-DUDEV_RULES_INSTALL_DIR=" #$output "/lib/udev/rules.d"))
           #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (setenv "DBUS_FATAL_WARNINGS" "0")
                     (invoke "dbus-launch" "ctest" "-E" "bluezqt-qmltests")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "QML wrapper for BlueZ")
    (description "bluez-qt is a Qt-style library for accessing the bluez
Bluetooth stack.  It is used by the KDE Bluetooth stack, BlueDevil.")
    (license (list license:lgpl2.1+ license:lgpl3+))))

(define-public breeze-icons
  (package
    (name "breeze-icons")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/frameworks/"
                                  (version-major+minor version)
                                  "/" name "-" version ".tar.xz"))
              (sha256
               (base32
                "09p6fjja5yqf1zvfjdik997clnhbyd1xx4gnqhyz3nypy9w669k7"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules
           fdupes
           `(,gtk+ "bin")
           python
           python-lxml))                ;for 24x24 icon generation
    (inputs (list qtbase))
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (add-after 'install 'update-cache
                          (lambda* _
                            (invoke "gtk-update-icon-cache"
                                    (string-append #$output
                                                   "/share/icons/breeze"))
                            (invoke "gtk-update-icon-cache"
                                    (string-append #$output
                                                   "/share/icons/breeze-dark")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Default KDE Plasma icon theme")
    (description "Breeze provides a freedesktop.org compatible icon theme.
It is the default icon theme for the KDE Plasma desktop.")
    ;; The license file mentions lgpl3+. The license files in the source
    ;; directories are lgpl3, while the top directory contains the lgpl2.1.
    ;; text.
    (license license:lgpl3+)))

(define-public kapidox
  (package
    (name "kapidox")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0knp680462dr9ib2b4dgz18659i1a33d6gmvnqh3k4mm659rrlr1"))))
    (build-system python-build-system)
    (arguments
     (list #:tests? #f ; test need network
           #:phases #~(modify-phases %standard-phases
                        (delete 'sanity-check)))) ;its insane.
    (propagated-inputs
     ;; kapidox is a python programm
     ;; TODO: check if doxygen has to be installed, the readme does not
     ;; mention it. The openSuse .rpm lists doxygen, graphviz, graphviz-gd,
     ;; and python-xml.
     (list python python-jinja2 python-pyyaml python-requests))
    (inputs
     (list qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE Doxygen Tools")
    (description "This framework contains scripts and data for building API
documentation (dox) in a standard format and style for KDE.

For the actual documentation extraction and formatting the Doxygen tool is
used, but this framework provides a wrapper script to make generating the
documentation more convenient (including reading settings from the target
framework or other module) and a standard template for the generated
documentation.")
    ;; Most parts are bsd-2, but incuded jquery is expat
    ;; This list is taken from http://packaging.neon.kde.org/cgit/
    (license (list license:bsd-2 license:expat))))

(define-public karchive
  (package
    (name "karchive")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/frameworks/"
                                  (version-major+minor version)
                                  "/" name "-" version ".tar.xz"))
              (sha256
               (base32
                "0aafcxizxzh239sz9ffsgxbq6c4a368bm3l93jj9m3v60xbpz017"))))
    (build-system cmake-build-system)
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (replace 'check
                          (lambda* (#:key tests? #:allow-other-keys)
                            (when tests?
                              (invoke "ctest" "-E" "karchivetest")))))))
    (native-inputs
     (list extra-cmake-modules pkg-config qttools))
    (inputs (list bzip2 qtbase xz zlib `(,zstd "lib")))
    (synopsis "Qt 6 addon providing access to numerous types of archives")
    (description
     "KArchive provides classes for easy reading, creation and
manipulation of @code{archive} formats like ZIP and TAR.

It also provides transparent compression and decompression of data, like the
GZip format, via a subclass of QIODevice.")
    (home-page "https://community.kde.org/Frameworks")
    ;; The included licenses is are gpl2 and lgpl2.1, but the sources are
    ;; under a variety of licenses.
    ;; This list is taken from http://packaging.neon.kde.org/cgit/
    (license (list license:lgpl2.1 license:lgpl2.1+
                   license:lgpl3+ license:bsd-2))))

(define-public karchive-5
  (package
    (inherit karchive)
    (name "karchive")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/frameworks/"
                                  (version-major+minor version)
                                  "/" name "-" version ".tar.xz"))
              (sha256
               (base32
                "02m3vvw58qsgmaps184xwy97bg4pgjl4i1gjwzn66h5qf34y6qqn"))))
    (native-inputs
     (list extra-cmake-modules pkg-config qttools-5))
    (inputs
     (list bzip2 qtbase-5 xz zlib `(,zstd "lib")))
    (synopsis "Qt 5 addon providing access to numerous types of archives")))

(define-public kcalendarcore
  (package
    (name "kcalendarcore")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1yqk2s52h6z9jlh2lg96agk273msrah6rxw10wr2cpnb0jv7dpyd"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules perl tzdata-for-tests))
    (inputs (list libical qtbase))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'check-setup
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "QT_QPA_PLATFORM" "offscreen")
              (setenv "TZ" "Europe/Prague")
              (setenv "TZDIR"
                      (search-input-directory inputs
                                              "share/zoneinfo")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Library for interfacing with calendars")
    (description "This library provides access to and handling of calendar
data.  It supports the standard formats iCalendar and vCalendar and the group
scheduling standard iTIP.

A calendar contains information like incidences (events, to-dos, journals),
alarms, time zones, and other useful information.  This API provides access to
that calendar information via well known calendar formats iCalendar (or iCal)
and the older vCalendar.")
    (license (list license:lgpl3+ license:bsd-2))))

(define-public kcodecs
  (package
    (name "kcodecs")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1v665sr76020yix4f2kkwrjz46lh0jyc4wdrzr1xairxzhd560k9"))))
    (build-system cmake-build-system)
    (native-inputs (list extra-cmake-modules gperf qttools))
    (inputs (list qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "String encoding and manipulating library")
    (description "KCodecs provide a collection of methods to manipulate
strings using various encodings.

It can automatically determine the charset of a string, translate XML
entities, validate email addresses, and find encodings by name in a more
tolerant way than QTextCodec (useful e.g. for data coming from the
Internet).")
    ;; The included licenses is are gpl2 and lgpl2.1, but the sources are
    ;; under a variety of licenses.
    ;; This list is taken from http://packaging.neon.kde.org/cgit/
    (license (list license:gpl2 license:gpl2+ license:bsd-2
                   license:lgpl2.1 license:lgpl2.1+ license:expat
                   license:lgpl3+ license:mpl1.1))))

(define-public kcodecs-5
  (package
    (inherit kcodecs)
    (name "kcodecs")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "03k8scmswxhx7bng5fh3niq84gqzksb19sf6ah4bdz6aj4pd52d4"))))
    (native-inputs (list extra-cmake-modules gperf qttools-5))
    (inputs (list qtbase-5))))

(define-public kcolorpicker
  (package
    (name "kcolorpicker")
    (version "0.3.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
              (url "https://github.com/ksnip/kColorPicker")
              (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1px40rasvz0r5db9av125q9mlyjz4xdnckg2767i3fndj3ic0vql"))))
    (build-system qt-build-system)
    (arguments
     (list #:qtbase qtbase
           #:configure-flags #~(list "-DBUILD_TESTS=ON"
                                     "-DBUILD_WITH_QT6=ON")))
    (home-page "https://github.com/ksnip/kColorPicker")
    (synopsis "Color Picker with popup menu")
    (description
     "@code{KColorPicker} is a subclass of @code{QToolButton} with color popup
menu which lets you select a color.  The popup features a color dialog button
which can be used to add custom colors to the popup menu.")
    (license license:lgpl3+)))

(define-public kcolorscheme
  (package
    (name "kcolorscheme")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))

              (sha256
               (base32
                "0dch0iv6kkbzc7cl5fbcls1ll2h4jdd16kv9g5d9y041ryyk05ri"))))
    (build-system qt-build-system)
    (native-inputs (list extra-cmake-modules))
    (inputs (list kguiaddons ki18n
                  qtdeclarative))
    (propagated-inputs (list kconfig))
    (arguments (list #:qtbase qtbase))
    (synopsis "Classes to read and interact with KColorScheme")
    (description "This package provide a Classes to read and interact with
KColorScheme.")
    (home-page "https://community.kde.org/Frameworks")
    (license (list license:cc0
                   license:lgpl2.0+
                   license:lgpl2.1
                   license:bsd-2
                   license:lgpl3))))

(define-public kconfig
  (package
    (name "kconfig")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0ybr5l0b9wvzkh3546s3dnv2di0vf3rcf0f6jzbyqlaigfprm04d"))))
    (build-system qt-build-system)
    (native-inputs
     (list dbus extra-cmake-modules inetutils qttools))
    (propagated-inputs (list qtdeclarative))
    (arguments
     (list
      #:qtbase qtbase
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'check-setup
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (with-output-to-file "autotests/BLACKLIST"
                  (lambda _
                    (for-each
                     (lambda (name)
                       (display (string-append "[" name "]\n*\n")))
                     (list "testNotifyIllegalObjectPath"
                           "testLocalDeletion"
                           "testNotify"
                           "testSignal"
                           "testDataUpdated"))))
                (setenv "HOME" (getcwd))
                (setenv "QT_QPA_PLATFORM" "offscreen")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Kconfiguration settings framework for Qt")
    (description "KConfig provides an advanced configuration system.
It is made of two parts: KConfigCore and KConfigGui.

KConfigCore provides access to the configuration files themselves.
It features:

@enumerate
@item Code generation: describe your configuration in an XML file, and use
`kconfig_compiler to generate classes that read and write configuration
entries.

@item Cascading configuration files (global settings overridden by local
settings).

@item Optional shell expansion support (see docs/options.md).

@item The ability to lock down configuration options (see docs/options.md).
@end enumerate

KConfigGui provides a way to hook widgets to the configuration so that they
are automatically initialized from the configuration and automatically
propagate their changes to their respective configuration files.")
    ;; The included licenses is are gpl2 and lgpl2.1, but the sources are
    ;; under a variety of licenses.
    ;; This list is taken from http://packaging.neon.kde.org/cgit/
    (license (list license:lgpl2.1 license:lgpl2.1+ license:expat
                   license:lgpl3+ license:gpl1 ; licende:mit-olif
                   license:bsd-2 license:bsd-3))))

(define-public kconfig-5
  (package
    (inherit kconfig)
    (name "kconfig")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "03j7cw0c05rpxrnblrc5ziq7vy1v193l5gj9bix1dakkj9hf6p9c"))))
    (native-inputs
     (list dbus extra-cmake-modules inetutils qttools-5
           xorg-server-for-tests))
    (inputs
     (list qtdeclarative-5))
    (propagated-inputs '())
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests? ;; kconfigcore-kconfigtest fails inconsistently!!
                     (setenv "HOME" (getcwd))
                     (setenv "QT_QPA_PLATFORM" "offscreen")
                     (invoke "ctest" "-E" "(kconfigcore-kconfigtest|\
kconfiggui-kstandardshortcutwatchertest)")))))))))

(define-public kcoreaddons
  (package
    (name "kcoreaddons")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0mn7qmfcics12w979q7gis3yn1w79fhzrxl30pv5y5x1qax97fxq"))))
    (build-system qt-build-system)
    (native-inputs (list extra-cmake-modules qttools shared-mime-info))
    (inputs (list qtdeclarative))
    (arguments
     (list
      #:qtbase qtbase
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'blacklist-failing-test
            (lambda _
              ;; Blacklist failing tests.
              (with-output-to-file "autotests/BLACKLIST"
                (lambda _
                  ;; FIXME: Make it pass.  Test failure caused by stout/stderr
                  ;; being interleaved.
                  (display "[test_channels]\n*\n")
                  ;; FIXME
                  (display "[test_inheritance]\n*\n")))))
          (add-before 'check 'check-setup
            (lambda _
              (setenv "HOME" (getcwd))
              (setenv "TMPDIR" (getcwd)))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Qt addon library with a collection of non-GUI utilities")
    (description "KCoreAddons provides classes built on top of QtCore to
perform various tasks such as manipulating mime types, autosaving files,
creating backup files, generating random sequences, performing text
manipulations such as macro replacement, accessing user information and
many more.")
    (license (list license:lgpl2.0+ license:lgpl2.1+))))

(define-public kcoreaddons-5
  (package
    (inherit kcoreaddons)
    (name "kcoreaddons")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0x1inzglgpz2z2w25bp46hzjv74gp3vyd3i911xczz7wd30b9yyy"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules qttools-5 shared-mime-info))
    (inputs
     (list qtbase-5))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'blacklist-failing-test
            (lambda _
              ;; Blacklist failing tests.
              (with-output-to-file "autotests/BLACKLIST"
                (lambda _
                  ;; FIXME: Make it pass.  Test failure caused by stout/stderr
                  ;; being interleaved.
                  (display "[test_channels]\n*\n")
                  ;; FIXME
                  (display "[test_inheritance]\n*\n")))))
          (add-before 'check 'check-setup
            (lambda _
              (setenv "HOME" (getcwd))
              (setenv "TMPDIR" (getcwd)))))))))

(define-public kdbusaddons
  (package
    (name "kdbusaddons")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "00i08baairndj5w6x3rhfxcws0xjd59wn2h08am3ll89xycqjbby"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules dbus qttools))
    (inputs (list libxkbcommon))
    (arguments
     (list #:qtbase qtbase
           #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (invoke "dbus-launch" "ctest")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Convenience classes for DBus")
    (description "KDBusAddons provides convenience classes on top of QtDBus,
as well as an API to create KDED modules.")
    ;; Some source files mention lgpl2.0+, but the included license is
    ;; the lgpl2.1. Some source files are under non-copyleft licenses.
    (license license:lgpl2.1+)))

(define-public kdbusaddons-5
  (package
    (inherit kdbusaddons)
    (name "kdbusaddons")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0mlfphk8knbvpyns3ixd8da9zjvsms29mv5z2xgif9y20i5kmdq3"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules dbus qttools-5))
    (inputs
     (list qtbase-5 qtx11extras kinit-bootstrap))
    ;; kinit-bootstrap: kinit package which does not depend on kdbusaddons.
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-before 'configure 'patch-source
                 (lambda* (#:key inputs #:allow-other-keys)
                   ;; look for the kdeinit5 executable in kinit's store directory,
                   ;; instead of the current application's directory:
                   (substitute* "src/kdeinitinterface.cpp"
                     (("<< QCoreApplication::applicationDirPath..")
                      (string-append
                       "<< QString::fromUtf8(\"/"
                       (dirname (search-input-file inputs "bin/kdeinit5"))
                       "\")" )))))
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (setenv "DBUS_FATAL_WARNINGS" "0")
                     (invoke "dbus-launch" "ctest")))))))))

(define kdbusaddons-5-bootstrap
  (package
    (inherit kdbusaddons-5)
    (source (origin
              (inherit (package-source kdbusaddons-5))
              (patches '())))
    (inputs (modify-inputs (package-inputs kdbusaddons-5) (delete "kinit")))
    (arguments
     (substitute-keyword-arguments (package-arguments kdbusaddons-5)
       ((#:phases phases)
        #~(modify-phases #$phases
            (delete 'patch-source)))))))

(define-public kdnssd
  (package
    (name "kdnssd")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0akip5sb8jva760lprxd3qbzlx9ql3vgdxdl1rblp5qsvv94h7b7"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list avahi ; alternativly dnssd could be used
           qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Network service discovery using Zeroconf")
    (description "KDNSSD is a library for handling the DNS-based Service
Discovery Protocol (DNS-SD), the layer of Zeroconf that allows network services,
such as printers, to be discovered without any user intervention or centralized
infrastructure.")
    (license license:lgpl2.1+)))

(define-public kdnssd-5
  (package
    (inherit kdnssd)
    (name "kdnssd")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1z2xyir6xvyyq3j48wmra3zka6hlpjr2rnfc4gbijl0aazv6srrm"))))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (inputs
     (list avahi qtbase-5))))

(define-public kgraphviewer
  (package
    (name "kgraphviewer")
    (version "2.5.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/kgraphviewer/"
                    version "/" name "-" version ".tar.xz"))
              (sha256
               (base32
                "0s9b3q7wvrbz52d500mcaflkrfjwhbzh5bsf5gxzgxjdzdiywaw7"))))
    (build-system cmake-build-system)
    (inputs
     (list qtbase
           boost
           graphviz
           ki18n
           kiconthemes
           kparts
           qtsvg
           qt5compat))
    (native-inputs
     (list pkg-config extra-cmake-modules kdoctools))
    (home-page "https://apps.kde.org/kgraphviewer/")
    (synopsis "Graphviz dot graph viewer for KDE")
    (description "KGraphViewer is a Graphviz DOT graph file viewer, aimed to
replace the other outdated Graphviz tools.")
    (license license:gpl2+)))

(define-public kguiaddons
  (package
    (name "kguiaddons")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "009jvkakgb44ykz3920pj87kxh9jgbp9mdi654f77hqyq0grnlg1"))))
    (build-system qt-build-system)
    ;; TODO: Build packages for the Python bindings.  Ideally this will be
    ;; done for all versions of python guix supports.  Requires python,
    ;; python-sip, clang-python, libclang.  Requires python-2 in all cases for
    ;; clang-python.
    (native-inputs (list extra-cmake-modules pkg-config))
    (inputs
     (list libxkbcommon qtwayland plasma-wayland-protocols wayland))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Utilities for graphical user interfaces")
    (description "The KDE GUI addons provide utilities for graphical user
interfaces in the areas of colors, fonts, text, images, keyboard input.")
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kguiaddons-5
  (package
    (inherit kguiaddons)
    (name "kguiaddons")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1rpw6glgchf7qs4rh7jxy9sas73708yllba1q880gdicn1nda42w"))))
    (native-inputs (list extra-cmake-modules pkg-config))
    (arguments '())
    (inputs
     (list qtwayland-5 qtx11extras plasma-wayland-protocols wayland))))

(define-public kholidays
  (package
    (name "kholidays")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32 "0pmcrzkq1s3aisihicazxgammmqmc63ywf6b0lwdb89xqwcf36cz"))))
    (build-system cmake-build-system)
    (native-inputs (list extra-cmake-modules qttools))
    (inputs (list qtbase qtdeclarative))
    (home-page "https://invent.kde.org/frameworks/kholidays")
    (synopsis "Library for regional holiday information")
    (description "This library provides a C++ API that determines holiday and
other special events for a geographical region.")
    (license license:lgpl2.0+)))

(define-public ki18n
  (package
    (name "ki18n")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "10kjjl6af3kbp0zs4pny6wrl5a7ld05fp5hkj31zww10p8g395ad"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list gettext-minimal))
    (native-inputs
     (list extra-cmake-modules python-minimal tzdata-for-tests))
    (inputs
     (list qtbase qtdeclarative iso-codes))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HOME"
                        (getcwd))
                (invoke "ctest" "-E"
                        "(kcountrytest|kcountrysubdivisiontest)")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE Gettext-based UI text internationalization")
    (description "KI18n provides functionality for internationalizing user
interface text in applications, based on the GNU Gettext translation system.  It
wraps the standard Gettext functionality, so that the programmers and translators
can use the familiar Gettext tools and workflows.

KI18n provides additional functionality as well, for both programmers and
translators, which can help to achieve a higher overall quality of source and
translated text.  This includes argument capturing, customizable markup, and
translation scripting.")
    (license license:lgpl2.1+)))

(define-public ki18n-5
  (package
    (inherit ki18n)
    (name "ki18n")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1kbb3rq85hbw1h5bd1w9cmdgz8bdg47w9b133ha41qlhh1i50clk"))))
    (propagated-inputs
     (list gettext-minimal python))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list qtbase-5 qtdeclarative-5 qtscript iso-codes))))

(define-public kidletime
  (package
    (name "kidletime")
    (version "6.3.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://kde/stable/frameworks/"
                           (version-major+minor version) "/"
                           name "-" version ".tar.xz"))
       (sha256
        (base32 "0ba74qa3p8qfmv2k1mq9wh00yih331y0wzc1i0mk8f37rry6g3yd"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules pkg-config
           ;; for wayland-scanner
           wayland))
    (inputs
     (list qtbase
           qtwayland
           wayland
           plasma-wayland-protocols
           wayland-protocols
           libxkbcommon))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Reporting of idle time of user and system")
    (description "KIdleTime is a singleton reporting information on idle time.
It is useful not only for finding out about the current idle time of the PC,
but also for getting notified upon idle time events, such as custom timeouts,
or user activity.")
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kidletime-5
  (package
    (inherit kidletime)
    (name "kidletime")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "15s9nxpkqy3i182xk82bpl92iaqcilsckja7301854fw6ppl8vvh"))))
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs
     (list libxscrnsaver ; X-Screensaver based poller, fallback mode
           qtbase-5 qtx11extras))))

(define-public kirigami
  (package
    (name "kirigami")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    "kirigami-" version ".tar.xz"))
              (sha256
               (base32
                "0nrrnbf7hmis6sbqilmqf6wgjyvg5zwzlkcgzq0kbh1pbfhgmjyv"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list kwindowsystem
           qtshadertools
           qtbase
           qtdeclarative
           qtsvg
           libxkbcommon))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "QtQuick components for mobile user interfaces")
    (description "Kirigami is a set of high level QtQuick components looking
and feeling well on both mobile and desktop devices.  They ease the creation
of applications that follow the Kirigami Human Interface Guidelines.")
    (license license:lgpl2.1+)))

(define-public kirigami-5
  (package
    (inherit kirigami)
    (name "kirigami")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    "kirigami2-" version ".tar.xz"))
              (sha256
               (base32
                "1q69b1qd2qs9hpwgw0y0ig93ag41l50dghribsnqhi0c9aklsn4b"))))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (inputs
     (list kwindowsystem-5
           qtbase-5
           qtdeclarative-5
           qtquickcontrols2-5
           qtsvg-5
           ;; Run-time dependency
           qtgraphicaleffects))
    (properties `((upstream-name . "kirigami2")))))

(define-public kitemmodels
  (package
    (name "kitemmodels")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1fmcas5n3ylgzjlmwhcnqpsm46p50zia4xzvnf5iz74icbxq9adk"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs (list qtdeclarative))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Set of item models extending the Qt model-view framework")
    (description "KItemModels provides the following models:

@enumerate
@item KBreadcrumbSelectionModel - Selects the parents of selected items to
create breadcrumbs.

@item KCheckableProxyModel - Adds a checkable capability to a source model.

@item KConcatenateRowsProxyModel - Concatenates rows from multiple source models.

@item KDescendantsProxyModel - Proxy Model for restructuring a Tree into a list.

@item KExtraColumnsProxyModel - Adds columns after existing columns.

@item KLinkItemSelectionModel - Share a selection in multiple views which do
not have the same source model.

@item KModelIndexProxyMapper - Mapping of indexes and selections through proxy
models.

@item KRearrangeColumnsProxyModel - Can reorder and hide columns from the source
model.

@item KRecursiveFilterProxyModel - Recursive filtering of models.

@item KSelectionProxyModel - A Proxy Model which presents a subset of its source
model to observers
@end enumerate")
    (license license:lgpl2.1+)))

(define-public kitemmodels-5
  (package
    (inherit kitemmodels)
    (name "kitemmodels")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1wcznkj24553spkl202zwifk6hgrvdd60j3y47jp2m6zpadywz2k"))))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list qtdeclarative-5))
    (arguments '())))

(define-public kitemviews
  (package
    (name "kitemviews")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0byllbqxk2q4svxh1pim8jm6n2qimh5gp9h0m0s1hqqiaqapsrfq"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules qttools))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Set of item views extending the Qt model-view framework")
    (description "KItemViews includes a set of views, which can be used with
item models.  It includes views for categorizing lists and to add search filters
to flat and hierarchical lists.")
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kitemviews-5
  (package
    (inherit kitemviews)
    (name "kitemviews")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1sq1kvqb9g0gzlyfyix9xsjq6wl2i1s3mfqkpdc0rdns13sgn3kc"))))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (arguments '())))

(define-public kplotting
  (package
    (name "kplotting")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "08cmp86h7pwjsds2kdcnnab8nincnmp72irk9y9ansqfglsgmrzq"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules qttools))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Data plotting library")
    (description "KPlotWidget is a QWidget-derived class that provides a virtual
base class for easy data-plotting.  The idea behind KPlotWidget is that you only
have to specify information in \"data units\", the natural units of the
data being plotted.  KPlotWidget automatically converts everything to screen
pixel units.")
    (license license:lgpl2.1+)))

(define-public ksvg
  (package
    (name "ksvg")
    (version "6.3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "15n7schzmwq4z0yiw0l1js45mml5wq3syb5vc7j9hs88j1jdcp6q"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list
      qtdeclarative
      qtsvg
      karchive
      kconfig
      kcolorscheme
      kcoreaddons
      kguiaddons
      kirigami))
    (arguments
     (list #:qtbase qtbase
           #:phases #~(modify-phases %standard-phases
                        (add-before 'check 'check-setup
                          (lambda _
                            (setenv "HOME" (getcwd)))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Components for handling SVGs")
    (description "A library for rendering SVG-based themes with stylesheet
re-coloring and on-disk caching.")
    (license license:lgpl2.1+)))

(define-public ksyntaxhighlighting
  (package
    (name "ksyntaxhighlighting")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    "syntax-highlighting-" version ".tar.xz"))
              (sha256
               (base32
                "117r5nsggqnlkd8mg9l2aa00q2ns891xadxl6vxgbgk9r4shlc1q"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules perl qttools))
    (inputs
     (list qtbase qtdeclarative))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-after 'patch-source-shebangs 'unpatch-source-shebang
                 (lambda _
                   ;; revert the patch-shebang phase on scripts which are
                   ;; in fact test data
                   (substitute* '("autotests/input/highlight.sh"
                                  "autotests/folding/highlight.sh.fold")
                     (((which "sh")) " /bin/sh")) ;; space in front!
                   (substitute* '("autotests/input/highlight.pl"
                                  "autotests/folding/highlight.pl.fold")
                     (((which "perl")) "/usr/bin/perl")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Syntax highlighting engine for Kate syntax definitions")
    (description "This is a stand-alone implementation of the Kate syntax
highlighting engine.  It's meant as a building block for text editors as well
as for simple highlighted text rendering (e.g. as HTML), supporting both
integration with a custom editor as well as a ready-to-use
@code{QSyntaxHighlighter} sub-class.")
    (properties `((upstream-name . "syntax-highlighting")))
    (license license:lgpl2.1+)))

(define-public ksyntaxhighlighting-5
  (package
    (inherit ksyntaxhighlighting)
    (name "ksyntaxhighlighting")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    "syntax-highlighting-" version ".tar.xz"))
              (sha256
               (base32
                "19zs3n6cn83rjs0bpyrn6f5r75qcflavf8rb1c2wxj8dpp7cm33g"))))
    (native-inputs
     (list extra-cmake-modules perl qttools-5
           ;; Optional, for compile-time validation of syntax definition files:
           qtxmlpatterns))
    (inputs
     (list qtbase-5))))

(define-public plasma-wayland-protocols
  (package
    (name "plasma-wayland-protocols")
    (version "1.13.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/" name "/"
                                  name "-" version ".tar.xz"))
              (sha256
               (base32
                "0znm2nhpmfq2vakyapmq454mmgqr5frc91k2d2nfdxjz5wspwiyx"))))
    (build-system cmake-build-system)
    (native-inputs (list extra-cmake-modules))
    (arguments '(#:tests? #f))          ;no tests
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE Plasma Wayland Protocols")
    (description
     "This package contains XML files describing non-standard Wayland
protocols used in KDE Plasma.")
    ;; The XML files have varying licenses, open them for details.
    (license (list license:bsd-3
                   license:lgpl2.1+
                   license:expat))))

(define-public kwayland
  (package
    (name "kwayland")
    (version "6.1.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/plasma/"
                                  version "/kwayland" "-"
                                  version ".tar.xz"))
              (sha256
               (base32
                "15dmbcqhajqc100k95y6nh0w2br8xwql4mlq8grh4r6cdgn378n6"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules pkg-config
           ;; for wayland-scanner
           wayland))
    (inputs
     (list libxkbcommon
           plasma-wayland-protocols
           qtwayland
           wayland
           wayland-protocols))
    (arguments
     (list #:qtbase qtbase))
    (home-page "https://invent.kde.org/plasma/kwayland")
    (synopsis "Qt-style API to interact with the wayland client and server")
    (description "As the names suggest they implement a Client respectively a
Server API for the Wayland protocol.  The API is Qt-styled removing the needs to
interact with a for a Qt developer uncomfortable low-level C-API.  For example
the callback mechanism from the Wayland API is replaced by signals, data types
are adjusted to be what a Qt developer expects - two arguments of int are
represented by a QPoint or a QSize.")
    (license license:lgpl2.1+)))

(define-public kwayland-5
  (package
    (inherit kwayland)
    (name "kwayland")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1n5fq0gppx6rzgzkkskd077jygzj7cindb7zwr35yvbg5l69gdc8"))))
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs
     (list libxkbcommon
           plasma-wayland-protocols
           qtwayland-5
           wayland
           wayland-protocols))
    (arguments
     (list
      ;; Tests spawn Wayland sessions that cannot run in parallel.
      #:parallel-tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'set-XDG_RUNTIME_DIR
            (lambda _
              (setenv "XDG_RUNTIME_DIR" (getcwd))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "ctest" "-E"
                        (string-append
                         "("
                         (string-join
                          ;; XXX: maybe is upstream bug
                          '("kwayland-testWaylandRegistry"
                            "kwayland-testPlasmaShell"
                            "kwayland-testPlasmaWindowModel"
                            ;; The 'kwayland-testXdgForeign' may fail on
                            ;; powerpc64le with a 'Subprocess aborted' error.
                            "kwayland-testXdgForeign") "|")
                         ")"))))))))))

(define-public kwidgetsaddons
  (package
    (name "kwidgetsaddons")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0k44s7j80qapnwsjr1y7igpzxddy065gw3xm7i1av9m0p46rygqf"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules qttools))
    (arguments
     (list
      #:qtbase qtbase
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? parallel-tests? #:allow-other-keys)
              (when tests?
                ;; hideLaterShouldHideAfterDelay function time: 300000ms, total time: 300009ms
                (invoke "ctest" "-E"
                        "(ktooltipwidgettest)"
                        "-j"
                        (if parallel-tests?
                            (number->string (parallel-job-count))
                            "1"))))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Large set of desktop widgets")
    (description "Provided are action classes that can be added to toolbars or
menus, a wide range of widgets for selecting characters, fonts, colors, actions,
dates and times, or MIME types, as well as platform-aware dialogs for
configuration pages, message boxes, and password requests.")
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kwidgetsaddons-5
  (package
    (inherit kwidgetsaddons)
    (name "kwidgetsaddons")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0rcm27wra9s7kzlk67y0f57l0rnh5vb9c2w39h6yjq37y5af1qd8"))))
    (native-inputs
     (list extra-cmake-modules qttools-5 xorg-server-for-tests))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "XDG_CACHE_HOME" "/tmp/xdg-cache")
                (invoke "ctest" "-E"
                        "(ksqueezedtextlabelautotest|\
kwidgetsaddons-kcolumnresizertest)")))))))))

(define-public kwindowsystem
  (package
    (name "kwindowsystem")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1fdax3c2q3fm56pvr99z0rwf1nwz7jmksblj9d42gg1l55ckrqs0"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules
           pkg-config
           wayland; for wayland-scanner
           dbus ; for the tests
           openbox ; for the test
           qttools
           xorg-server-for-tests)) ; for the tests
    (inputs
     (list qtbase
           qtdeclarative
           qtwayland
           wayland-protocols
           plasma-wayland-protocols
           libxkbcommon
           wayland
           xcb-util-keysyms
           xcb-util-wm))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              ;; The test suite requires a running window anager
              (when tests?
                (setenv "XDG_RUNTIME_DIR" (getcwd))
                (system "Xvfb :1 -ac -screen 0 640x480x24 &")
                (setenv "DISPLAY" ":1")
                (sleep 5) ;; Give Xvfb a few moments to get on it's feet
                (system "openbox &")
                (setenv "CTEST_OUTPUT_ON_FAILURE" "1")
                (setenv "DBUS_FATAL_WARNINGS" "0")
                (invoke "dbus-launch" "ctest")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE access to the windowing system")
    (description "KWindowSystem provides information about and allows
interaction with the windowing system.  It provides a high level API, which
is windowing system independent and has platform specific
implementations.  This API is inspired by X11 and thus not all functionality
is available on all windowing systems.

In addition to the high level API, this framework also provides several
lower level classes for interaction with the X Windowing System.")
    ;; Some source files mention lgpl2.0+, but the included license is
    ;; the lgpl2.1. Some source files are under non-copyleft licenses.
    (license license:lgpl2.1+)))

(define-public kwindowsystem-5
  (package
    (inherit kwindowsystem)
    (name "kwindowsystem")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0d2kxcpcvpzv07ldd1kb5gjclhmn6gcn5ms0bd8f5g9gflrpdjby"))))
    (native-inputs
     (list extra-cmake-modules
           pkg-config
           dbus ; for the tests
           openbox ; for the tests
           qttools-5
           xorg-server-for-tests)) ; for the tests
    (inputs
     (list libxrender
           qtbase-5
           qtx11extras
           xcb-util-keysyms
           xcb-util-wm))))

(define-public modemmanager-qt
  (package
    (name "modemmanager-qt")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1ky77v27nbil5vcig07yyk3jahv673qr7pn41dsb7f588sbh5www"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules dbus pkg-config))
    (propagated-inputs
     ;; Headers contain #include <ModemManager/ModemManager.h>
     (list modem-manager))
    (inputs
     (list qtbase))
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (replace 'check
                          (lambda* (#:key tests? #:allow-other-keys)
                            (when tests?
                              (setenv "DBUS_FATAL_WARNINGS" "0")
                              (invoke "dbus-launch" "ctest")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Qt wrapper for ModemManager DBus API")
    (description "ModemManagerQt provides access to all ModemManager features
exposed on DBus.  It allows you to manage modem devices and access to
information available for your modem devices, like signal, location and
messages.")
    (license license:lgpl2.1+)))

(define-public networkmanager-qt
  (package
    (name "networkmanager-qt")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1q1r3s136bpg2gnrwhakww9yzd42ccymvisrpqv3l0wgywxnma8c"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules dbus pkg-config))
    (inputs (list qtbase))
    (propagated-inputs
     ;; Headers contain #include <NetworkManager.h> and
     ;;                 #include <libnm/NetworkManager.h>
     (list network-manager
           qtdeclarative))
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (replace 'check
                          (lambda* (#:key tests? #:allow-other-keys)
                            (when tests?
                              (setenv "DBUS_FATAL_WARNINGS" "0")
                              (invoke "dbus-launch" "ctest")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Qt wrapper for NetworkManager DBus API")
    (description "NetworkManagerQt provides access to all NetworkManager
features exposed on DBus.  It allows you to manage your connections and control
your network devices and also provides a library for parsing connection settings
which are used in DBus communication.")
    (license license:lgpl2.1+)))

(define-public networkmanager-qt5
  (package
    (inherit networkmanager-qt)
    (name "networkmanager-qt5")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version)
                    "/networkmanager-qt-" version ".tar.xz"))
              (sha256
               (base32
                "0s8vc3qqx76f70vql77hb3nxkn6b3hvzdm6bgcpnnxqhw6j80khb"))))
    (native-inputs
     (list extra-cmake-modules dbus pkg-config))
    (propagated-inputs
     ;; Headers contain #include <NetworkManager.h> and
     ;;                 #include <libnm/NetworkManager.h>
     (list network-manager))
    (inputs
     (list qtbase-5))
    (properties `((upstream-name . "networkmanager-qt")))))

(define-public oxygen-icons
  (package
    (name "oxygen-icons")
    (version "6.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/oxygen-icons/"
                    "/oxygen-icons" "-" version ".tar.xz"))
              (sha256
               (base32
                "0x2piq03gj72p5qlhi8zdx3r58va088ysp7lg295vhfwfll1iv18"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules
           ;; for test
           fdupes))
    (inputs (list qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Oxygen provides the standard icon theme for the KDE desktop")
    (description "Oxygen icon theme for the KDE desktop")
    (license license:lgpl3+)))

(define-public prison
  (package
    (name "prison")
    (version "6.3.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://kde/stable/frameworks/"
                           (version-major+minor version) "/"
                           name "-" version ".tar.xz"))
       (sha256
        (base32 "0imwniw2lpsjipzyx9vmwwdy370sg5zynh9gk9g1w1c7axr0g63n"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list libdmtx zxing-cpp qrencode qtbase qtdeclarative qtmultimedia))
    (home-page "https://api.kde.org/frameworks/prison/html/index.html")
    (synopsis "Barcode generation abstraction layer")
    (description "Prison is a Qt-based barcode abstraction layer/library and
provides uniform access to generation of barcodes with data.")
    (license license:lgpl2.1+)))

(define-public pulseaudio-qt
  (package
    (name "pulseaudio-qt")
    (version "1.5.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/pulseaudio-qt"
                                  "/pulseaudio-qt-" version ".tar.xz"))
              (sha256
               (base32
                "0845d910jyd6w02yc157m4myfwzbmj1l0y6mj3yx0wq0f34533yd"))))
    (build-system cmake-build-system)
    (arguments (list #:configure-flags #~(list "-DBUILD_WITH_QT6=ON")))
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs
     (list glib pulseaudio qtdeclarative qtbase))
    (home-page "https://invent.kde.org/libraries/pulseaudio-qt/")
    (synopsis "Qt bindings for PulseAudio")
    (description
     "pulseaudio-qt is a Qt-style wrapper for libpulse.  It allows querying
and manipulation of various PulseAudio objects such as @code{Sinks},
@code{Sources} and @code{Streams}.  It does not wrap the full feature set of
libpulse.")
    ;; User can choose between LGPL version 2.1 or 3.0; or
    ;; "any later version accepted by the membership of KDE e.V".
    (license (list license:lgpl2.1 license:lgpl3))))

(define-public qqc2-desktop-style
  (package
    (name "qqc2-desktop-style")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1c5wy4a8x2lslc3dkqpn7k479jfpam63c93sqgyd4iingyxnjzly"))))
    (build-system qt-build-system)
    (arguments
     (list
      #:qtbase qtbase
      #:phases #~(modify-phases %standard-phases
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         (invoke "dbus-launch" "ctest"
                                 "--rerun-failed" "--output-on-failure")))))))
    (native-inputs
     (list extra-cmake-modules dbus pkg-config qttools))
    (inputs
     (list kauth
           kconfig ; optional
           kcoreaddons
           kiconthemes ; optional
           kirigami
           qtdeclarative
           sonnet)) ; optional
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "QtQuickControls2 style that integrates with the desktop")
    (description "This is a style for QtQuickControls2 which is using
QWidget's QStyle to paint the controls in order to give it a native look and
feel.")
    ;; Mostly LGPL 2+, but many files are dual-licensed
    (license (list license:lgpl2.1+ license:gpl3+))))

(define-public solid
  (package
    (name "solid")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1nckgnr2834ppjjm3nq5xcasw7f3rvr95g8d37yh3vmwk6arj8dq"))))
    (build-system cmake-build-system)
    (native-inputs
     (list bison dbus extra-cmake-modules flex qttools))
    ;; TODO: Add runtime-only dependency MediaPlayerInfo
    (inputs
     (list `(,util-linux "lib") ;; Optional, for libmount
           libxkbcommon
           vulkan-headers
           qtbase qtdeclarative eudev))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Desktop hardware abstraction")
    (description "Solid is a device integration framework.  It provides a way of
querying and interacting with hardware independently of the underlying operating
system.")
    (license license:lgpl2.1+)))

(define-public solid-5
  (package
    (inherit solid)
    (name "solid")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "04359x7rhhl68xcrspxywxywb900dvlkna5fb442npwiqaxdxhy6"))))
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (replace 'check
                          (lambda* (#:key tests? #:allow-other-keys)
                            (when tests?
                              (setenv "DBUS_FATAL_WARNINGS" "0")
                              (invoke "dbus-launch" "ctest")))))))
    (native-inputs
     (list bison dbus extra-cmake-modules flex qttools-5))
    (inputs
     (list qtbase-5 qtdeclarative-5 eudev))))

(define-public sonnet
  (package
    (name "sonnet")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0zjcjy2b697wizgrr210g24cvkli6yi2ry05kzfc6xxarq0dsi3b"))))
    (build-system qt-build-system)
    (arguments (list #:qtbase qtbase))
    (native-inputs
     (list extra-cmake-modules pkg-config qttools))
    (inputs
     (list aspell hunspell
           ;; TODO: hspell (for Hebrew), Voikko (for Finish)
           qtdeclarative))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Multi-language spell checker")
    (description "Sonnet is a plugin-based spell checking library for Qt-based
applications.  It supports several different plugins, including HSpell, Enchant,
ASpell and HUNSPELL.")
    (license license:lgpl2.1+)))

(define-public sonnet-5
  (package
    (inherit sonnet)
    (name "sonnet")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0jja3wxk4h62ik5pkf0i5v9012d0qjaljyaab2a9g0j2wy070hcq"))))
    (arguments '())
    (native-inputs
     (list extra-cmake-modules pkg-config qttools-5))
    (inputs
     (list aspell
           hunspell
           qtdeclarative-5))))

(define-public threadweaver
  (package
    (name "threadweaver")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "04yrywhjhlyf1ha3w6rmaszyb28j91lc9j55frxrdmhqk67iy841"))))
    (build-system cmake-build-system)
    (native-inputs (list extra-cmake-modules))
    (inputs (list qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Helper for multithreaded programming")
    (description "ThreadWeaver is a helper for multithreaded programming.  It
uses a job-based interface to queue tasks and execute them in an efficient way.")
    (license license:lgpl2.1+)))

(define-public threadweaver-5
  (package
    (inherit threadweaver)
    (name "threadweaver")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1q7ax3dhsayz35j0l9pdmarkwfyyy1dsy2crdf5xz8pr5mjxq8wp"))))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list qtbase-5))))

(define-public libkdcraw
  (package
    (name "libkdcraw")
    (version "24.05.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://kde/stable/release-service/" version
                           "/src/" name "-" version ".tar.xz"))
       (sha256
        (base32 "0a4aifi3jwkizdn2qsa441f28j9ykymw4bn922d5pz6c9riw3ssr"))))
    (build-system cmake-build-system)
    (native-inputs
     (list pkg-config extra-cmake-modules))
    (inputs
     (list libraw qtbase))
    (arguments (list #:configure-flags
                     #~(list #$(string-append
                                "-DQT_MAJOR_VERSION="
                                (version-major
                                 (package-version
                                  (this-package-input "qtbase")))))))
    (home-page "https://invent.kde.org/graphics/libkdcraw")
    (synopsis "C++ interface used to decode RAW picture files")
    (description "Libkdcraw is a C++ interface around LibRaw library used to
decode RAW picture files.")
    (license (list license:gpl2+ license:bsd-3))))

(define-public libkdcraw-qt5
  (package
    (inherit libkdcraw)
    (name "libkdcraw-qt5")
    (inputs (modify-inputs (package-inputs libkdcraw)
              (replace "qtbase" qtbase-5)))))

;; Tier 2
;;
;; Tier 2 frameworks additionally depend on tier 1 frameworks, but still have
;; easily manageable dependencies.

(define-public kactivities
  (package
    (name "kactivities")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0zbjs4sysfaf6zsdnfmkbpxsc2bg5ncnhkzfn1dyhrsqk68lwz3s"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list boost
           kauth-5
           kbookmarks-5
           kcodecs-5
           kcompletion-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kio-5
           kitemviews-5
           kjobwidgets-5
           kservice-5
           kwidgetsaddons-5
           kwindowsystem-5
           kxmlgui-5
           qtdeclarative-5
           solid-5))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Core components for the KDE Activity concept")
    (description "KActivities provides the infrastructure needed to manage a
user's activities, allowing them to switch between tasks, and for applications
to update their state to match the user's current activity.  This includes a
daemon, a library for interacting with that daemon, and plugins for integration
with other frameworks.")
    ;; triple licensed
    (license (list license:gpl2+ license:lgpl2.0+ license:lgpl2.1+))))

(define-public kauth
  (package
    (name "kauth")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1d9kmxbb3rx4nx1yq0crywirmnnp8qvhs2pdng7s49pqdy0kdkzb"))))
    (build-system cmake-build-system)
    (native-inputs
     (list dbus extra-cmake-modules qttools))
    (propagated-inputs (list kcoreaddons))
    (inputs
     (list kwindowsystem polkit-qt6 qtbase))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-cmake-install-directories
            (lambda _
              ;; Make packages using kauth put their policy files and helpers
              ;; into their own prefix.
              (substitute* #$(string-append "KF" (version-major
                                                  (package-version this-package))
                                            "AuthConfig.cmake.in")
                (("@KAUTH_POLICY_FILES_INSTALL_DIR@")
                 "${KDE_INSTALL_DATADIR}/polkit-1/actions")
                (("@KAUTH_HELPER_INSTALL_DIR@")
                 "${KDE_INSTALL_LIBEXECDIR}/kauth")
                (("@KAUTH_HELPER_INSTALL_ABSOLUTE_DIR@")
                 "${KDE_INSTALL_FULL_LIBEXECDIR}/kauth"))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "DBUS_FATAL_WARNINGS" "0")
                (invoke "dbus-launch" "ctest")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Execute actions as privileged user")
    (description "KAuth provides a convenient, system-integrated way to offload
actions that need to be performed as a privileged user to small set of helper
utilities.")
    (license license:lgpl2.1+)))

(define-public kauth-5
  (package
    (inherit kauth)
    (name "kauth")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1x0zd6lqv855jkihxpzhxs732qiva31kzjah9hf2j6xaq0dfxqdc"))))
    (build-system cmake-build-system)
    (native-inputs
     (list dbus extra-cmake-modules qttools-5))
    (inputs
     (list kcoreaddons-5 polkit-qt qtbase-5))
    (propagated-inputs '())))

(define-public kcompletion
  (package
    (name "kcompletion")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0bkixs49w56d6s2yi5nkk6q2rg86wc81phrqa0508p98pp37l0iz"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list kcodecs kconfig kwidgetsaddons))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Powerful autocompletion framework and widgets")
    (description "This framework helps implement autocompletion in Qt-based
applications.  It provides a set of completion-ready widgets, or can be
integrated it into your application's other widgets.")
    (license license:lgpl2.1+)))

(define-public kcompletion-5
  (package
    (inherit kcompletion)
    (name "kcompletion")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1sh9gpbi65mbs8bszrxh7a9ifgcr7z5jrhsac3670905a6mdmfjj"))))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (inputs
     (list kconfig-5 kwidgetsaddons-5))
    (arguments '())))

(define-public kcontacts
  (package
    (name "kcontacts")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (patches
               (search-patches "kcontacts-incorrect-country-name.patch"))
              (sha256
               (base32
                "01xi60ykp7lhmwr7890byij893pfxn35qwbz4bmzmiydjwbmp6r2"))))
    (build-system qt-build-system)
    (native-inputs (list extra-cmake-modules
                         ;; for test
                         iso-codes))
    (inputs (list qtdeclarative))
    (propagated-inputs
     (list ;; As required by KF6ContactsConfig.cmake.
      kcodecs kconfig kcoreaddons ki18n))
    (arguments
     (list
      #:qtbase qtbase
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'check-setup
            (lambda _ (setenv "HOME" (getcwd)))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "API for contacts/address book data following the vCard standard")
    (description "This library provides a vCard data model, vCard
input/output, contact group management, locale-aware address formatting, and
localized country name to ISO 3166-1 alpha 2 code mapping and vice verca.
")
    (license license:lgpl2.1+)))

(define-public kcrash
  (package
    (name "kcrash")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0hcgljz5wm9v4qphc4cmn81gdrs8lcb4x978xz82gnmqx47pmik5"))))
    (build-system qt-build-system)
    (native-inputs (list extra-cmake-modules))
    (inputs (list kcoreaddons kwindowsystem))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Graceful handling of application crashes")
    (description "KCrash provides support for intercepting and handling
application crashes.")
    (license license:lgpl2.1+)))

(define-public kcrash-5
  (package
    (inherit kcrash)
    (name "kcrash")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0rg8g50y44gq3hjl5fc36siyyq3czd2zrf4c70fspk33svwldlw1"))))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list kcoreaddons-5 kwindowsystem-5 qtx11extras))
    (arguments '())))

(define-public kdoctools
  (package
    (name "kdoctools")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0jl5qxjscjdpf0jpl35ymdqhks3ynk8jxlwv6xdqml6vp4aysl2b"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list docbook-xml-4.5
           docbook-xsl
           gettext-minimal
           karchive
           ki18n
           libxml2
           libxslt
           perl
           perl-uri
           qtbase))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'cmake-find-docbook
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* (find-files "cmake" "\\.cmake$")
                (("CMAKE_SYSTEM_PREFIX_PATH") "CMAKE_PREFIX_PATH"))
              (substitute* "cmake/FindDocBookXML4.cmake"
                (("^.*xml/docbook/schema/dtd.*$")
                 "xml/dtd/docbook\n"))
              (substitute* "cmake/FindDocBookXSL.cmake"
                (("^.*xml/docbook/stylesheet.*$")
                 (string-append "xml/xsl/docbook-xsl-"
                                #$(package-version (this-package-input "docbook-xsl"))
                                "\n"))))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Create documentation from DocBook")
    (description "Provides tools to generate documentation in various format
from DocBook files.")
    (license license:lgpl2.1+)))

(define-public kdoctools-5
  (package
    (inherit kdoctools)
    (name "kdoctools")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1cvb39ggc79fpfa84rshm6vl10h0avn2rf6qxaxb41r9887ad81n"))))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list docbook-xml-4.5
           docbook-xsl
           karchive-5
           ki18n-5
           libxml2
           libxslt
           perl
           perl-uri
           qtbase-5))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'cmake-find-docbook
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* (find-files "cmake" "\\.cmake$")
                (("CMAKE_SYSTEM_PREFIX_PATH")
                 "CMAKE_PREFIX_PATH"))
              (substitute* "cmake/FindDocBookXML4.cmake"
                (("^.*xml/docbook/schema/dtd.*$")
                 "xml/dtd/docbook\n"))
              (substitute* "cmake/FindDocBookXSL.cmake"
                (("^.*xml/docbook/stylesheet.*$")
                 (string-append "xml/xsl/docbook-xsl-"
                                #$(package-version docbook-xsl)
                                "\n")))))
          (add-after 'install 'add-symlinks
            ;; Some package(s) (e.g. kdelibs4support) refer to this locale by a
            ;; different spelling.
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((xsl (string-append (assoc-ref outputs "out")
                                        "/share/kf5/kdoctools/customization/xsl/")))
                (symlink (string-append xsl "pt_br.xml")
                         (string-append xsl "pt-BR.xml"))))))))))

(define-public kfilemetadata
  (package
    (name "kfilemetadata")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1230gl5jf4wizvxhfl0l4393vzgfzj0im139kjlss0qshrwf725x"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "ctest" "-E" "(exiv2extractortest|usermetadatawritertest)")))))))
    (native-inputs (list extra-cmake-modules pkg-config))
    (inputs
     (list attr
           ebook-tools
           kcodecs
           libplasma
           karchive
           kconfig
           kcoreaddons
           kdegraphics-mobipocket
           ki18n
           qtmultimedia
           qtbase
           ;; Required run-time packages
           catdoc
           ;; Optional run-time packages
           exiv2
           ffmpeg
           poppler-qt6
           taglib))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Extract metadata from different fileformats")
    (description "KFileMetaData provides a simple library for extracting the
text and metadata from a number of different files.  This library is typically
used by file indexers to retrieve the metadata.  This library can also be used
by applications to write metadata.")
    (license (list license:lgpl2.0 license:lgpl2.1 license:lgpl3))))

(define-public kfilemetadata-5
  (package
    (inherit kfilemetadata)
    (name "kfilemetadata")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "13yfcy02rmhrhf8lxv7smk1n9rg1ywsh60hwzm94b8hq9a62qp0r"))))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "ctest" "-E"
                        "(usermetadatawritertest|taglibextractortest)")))))))
    (native-inputs (list extra-cmake-modules pkg-config))
    (inputs
     (list attr
           ebook-tools
           karchive-5
           kconfig-5
           kcoreaddons-5
           ki18n-5
           qtmultimedia-5
           qtbase-5
           ;; Required run-time packages
           catdoc
           ;; Optional run-time packages
           exiv2
           ffmpeg
           poppler-qt5
           taglib))))

(define-public kimageannotator
  (package
    (name "kimageannotator")
    (version "0.7.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ksnip/kImageAnnotator")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1f1y4r5rb971v2g34fgjbr14g0mdms5h66yl5k0p1zf50kr2wnic"))))
    (build-system qt-build-system)
    (arguments
     (list #:qtbase qtbase
           #:configure-flags #~(list "-DBUILD_SHARED_LIBS=ON"
                                     "-DBUILD_TESTS=ON"
                                     "-DBUILD_WITH_QT6=ON")
           #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda _
                   ;; 1 test requires a running X server, it calls
                   ;; 'XCloseDisplay'.
                   (system "Xvfb :1 -screen 0 640x480x24 &")
                   (setenv "DISPLAY" ":1")
                   (invoke "ctest" "--test-dir" "tests"))))))
    (native-inputs
     (list qttools xorg-server-for-tests))
    (inputs
     (list googletest qtsvg kcolorpicker))
    (home-page "https://github.com/ksnip/kImageAnnotator")
    (synopsis "Image annotating library")
    (description "This library provides tools to annotate images.")
    (license license:lgpl3+)))

(define-public kimageformats
  (package
    (name "kimageformats")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "040j1jr7v4bc0zh4lf7bn9sj4a7g3c8icljagjpm7v9mpmqhgm0f"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs
     (list karchive ; for Krita and OpenRaster images
           openexr ; for OpenEXR high dynamic-range images
           qtbase
           libjxl
           libraw
           libavif
           ;; see https://bugs.kde.org/show_bug.cgi?id=468288,
           ;; kimageformats-read-psd test need QTiffPlugin
           qtimageformats
           ;; FIXME: make openexr propagate two package
           imath zlib))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'check-setup
            (lambda _
              ;; make Qt render "offscreen", required for tests
              (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Plugins to allow QImage to support extra file formats")
    (description "This framework provides additional image format plugins for
QtGui.  As such it is not required for the compilation of any other software,
but may be a runtime requirement for Qt-based software to support certain image
formats.")
    (license license:lgpl2.1+)))

(define-public kimageformats-5
  (package
    (inherit kimageformats)
    (name "kimageformats")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "174g32s3m7irzv2h3lk7bmp3yfc7zrmp7lmp02n3m5ppbv6rn4bw"))))
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs
     (list karchive-5 ; for Krita and OpenRaster images
           openexr-2 ; for OpenEXR high dynamic-range images
           qtbase-5
           qtimageformats-5))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'check-setup
            (lambda _
              ;; make Qt render "offscreen", required for tests
              (setenv "QT_QPA_PLATFORM" "offscreen"))))
      #:configure-flags #~(list (string-append "-DCMAKE_CXX_FLAGS=-I"
                                               (assoc-ref %build-inputs
                                                          "ilmbase")
                                               "/include/OpenEXR"))))))

(define-public kjobwidgets
  (package
    (name "kjobwidgets")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1n08y5kv3n2179hgqiq3y7illjs6n6i3w33r492cgykrji5jvvjz"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list libxkbcommon kcoreaddons knotifications kwidgetsaddons qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Widgets for showing progress of asynchronous jobs")
    (description "KJobWIdgets provides widgets for showing progress of
asynchronous jobs.")
    (license license:lgpl2.1+)))

(define-public kjobwidgets-5
  (package
    (inherit kjobwidgets)
    (name "kjobwidgets")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "11xy7n2sz340wili21ia92ihfq76irh8c7db8x1qsgqq09ypzhza"))))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (inputs
     (list kcoreaddons-5 kwidgetsaddons-5 qtbase-5 qtx11extras))))

(define-public knotifications
  (package
    (name "knotifications")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0xvqri0ykx9qb6q2gjpxri71jvghzwy6p332vj8drzlm6wd3rvfc"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules pkg-config qttools))
    (propagated-inputs (list qtdeclarative))
    (inputs
     (list kconfig
           kcoreaddons
           libcanberra
           qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Desktop notifications")
    (description "KNotification is used to notify the user of an event.  It
covers feedback and persistent events.")
    (license license:lgpl2.1+)))

(define-public knotifications-5
  (package
    (inherit knotifications)
    (name "knotifications")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0jxld7f82psa48r0n9qv1cks6w1vd6krjnyb4mw68vgm38030na8"))))
    (native-inputs
     (list extra-cmake-modules dbus pkg-config qttools-5))
    (inputs
     (list kcodecs-5
           kconfig-5
           kcoreaddons-5
           kwindowsystem-5
           libcanberra
           libdbusmenu-qt
           phonon
           qtdeclarative-5
           qtbase-5
           qtspeech-5
           qtx11extras))
    (propagated-inputs '())
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (replace 'check
                          (lambda* (#:key tests? #:allow-other-keys)
                            (when tests?
                              (setenv "HOME"
                                      (getcwd))
                              (setenv "DBUS_FATAL_WARNINGS" "0")
                              (invoke "dbus-launch" "ctest")))))))))

(define-public kpackage
  (package
    (name "kpackage")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0k8ba4s5g7i57nlz3y1qs1gaagxjdv4arzna0ymfmhciw04nh7c1"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (propagated-inputs (list kcoreaddons))
    (inputs
     (list karchive
           kconfig
           kdoctools
           ki18n
           qtbase))
    (arguments
     (list
      ;; The `plasma-querytest' test is known to fail when tests are run in parallel:
      ;; <https://sources.debian.org/src/kpackage/5.115.0-2/debian/changelog/#L109>
      #:parallel-tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch
            (lambda _
              (substitute* "src/kpackage/package.cpp"
                (("bool externalPaths = false;")
                 "bool externalPaths = true;"))
              (substitute* '("src/kpackage/packageloader.cpp")
                (("QDirIterator::Subdirectories")
                 "QDirIterator::Subdirectories | QDirIterator::FollowSymlinks"))))
          (add-before 'check 'check-setup
            (lambda _ (setenv "HOME" (getcwd))))
          (replace 'check
            (lambda* (#:key tests? parallel-tests? #:allow-other-keys)
              (setenv "CTEST_OUTPUT_ON_FAILURE" "1")
              ;; sometime plasmoidpackagetest will fail.
              (invoke "ctest" "--rerun-failed" "--output-on-failure"
                      "-j" (if parallel-tests?
                               (number->string (parallel-job-count))
                               "1")
                      "-E" "plasmoidpackagetest"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Installation and loading of additional content as packages")
    (description "The Package framework lets the user install and load packages
of non binary content such as scripted extensions or graphic assets, as if they
were traditional plugins.")
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kpackage-5
  (package
    (inherit kpackage)
    (name "kpackage")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1gpixfkyaflmzk8lkxnknydm4x6w5339yrgs2n9g229bqy2v21ap"))))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list karchive-5
           kconfig-5
           kcoreaddons-5
           kdoctools-5
           ki18n-5
           qtbase-5))
    (propagated-inputs '())
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch
            (lambda _
              (substitute* "src/kpackage/package.cpp"
                (("externalPaths.false.")
                 "externalPaths(true)"))
              ;; Make QDirIterator follow symlinks
              (substitute* '("src/kpackage/packageloader.cpp")
                (("^\\s*(const QDirIterator::IteratorFlags flags = QDirIterator::Subdirectories)(;)"
                  _ a b)
                 (string-append a " | QDirIterator::FollowSymlinks" b))
                (("^\\s*(QDirIterator it\\(.*, QDirIterator::Subdirectories)(\\);)"
                  _ a b)
                 (string-append a " | QDirIterator::FollowSymlinks" b)))))
          (add-after 'unpack 'patch-tests
            (lambda _
              ;; /bin/ls doesn't exist in the build-container use /etc/passwd
              (substitute* "autotests/packagestructuretest.cpp"
                (("(addDirectoryDefinition\\(\")bin(\".*\")bin(\".*\")bin\""
                  _ a b c)
                 (string-append a "etc" b "etc" c "etc\""))
                (("filePath\\(\"bin\", QStringLiteral\\(\"ls\"))")
                 "filePath(\"etc\", QStringLiteral(\"passwd\"))")
                (("\"/bin/ls\"")
                 "\"/etc/passwd\""))))
          (add-after 'unpack 'disable-problematic-tests
            (lambda _
              ;; The 'plasma-query' test fails non-deterministically, as
              ;; reported e.g. in <https://bugs.gentoo.org/919151>.
              (substitute* "autotests/CMakeLists.txt"
                ((".*querytest.*")
                 ""))))
          (add-before 'check 'check-setup
            (lambda _
              (setenv "HOME" (getcwd)))))))))

(define-public kpty
  (package
    (name "kpty")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "19m01phaca84n736sdh1d002vbfbhf7lzb8cf1wqrhaak0wrp933"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     ;; TODO: utempter, for managing UTMP entries
     (list kcoreaddons ki18n qtbase))
    (arguments
     (list #:tests? #f ; FIXME: 1/1 tests fail.
           #:phases #~(modify-phases %standard-phases
                        (add-after 'unpack 'patch-tests
                          (lambda _
                            (substitute* "autotests/kptyprocesstest.cpp"
                              (("/bin/sh")
                               (which "bash"))))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Interfacing with pseudo terminal devices")
    (description "This library provides primitives to interface with pseudo
terminal devices as well as a KProcess derived class for running child processes
and communicating with them using a pty.")
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kunitconversion
  (package
    (name "kunitconversion")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "16q7jl86bc6y17xd6hyi6b506cpjx21jirlffkmz8ggzs0nz9cvx"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list ki18n qtbase))
    (arguments `(#:tests? #f)) ;; Requires network.
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Converting physical units")
    (description "KUnitConversion provides functions to convert values in
different physical units.  It supports converting different prefixes (e.g. kilo,
mega, giga) as well as converting between different unit systems (e.g. liters,
gallons).")
    (license license:lgpl2.1+)))

(define-public syndication
  (package
    (name "syndication")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1m68g7cm1cqkysb1yxnqnq9fcvjjp1kjl1s0j203jpp3kg05gw6d"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list kcodecs qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "RSS/Atom parser library")
    (description "@code{syndication} supports RSS (0.9/1.0, 0.91..2.0) and
Atom (0.3 and 1.0) feeds.  The library offers a unified, format-agnostic view
on the parsed feed, so that the using application does not need to distinguish
between feed formats.")
    (license license:lgpl2.1+)))


;; Tier 3
;;
;; Tier 3 frameworks are generally more powerful, comprehensive packages, and
;; consequently have more complex dependencies.

(define-public baloo
  (package
    (name "baloo")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0r50alvnzkqmyhk9bfp1k1b6w6v3clb80z4bcag4f0wkipjrdbw7"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kcoreaddons kfilemetadata))
    (native-inputs
     (list dbus extra-cmake-modules))
    (inputs
     (list kbookmarks
           kcompletion
           kconfig
           kcrash
           kdbusaddons
           kidletime
           kio
           kitemviews
           ki18n
           kjobwidgets
           kservice
           kwidgetsaddons
           kxmlgui
           lmdb
           qtbase
           qtdeclarative
           solid))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (setenv "DBUS_FATAL_WARNINGS" "0")
                     (setenv "HOME"
                             (getcwd))
                     (invoke "dbus-launch" "ctest" "-E"
                             ;; this require udisks2.
                             "filewatchtest")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "File searching and indexing")
    (description "Baloo provides file searching and indexing.  It does so by
maintaining an index of the contents of your files.")
    ;; dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public plasma-activities
  (package
    (name "plasma-activities")
    (version "6.1.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/plasma/"
                                  version "/plasma-activities-"
                                  version ".tar.xz"))
              (sha256
               (base32
                "1nx6363l85f0c4f3l189cjfz4rbap2cq292v2136agdppl4gq0iy"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list boost
           kconfig
           kcoreaddons
           kwindowsystem
           qtdeclarative
           solid))
    (arguments (list #:qtbase qtbase))
    (home-page "https://invent.kde.org/plasma/plasma-activities")
    (synopsis "Core components for the KDE Activity System")
    (description "KActivities provides the infrastructure needed to manage a
user's activities, allowing them to switch between tasks, and for applications
to update their state to match the user's current activity.  This includes a
daemon, a library for interacting with that daemon, and plugins for integration
with other frameworks.")
    ;; triple licensed
    (license (list license:gpl2+ license:lgpl2.0+ license:lgpl2.1+))))

(define-public plasma-activities-stats
  (package
    (name "plasma-activities-stats")
    (version "6.1.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/plasma/"
                                  version "/plasma-activities-stats-"
                                  version ".tar.xz"))
              (sha256
               (base32
                "0yca3yb85hvl33ny09xvm67c3wih4nafrbfdgpf7fsrxy1jc75iq"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list boost plasma-activities kconfig qtbase qtdeclarative))
    (home-page "https://invent.kde.org/plasma/plasma-activities-stats")
    (synopsis "Access usage statistics collected by the activity manager")
    (description "The KActivitiesStats library provides a querying mechanism for
the data that the activity manager collects---which documents have been opened
by which applications, and what documents have been linked to which activity.")
    ;; triple licensed
    (license (list license:lgpl2.0+ license:lgpl2.1+ license:lgpl3+))))

(define-public kbookmarks
  (package
    (name "kbookmarks")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "18gydjkjl9iwz5579xqw940d5w8by8ki7qli392w5c46mfm9sy7h"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kwidgetsaddons))
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list kauth
           kcodecs
           kconfig
           kconfigwidgets
           kcoreaddons
           kiconthemes
           kcolorscheme
           kxmlgui
           qtdeclarative
           qtbase))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'check-setup
            (lambda _
              (setenv "HOME" (getcwd))
              ;; make Qt render "offscreen", required for tests
              (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Bookmarks management library")
    (description "KBookmarks lets you access and manipulate bookmarks stored
using the XBEL format.")
    (license license:lgpl2.1+)))

(define-public kbookmarks-5
  (package
    (inherit kbookmarks)
    (name "kbookmarks")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "01cg6qsfjr59ncrxwmiid36cpzynjwxgfydgk23j29bk9gjml2jl"))))
    (propagated-inputs
     (list kwidgetsaddons-5))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (inputs
     (list kauth-5
           kcodecs-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kiconthemes-5
           kxmlgui-5
           qtbase-5))))

(define-public kcmutils
  (package
    (name "kcmutils")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0h4fjav5r2hc8520yh5hwvxw982rad3sf9n1vjffbj93wj6b164r"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kconfigwidgets
           kcoreaddons
           qtdeclarative))
    (native-inputs
     (list extra-cmake-modules
           gettext-minimal
           qttools
           ;; required by kcmloadtest test
           kirigami))
    (inputs
     (list kio
           kcompletion
           kguiaddons
           kiconthemes
           kitemviews
           ki18n
           kcolorscheme
           kwidgetsaddons
           kxmlgui
           qtbase))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'check-setup
            (lambda _
              (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Utilities for KDE System Settings modules")
    (description "KCMUtils provides various classes to work with KCModules.
KCModules can be created with the KConfigWidgets framework.")
    (license license:lgpl2.1+)))

(define-public kcmutils-5
  (package
    (inherit kcmutils)
    (name "kcmutils")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "06aw308wv3fyl1g60n1i2hxx74f0isdsfwwzidsjk79danyqsa4i"))))
    (propagated-inputs
     (list kconfigwidgets-5 kservice-5))
    (native-inputs
     (list extra-cmake-modules))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch
            (lambda _
              (substitute* "src/kpluginselector.cpp"
                ;; make QDirIterator follow symlinks
                (("^\\s*(QDirIterator it\\(.*, QDirIterator::Subdirectories)(\\);)"
                  _ a b)
                 (string-append a
                                " | QDirIterator::FollowSymlinks" b)))
              (substitute* "src/kcmoduleloader.cpp"
                ;; print plugin name when loading fails
                (("^\\s*(qWarning\\(\\) << \"Error loading) (plugin:\")( << loader\\.errorString\\(\\);)"
                  _ a b c)
                 (string-append a
                                " KCM plugin\" << mod.service()->library() << \":\""
                                c)))))
          (add-before 'check 'check-setup
            (lambda _
              (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (inputs
     (list kauth-5
           kcodecs-5
           kconfig-5
           kcoreaddons-5
           kdeclarative-5
           kguiaddons-5
           kiconthemes-5
           kitemviews-5
           ki18n-5
           kpackage-5
           kwidgetsaddons-5
           kxmlgui-5
           qtbase-5
           qtdeclarative-5))))

(define-public kconfigwidgets
  (package
    (name "kconfigwidgets")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "14104r6j38kjqmvx3d66xm4amdbdxl1450257l6zlf9wp1lndj5s"))))
    (build-system qt-build-system)
    (propagated-inputs
     (list kcodecs kconfig kcolorscheme kwidgetsaddons))
    (native-inputs
     (list extra-cmake-modules kdoctools qttools))
    (inputs
     (list kcoreaddons
           kguiaddons
           ki18n
           ;; todo: PythonModuleGeneration
           qtdeclarative
           libxkbcommon))
    (arguments
     (list
      #:qtbase qtbase
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch
            (lambda _
              (substitute* "src/khelpclient.cpp"
                ;; make QDirIterator follow symlinks
                (("^\\s*(QDirIterator it\\(.*, QDirIterator::Subdirectories)(\\);)" _ a b)
                 (string-append a " | QDirIterator::FollowSymlinks" b)))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HOME"
                        (getcwd))
                (invoke "ctest" "-E" "(kstandardactiontest|\
klanguagenametest)")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Widgets for configuration dialogs")
    (description "KConfigWidgets provides easy-to-use classes to create
configuration dialogs, as well as a set of widgets which uses KConfig to store
their settings.")
    ;; dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kconfigwidgets-5
  (package
    (inherit kconfigwidgets)
    (name "kconfigwidgets")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1f65ayyyadiajf7xgf7369rly2yzigh6gqlb0nkgg8cp2bq9fmp4"))))
    (propagated-inputs
     (list kauth-5 kcodecs-5 kconfig-5 kwidgetsaddons-5))
    (native-inputs
     (list extra-cmake-modules kdoctools-5 qttools-5))
    (inputs
     (list kcoreaddons-5
           kguiaddons-5
           ;; todo: PythonModuleGeneration
           ki18n-5))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch
            (lambda _
              (substitute* "src/khelpclient.cpp"
                ;; make QDirIterator follow symlinks
                (("^\\s*(QDirIterator it\\(.*, QDirIterator::Subdirectories)(\\);)" _ a b)
                 (string-append a " | QDirIterator::FollowSymlinks" b)))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HOME"
                        (getcwd))
                (invoke "ctest" "-E" "kstandardactiontest")))))))))

(define-public kdeclarative
  (package
    (name "kdeclarative")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1kkdlkavd3v60sihxvlqxw2fmv1szf04llffhm0db7kmhz286zc0"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kconfig qtdeclarative))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list kglobalaccel
           kguiaddons
           ki18n
           kwidgetsaddons
           qtshadertools
           qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Integration of QML and KDE work spaces")
    (description "KDeclarative provides integration of QML and KDE work spaces.
It's comprises two parts: a library used by the C++ part of your application to
intergrate QML with KDE Frameworks specific features, and a series of QML imports
that offer bindings to some of the Frameworks.")
    ;; dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kdeclarative-5
  (package
    (inherit kdeclarative)
    (name "kdeclarative")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0py5x9ia8p7ngk1q3nqwqi1b9zv6jdxc23qam8xyqbfjqcm9qzwy"))))
    (propagated-inputs
     (list kconfig-5 kpackage-5 qtdeclarative-5))
    (native-inputs
     (list dbus extra-cmake-modules pkg-config xorg-server-for-tests))
    (inputs
     (list kauth-5
           kcoreaddons-5
           kglobalaccel-5
           kguiaddons-5
           kiconthemes-5
           kio-5
           ki18n-5
           kjobwidgets-5
           knotifications-5
           kservice-5
           kwidgetsaddons-5
           kwindowsystem-5
           libepoxy
           qtbase-5
           qtdeclarative-5
           solid-5))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-before 'check 'start-xorg-server
                 (lambda* (#:key inputs #:allow-other-keys)
                   ;; The test suite requires a running X server, setting
                   ;; QT_QPA_PLATFORM=offscreen does not suffice.
                   (system "Xvfb :1 -screen 0 640x480x24 &")
                   (setenv "DISPLAY" ":1")))
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (setenv "HOME"
                             (getcwd))
                     (setenv "XDG_RUNTIME_DIR"
                             (getcwd))
                     (setenv "QT_QPA_PLATFORM" "offscreen")
                     (setenv "DBUS_FATAL_WARNINGS" "0")
                     (invoke "dbus-launch" "ctest")))))))))

(define-public kded
  (package
    (name "kded")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0j2y4gk7vaqwia8kpk2glfch84rpwrcbjfksvw9bmdhip9ffbcyl"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules kdoctools))
    (inputs
     (list kconfig
           kcoreaddons
           kcrash
           kdbusaddons
           kdoctools
           kservice
           qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Central daemon of KDE work spaces")
    (description "KDED stands for KDE Daemon.  KDED runs in the background and
performs a number of small tasks.  Some of these tasks are built in, others are
started on demand.")
    ;; dual licensed
    (license (list license:lgpl2.0+ license:lgpl2.1+))))

(define-public kded-5
  (package
    (inherit kded)
    (name "kded")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0gd0dy748zw12xksk7xmv1xkra2g9s3av4d0i1d7dbb6z1ap5djw"))))
    (native-inputs
     (list extra-cmake-modules kdoctools-5))
    (inputs
     (list kconfig-5
           kcoreaddons-5
           kcrash-5
           kdbusaddons-5
           kdoctools-5
           kservice-5
           qtbase-5))))

(define-public kdesignerplugin
  (package
    (name "kdesignerplugin")
    (version "5.114.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/portingAids/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0zlvkayv6zl5rp1076bscmdzyw93y7sxqb5848w11vs0g9amcj9n"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules kdoctools qttools-5))
    (inputs
     (list kconfig
           kcoreaddons
           kdoctools
           qtbase-5))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Integrating KDE frameworks widgets with Qt Designer")
    (description "This framework provides plugins for Qt Designer that allow it
to display the widgets provided by various KDE frameworks, as well as a utility
(kgendesignerplugin) that can be used to generate other such plugins from
ini-style description files.")
    (license license:lgpl2.1+)))

(define-public kdesu
  (package
    (name "kdesu")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1pp7m4k42wv1m9wy83ysnv1j0nji7py668320xwpfirkh6hhb6d3"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kpty))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list kconfig kcoreaddons ki18n kservice qtbase))
    ;; FIXME: kdesutest test fail.
    (arguments (list #:tests? #f))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "User interface for running shell commands with root privileges")
    (description "KDESU provides functionality for building GUI front ends for
(password asking) console mode programs.  kdesu and kdessh use it to interface
with su and ssh respectively.")
    (license license:lgpl2.1+)))

(define-public kemoticons
  (package
    (name "kemoticons")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0lv8cb7h7v4fbf8vyrsf9kygnhjxznf5sj92nv5is5gy0wdk8qxc"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kservice-5))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list karchive-5 kconfig-5 kcoreaddons-5 qtbase-5))
    (arguments
     (list #:phases #~(modify-phases %standard-phases
                        (add-before 'check 'check-setup
                          (lambda _
                            (setenv "HOME"
                                    (getcwd))
                            ;; make Qt render "offscreen", required for tests
                            (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Convert text emoticons to graphical emoticons")
    (description "KEmoticons converts emoticons from text to a graphical
representation with images in HTML.  It supports setting different themes for
emoticons coming from different providers.")
    ;; dual licensed, image files are licensed under cc-by-sa4.0
    (license (list license:gpl2+ license:lgpl2.1+ license:cc-by-sa4.0))))

(define-public kglobalaccel
  (package
    (name "kglobalaccel")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1wcx0b3vi5xm5hhyylkdrcq8i46m49lw1j53m2i2f4nv7750d0n0"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules pkg-config qttools))
    (inputs
     (list kconfig
           kcrash
           kcoreaddons
           kdbusaddons
           kwindowsystem
           qtdeclarative))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Global desktop keyboard shortcuts")
    (description "KGlobalAccel allows you to have global accelerators that are
independent of the focused window.  Unlike regular shortcuts, the application's
window does not need focus for them to be activated.")
    (license license:lgpl2.1+)))

(define-public kglobalaccel-5
  (package
    (inherit kglobalaccel)
    (name "kglobalaccel")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0rlqclaq4szzqa2kz7c9ad81rm0b2byr806l5v0xz968h8jampzn"))))
    (native-inputs
     (list extra-cmake-modules pkg-config qttools-5))
    (inputs
     (list kconfig-5
           kcrash-5
           kcoreaddons-5
           kdbusaddons-5
           kwindowsystem-5
           qtx11extras
           qtdeclarative-5
           xcb-util-keysyms))
    (arguments '())))

(define-public kiconthemes
  (package
    (name "kiconthemes")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "00y3gjrplxk29l0f11yf7d9cszzf7ggady87pwj7j87qr6pr8lwl"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules qttools shared-mime-info))
    (inputs
     (list libxkbcommon
           karchive
           kauth
           kcodecs
           kcolorscheme
           kcoreaddons
           kconfig
           kconfigwidgets
           ki18n
           kitemviews
           kwidgetsaddons
           qtbase
           qtdeclarative
           qtsvg
           breeze-icons))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-before 'check 'check-setup
                 (lambda* (#:key inputs #:allow-other-keys)
                   (setenv "HOME" (getcwd))
                   ;; make Qt render "offscreen", required for tests
                   (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Icon GUI utilities")
    (description "This library contains classes to improve the handling of icons
in applications using the KDE Frameworks.")
    (license license:lgpl2.1+)))

(define-public kiconthemes-5
  (package
    (inherit kiconthemes)
    (name "kiconthemes")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0q859zbjys7lajwpgl78ji4dif7cxdxirqb8b6f7k7bk53ignvly"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules qttools-5 shared-mime-info))
    (inputs
     (list karchive-5
           kauth-5
           kcodecs-5
           kcoreaddons-5
           kconfig-5
           kconfigwidgets-5
           ki18n-5
           kitemviews-5
           kwidgetsaddons-5
           qtbase-5
           qtdeclarative-5
           qtsvg-5))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-before 'check 'check-setup
                 (lambda* (#:key inputs #:allow-other-keys)
                   (setenv "XDG_DATA_DIRS"
                           (string-append #$(this-package-native-input
                                             "shared-mime-info")
                                          "/share"))
                   (setenv "HOME" (getcwd))
                   ;; make Qt render "offscreen", required for tests
                   (setenv "QT_QPA_PLATFORM" "offscreen"))))))))

(define-public kinit
  (package
    (name "kinit")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0b5w7pk7wbyzix2jvn3yk89f9r620wrx55v3cgvj4p83c73ar974"))
              ;; Use the store paths for other packages and dynamically loaded
              ;; libs
              (patches (search-patches "kinit-kdeinit-extra_libs.patch"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-paths
            (lambda* (#:key inputs outputs #:allow-other-keys)
              ;; Set patched-in values:
              (substitute* "src/kdeinit/kinit.cpp"
                (("GUIX_PKGS_KF5_KIO") #$(this-package-input "kio"))
                (("GUIX_PKGS_KF5_PARTS") #$(this-package-input "kparts"))
                (("GUIX_PKGS_KF5_PLASMA")
                 #$(this-package-input "plasma-framework"))))))))
    (native-search-paths
     (list (search-path-specification
            (variable "KDEINIT5_LIBRARY_PATH")
            (files '("lib/")))))
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs
     (list kauth-5
           kbookmarks-5
           kcodecs-5
           kcompletion-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kcrash-5
           kdbusaddons-5
           kdoctools-5
           kio-5
           kitemviews-5
           ki18n-5
           kjobwidgets-5
           kparts-5
           kservice-5
           kwidgetsaddons-5
           kwindowsystem-5
           kxmlgui-5
           libcap ; to install start_kdeinit with CAP_SYS_RESOURCE
           plasma-framework
           qtbase-5
           solid-5))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Library to speed up start of applications on KDE workspaces")
    (description "Kdeinit is a process launcher similar to init used for booting
UNIX.  It launches processes by forking and then loading a dynamic library which
contains a @code{kdemain(@dots{})} function.  Using kdeinit to launch KDE
applications makes starting KDE applications faster and reduces memory
consumption.")
    ;; dual licensed
    (license (list license:lgpl2.0+ license:lgpl2.1+))))

(define kinit-bootstrap
  ((package-input-rewriting `((,kdbusaddons-5 . ,kdbusaddons-5-bootstrap))) kinit))

(define-public kio
  (package
    (name "kio")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0j04kbbmjlbv2qhra5src6zxx1m8imix9hb0kih0b5h64jrszq9r"))
              (patches (search-patches "kio-search-smbd-on-PATH.patch"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list acl
           kbookmarks
           kconfig
           kcompletion
           kcoreaddons
           kitemviews
           kjobwidgets
           kservice
           kwindowsystem
           solid))
    (native-inputs
     (list extra-cmake-modules dbus kdoctools qttools))
    (inputs (list karchive
                  kauth
                  kcodecs
                  kconfigwidgets
                  kcrash
                  kdbusaddons
                  kded
                  kguiaddons
                  kiconthemes
                  ki18n
                  kwallet
                  kwidgetsaddons
                  libxml2
                  libxslt
                  qt5compat
                  qtbase
                  qtdeclarative
                  libxkbcommon
                  sonnet
                  `(,util-linux "lib")  ; libmount
                  zlib))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch
            (lambda _
              ;; Better error message (taken from NixOS)
              (substitute* "src/kiod/kiod_main.cpp"
                (("(^\\s*qCWarning(KIOD_CATEGORY) << \
\"Error loading plugin:\")( << loader.errorString();)" _ a b)
                 (string-append a "<< name" b)))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HOME" (getcwd))
                (setenv "XDG_RUNTIME_DIR" (getcwd))
                (setenv "QT_QPA_PLATFORM" "offscreen")
                (setenv "DBUS_FATAL_WARNINGS" "0")
                (invoke "dbus-launch" "ctest"
                        "--rerun-failed" "--output-on-failure"
                        "-E"

                        (string-append
                         "(kiogui-favicontest"
                         "|kiocore-filefiltertest"
                         "|kpasswdservertest"
                         "|kiowidgets-kfileitemactionstest"
                         "|kiofilewidgets-kfileplacesmodeltest"
                         ;; The following tests fail or are flaky (see:
                         ;; https://bugs.kde.org/show_bug.cgi?id=440721).
                         "|kiocore-jobtest"
                         "|kiocore-kmountpointtest"
                         "|kiowidgets-kdirlistertest"
                         "|kiocore-kfileitemtest"
                         "|kiocore-ktcpsockettest"
                         "|kiocore-mimetypefinderjobtest"
                         "|kiocore-krecentdocumenttest"
                         "|kiocore-http_jobtest"
                         "|kiogui-openurljobtest"
                         "|kioslave-httpheaderdispositiontest"
                         "|applicationlauncherjob_forkingtest"
                         "|applicationlauncherjob_scopetest"
                         "|applicationlauncherjob_servicetest"
                         "|commandlauncherjob_forkingtest"
                         "|commandlauncherjob_scopetest"
                         "|commandlauncherjob_servicetest"
                         "|kiowidgets-kdirmodeltest"
                         "|kiowidgets-kurifiltertest-colon-separator"
                         "|kiofilewidgets-kfilewidgettest"
                         "|kiowidgets-kurifiltertest-space-separator"
                         "|kioworker-httpheaderdispositiontest)"))))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Network transparent access to files and data")
    (description "This framework implements a lot of file management functions.
It supports accessing files locally as well as via HTTP and FTP out of the box
and can be extended by plugins to support other protocols as well.  There is a
variety of plugins available, e.g. to support access via SSH.  The framework can
also be used to bridge a native protocol to a file-based interface.  This makes
the data accessible in all applications using the KDE file dialog or any other
KIO enabled infrastructure.")
    (license license:lgpl2.1+)))

(define-public kio-5
  (package
    (inherit kio)
    (name "kio")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0nhins85cqlr3xz4xi0g54rshagphin3pjjx2qxs0fcwcpb1kdzg"))
              (patches (search-patches "kio-search-smbd-on-PATH.patch"))))
    (propagated-inputs
     (list acl
           kbookmarks-5
           kconfig-5
           kcompletion-5
           kcoreaddons-5
           kitemviews-5
           kjobwidgets-5
           kservice-5
           kwindowsystem-5
           kxmlgui-5
           solid-5))
    (native-inputs
     (list extra-cmake-modules dbus kdoctools-5 qttools-5))
    (inputs (list mit-krb5
                  karchive-5
                  kauth-5
                  kcodecs-5
                  kconfigwidgets-5
                  kcrash-5
                  kdbusaddons-5
                  kded-5
                  kguiaddons-5
                  kiconthemes-5
                  ki18n-5
                  knotifications-5
                  ktextwidgets-5
                  kwallet-5
                  kwidgetsaddons-5
                  libxml2
                  libxslt
                  qtbase-5
                  qtdeclarative-5
                  qtscript
                  qtx11extras
                  sonnet-5
                  `(,util-linux "lib")  ; libmount
                  zlib))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch
            (lambda _
              ;; Better error message (taken from NixOS)
              (substitute* "src/kiod/kiod_main.cpp"
                (("(^\\s*qCWarning(KIOD_CATEGORY) << \
\"Error loading plugin:\")( << loader.errorString();)" _ a b)
                 (string-append a "<< name" b)))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HOME" (getcwd))
                (setenv "XDG_RUNTIME_DIR" (getcwd))
                (setenv "QT_QPA_PLATFORM" "offscreen")
                (setenv "DBUS_FATAL_WARNINGS" "0")
                (invoke "dbus-launch" "ctest"
                        "--rerun-failed" "--output-on-failure"
                        "-E"
                        ;; The following tests fail or are flaky (see:
                        ;; https://bugs.kde.org/show_bug.cgi?id=440721).
                        (string-append "(kiocore-jobtest"
                                       "|kiocore-kmountpointtest"
                                       "|kiowidgets-kdirlistertest"
                                       "|kiocore-kfileitemtest"
                                       "|kiocore-ktcpsockettest"
                                       "|kiocore-mimetypefinderjobtest"
                                       "|kiocore-krecentdocumenttest"
                                       "|kiocore-http_jobtest"
                                       "|kiogui-openurljobtest"
                                       "|kioslave-httpheaderdispositiontest"
                                       "|applicationlauncherjob_forkingtest"
                                       "|applicationlauncherjob_scopetest"
                                       "|applicationlauncherjob_servicetest"
                                       "|commandlauncherjob_forkingtest"
                                       "|commandlauncherjob_scopetest"
                                       "|commandlauncherjob_servicetest"
                                       "|kiowidgets-kdirmodeltest"
                                       "|kiowidgets-kurifiltertest-colon-separator"
                                       "|kiofilewidgets-kfilewidgettest"
                                       "|kiowidgets-kurifiltertest-space-separator"
                                       "|kioworker-httpheaderdispositiontest)")))))
          (add-after 'install 'add-symlinks
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((kst5 (string-append #$output "/share/kservicetypes5/")))
                (symlink (string-append kst5 "kfileitemactionplugin.desktop")
                         (string-append kst5 "kfileitemaction-plugin.desktop"))))))))))

(define-public knewstuff
  (package
    (name "knewstuff")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1mv7v4r902q2mgr377mg5c2y6aapg32p385ildcm3jwl5sr1cvd1"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list attica
           kcoreaddons))
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list karchive
           kconfig
           kirigami
           ki18n
           kpackage
           kwidgetsaddons
           qtbase
           qtdeclarative
           syndication))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-before 'check 'check-setup
                 (lambda _ ; XDG_DATA_DIRS isn't set
                   (setenv "HOME" (getcwd))
                   ;; make Qt render "offscreen", required for tests
                   (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Framework for downloading and sharing additional application data")
    (description "The KNewStuff library implements collaborative data sharing
for applications.  It uses libattica to support the Open Collaboration Services
specification.")
    (license license:lgpl2.1+)))

(define-public knewstuff-5
  (package
    (inherit knewstuff)
    (name "knewstuff")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "02n7429ldkyyzbk9rbr9h4ss80zhc3vnir29q2yksyhcyqkkjc42"))))
    (propagated-inputs
     (list attica-5 kservice-5 kxmlgui-5))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (inputs
     (list karchive-5
           kauth-5
           kbookmarks-5
           kcodecs-5
           kcompletion-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kio-5
           kitemviews-5
           ki18n-5
           kiconthemes-5
           kjobwidgets-5
           kpackage-5
           ktextwidgets-5
           kwidgetsaddons-5
           qtbase-5
           qtdeclarative-5
           solid-5
           sonnet-5))))

(define-public knotifyconfig
  (package
    (name "knotifyconfig")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0paj00lsqlk40xwkhm0z7hims22mknp8m1cs5sqssgp5a5g6zwpb"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list kauth
           kbookmarks
           kcodecs
           kcompletion
           kconfig
           kconfigwidgets
           kcoreaddons
           kio
           kitemviews
           ki18n
           kjobwidgets
           knotifications
           kservice
           kwidgetsaddons
           kxmlgui
           phonon
           qtbase
           solid))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Configuration dialog for desktop notifications")
    (description "KNotifyConfig provides a configuration dialog for desktop
notifications which can be embedded in your application.")
    ;; dual licensed
    (license (list license:lgpl2.0+ license:lgpl2.1+))))

(define-public knotifyconfig-5
  (package
    (inherit knotifyconfig)
    (name "knotifyconfig")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0zwrcdl565nlzf6q2zljq6xn8929frrhqr8jlmb6kcv5i93yals0"))))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list kauth-5
           kbookmarks-5
           kcodecs-5
           kcompletion-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kio-5
           kitemviews-5
           ki18n-5
           kjobwidgets-5
           knotifications-5
           kservice-5
           kwidgetsaddons-5
           kxmlgui-5
           phonon
           qtbase-5
           solid-5))))

(define-public kparts
  (package
    (name "kparts")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0004ln6fby8jgx6j27qlhmlagxy7c70akn0kayfqi6glfdk2gz22"))))
    (build-system qt-build-system)
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'disable-partloader-test
                 (lambda _
                   (substitute* "autotests/CMakeLists.txt"
                     ;; XXX: PartLoaderTest wants to create a .desktop file
                     ;; in the common locations and test that MIME types work.
                     ;; The setup required for this is extensive, skip for now.
                     (("partloadertest\\.cpp") "")))))))
    (propagated-inputs
     (list kio kservice kxmlgui))
    (native-inputs
     (list extra-cmake-modules shared-mime-info))
    (inputs
     (list
      kcompletion
      kconfig
      kcoreaddons
      kitemviews
      ki18n
      kjobwidgets
      kwidgetsaddons
      qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Plugin framework for user interface components")
    (description "This library implements the framework for KDE parts, which are
widgets with a user-interface defined in terms of actions.")
    (license license:lgpl2.1+)))

(define-public kparts-5
  (package
    (inherit kparts)
    (name "kparts")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0czrlqh5cxnj1mlbz839c7hifhnpzl476d92lv4hxji50wnjlfqr"))))
    (propagated-inputs
     (list kio-5 ktextwidgets-5 kxmlgui-5))
    (native-inputs
     (list extra-cmake-modules shared-mime-info))
    (inputs
     (list kauth-5
           kbookmarks-5
           kcodecs-5
           kcompletion-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kiconthemes-5
           kitemviews-5
           ki18n-5
           kjobwidgets-5
           kservice-5
           kwidgetsaddons-5
           qtbase-5
           solid-5
           sonnet-5))))

(define-public kpeople
  (package
    (name "kpeople")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0gihf93jjy3qc02h9qjnxjp67jb38rahx5f1k1hm9pxcasg9fzwn"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list kconfig
           kcoreaddons
           kitemviews
           ki18n
           kservice
           kcontacts
           kwidgetsaddons
           qtdeclarative))
    (arguments
     (list #:qtbase qtbase
           #:tests? #f))                    ; FIXME: 1/3 tests fail.
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Provides access to all contacts and aggregates them by person")
    (description "KPeople offers unified access to our contacts from different
sources, grouping them by person while still exposing all the data.  KPeople
also provides facilities to integrate the data provided in user interfaces by
providing QML and Qt Widgets components.  The sources are plugin-based, allowing
to easily extend the contacts collection.")
    (license license:lgpl2.1+)))

(define-public krunner
  (package
    (name "krunner")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "09g464v1v7c14m39ic3qpny10l4dnazr7fax76irs3dwr54zx9kc"))))
    (build-system qt-build-system)
    (propagated-inputs
     (list kcoreaddons))
    (native-inputs
     (list extra-cmake-modules
           ;; For tests.
           dbus))
    (inputs
     (list kconfig
           kitemmodels
           ki18n
           qtdeclarative))
    (arguments
     (list
      #:qtbase qtbase
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HOME" (getcwd))
                (invoke "dbus-launch" "ctest")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Framework for Plasma runners")
    (description "The Plasma workspace provides an application called KRunner
which, among other things, allows one to type into a text area which causes
various actions and information that match the text appear as the text is being
typed.")
    (license license:lgpl2.1+)))

(define-public krunner-5
  (package
    (inherit krunner)
    (name "krunner")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0h889a4bj7vqhvy9hkqxd9v437zly73phyav10gv5b2l8fgb4zxq"))))
    (propagated-inputs
     (list plasma-framework))
    (native-inputs
     (list extra-cmake-modules
           ;; For tests.
           dbus))
    (inputs
     (list kactivities
           kauth-5
           kbookmarks-5
           kcodecs-5
           kcompletion-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kio-5
           kitemviews-5
           ki18n-5
           kjobwidgets-5
           kpackage-5
           kservice-5
           kwidgetsaddons-5
           kwindowsystem-5
           kxmlgui-5
           qtdeclarative-5
           solid-5
           threadweaver-5))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-paths-for-test
            ;; This test tries to access paths like /home, /usr/bin and /bin/ls
            ;; which don't exist in the build-container. Change to existing paths.
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* "autotests/runnercontexttest.cpp"
                (("/home\"") "/tmp\"") ;; single path-part
                (("//usr/bin\"") (string-append (getcwd) "\"")) ;; multiple path-parts
                (("/bin/ls")
                 (search-input-file inputs "/bin/ls")))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "HOME" (getcwd))
                (setenv "QT_QPA_PLATFORM" "offscreen")
                (invoke "dbus-launch" "ctest")))))))))

(define-public kservice
  (package
    (name "kservice")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0m7ym2hzsw1aylrinqmq88912mi89j0wyffb1lxjkwp0q5i4smm0"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kconfig kcoreaddons kdoctools))
    (native-inputs
     (list bison extra-cmake-modules flex shared-mime-info))
    (inputs
     (list kcrash kdbusaddons kdoctools ki18n qtbase qtdeclarative))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch
            ;; Adopted from NixOS' patches "qdiriterator-follow-symlinks" and
            ;; "no-canonicalize-path".
            (lambda _
              (substitute* "src/sycoca/kbuildsycoca.cpp"
                ;; make QDirIterator follow symlinks
                (("^\\s*(QDirIterator it\\(.*, QDirIterator::Subdirectories)(\\);)" _ a b)
                 (string-append a " | QDirIterator::FollowSymlinks" b)))
              (substitute* "src/sycoca/vfolder_menu.cpp"
                ;; Normalize path, but don't resolve symlinks (taken from
                ;; NixOS)
                (("^\\s*QString resolved = QDir\\(dir\\)\\.canonicalPath\\(\\);")
                 "QString resolved = QDir::cleanPath(dir);"))))
          (add-before 'check 'check-setup
            (lambda _
              (with-output-to-file "autotests/BLACKLIST"
                (lambda _
                  (for-each
                   (lambda (name) (display (string-append "[" name "]\n*\n")))
                   (list "extraFileInFutureShouldRebuildSycocaOnce"
                         "testNonReadableSycoca"))))
              (setenv "XDG_RUNTIME_DIR" (getcwd))
              (setenv "HOME" (getcwd))
              ;; Make Qt render "offscreen", required for tests
              (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Plugin framework for desktop services")
    (description "KService provides a plugin framework for handling desktop
services.  Services can be applications or libraries.  They can be bound to MIME
types or handled by application specific code.")
    ;; triple licensed
    (license (list license:gpl2+ license:gpl3+ license:lgpl2.1+))))

(define-public kservice-5
  (package
    (inherit kservice)
    (name "kservice")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0sd8yj9a1ja97c515g9shjqyzdz0jd7rn3r06g5659nh2z1w5dsj"))))
    (propagated-inputs
     (list kconfig-5 kcoreaddons-5 kdoctools-5))
    (native-inputs
     (list bison extra-cmake-modules flex shared-mime-info))
    (inputs
     (list kcrash-5 kdbusaddons-5 kdoctools-5 ki18n-5 qtbase-5))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'patch
                 ;; Adopted from NixOS' patches "qdiriterator-follow-symlinks" and
                 ;; "no-canonicalize-path".
                 (lambda _
                   (substitute* "src/sycoca/kbuildsycoca.cpp"
                     ;; make QDirIterator follow symlinks
                     (("^\\s*(QDirIterator it\\(.*, QDirIterator::Subdirectories)(\\);)" _ a b)
                      (string-append a " | QDirIterator::FollowSymlinks" b)))
                   (substitute* "src/sycoca/vfolder_menu.cpp"
                     ;; Normalize path, but don't resolve symlinks (taken from
                     ;; NixOS)
                     (("^\\s*QString resolved = QDir\\(dir\\)\\.canonicalPath\\(\\);")
                      "QString resolved = QDir::cleanPath(dir);"))))
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (setenv "HOME" (getcwd))
                     (setenv "QT_QPA_PLATFORM" "offscreen")
                     ;; Disable failing tests.
                     (invoke "ctest" "-E" "(kautostarttest|ksycocatest|kapplicationtradertest)")))))))))

(define-public kstatusnotifieritem
  (package
    (name "kstatusnotifieritem")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1n4c761xgr9xbcwkw5q3l3v38wmanyvpf284y141ms6vs0rjw7yf"))))
    (build-system qt-build-system)
    (arguments (list #:qtbase qtbase))
    (native-inputs (list extra-cmake-modules qttools))
    (inputs (list kwindowsystem libxkbcommon))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Implementation of Status Notifier Items")
    (description "This package provides a Implementation of Status Notifier
Items.")
    (license (list license:cc0 license:lgpl2.0+))))

(define-public ktexteditor
  (package
    (name "ktexteditor")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    "ktexteditor-" version ".tar.xz"))
              (sha256
               (base32
                "0xip50g976s9h6196nlgpzc1wvmyl051iyjyfjri610axgxbz7cp"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kparts
           ksyntaxhighlighting))
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs
     (list editorconfig-core-c
           karchive
           kauth
           kcompletion
           kconfigwidgets
           kcolorscheme
           kguiaddons
           kitemviews
           ki18n
           ktextwidgets
           kwidgetsaddons
           kxmlgui
           qtbase
           qtdeclarative
           qtspeech
           sonnet))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests? ;; Maybe locale issues with tests?
                     (setenv "QT_QPA_PLATFORM" "offscreen")
                     (invoke "ctest" "-E" "(kateview_test|movingrange_test)")))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Full text editor component")
    (description "KTextEditor provides a powerful text editor component that you
can embed in your application, either as a KPart or using the KF5::TextEditor
library.")
    ;; triple licensed
    (license (list license:gpl2+ license:lgpl2.0+ license:lgpl2.1+))))

(define-public ktexteditor-5
  (package
    (inherit ktexteditor)
    (name "ktexteditor")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    "ktexteditor-" version ".tar.xz"))
              (sha256
               (base32
                "0rph5nwp7d02xicjxrqpbz3kjb9kqqa40pp1w81fnq8jgln3hhh5"))))
    (propagated-inputs
     (list kparts-5
           ksyntaxhighlighting-5))
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs
     (list editorconfig-core-c
           karchive-5
           kauth-5
           kbookmarks-5
           kcodecs-5
           kcompletion-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kguiaddons-5
           kiconthemes-5
           kio-5
           kitemviews-5
           ki18n-5
           kjobwidgets-5
           kparts-5
           kservice-5
           ktextwidgets-5
           kwidgetsaddons-5
           kxmlgui-5
           libgit2
           perl
           qtbase-5
           qtdeclarative-5
           qtscript
           qtxmlpatterns
           solid-5
           sonnet-5))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'setup
                 (lambda* (#:key inputs #:allow-other-keys)
                   (setenv "XDG_DATA_DIRS" ; FIXME build phase doesn't find parts.desktop
                           (string-append #$(this-package-input "kparts") "/share"))))
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests? ;; Maybe locale issues with tests?
                     (setenv "QT_QPA_PLATFORM" "offscreen")
                     (invoke "ctest" "-E" "(kateview_test|movingrange_test)"))))
               (add-after 'install 'add-symlinks
                 ;; Some package(s) (e.g. plasma-sdk) refer to these service types
                 ;; by the wrong name.  I would prefer to patch those packages, but
                 ;; I cannot find the files!
                 (lambda* (#:key outputs #:allow-other-keys)
                   (let ((kst5 (string-append #$output
                                              "/share/kservicetypes5/")))
                     (symlink (string-append kst5 "ktexteditorplugin.desktop")
                              (string-append kst5 "ktexteditor-plugin.desktop"))))))))))

(define-public ktextwidgets
  (package
    (name "ktextwidgets")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0piqskblzi79wmza9z9qh0hc9vsihp5jdxsv7kspymdswspbb7wy"))))
    (build-system qt-build-system)
    (propagated-inputs
     (list ki18n sonnet))
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list kauth
           kcodecs
           kcompletion
           kconfig
           kconfigwidgets
           kcoreaddons
           kiconthemes
           kservice
           kwidgetsaddons
           kwindowsystem
           qtspeech))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Text editing widgets")
    (description "KTextWidgets provides widgets for displaying and editing text.
It supports rich text as well as plain text.")
    ;; dual licensed
    (license (list license:lgpl2.0+ license:lgpl2.1+))))

(define-public ktextwidgets-5
  (package
    (inherit ktextwidgets)
    (name "ktextwidgets")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0lkm27g1dc6vmyjz7jaiqh2z1cfgvzlnk58wcs2bkny05i87x01l"))))
    (propagated-inputs
     (list ki18n-5 sonnet-5))
    (native-inputs
     (list extra-cmake-modules qttools-5))
    (inputs
     (list kauth-5
           kcodecs-5
           kcompletion-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kiconthemes-5
           kservice-5
           kwidgetsaddons-5
           kwindowsystem-5
           qtbase-5
           qtspeech-5))))

(define-public ktexttemplate
  (package
    (name "ktexttemplate")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/ktexttemplate-"
                    version ".tar.xz"))
              (sha256
               (base32
                "17df96rmmyni2adv97p77y349vyvirs0svzs6dzzmclzb2f8hlck"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (inputs (list qtdeclarative))
    (arguments (list #:qtbase qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE's Text Template")
    (description "KTextTemplate is to make it easier for application developers
to separate the structure of documents from the data they contain.")
    (license (list license:lgpl2.1+))))

(define-public kwallet
  (package
    (name "kwallet")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1p9a5lwn4lpalxs6nj8fbcmmngcbgaj6s9n9vz56j26rlfzypdpd"))))
    (build-system cmake-build-system)
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests? ;; Seems to require network.
                     (invoke "ctest" "-E"
                             "(fdo_secrets_test)")))))))
    (native-inputs
     (list extra-cmake-modules kdoctools))
    (inputs
     (list gpgme
           kauth
           kcodecs
           kconfig
           kconfigwidgets
           kcoreaddons
           kdbusaddons
           kdoctools
           kiconthemes
           ki18n
           knotifications
           kservice
           kwidgetsaddons
           kwindowsystem
           libgcrypt
           phonon
           qgpgme
           qca-qt6
           qtbase))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Safe desktop-wide storage for passwords")
    (description "This framework contains an interface to KWallet, a safe
desktop-wide storage for passwords and the kwalletd daemon used to safely store
the passwords on KDE work spaces.")
    (license license:lgpl2.1+)))

(define-public kwallet-5
  (package
    (inherit kwallet)
    (name "kwallet")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "12s4rnybadpcjmw3dvdn68vm369h1yk7yp7mv736mj1brdg8pkhy"))))
    (native-inputs
     (list extra-cmake-modules kdoctools-5))
    (inputs
     (list gpgme
           kauth-5
           kcodecs-5
           kconfig-5
           kconfigwidgets-5
           kcoreaddons-5
           kdbusaddons-5
           kdoctools-5
           kiconthemes-5
           ki18n-5
           knotifications-5
           kservice-5
           kwidgetsaddons-5
           kwindowsystem-5
           libgcrypt
           phonon
           qgpgme
           qca
           qtbase-5))))

(define-public kxmlgui
  (package
    (name "kxmlgui")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0plrww25q417vldf59ybiwkg3clygm7wrjy4a28wry1jxfrgswr2"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kconfig kconfigwidgets))
    (native-inputs
     (list extra-cmake-modules qttools))
    (inputs
     (list attica
           kauth
           kcodecs
           kcolorscheme
           kcoreaddons
           kglobalaccel
           kguiaddons
           kiconthemes
           kitemviews
           ki18n
           ktextwidgets
           kwidgetsaddons
           kwindowsystem
           qtbase
           qtdeclarative
           sonnet))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-before 'check 'check-setup
                 (lambda* (#:key tests? #:allow-other-keys)
                   (with-output-to-file "autotests/BLACKLIST"
                     (lambda _
                       (for-each
                        (lambda (name)
                          (display (string-append "[" name "]\n*\n")))
                        (list "testSpecificApplicationLanguageQLocale"
                              "testToolButtonStyleNoXmlGui"
                              "testToolButtonStyleXmlGui"))))
                   (setenv "HOME" (getcwd))
                   (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Framework for managing menu and toolbar actions")
    (description "KXMLGUI provides a framework for managing menu and toolbar
actions in an abstract way.  The actions are configured through a XML description
and hooks in the application code.  The framework supports merging of multiple
descriptions for integrating actions from plugins.")
    ;; dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public kxmlgui-5
  (package
    (inherit kxmlgui)
    (name "kxmlgui")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0h3s3jcmn4pzcfxs4hywrgk92dd5hfx9hzyy14f03c0dafi6crb3"))))
    (propagated-inputs
     (list kconfig-5 kconfigwidgets-5))
    (native-inputs
     (list extra-cmake-modules qttools-5 xorg-server-for-tests))
    (inputs
     (list attica-5
           kauth-5
           kcodecs-5
           kcoreaddons-5
           kglobalaccel-5
           kguiaddons-5
           kiconthemes-5
           kitemviews-5
           ki18n-5
           ktextwidgets-5
           kwidgetsaddons-5
           kwindowsystem-5
           qtbase-5
           sonnet-5))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (setenv "HOME" (getcwd))
                     (setenv "QT_QPA_PLATFORM" "offscreen") ;; These tests fail
                     (invoke "ctest" "-E" "(ktoolbar_unittest|kxmlgui_unittest)")))))))))

(define-public libplasma
  (package
    (name "libplasma")
    (version "6.1.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kde/stable/plasma/"
                                  version "/" name "-"
                                  version ".tar.xz"))
              (sha256
               (base32
                "0ji1cd8nc744lqg6m8qnbn923x57ljy5fcaxbq0fzh7qwij42qc0"))))
    (build-system qt-build-system)
    (propagated-inputs
     (list kpackage kwindowsystem))
    (native-inputs
     (list extra-cmake-modules kdoctools pkg-config
           gettext-minimal
           ;; for wayland-scanner
           wayland))
    (inputs (list
             karchive
             kconfigwidgets
             kglobalaccel
             kguiaddons
             kiconthemes
             kirigami
             kio
             ki18n
             kcmutils
             ksvg
             kglobalaccel
             knotifications
             plasma-wayland-protocols
             plasma-activities
             qtdeclarative
             qtsvg
             qtwayland
             wayland
             libxkbcommon))
    (arguments
     (list #:qtbase qtbase
           #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (setenv "HOME" (getcwd))
                     (invoke "ctest" "-E"
                             (string-append "(plasma-dialogstatetest"
                                            "|plasma-iconitemtest"
                                            "|plasma-dialogqmltest"
                                            "|plasma-themetest"
                                            "|iconitemhidpitest"
                                            "|bug485688test"
                                            "|dialognativetest)"))))))))
    (home-page "https://invent.kde.org/plasma/libplasma")
    (synopsis "Libraries, components and tools of Plasma workspaces")
    (description "The plasma framework provides QML components, libplasma and
script engines.")
    ;; dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public plasma-framework
  (package
    (name "plasma-framework")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "0kwza2n9vbzf9p9dq7j448ynlfgg65918fvxw1n209zmlm6jr4vy"))))
    (build-system cmake-build-system)
    (propagated-inputs
     (list kpackage-5 kservice-5))
    (native-inputs
     (list extra-cmake-modules kdoctools-5 pkg-config))
    (inputs (list kactivities
                  karchive-5
                  kauth-5
                  kbookmarks-5
                  kcodecs-5
                  kcompletion-5
                  kconfig-5
                  kconfigwidgets-5
                  kcoreaddons-5
                  kdbusaddons-5
                  kdeclarative-5
                  kglobalaccel-5
                  kguiaddons-5
                  kiconthemes-5
                  kirigami-5
                  kitemviews-5
                  kio-5
                  ki18n-5
                  kjobwidgets-5
                  knotifications-5
                  kwayland-5
                  kwidgetsaddons-5
                  kwindowsystem-5
                  kxmlgui-5
                  ;; XXX: "undefined reference to `glGetString'" errors occur without libglvnd,
                  libglvnd
                  phonon
                  qtbase-5
                  qtdeclarative-5
                  qtquickcontrols2-5
                  qtsvg-5
                  qtx11extras
                  solid-5))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     (setenv "HOME"
                             (getcwd))
                     (setenv "QT_QPA_PLATFORM" "offscreen") ;; These tests fail
                     (invoke "ctest" "-E"
                             (string-append "(plasma-dialogstatetest"
                                            "|plasma-iconitemtest"
                                            "|plasma-themetest"
                                            "|iconitemhidpitest"
                                            "|dialognativetest)"))))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Libraries, components and tools of Plasma workspaces")
    (description "The plasma framework provides QML components, libplasma and
script engines.")
    ;; dual licensed
    (license (list license:gpl2+ license:lgpl2.1+))))

(define-public purpose
  (package
    (name "purpose")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "05zcwrg65z7vm1jvgfajama2mrz70gn08kdsxd5fzkxx8rk6yadz"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules gettext-minimal))
    (inputs
     (list
      ;;TODO: kaccounts
      kconfig
      kcoreaddons
      knotifications
      ki18n
      kio
      kirigami
      kwidgetsaddons
      kitemviews
      kcompletion
      kservice
      qtbase
      qtdeclarative
      prison))
    (arguments
     (list #:tests? #f ;; seem to require network; don't find QTQuick components
           #:configure-flags #~'("-DBUILD_TESTING=OFF"))) ; not run anyway
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Offers available actions for a specific purpose")
    (description "This framework offers the possibility to create integrate
services and actions on any application without having to implement them
specifically.  Purpose will offer them mechanisms to list the different
alternatives to execute given the requested action type and will facilitate
components so that all the plugins can receive all the information they
need.")
    (license license:lgpl2.1+)))

(define-public purpose-5
  (package
    (inherit purpose)
    (name "purpose")
    (version "5.116.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    name "-" version ".tar.xz"))
              (sha256
               (base32
                "1g0xip1khclinx3vb835krdsj66jllgbx1fka8d9f55n68d6rmk2"))))
    (native-inputs
     (list extra-cmake-modules))
    (inputs
     (list
      kconfig-5
      kcoreaddons-5
      knotifications-5
      ki18n-5
      kio-5
      kirigami-5
      qtbase-5
      qtdeclarative-5))
    (arguments
     (list #:tests? #f ;; seem to require network; don't find QTQuick components
           ;; not run anyway
           #:configure-flags #~'("-DBUILD_TESTING=OFF")))))

(define-public ktextaddons
  (package
    (name "ktextaddons")
    (version "1.5.4")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "mirror://kde/stable/" name "/" name "-" version ".tar.xz"))
       (sha256
        (base32
         "083v4x5f46h609g8zar6x22mp1ps85ikzbr08qbfj9abx010df34"))))
    (build-system qt-build-system)
    (arguments
     (list #:qtbase qtbase
           #:configure-flags #~(list "-DQT_MAJOR_VERSION=6")
           #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda _
                   (setenv "HOME" (getcwd))
                   ;; XXX: 6 tests failed due to:
                   ;;   missing icons
                   ;;   translators plugins not available during tests
                   (invoke "ctest" "-E"
                           "(grammalecteresultwidgettest|grammalecteconfigwidgettest||grammalecteresultjobtest|languagetoolconfigwidgettest|translator-translatorwidgettest|translator-translatorengineloadertest)"))))))
    (native-inputs
     (list extra-cmake-modules
           qttools))
    (inputs
     (list karchive
           kconfigwidgets
           kcoreaddons
           ki18n
           kio
           ksyntaxhighlighting
           kxmlgui
           qtkeychain-qt6
           sonnet))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "Various text handling addons")
    (description "This library provides text addons (autocorrection, text to
speak, grammar checking, text translator, emoticon support) for Qt
applications.")
    (license
     (list license:lgpl2.0+ license:bsd-3 license:gpl2+ license:cc0))))


;; Tier 4
;;
;; Tier 4 frameworks can be mostly ignored by application programmers; this
;; tier consists of plugins acting behind the scenes to provide additional
;; functionality or platform integration to existing frameworks (including
;; Qt).

(define-public kde-frameworkintegration
  (package
    (name "kde-frameworkintegration")
    (version "6.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://kde/stable/frameworks/"
                    (version-major+minor version) "/"
                    "frameworkintegration-" version ".tar.xz"))
              (sha256
               (base32
                "0zscmn1hvv0y7j5r22r6cdmqznkv7h0s6v7a4wmpjgrpnd8haw4l"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules pkg-config))
    (inputs (list packagekit-qt6
                  appstream-qt6
                  kconfig
                  kconfigwidgets
                  kcoreaddons
                  ki18n
                  kiconthemes
                  kitemviews
                  knewstuff
                  knotifications
                  kpackage
                  kwidgetsaddons
                  qtbase))
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (add-before 'check 'check-setup
                 (lambda _
                   (setenv "HOME" (getcwd))
                   ;; Make Qt render "offscreen", required for tests
                   (setenv "QT_QPA_PLATFORM" "offscreen"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE Frameworks 6 workspace and cross-framework integration plugins")
    (description "Framework Integration is a set of plugins responsible for
better integration of Qt applications when running on a KDE Plasma
workspace.")
    ;; This package is distributed under either LGPL2 or LGPL3, but some
    ;; files are explicitly LGPL2+.
    (license (list license:lgpl2.0 license:lgpl3 license:lgpl2.0+))
    (properties `((upstream-name . "frameworkintegration")))))


;; Porting Aids
;;
;; Porting Aids frameworks provide code and utilities to ease the transition
;; from kdelibs 4 to KDE Frameworks 5. Code should aim to port away from this
;; framework, new projects should avoid using these libraries.

(define-public kdelibs4support
  (package
    (name "kdelibs4support")
    (version "5.114.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "mirror://kde/stable/frameworks/"
             (version-major+minor version) "/portingAids/"
             name "-" version ".tar.xz"))
       (sha256
        (base32 "17473him2fjfcw5f88diarqac815wsakfyb9fka82a4qqh9l41mc"))
       (modules '((guix build utils)))
       (snippet
        '(substitute* "autotests/kmimetypetest.cpp"
           ;; Adjust the test for shared-mime-info changes:
           ;; https://gitlab.freedesktop.org/xdg/shared-mime-info/-/issues/202
           ;; https://gitlab.freedesktop.org/xdg/shared-mime-info/-/merge_requests/255
           (("empty document") "Empty document")
           (("Bzip archive") "Bzip2 archive")
           (("<< \"application/x-bzip") "<< \"application/x-bzip2")))))
    (build-system cmake-build-system)
    (native-inputs
     (list dbus
           docbook-xml-4.4 ; optional
           extra-cmake-modules
           kdoctools
           perl
           perl-uri
           pkg-config
           qttools
           shared-mime-info
           kjobwidgets ;; required for running the tests
           strace
           tzdata-for-tests))
    (propagated-inputs
     ;; These are required to be installed along with this package, see
     ;; lib64/cmake/KF5KDELibs4Support/KF5KDELibs4SupportConfig.cmake
     (list karchive
           kauth
           kconfigwidgets
           kcoreaddons
           kcrash
           kdbusaddons
           kdesignerplugin
           kdoctools
           kemoticons
           kguiaddons
           kiconthemes
           kinit
           kitemmodels
           knotifications
           kparts
           ktextwidgets
           kunitconversion
           kwindowsystem
           qtbase-5))
    (inputs
     (list kcompletion
           kconfig
           kded
           kglobalaccel
           ki18n
           kio
           kservice
           kwidgetsaddons
           kxmlgui
           libsm
           networkmanager-qt
           openssl
           qtsvg-5
           qttools-5
           qtx11extras))
    ;; FIXME: Use Guix ca-bundle.crt in etc/xdg/ksslcalist and
    ;; share/kf5/kssl/ca-bundle.crt
    ;; TODO: NixOS has nix-kde-include-dir.patch to change std-dir "include"
    ;; into "@dev@/include/". Think about whether this is needed for us, too.
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'make-cmake-to-find-docbook
           (lambda _
             (substitute* "cmake/FindDocBookXML4.cmake"
               (("^.*xml/docbook/schema/dtd.*$")
                "xml/dtd/docbook\n"))))
         (delete 'check)
         (add-after 'install 'check-post-install
           (lambda* (#:key inputs tests? #:allow-other-keys)
             (setenv "HOME" (getcwd))
             (setenv "TZDIR"    ; KDateTimeTestsome needs TZDIR
                     (search-input-directory inputs
                                             "share/zoneinfo"))
             ;; Make Qt render "offscreen", required for tests
             (setenv "QT_QPA_PLATFORM" "offscreen")
             ;; enable debug output
             (setenv "CTEST_OUTPUT_ON_FAILURE" "1") ; enable debug output
             (setenv "DBUS_FATAL_WARNINGS" "0")
             ;; Make kstandarddirstest pass (see https://bugs.kde.org/381098)
             (mkdir-p ".kde-unit-test/xdg/config")
             (with-output-to-file ".kde-unit-test/xdg/config/foorc"
               (lambda () #t))  ;; simply touch the file
             ;; Blacklist a test-function (failing at build.kde.org, too).
             (with-output-to-file "autotests/BLACKLIST"
               (lambda _
                 (display "[testSmb]\n*\n")))
             (invoke "dbus-launch" "ctest"
                     "-E" "kstandarddirstest"))))))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE Frameworks 5 porting aid from KDELibs4")
    (description "This framework provides code and utilities to ease the
transition from kdelibs 4 to KDE Frameworks 5.  This includes CMake macros and
C++ classes whose functionality has been replaced by code in CMake, Qt and
other frameworks.

Code should aim to port away from this framework eventually.  The API
documentation of the classes in this framework and the notes at
http://community.kde.org/Frameworks/Porting_Notes should help with this.")
    ;; Most files are distributed under LGPL2+, but the package includes code
    ;; under a variety of licenses.
    (license (list license:lgpl2.1+ license:lgpl2.0 license:lgpl2.0+
                   license:gpl2 license:gpl2+
                   license:expat license:bsd-2 license:bsd-3
                   license:public-domain))))

(define-public khtml
  (package
    (name "khtml")
    (version "5.116.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "mirror://kde/stable/frameworks/"
             (version-major+minor version) "/portingAids/"
             name "-" version ".tar.xz"))
       (sha256
        (base32 "13nc5dcj536xyd87prla30mpbzsyjnylb34a979qn7qvpr0zn8c9"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules perl))
    (inputs
     (list giflib
           gperf
           karchive-5
           kcodecs-5
           kglobalaccel-5
           ki18n-5
           kiconthemes-5
           kio-5
           kjs
           knotifications-5
           kparts-5
           ktextwidgets-5
           kwallet-5
           kwidgetsaddons-5
           kwindowsystem-5
           kxmlgui-5
           libjpeg-turbo
           libpng
           openssl
           phonon
           qtbase-5
           qtx11extras
           sonnet-5))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE Frameworks 5 HTML widget and component")
    (description "KHTML is a web rendering engine, based on the KParts
technology and using KJS for JavaScript support.")
    ;; Most files are distributed under LGPL2+, but the package includes code
    ;; under a variety of licenses.
    (license (list license:lgpl2.0+ license:lgpl2.1+
                   license:gpl2  license:gpl3+
                   license:expat license:bsd-2 license:bsd-3))))

(define-public kjs
  (package
    (name "kjs")
    (version "5.116.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "mirror://kde/stable/frameworks/"
             (version-major+minor version) "/portingAids/"
             name "-" version ".tar.xz"))
       (sha256
        (base32 "1dz1v5gizjywp452q98r4ka6iafa3b3c24ck8jv1xcym64zg7d4z"))))
    (build-system cmake-build-system)
    (native-inputs
     (list extra-cmake-modules kdoctools perl pkg-config))
    (inputs
     (list pcre qtbase-5))
    (home-page "https://community.kde.org/Frameworks")
    (synopsis "KDE Frameworks 5 support for Javascript scripting in Qt
applications")
    (description "Add-on library to Qt which adds JavaScript scripting
support.")
    ;; Most files are distributed under LGPL2+, but the package also includes
    ;; code under a variety of licenses.
    (license (list license:lgpl2.1+
                   license:bsd-2 license:bsd-3
                   (license:non-copyleft "file://src/kjs/dtoa.cpp")))))

(define-public kdav
  (package
    (name "kdav")
    (version "6.3.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://kde/stable/frameworks/"
                           (version-major+minor version) "/"
                           name "-" version ".tar.xz"))
       (sha256
        (base32 "1f99nw6jsrka5hpp4ad13mgwprmzivv2h46vg2arjlr5x0csk4mh"))))
    (build-system qt-build-system)
    (native-inputs
     (list extra-cmake-modules))
    (propagated-inputs (list kcoreaddons))
    (inputs
     (list ki18n kio))
    (arguments
     (list
      #:qtbase qtbase
      #:phases #~(modify-phases %standard-phases
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         ;; Seems to require network.
                         (invoke "ctest" "-E"
                                 "(kdav-davcollectionsmultifetchjobtest|\
kdav-davitemfetchjob)")))))))
    (home-page "https://invent.kde.org/frameworks/kdav")
    (synopsis "DAV protocol implementation with KJobs")
    (description "This is a DAV protocol implementation with KJobs.  Calendars
and todos are supported, using either GroupDAV or CalDAV, and contacts are
supported using GroupDAV or CardDAV.")
    (license ;; GPL for programs, LGPL for libraries
     (list license:gpl2+ license:lgpl2.0+))))
