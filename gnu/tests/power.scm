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

(define-module (gnu tests power)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system vm)
  #:use-module (gnu services)
  #:use-module (gnu services power)
  #:use-module (gnu services networking)
  #:use-module (gnu packages power)
  #:use-module (guix gexp)
  #:export (%test-apcupsd))

(define (run-apcupsd-test name)
  "Run a test of an OS running an apcupsd-service-type, which behaves like
it normally does."
  (define os
    (marionette-operating-system
     (simple-operating-system
      (service dhcp-client-service-type)
      (service apcupsd-service-type))
     #:imported-modules '((gnu services herd)
                          (guix combinators))))

  (define vm
    (virtual-machine os))

  (define test
    (with-imported-modules '((gnu build marionette))
      #~(begin
          (use-modules (gnu build marionette)
                       (srfi srfi-64))
          (define marionette
            ;; Boot the marionette VM
            (make-marionette (list #$vm)))

          (test-runner-current (system-test-runner #$output))

          (test-begin "apcupsd-daemon")

          ;; Wait for apcupsd to be up and running.
          (test-assert "apcupsd service running"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'apcupsd))
             marionette))

          ;; Check apcupsd's PID file
          (test-assert "apcupsd PID"
            (let ((shepherd-pid (marionette-eval
                                 '(begin
                                    (use-modules (gnu services herd)
                                                 (srfi srfi-1))
                                    (live-service-running
                                     (find (lambda (live)
                                             (memq 'apcupsd
                                                   (live-service-provision live)))
                                           (current-services))))
                                 marionette)))
              (= shepherd-pid
                 (wait-for-file "/var/run/apcupsd.pid" marionette))))

          (test-end))))

  (gexp->derivation name test))

(define %test-apcupsd
  (system-test
   (name "apcupsd")
   (description "Test apcupsd")
   (value (run-apcupsd-test name))))
