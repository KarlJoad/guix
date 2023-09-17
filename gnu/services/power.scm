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

(define-module (gnu services power)
  #:use-module (gnu packages power)
  #:use-module (gnu packages base)
  #:use-module (gnu packages mail)
  #:use-module (gnu services)
  #:use-module (gnu services configuration)
  #:use-module (gnu services shepherd)
  #:use-module (guix packages)
  #:use-module (guix build-system copy)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (guix modules)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:export (apcupsd-configuration
            apcupsd-service-type))

(define %apcupsd-events
  ;; List of events from "man apccontrol"
  '(annoyme ; Reminder pings to users to sign off
    ;; Battery events
    battattach battdetach changeme
    ;; Communication with UPS
    commfailure commok
    ;; UPS/apcupsd signalling things to happen
    doreboot doshutdown emergency failing
    ;; Shut off UPS. NOTE: killpower must happen & send to UPS before a doshutdown event.
    ;; Needs grace time.
    killpower
    ;; UPS reached max load
    loadlimit
    ;; "Normal" UPS operation, in left-to-right order
    powerout onbattery offbattery mainsback
    ;; Self tests
    startselftest endselftest
    ;; Rest
    remotedown runlimit timeout))

(define apcupsd-serialize-package serialize-package)
(define package? file-like?)
(define apcupsd-package? file-like?)

(define (apcupsd-serialize-integer field-name value)
  #~(format #f "~a ~a~%" (string-upcase #$field-name) #$value))

(define (apcupsd-serialize-boolean field-name value)
  #~(format #f "~a ~a~%" #$(string-upcase field-name)
            #$(if value "on" "off")))

(define (apcupsd-serialize-string field-name value)
  #~(format #f "~a ~a~%" (string-upcase #$field-name) #$value))

(define (alist-symbol-gexp? values)
  (every (match-lambda
           ((event . handler)
            (and (symbol? event)
                 (or (gexp? handler)
                     (eq? #f handler)))))
         values))
(define (sanitize-alist-symbol-gexp values)
  ;; Filter out events that do not match what is in %apcupsd-events
  ;; FIXME: Print out which events are thrown away?
  (filter (match-lambda
            ((event . _)
             (memq event %apcupsd-events)))
          values))
(define (apcupsd-serialize-alist-symbol-gexp field-name vals)
  ;; Serializing this alist means we build the SCRIPTDIR filled with scripts
  ;; provided by the user which are executed before apcupsd's default handlers.
  ;; Once the file-union of scripts is built, we copy these and apccontrol to
  ;; another directory and write that final path to the config file.
  (define (build-scriptdir event-handler-alist)
    (file-union "apcupsd-extra-scripts"
                 (map (match-lambda
                       ((event . handler)
                        (let ((script-name (symbol->string event)))
                          ;; FIXME: For now assume handler is a gexp
                          (list (string-append "scripts/" script-name)
                                (program-file (string-append script-name ".scm")
                                              #~(begin
                                                  ;; Provide way to call back
                                                  (setenv "APCCONTROL" "@APCCONTROL@")
                                                  ;; TODO: Make call back a procedure?
                                                  #$handler)
                                              )))))
                      event-handler-alist)))

  (define apccontrol-with-extra-scripts
    (package
      (inherit apcupsd) ; Only for package metadata (homepage, etc.)
      (name "apccontrol")
      (source apcupsd)
      (native-inputs `(("apcupsd-scripts" ,(build-scriptdir vals))))
      (build-system copy-build-system)
      (arguments
       (list
        #:phases
        #~(modify-phases %standard-phases
            (add-after 'install 'substitute-extra-script-dir
              (lambda* (#:key inputs outputs #:allow-other-keys)
                (substitute* (string-append (assoc-ref outputs "out") "/apccontrol")
                  (("SCRIPTDIR=.*")
                   (string-append "SCRIPTDIR=" (assoc-ref outputs "out") "\n")))))
            (add-after 'install 'substitute-apccontrol-script-callback
              (lambda* (#:key inputs outputs #:allow-other-keys)
                (substitute* (find-files (assoc-ref outputs "out")
                                         (lambda (file stat) (executable-file? file)))
                  (("@APCCONTROL@")
                   (string-append (assoc-ref outputs "out") "/apccontrol"))))))
        #:install-plan
        ``(("etc/apccontrol" "/")
           (,(string-append (assoc-ref %build-inputs "apcupsd-scripts")
                            "/scripts/") "/"))))))

  ;; NOTE: SCRIPTDIR in apcupsd.conf must point to directory with apccontrol script.
  ;; The apccontrol script _also_ has SCRIPTDIR, which must point to the extra
  ;; scripts to run!
  #~(string-append
     "# SCRIPTDIR points to directory with apccontrol script.\n"
     (format #f "SCRIPTDIR ~a~%" #$apccontrol-with-extra-scripts)
     "# The apccontrol script has another SCRIPTDIR pointing to the extra scripts.\n"))

(define-configuration apcupsd-configuration
  (package
    (package apcupsd)
    "The apcupsd package to use.")
  (ups-type
   (string "usb")
   "The type of connection made to the UPS."
   (serializer
    (lambda (_ value) (apcupsd-serialize-string "UPSTYPE" value))))
  (net-server?
   (boolean #t)
   "Should the Network Information Server (NIS) be started?"
   (serializer
    (lambda (_ value) (apcupsd-serialize-boolean "NETSERVER" value))))
  (ip-address
   (string "127.0.0.1") ;; FIXME: maybe-string
   "IP address of the NIS server."
   (serializer
    (lambda (_ value) (apcupsd-serialize-string "NISIP" value))))
  (battery-threshold
   (integer 50)
   "The amount of battery left in the UPS when the UPS powers off the computer."
   (serializer
    (lambda (_ value) (apcupsd-serialize-integer "BATTERYLEVEL" value))))
  (minutes-threshold
   (integer 5)
   "The amount of time left in the UPS when the UPS powers off the computer."
   (serializer
    (lambda (_ value) (apcupsd-serialize-integer "MINUTES" value))))
  ;; We do not serialize event-handlers the normal way, despite it having a
  ;; serializer. Please see the apcupsd-serialize-alist-symbol-gexp
  ;; procedure above.
  (event-handlers
   (alist-symbol-gexp (map (lambda (event) `(,event . #f)) %apcupsd-events))
   "Scripts/gexp objects to add to the script directory, which will be
executed as a handler for the specified event @emph{before} executing the
default event handler.
If you want to stop apcupsd's default handler for that event from executing after your
script, your script must exit with value @t{99}."
   (sanitizer apcupsd-sanitize-alist-symbol-gexp))
  (prefix apcupsd-))

(define (apcupsd-config-file config)
  "Return a list of configuration files for apcupsd based on the contents
of CONFIG."
  (mixed-text-file
   "apcupsd.conf"
   #~(begin
       (string-append
        "## apcupsd.conf v1.1 ##\n"
        ;; Taken from apcupsd nixos module
        "# apcupsd complains if the first line is not like above.\n"
        "# Generated by 'apcupsd-service'.\n"
        #$(serialize-configuration config apcupsd-configuration-fields)))))

(define (apcupsd-shepherd-service config)
  "Return a list of <shepherd-service>s for apcupsd with CONFIG."

  (define package
    (apcupsd-configuration-package config))

  (define pid-file "/var/run/apcupsd.pid")

  (define config-file
    (apcupsd-config-file config))

  (define apcupsd-command
    #~(list (string-append #$package "/sbin/apcupsd")
            "-b" ;; Do not fork off to background
            "-P" #$pid-file
            "-f" #$(apcupsd-config-file config)
            "-d1"))

  (list (shepherd-service
         (documentation "apcupsd UPS monitoring daemon.")
         (requirement '(networking syslogd))
         (provision '(apcupsd))
         ;; Use make-inetd-constructor??
         (start #~(make-forkexec-constructor
                   #$apcupsd-command
                   #:pid-file #$pid-file
                   #:environment-variables
                   (list (string-append
                          "PATH="
                          #$(file-append package "/sbin") ":"
                          #$(file-append mailutils "/bin") ":"
                          #$(file-append coreutils "/bin")))))
         (stop #~(make-kill-destructor)))))

(define (apcupsd-wrapper config)
  "Wrap all the binaries in apcupsd to automatically pass the location of the
config file for the service.

If the daemon is running and the user does not provide a host:port combination,
then the sbin/ binaries grab their information from localhost:3551. This can be
overridden on the command line or through the config file, which is why we
wrap."
  (define (exp bin)
    ;; NOTE: sbin is the only one with ELF binaries. etc has SH scripts
    ;; which get called by the apcupsd binary when an event occurs.
    (list bin
          (program-file
           bin
           #~(begin
               (let ((real-bin #$(file-append (apcupsd-configuration-package config)
                                              "/sbin/" bin)))
                 (apply execl real-bin real-bin
                        "-f" #$(apcupsd-config-file config)
                        (cdr (command-line))))))))

  (file-union "wrapped-apc-binaries"
              (map exp '("apctest" "apcaccess"))))

(define (apcupsd-profile-service config)
  ;; XXX: profile-service-type only accepts <package> objects
  (list
   (package
     (name "apcupsd-wrapper")
     (version (package-version apcupsd))
     (source (apcupsd-wrapper config))
     (build-system copy-build-system)
     (arguments
      (list
       #:install-plan
       ''(("./" "sbin/"))))
     (home-page (package-home-page apcupsd))
     (synopsis (package-synopsis apcupsd))
     (description (package-description apcupsd))
     (license (package-license apcupsd)))))

(define (extend-apcupsd-configuration config extras)
  "Extend CONFIG with the extra EXTRAS."
  (apcupsd-configuration
   (inherit config)))

(define apcupsd-service-type
  (service-type (name 'apcupsd)
                (description
                 "Monitor APC UPSes using the apcupsd daemon, @command{apcupsd}.")
                (extensions
                 (list (service-extension shepherd-root-service-type
                                          apcupsd-shepherd-service)
                       ;; Install wrapped apcaccess & apctest in system profile
                       (service-extension profile-service-type
                                          apcupsd-profile-service)))
                (compose concatenate)
                (extend extend-apcupsd-configuration)
                (default-value (apcupsd-configuration))))


;;;
;;; Generate documentation.
;;;
(define (generate-apcupsd-documentation)
  (generate-documentation `((apcupsd-configuration ,apcupsd-configuration-fields))
                          'apcupsd-configuration))
