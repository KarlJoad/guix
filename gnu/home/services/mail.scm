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
  #:use-module (gnu packages mail) ; isync, msmtp, mu
  #:use-module (guix gexp)
  #:use-module (guix profiles)

  #:export (home-msmtp-service-type
            home-msmtp-configuration
            msmtp-account-configuration
            password-command

            home-isync-service-type
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
