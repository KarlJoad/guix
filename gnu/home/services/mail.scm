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
            home-msmtp-configuration?))

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

(define (serialize-password-cmd field-name val)
  #~(string-append
     #$@(map
         (match-lambda
           ((cmd . file)
            #~(string-append #$cmd " " #$file)))
         val)))

(define-configuration home-msmtp-configuration
  (package
    (package msmtp)
    "The MSMTP package to use.")
  ;; home-msmtp-configuration make-home-msmtp-configuration
  ;; home-msmtp-configuration?
  (account
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
   (alist '()) ; I am not terribly fond of the single-element alist
   "Command & password file to interact with."
   serialize-password-cmd)
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

;; Filter out the requested field from the configuration struct
(define (msmtp-file-filter-fields field)
  (filter-configuration-fields home-msmtp-configuration-fields (list field)))

;; Serialize a single field of the msmtp configuration file
(define (msmtp-file-serialize-field config field)
  ;; In here, config is the concrete, provided, instance of the configuration
  (serialize-configuration config (msmtp-file-filter-fields field)))

(define (add-msmtp-configuration config)
  `(("msmtp/config"
     ,(mixed-text-file
       "config"
       "# Global Settings
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt\n\n
# Per-email account settings\n\n"
       "account " (msmtp-file-serialize-field config 'account) "\n"
       "auth on\n"
       "from " (msmtp-file-serialize-field config 'email) "\n"
       "host " (msmtp-file-serialize-field config 'host) "\n"
       "user " (msmtp-file-serialize-field config 'user) "\n"
       "passwordeval " (msmtp-file-serialize-field config 'pass-cmd) "\n"
       "port " (msmtp-file-serialize-field config 'port-num) "\n"
       "protocol " (msmtp-file-serialize-field config 'protocol) "\n"
       "tls " (msmtp-file-serialize-field config 'enable-tls?) "\n"
       "tls_starttls " (msmtp-file-serialize-field config 'enable-starttls?) "\n"
       "tls_trust_file " (msmtp-file-serialize-field config 'tls-trust-file)))))

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
                        ca-certificate-bundle)))
                (compose concatenate)
                ;; (extend add-profile-extensions)
                (default-value (home-msmtp-configuration))
                (description "Create @file{~/.msmtprc}, which is used
by the @code{msmtp} program to send email to an SMTP mail server, which
then forwards the mail on behalf of the sender.  This service type can
be extended with a list of file-like objects.")))
