;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2012-2020, 2022-2024 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2013 Mark H Weaver <mhw@netris.org>
;;; Copyright © 2014 Eric Bavier <bavier@member.fsf.org>
;;; Copyright © 2016, 2017 Alex Kost <alezost@gmail.com>
;;; Copyright © 2016 Mathieu Lirzin <mthl@gnu.org>
;;; Copyright © 2022 Antero Mejr <antero@mailbox.org>
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

(define-module (gnu packages)
  #:use-module (guix packages)
  #:use-module (guix ui)
  #:use-module (guix utils)
  #:use-module (guix diagnostics)
  #:use-module (guix discovery)
  #:use-module (guix memoization)
  #:use-module ((guix build utils)
                #:select ((package-name->name+version
                           . hyphen-separated-name->name+version)
                          mkdir-p))
  #:use-module (guix profiles)
  #:use-module (guix describe)
  #:use-module (guix deprecation)
  #:use-module (ice-9 vlist)
  #:use-module (ice-9 match)
  #:use-module (ice-9 binary-ports)
  #:autoload   (rnrs bytevectors) (bytevector?)
  #:autoload   (system base compile) (compile)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-34)
  #:use-module (srfi srfi-35)
  #:use-module (srfi srfi-39)
  #:use-module (srfi srfi-71)
  #:export (search-patch
            search-patches
            search-auxiliary-file
            %patch-path
            %auxiliary-files-path
            %package-module-path
            %default-package-module-path
            cache-is-authoritative?

            fold-packages
            all-packages
            fold-available-packages

            find-newest-available-packages
            find-packages-by-name
            find-package-locations
            find-best-packages-by-name

            specification->package
            specification->package+output
            specification->location
            specifications->manifest
            specifications->packages

            package-unique-version-prefix

            generate-package-cache))

;;; Commentary:
;;;
;;; General utilities for the software distribution---i.e., the modules under
;;; (gnu packages ...).
;;;
;;; Code:

;; By default, we store patches and auxiliary files
;; alongside Guile modules.  This is so that these extra files can be
;; found without requiring a special setup, such as a specific
;; installation directory and an extra environment variable.  One
;; advantage of this setup is that everything just works in an
;; auto-compilation setting.

(define %auxiliary-files-path
  (make-parameter
   (map (cut string-append <> "/gnu/packages/aux-files")
        %load-path)))

(define (search-auxiliary-file file-name)
  "Search the auxiliary FILE-NAME.  Return #f if not found."
  (search-path (%auxiliary-files-path) file-name))

(define (search-patch file-name)
  "Search the patch FILE-NAME.  Raise an error if not found."
  (or (search-path (%patch-path) file-name)
      (raise (formatted-message (G_ "~a: patch not found")
                                file-name))))

(define-syntax-rule (search-patches file-name ...)
  "Return the list of absolute file names corresponding to each
FILE-NAME found in %PATCH-PATH."
  (list (search-patch file-name) ...))

(define %distro-root-directory
  ;; Absolute file name of the module hierarchy.  Since (gnu packages …) might
  ;; live in a directory different from (guix), try to get the best match.
  (letrec-syntax ((dirname* (syntax-rules ()
                              ((_ file)
                               (dirname file))
                              ((_ file head tail ...)
                               (dirname (dirname* file tail ...)))))
                  (try      (syntax-rules ()
                              ((_ (file things ...) rest ...)
                               (match (search-path %load-path file)
                                 (#f
                                  (try rest ...))
                                 (absolute
                                  (dirname* absolute things ...))))
                              ((_)
                               #f))))
    (try ("gnu/packages/base.scm" gnu/ packages/)
         ("gnu/packages.scm"      gnu/)
         ("guix.scm"))))

(define %default-package-module-path
  ;; Default search path for package modules.
  `((,%distro-root-directory . "gnu/packages")))

(define (cache-is-authoritative?)
  "Return true if the pre-computed package cache is authoritative.  It is not
authoritative when entries have been added via GUIX_PACKAGE_PATH or '-L'
flags."
  (equal? (%package-module-path)
          (append %default-package-module-path
                  (package-path-entries))))

(define %package-module-path
  ;; Search path for package modules.  Each item must be either a directory
  ;; name or a pair whose car is a directory and whose cdr is a sub-directory
  ;; to narrow the search.
  (let* ((not-colon   (char-set-complement (char-set #\:)))
         (environment (string-tokenize (or (getenv "GUIX_PACKAGE_PATH") "")
                                       not-colon))
         (channels-scm (package-path-entries)))
    ;; Automatically add channels and items from $GUIX_PACKAGE_PATH to Guile's
    ;; search path.  For historical reasons, $GUIX_PACKAGE_PATH goes to the
    ;; front; channels go to the back so that they don't override Guix' own
    ;; modules.
    (append-channels-to-load-path!)
    (set! %load-path
      (append environment %load-path))
    (set! %load-compiled-path
      (append environment %load-compiled-path))

    (make-parameter
     (append environment
             %default-package-module-path
             channels-scm))))

(define %patch-path
  ;; Define it after '%package-module-path' so that '%load-path' contains user
  ;; directories, allowing patches in $GUIX_PACKAGE_PATH to be found.
  (make-parameter
   (map (lambda (directory)
          (if (string=? directory %distro-root-directory)
              (string-append directory "/gnu/packages/patches")
              directory))
        %load-path)))

;; This procedure is used by Emacs-Guix up to 0.5.1.1, so keep it for now.
;; See <https://github.com/alezost/guix.el/issues/30>.
(define-deprecated find-newest-available-packages
  find-packages-by-name
  (mlambda ()
    "Return a vhash keyed by package names, and with
associated values of the form

  (newest-version newest-package ...)

where the preferred package is listed first."
    (fold-packages (lambda (p r)
                     (let ((name    (package-name p))
                           (version (package-version p)))
                       (match (vhash-assoc name r)
                         ((_ newest-so-far . pkgs)
                          (case (version-compare version newest-so-far)
                            ((>) (vhash-cons name `(,version ,p) r))
                            ((=) (vhash-cons name `(,version ,p ,@pkgs) r))
                            ((<) r)))
                         (#f (vhash-cons name `(,version ,p) r)))))
                   vlist-null)))

(define (fold-available-packages proc init)
  "Fold PROC over the list of available packages.  For each available package,
PROC is called along these lines:

  (PROC NAME VERSION RESULT
        #:outputs OUTPUTS
        #:location LOCATION
        …)

PROC can use #:allow-other-keys to ignore the bits it's not interested in.
When a package cache is available, this procedure does not actually load any
package module."
  (define cache
    (load-package-cache (current-profile)))

  (if (and cache (cache-is-authoritative?))
      (vhash-fold (lambda (name vector result)
                    (match vector
                      (#(name version module symbol outputs
                              supported? deprecated?
                              file line column)
                       (proc name version result
                             #:outputs outputs
                             #:location (and file
                                             (location file line column))
                             #:supported? supported?
                             #:deprecated? deprecated?))))
                  init
                  cache)
      (fold-packages (lambda (package result)
                       (proc (package-name package)
                             (package-version package)
                             result
                             #:outputs (package-outputs package)
                             #:location (package-location package)
                             #:supported?
                             (->bool (supported-package? package))
                             #:deprecated?
                             (->bool
                              (package-superseded package))))
                     init)))

(define* (fold-packages proc init
                        #:optional
                        (modules (all-modules (%package-module-path)
                                              #:warn
                                              warn-about-load-error))
                        #:key (select? (negate hidden-package?)))
  "Call (PROC PACKAGE RESULT) for each available package defined in one of
MODULES that matches SELECT?, using INIT as the initial value of RESULT.  It
is guaranteed to never traverse the same package twice."
  (fold-module-public-variables (lambda (object result)
                                  (if (and (package? object) (select? object))
                                      (proc object result)
                                      result))
                                init
                                modules))

(define all-packages
  (mlambda ()
    "Return the list of all public packages, including replacements and hidden
packages, excluding superseded packages."
    ;; Note: 'fold-packages' never traverses the same package twice but
    ;; replacements break that (they may or may not be visible to
    ;; 'fold-packages'), hence this hash table to track visited packages.
    (define visited (make-hash-table))

    (fold-packages (lambda (package result)
                     (if (hashq-ref visited package)
                         result
                         (begin
                           (hashq-set! visited package #t)
                           (match (package-replacement package)
                             ((? package? replacement)
                              (hashq-set! visited replacement #t)
                              (cons* replacement package result))
                             (#f
                              (cons package result))))))
                   '()

                   ;; Dismiss deprecated packages but keep hidden packages.
                   #:select? (negate package-superseded))))

(define %package-cache-file
  ;; Location of the package cache.
  "/lib/guix/package.cache")

(define load-package-cache
  (mlambda (profile)
    "Attempt to load the package cache.  On success return a vhash keyed by
package names.  Return #f on failure."
    (match profile
      (#f #f)
      (profile
       (catch 'system-error
         (lambda ()
           (define lst
             (load-compiled (string-append profile %package-cache-file)))
           (fold (lambda (item vhash)
                   (match item
                     (#(name version module symbol outputs
                             supported? deprecated?
                             file line column)
                      (vhash-cons name item vhash))))
                 vlist-null
                 lst))
         (lambda args
           (if (= ENOENT (system-error-errno args))
               #f
               (apply throw args))))))))

(define find-packages-by-name/direct              ;bypass the cache
  (let ((packages (delay
                    (fold-packages (lambda (p r)
                                     (vhash-cons (package-name p) p r))
                                   vlist-null)))
        (version>? (lambda (p1 p2)
                     (version>? (package-version p1) (package-version p2)))))
    (lambda* (name #:optional version)
      "Return the list of packages with the given NAME.  If VERSION is not #f,
then only return packages whose version is prefixed by VERSION, sorted in
decreasing version order."
      (let ((matching (sort (vhash-fold* cons '() name (force packages))
                            version>?)))
        (if version
            (filter (lambda (package)
                      (version-prefix? version (package-version package)))
                    matching)
            matching)))))

(define (cache-lookup cache name)
  "Lookup package NAME in CACHE.  Return a list sorted in increasing version
order."
  (define (package-version<? v1 v2)
    (version>? (vector-ref v2 1) (vector-ref v1 1)))

  (sort (vhash-fold* cons '() name cache)
        package-version<?))

(define* (find-packages-by-name name #:optional version)
  "Return the list of packages with the given NAME.  If VERSION is not #f,
then only return packages whose version is prefixed by VERSION, sorted in
decreasing version order."
  (define cache
    (load-package-cache (current-profile)))

  (if (and (cache-is-authoritative?) cache)
      (match (cache-lookup cache name)
        (#f #f)
        ((#(_ versions modules symbols _ _ _ _ _ _) ...)
         (fold (lambda (version* module symbol result)
                 (if (or (not version)
                         (version-prefix? version version*))
                     (cons (module-ref (resolve-interface module)
                                       symbol)
                           result)
                     result))
               '()
               versions modules symbols)))
      (find-packages-by-name/direct name version)))

(define* (find-package-locations name #:optional version)
  "Return a list of version/location pairs corresponding to each package
matching NAME and VERSION."
  (define cache
    (load-package-cache (current-profile)))

  (if (and cache (cache-is-authoritative?))
      (match (cache-lookup cache name)
        (#f '())
        ((#(name versions modules symbols outputs
                 supported? deprecated?
                 files lines columns) ...)
         (fold (lambda (version* file line column result)
                 (if (and file
                          (or (not version)
                              (version-prefix? version version*)))
                     (alist-cons version* (location file line column)
                                 result)
                     result))
               '()
               versions files lines columns)))
      (map (lambda (package)
             (cons (package-version package) (package-location package)))
           (find-packages-by-name/direct name version))))

(define (find-best-packages-by-name name version)
  "If version is #f, return the list of packages named NAME with the highest
version numbers; otherwise, return the list of packages named NAME and at
VERSION."
  (if version
      (find-packages-by-name name version)
      (match (find-packages-by-name name)
        (()
         '())
        ((matches ...)
         ;; Return the subset of MATCHES with the higher version number.
         (let ((highest (package-version (first matches))))
           (take-while (lambda (p)
                         (string=? (package-version p) highest))
                       matches))))))

;; Prevent Guile 3 from inlining this procedure so we can mock it in tests.
(set! find-best-packages-by-name find-best-packages-by-name)

(define (generate-package-cache directory)
  "Generate under DIRECTORY a cache of all the available packages.

The primary purpose of the cache is to speed up package lookup by name such
that we don't have to traverse and load all the package modules, thereby also
reducing the memory footprint."
  (define cache-file
    (string-append directory %package-cache-file))

  (define expand-cache
    (match-lambda*
      (((module symbol variable) (result . seen))
       (let ((package (variable-ref variable)))
         (if (or (vhash-assq package seen)
                 (hidden-package? package))
             (cons result seen)
             (cons (cons `#(,(package-name package)
                            ,(package-version package)
                            ,(module-name module)
                            ,symbol
                            ,(package-outputs package)
                            ,(->bool (supported-package? package))
                            ,(->bool (package-superseded package))
                            ,@(let ((loc (package-location package)))
                                (if loc
                                    `(,(location-file loc)
                                      ,(location-line loc)
                                      ,(location-column loc))
                                    '(#f #f #f))))
                         result)
                   (vhash-consq package #t seen)))))))

  (define entry-key
    (match-lambda
      ((module symbol variable)
       (let ((value (variable-ref variable)))
         (string-append (package-name value) (package-version value)
                        (object->string module)
                        (symbol->string symbol))))))

  (define (entry<? a b)
    (string<? (entry-key a) (entry-key b)))

  (define variables
    ;; First sort variables so that 'expand-cache' later dismisses
    ;; already-seen package objects in a deterministic fashion.
    (sort
     (fold-module-public-variables* (lambda (module symbol variable lst)
                                      (let ((value (false-if-exception
                                                    (variable-ref variable))))
                                        (if (package? value)
                                            (cons (list module symbol variable)
                                                  lst)
                                            lst)))
                                    '()
                                    (all-modules (%package-module-path)
                                                 #:warn
                                                 warn-about-load-error))
     entry<?))

  (define exp
    (first (fold expand-cache (cons '() vlist-null) variables)))

  (mkdir-p (dirname cache-file))
  (call-with-output-file cache-file
    (lambda (port)
      ;; Store the cache as a '.go' file.  This makes loading fast and reduces
      ;; heap usage since some of the static data is directly mmapped.
      (match (compile `'(,@exp)
                      #:to 'bytecode
                      #:opts '(#:to-file? #t))
        ((? bytevector? bv)
         (put-bytevector port bv))
        (proc
         ;; In Guile 3.0.9, the linker can return a procedure instead of a
         ;; bytevector.  Adjust to that.
         (proc port)))))
  cache-file)


(define %sigint-prompt
  ;; The prompt to jump to upon SIGINT.
  (make-prompt-tag "interruptible"))

(define (call-with-sigint-handler thunk handler)
  "Call THUNK and return its value.  Upon SIGINT, call HANDLER with the signal
number in the context of the continuation of the call to this function, and
return its return value."
  (call-with-prompt %sigint-prompt
                    (lambda ()
                      (sigaction SIGINT
                        (lambda (signum)
                          (sigaction SIGINT SIG_DFL)
                          (abort-to-prompt %sigint-prompt signum)))
                      (dynamic-wind
                        (const #t)
                        thunk
                        (cut sigaction SIGINT SIG_DFL)))
                    (lambda (k signum)
                      (handler signum))))


;;;
;;; Package specification.
;;;

(define* (%find-package spec name version)
  (match (find-best-packages-by-name name version)
    ((pkg . pkg*)
     (unless (null? pkg*)
       (warning (G_ "ambiguous package specification `~a'~%") spec)
       (warning (G_ "choosing ~a@~a from ~a~%")
                (package-name pkg) (package-version pkg)
                (location->string (package-location pkg))))
     (match (package-superseded pkg)
       ((? package? new)
        (info (G_ "package '~a' has been superseded by '~a'~%")
              (package-name pkg) (package-name new))
        new)
       (#f
        pkg)))
    (x
     (if version
         (leave (G_ "~A: package not found for version ~a~%") name version)
         (leave (G_ "~A: unknown package~%") name)))))

(define (specification->package spec)
  "Return a package matching SPEC.  SPEC may be a package name, or a package
name followed by an at-sign and a version number.  If the version number is not
present, return the preferred newest version."
  (let ((name version (package-name->name+version spec)))
    (%find-package spec name version)))

(define (specification->location spec)
  "Return the location of the highest-numbered package matching SPEC, a
specification such as \"guile@2\" or \"emacs\"."
  (let ((name version (package-name->name+version spec)))
    (match (find-package-locations name version)
      (()
       (if version
           (leave (G_ "~A: package not found for version ~a~%") name version)
           (leave (G_ "~A: unknown package~%") name)))
      (lst
       (let* ((highest   (match lst (((version . _) _ ...) version)))
              (locations (take-while (match-lambda
                                       ((version . location)
                                        (string=? version highest)))
                                     lst)))
         (match locations
           (((version . location) . rest)
            (unless (null? rest)
              (warning (G_ "ambiguous package specification `~a'~%") spec)
              (warning (G_ "choosing ~a@~a from ~a~%")
                       name version
                       (location->string location)))
            location)))))))

(define* (specification->package+output spec #:optional (output "out"))
  "Return the package and output specified by SPEC, or #f and #f; SPEC may
optionally contain a version number and an output name, as in these examples:

  guile
  guile@2.0.9
  guile:debug
  guile@2.0.9:debug

If SPEC does not specify a version number, return the preferred newest
version; if SPEC does not specify an output, return OUTPUT.

When OUTPUT is false and SPEC does not specify any output, return #f as the
output."
  (let ((name version sub-drv
              (package-specification->name+version+output spec output)))
    (match (%find-package spec name version)
      (#f
       (values #f #f))
      (package
       (if (or (and (not output) (not sub-drv))
               (member sub-drv (package-outputs package)))
           (values package sub-drv)
           (leave (G_ "package `~a' lacks output `~a'~%")
                  (package-full-name package)
                  sub-drv))))))

(define (specifications->packages specs)
  "Given SPECS, a list of specifications such as \"emacs@25.2\" or
\"guile:debug\", return a list of package/output tuples."
  ;; This procedure exists so users of 'guix home' don't have to write out the
  ;; (map (compose list specification->package+output)... boilerplate.
  (map (compose list specification->package+output) specs))

(define (specifications->manifest specs)
  "Given SPECS, a list of specifications such as \"emacs@25.2\" or
\"guile:debug\", return a profile manifest."
  ;; This procedure exists mostly so users of 'guix package -m' don't have to
  ;; fiddle with multiple-value returns.
  (packages->manifest
   (specifications->packages specs)))

(define (package-unique-version-prefix name version)
  "Search among all the versions of package NAME that are available, and
return the shortest unambiguous version prefix to designate VERSION.  If only
one version of the package is available, return the empty string."
  (match (map package-version (find-packages-by-name name))
    ((_)
     ;; A single version of NAME is available, so do not specify the version
     ;; number, even if the available version doesn't match VERSION.
     "")
    (versions
     ;; If VERSION is the latest version, don't specify any version.
     ;; Otherwise return the shortest unique version prefix.  Note that this
     ;; is based on the currently available packages so the result may vary
     ;; over time.
     (if (every (cut version>? version <>)
                (delete version versions))
         ""
         (version-unique-prefix version versions)))))
