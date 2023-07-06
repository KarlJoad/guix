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
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (guix modules)
  #:use-module (srfi srfi-1)
  #:export (apcupsd-configuration
            apcupsd-service-type))

(define-record-type* <apcupsd-configuration>
  apcupsd-configuration make-apcupsd-configuration
  apcupsd-configuration?
  ;; file-like object
  (package apcupsd-configuration-package
           (default apcupsd)))

(define (apcupsd-shepherd-service config)
  "Return a list of <shepherd-service>s for apcupsd with CONFIG."

  (define package
    (apcupsd-configuration-package config))

  (define apcupsd-command
    #~(list (string-append #$package "/sbin/apcupsd")
            "-b" ;; Do not fork off to background
            ;; "-f" "config-file"
            "-d1"))

  (list (shepherd-service
         (documentation "apcupsd UPS monitoring daemon.")
         (requirement '(networking syslogd))
         (provision '(apcupsd))
         ;; Use make-inetd-constructor??
         (start #~(make-forkexec-constructor #$apcupsd-command))
         (stop #~(make-kill-destructor))
         (actions (list (shepherd-configuration-action config))))))

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
                                          apcupsd-shepherd-service)))
                (compose concatenate)
                (extend extend-apcupsd-configuration)
                (default-value (apcupsd-configuration))))
