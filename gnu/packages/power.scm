;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2023 Karl Hallsby <karl@hallsby.com>
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

(define-module (gnu packages power)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages gd)
  #:use-module ((guix licenses) #:prefix license:))

(define-public apcupsd
  (package
    (name "apcupsd")
    (version "3.14.14")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://sourceforge/apcupsd/apcupsd - Stable/"
                           version "/"
                           name "-" version ".tar.gz"))
       (sha256
        (base32 "0rwqiyzlg9p0szf3x6q1ppvrw6f6dbpn2rc5z623fk3bkdalhxyv"))
       (patches
        (search-patches
         ;; Need to change doshutdown and doreboot event commands
         "apcupsd-apccontrol-shutdown.patch" ; shepherd shutdown has no args
         ;; Give apccontrol a REBOOT, shepherd shutdown does not have -r option
         "apcupsd-apccontrol-reboot.patch"))
       (modules '((guix build utils)))
       (snippet
        #~(list
           ;; Fix Makefile and target.mak to NOT strip stuff when installing
           ;; Taken from nixpkgs' definition of apcupsd
           (substitute* "src/apcagent/Makefile"
             (("$(INSTALL_PROGRAM) $(STRIP)")
              "$(INSTALL_PROGRAM)"))
           (substitute* "autoconf/targets.mak"
             (("$(INSTALL_PROGRAM) $(STRIP)")
              "$(INSTALL_PROGRAM)"))
           ;; Make WALL called by scripts actually be filled in by configure
           (substitute* "platforms/apccontrol.in"
             (("WALL=wall")
              "WALL=@WALL@"))))))
    (native-inputs
     (list pkg-config libusb
           util-linux))
    (inputs
     (list shepherd gd))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list
         ;; ./configure ignores --prefix, so we must specify some paths manually
         ;; Some of these mirror nixpkgs' definition of apcupsd
         (string-append "--exec-prefix=" #$output)
         (string-append "--sbindir=" #$output "/sbin")
         (string-append "--sysconfdir=" #$output "/etc")
         (string-append "--with-halpolicydir=" #$output "/share/halpolicy")
         "--localstatedir=/var"
         "--with-log-dir=/var/log"
         "--with-pid-dir=/var/run"
         "--with-lock-dir=/var/lock"
         ;; nologin prevents new users from logging in during UPS event
         "--with-nologin=/run"
         ;; pwrfail-dir is where power failure files get put during UPS event
         "--with-pwrfail-dir=/run/apcupsd"
         (string-append "ac_cv_path_SHUTDOWN=" #$shepherd "/sbin/shutdown")
         (string-append "ac_cv_path_REBOOT=" #$shepherd "/sbin/reboot")
         (string-append "ac_cv_path_WALL=" #$util-linux "/bin/wall")
         "--enable-test" ;; Enable test driver code.
         "--enable-usb"  ;; Add USB support
         "--enable-net"
         "--enable-snmp"
         "--enable-cgi"
         (string-append "--with-cgi-bin=" #$output "/libexec/cgi-bin"))
      #:phases
      #~(modify-phases %standard-phases
          ;; configure hardcodes /bin/cat in an existence test. Fix that.
          ;; Taken from nixpkgs' definition of apcupsd
          (add-before 'configure 'fix-configure-cat
            (lambda _
              (substitute* "configure"
                (("/bin/cat") #$(file-append coreutils "/bin/cat")))))
          ;; There are no tests.
          (delete 'check))))
    ;; NOTE: "Unknown distribution installation" is EXPECTED in the build
    ;; logs! On other OSs, the apcupsd boot and halt scripts for booting
    ;; and halting the system using information from the UPS must be added
    ;; manually.
    ;; On Guix, a service-type must provide those scripts.
    (home-page "http://www.apcupsd.org")
    (synopsis "A daemon for controlling APC UPSes")
    (description "Apcupsd can be used for power mangement and controlling most
of APC’s UPS models on Unix and Windows machines.  Apcupsd works with most of
APC’s Smart-UPS models as well as most simple signalling models such a
Back-UPS, and BackUPS-Office.")
    (license license:gpl2)))
