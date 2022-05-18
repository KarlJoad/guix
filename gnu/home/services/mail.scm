;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2022 Karl Hallsby <karl@hallsby.com>
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

(define-module (gnu home services mail)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (ice-9 format)
  #:use-module (guix records)
  #:use-module (guix packages)
  #:use-module (gnu services configuration)
  #:use-module (gnu home services)
  #:use-module (gnu home services utils)
  #:use-module (rnrs enums)
  #:use-module (gnu packages mail) ; isync, msmtp, mu
  #:use-module (guix gexp)
  #:use-module (guix profiles)

  #:export (home-msmtp-service-type
            home-msmtp-configuration
            msmtp-account-configuration
            password-command

            home-isync-service-type
            home-mbsync-configuration
            mbsync-configuration
            mbsync-account-configuration

            home-mu-service-type))

;;; Commentary:
;;;
;;; This module contains the necessary translation between the Scheme syntax
;;; used in Guix to the configuration format used by each of the programs.
;;;
;;; Code:


;;;
;;;
;;;

;; Shadow the undefined serialize-string function for define-configuration to
;; use for fields marked as of type string.
(define (serialize-string field-name val) val)
(define (serialize-number field-name val) (number->string val))
(define (serialize-boolean field-name val)
  (if val
      "on"
      "off"))

(define-configuration password-command
  (command
   (file-like)
   "Command to run on the provided file to get a password to use.")
  (file
   (string "")
   "Path to a file containing a password to use.  This file will
@emph{NOT} be added to the store, because the store is world-readable!"))

(define (serialize-password-command field-name val)
  #~(string-append
     #$(password-command-command val)
     " "
     #$(password-command-file val)))

(define-configuration msmtp-account-configuration
  (account-name
   (string "")
   "String for the short-hand name to refer to this account.")
  (email
   (string "")
   "Email address the @emph{server} uses to send from.")
  (host
   (string "")
   "Fully-qualified name for the SMTP server you are sending through.")
  (user
   (string "")
   "User account to sign into SMTP server with.")
  (pass-cmd
   (password-command)
   "Command & password file to interact with.")
  (port-num
   (number 587)
   "Port number for the SMTP server you are sending through.")
  (protocol
   (string "smtp")
   "Name of protocol mail is being sent to server over.")
  (enable-tls?
   (boolean #t)
   "Should mail be sent to SMTP server over a TLS connection?")
  (enable-starttls?
   (boolean #t)
   "Enable StartTLS, allowing SMTP connections to be secured.")
  ;; The trust file /etc/ssl/certs/ca-certificates.crt is generated
  ;; by ca-certificate-bundle in guix/profiles.scm
  (tls-trust-file
   (string "/etc/ssl/certs/ca-certificates.crt")
   "File path to the @file{ca-certificates.crt} file."))

(define (serialize-msmtp-account-configuration field-name config)
  (define (filter-fields field)
    (filter-configuration-fields msmtp-account-configuration-fields
                                 (list field)))

  (define (serialize-field field)
    (serialize-configuration
     config
     (filter-fields field)))

  #~(format #f
            "account ~a
auth on
from ~a
host ~a
user ~a
passwordeval ~a
port ~a
protocol ~a
tls ~a
tls_starttls ~a
tls_trust_file ~a\n\n"
            #$(serialize-field 'account-name)
            #$(serialize-field 'email)
            #$(serialize-field 'host)
            #$(serialize-field 'user)
            #$(serialize-field 'pass-cmd)
            #$(serialize-field 'port-num)
            #$(serialize-field 'protocol)
            #$(serialize-field 'enable-tls?)
            #$(serialize-field 'enable-starttls?)
            #$(serialize-field 'tls-trust-file)))

(define (msmtp-account-configuration-list? config-list)
  (and (list? config-list) (and-map msmtp-account-configuration? config-list)))
(define (serialize-msmtp-account-configuration-list field-name config-list)
  #~(string-append
     #$@(map (lambda (config)
               (serialize-msmtp-account-configuration field-name config))
             config-list)))

(define-configuration home-msmtp-configuration
  (package
    (package msmtp)
    "The MSMTP package to use.")
  (accounts
   (msmtp-account-configuration-list
    (list (msmtp-account-configuration)))
   "List of accounts to configure for MSMTP.")
  (default-account
    (string "")
    "The @code{account-name} that should be considered the default."))

;; Filter out the requested field from the configuration struct
(define (msmtp-file-filter-fields field)
  (filter-configuration-fields home-msmtp-configuration-fields (list field)))

;; Serialize a single field of the msmtp configuration file
(define (msmtp-file-serialize-field config field)
  ;; In here, config is the concrete, provided, instance of the configuration
  (serialize-configuration config (msmtp-file-filter-fields field)))

;; Serialize the entire msmtp configuration file
(define (msmtp-file-serialize config)
  ;; In here, config is the concrete, provided, instance of the configuration
  (serialize-configuration config (msmtp-file-filter-fields '(account))))

(define (add-msmtp-configuration config)
  `(("msmtp/config"
     ,(mixed-text-file
       "config"
       "# Generated by Guix Home. Do not edit!"
       "# Global Settings
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt\n\n
# Per-email account settings\n\n"
       (serialize-msmtp-account-configuration-list
        'accounts
        (home-msmtp-configuration-accounts config))
       "account default : "
       (serialize-string 'default-account
                         (home-msmtp-configuration-default-account config))))))

(define (add-msmtp-packages config)
  (list (home-msmtp-configuration-package config)))

(define home-msmtp-service-type
  (service-type (name 'home-msmtp)
                (extensions
                 (list (service-extension
                        home-xdg-configuration-files-service-type
                        add-msmtp-configuration)
                       (service-extension
                        home-profile-service-type
                        add-msmtp-packages)
                       (service-extension
                        home-profile-service-type
                        ca-certificate-bundle)
                       ))
                (compose concatenate)
                ;; (extend add-profile-extensions)
                ;; (default-value (home-msmtp-configuration))
                (description "Create @file{~/.msmtprc}, which is used
by the @code{msmtp} program to send email to an SMTP mail server, which
then forwards the mail on behalf of the sender.  This service type can
be extended with a list of file-like objects.")))


;;;
;;; isync/mbsync
;;;
(define (string-list? strings)
  (and (list? strings) (and-map string? strings)))
(define (serialize-string-list field-name strings)
  #~(string-append
     #$@(map (lambda (config)
               (serialize-string field-name config))
             strings)))

(define mbsync-ssl-types
  (make-enumeration '(none
                      starttls
                      imaps)))
(define (mbsync-ssl-types? ssl-type)
  (enum-set-member? ssl-type mbsync-ssl-types))
(define (serialize-mbsync-ssl-types field-name val)
  (symbol->string val))

(define mbsync-ssl-version-types
  (make-enumeration '(sslv3
                      tlsv1
                      tlsv1.1
                      tlsv1.2
                      tlsv1.3)))
(define (mbsync-ssl-version-types? ssl-version)
  (enum-set-member? ssl-version mbsync-ssl-version-types))
(define (serialize-mbsync-ssl-version-types field-name val)
  (symbol->string val))
(define (mbsync-ssl-version-types-list? ssl-versions-list)
  (and (list? ssl-versions-list)
       (and-map mbsync-ssl-version-types? ssl-versions-list)))
(define (serialize-mbsync-ssl-version-types-list field-name vals)
  #~(string-append
     #$@(map (lambda (val)
               (serialize-mbsync-ssl-version-types field-name val))
             vals)))

(define (serialize-mbsync-account-configuration field-name val)
  (define (filter-fields field)
    (filter-configuration-fields mbsync-account-configuration-fields
                                 (list field)))

  (define (serialize-field field)
    (serialize-configuration
     config
     (filter-fields field)))
  (format #f
          "IMAPAccount ~a
"
          #$(serialize-field 'account-name)))

(define-configuration mbsync-account-configuration
  (account-name
   (string "")
   "Name to refer to this account.  Should also be a valid path name.")
  (host
   (string "")
   "DNS name or IP address of server.")
  (port
   (number 993)
   "TCP port number for IMAP.  993 is default for IMAPS, 143 for IMAP.")
  (auth-mechs
   (string-list (list ""))
   "List of SASL mechanisms to use to attempt authentication.
Legacy @code{LOGIN} mechanism is also supported.
http://www.iana.org/assignments/sasl-mechanisms/sasl-mechanisms.xhtml")
  (user
   (string "")
   "The email address to synchronize.")
  (pass-cmd
   (password-command)
   "Command to run with file as argument to produce a password.
Make sure the command does @emph{not} produce TTY output, otherwise things
get messy.")
  (ssl-type
   (mbsync-ssl-types)
   "Connection security/encryption methods to use.")
  (ssl-versions
   (mbsync-ssl-version-types-list (list mbsync-ssl-version-types))
   "List of acceptable TLS/SSL versions to use.")
  (certificate-file
   (string "")
   "File-like object that creates a path to a X.509 certificate store.")
  (pipeline-depth
   (number 50)
   "Number of IMAP commands in-flight simultaneously.  Setting to 1
disables pipelining.  Setting to 0 makes pipeline unlimited."))

(define-configuration mbsync-configuration
  (account-config
   (mbsync-account-configuration)
   "Account configuration for the remote-side connection for this
account's store.")
  ;; (imap-store-config
;;    mbsync-imap-store-configuration
;;    "Store configuration for remote IMAP side of connection.")
;;   (local-store-config
;;    mbsync-local-store-configuration
;;    "Store configuration for local side of connection.")
;;   (channel-config
;;    mbsync-channel-configuration
;;    "Channel configuration determining how to synchronize mail between
;; the remote and the local stores.")
  )

(define (serialize-alist field-name val)
  #~(string-append
     #$@(map
         (match-lambda
           ((key . value)
            #~(string-append #$key " " #$value)))
         val)))

(define (path? maybe-path)
  (string? maybe-path))
(define (serialize-path field-name val)
  val)

(define (serialize-mbsync-configuration field-name config)
  ;; TODO: Use for-each to serialize each element in the configuration.
  (serialize-mbsync-account-configuration field-name config))
  ;; (serialize-configuration config
  ;;                          (mbsync-configuration-account-config config)))
(define (mbsync-configuration-list? configs)
  (and (list? configs) (and-map mbsync-configuration? configs)))
(define (serialize-mbsync-configuration-list field-name vals)
  #~(string-append
     #$@(map (lambda (val)
               (serialize-mbsync-configuration field-name val))
             vals)))

(define %default-mbsync-global-config
  '(("Sync" . "All")
    ("Create" . "Both")
    ("Remove" . "None")
    ("Expunge" . "Both")
    ("CopyArrivalDate" . "yes")
    ("SyncState" . "*")))

(define-configuration home-mbsync-configuration
  (package
    (package isync)
    "The @code{mbsync} package to use.")
  (extra-global-config
   (alist %default-mbsync-global-config)
   "Global configuration that is not covered by any other configurations.
The pair
@lisp
'((\"Sync\" . \"All\"))
@end lisp

turns into

@example
Sync All
@end example")
  (base-path
   (path "~/Mail")
   "The base path where all mail is placed.")
  (accounts
   (mbsync-configuration-list
    (list (mbsync-configuration)))
   "List of email accounts to configure."))

(define (add-mbsync-configuration config)
  `((".mbsyncrc"
     ,(mixed-text-file
       "mbsyncrc"
       "Generated by Guix Home. Do not manually edit!"
       (serialize-configuration
        config
        (filter-configuration-fields
         home-mbsync-configuration-fields (list 'accounts)))))))

(define (add-mbsync-package config)
  (list (home-mbsync-configuration-package config)))

(define home-isync-service-type
  (service-type (name 'home-isync)
                (extensions
                 (list (service-extension
                        home-files-service-type
                        add-mbsync-configuration)
                       (service-extension
                        home-profile-service-type
                        add-mbsync-package)))
                (compose concatenate)
                ;; (extend add-isync-extensions)
                ;; (default-value (home-mbsync-configuration))
                (description "Create a @file{.mbsyncrc} configuration
file which is used by the @code{mbsync} program (from the isync project),
which can synchronize IMAP and POP3 mailboxes.")))

