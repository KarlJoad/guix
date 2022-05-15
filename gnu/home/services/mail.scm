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
  #:use-module (guix records)
  #:use-module (gnu services configuration)
  #:use-module (gnu home services)
  #:use-module (gnu home services utils)
  #:use-module (gnu packages mail) ; isync, msmtp, mu
  #:use-module (guix gexp)

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

(define-configuration home-msmtp-configuration
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
   "Fully-qualified name for the SMTP server you are sending through."))

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
       "host " (msmtp-file-serialize-field config 'host)))))

(define home-msmtp-service-type
  (service-type (name 'home-msmtp)
                (extensions
                 (list (service-extension
                        home-xdg-configuration-files-service-type
                        add-msmtp-configuration)))
                (compose concatenate)
                ;; (extend add-profile-extensions)
                (default-value (home-msmtp-configuration))
                (description "Create @file{~/.msmtprc}, which is used
by the @code{msmtp} program to send email to an SMTP mail server, which
then forwards the mail on behalf of the sender.  This service type can
be extended with a list of file-like objects.")))
