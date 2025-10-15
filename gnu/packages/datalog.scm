;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2025 Raven Hallsby <karl@hallsby.com>
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

(define-module (gnu packages datalog)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix build-system cmake)
  #:use-module (guix utils)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cpp)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages ghostscript)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages java)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages swig)
  #:use-module (gnu packages version-control))

(define-public souffle
  (package
    (name "souffle")
    (version "2.5")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/souffle-lang/souffle")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1lrw69g02b17vxxz4g7cj8hbmc39wlzl80vl5fwy40a6b9pxwrsj"))))
    (native-inputs (list bison
                         flex
                         ;; Only needed for building documentation
                         doxygen
                         fontconfig
                         font-ghostscript
                         graphviz-minimal))
    ;; These inputs are used when souffle is invoked as a compiler, so they are
    ;; needed at runtime.
    (inputs (list gcc-toolchain
                  mcpp
                  python-minimal
                  bash-minimal
                  libffi
                  ncurses
                  sqlite
                  swig
                  `(,openjdk "jdk")
                  zlib))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list
         ;; Prevent souffle from calling out to git for a version number
         "-DSOUFFLE_GIT=OFF"
         ;; Use larger representation values.
         "-DSOUFFLE_DOMAIN_64BIT=ON"
         ;; Allow Java/Python/others to use libffi to interop with souffle.
         "-DSOUFFLE_SWIG=ON"
         ;; By default Souffle only runs tests on evaluation examples. We
         ;; force it to also test its code examples.
         "-DSOUFFLE_ENABLE_TESTING=ON"
         "-DSOUFFLE_TEST_EXAMPLES=ON"
         "-DSOUFFLE_TEST_EVALUATION=ON"
         ;; Enable documentation target
         "-DSOUFFLE_GENERATE_DOXYGEN=man"
         ;; Generate Bash completions
         "-DSOUFFLE_BASH_COMPLETION=on"
         (string-append "-DBASH_COMPLETION_COMPLETIONSDIR="
                        #$output "/etc/bash_completion.d"))
      #:phases
      #~(modify-phases %standard-phases
          ;; Allow for parallel testing. The -j in the "make check" command does
          ;; not propagate to ctest. With 4500+ tests, and some taking multiple
          ;; minutes to finish, parallelism really helps.
          (replace 'check
            (lambda* (#:key tests? parallel-tests? #:allow-other-keys)
              (setenv "CTEST_OUTPUT_ON_FAILURE" "1")
              (when tests?
                (invoke "ctest" "--output-on-failure" "-j"
                        (if parallel-tests?
                            (number->string (parallel-job-count)) "1")
                        ;; Increase per-test time-out, since some tests can take
                        ;; >1 hour to run.
                        ;; Timeout is measured in seconds.
                        ;; Set to 0 because we time-out at the Guix level.
                        "--timeout" (number->string 0)))))
          (add-after 'check 'build-docs
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Already in build/ directory
              ;; Set a cache directory for fontconfig
              (setenv "XDG_CACHE_HOME"
                      (mkdtemp "/tmp/cache-XXXXXX"))
              (invoke "make" "doxygen")))
          (add-after 'install 'install-docs
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((out (assoc-ref outputs "out")))
                ;; Still currently in build/
                (format #t "~a~%"
                        (getcwd))
                (with-directory-excursion "../source"
                  (format #t "excursion: ~a~%"
                          (getcwd))
                  (mkdir-p (string-append out "/share/man/man1/"))
                  (copy-recursively "man/"
                                    (string-append out "/share/man/man1/"))
                  (mkdir-p (string-append out "/share/man/man3/"))
                  (install-file "doc/man/man3/souffle.3"
                                (string-append out "/share/man/man3/"))))))
          ;; Clean up various files and wrap binaries.
          ;; The compiler wrapper script takes many of its values from an
          ;; embedded JSON string rather than environment variables, which
          ;; makes some of our wrapping ineffective.
          (add-after 'install 'wrap-programs
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Wrap the compiled binaries that point to the libraries
              ;; souffle needs at runtime.
              (wrap-program (string-append #$output "/bin/souffle")
                `("PATH" ":"
                  prefix
                  ;; Souffle has a "build system" that will run the souffle
                  ;; compiler to produce a C++ program and then run g++ to
                  ;; build the final binary.
                  ,(list (string-append #$(this-package-input "swig") "/bin")
                         (string-append #$(this-package-input "python-minimal")
                                        "/bin")
                         (string-append #$(this-package-input "mcpp") "/bin")
                         (string-append #$(this-package-input "gcc-toolchain")
                                        "/bin")))
                `("C_INCLUDE_PATH" ":" prefix
                  ,(list (string-append #$output "/include")
                         (string-append #$(this-package-input "gcc-toolchain")
                                        "/include")
                         (string-append #$(this-package-input "zlib")
                                        "/include")
                         (string-append #$(this-package-input "ncurses")
                                        "/include")
                         (string-append #$(this-package-input "sqlite")
                                        "/include")
                         (string-append #$(this-package-input "libffi")
                                        "/include")))
                `("CPLUS_INCLUDE_PATH" ":" prefix
                  ;; Souffle needs to know where its own headers are.
                  ,(list (string-append #$output "/include")
                         (string-append #$(this-package-input "gcc-toolchain")
                                        "/include/c++")
                         (string-append #$(this-package-input "gcc-toolchain")
                                        "/include")
                         (string-append #$(this-package-input "zlib")
                                        "/include")
                         (string-append #$(this-package-input "ncurses")
                                        "/include")
                         (string-append #$(this-package-input "sqlite")
                                        "/include")
                         (string-append #$(this-package-input "libffi")
                                        "/include")))
                ;; Make sure g++ and co. can find necessary files when
                ;; compiling the souffle-generated C++ program. In particular,
                ;; crt1.o and crti.o need to be found.
                ;; The final compiled program has rpaths set to libraries by
                ;; the compiler script. So no LD_LIBRARY_PATH changes are
                ;; needed.
                `("LIBRARY_PATH" ":" prefix
                  ,(list (string-append #$output "/lib") ;Technically Souffle has no /lib
                         (string-append #$(this-package-input "gcc-toolchain")
                                        "/lib")
                         (string-append #$(this-package-input "zlib") "/lib")
                         (string-append #$(this-package-input "ncurses")
                                        "/lib")
                         (string-append #$(this-package-input "sqlite") "/lib")
                         (string-append #$(this-package-input "libffi") "/lib"))))
              ;; And now we must "wrap" souffle's compiler wrapper script's
              ;; internal JSON config file, so the invoked g++ can find
              ;; everything it needs.
              (with-directory-excursion #$output
                (let ((includes (list (string-append #$output "/include")
                                      (string-append #$(this-package-input
                                                        "gcc-toolchain")
                                                     "/include/c++")
                                      (string-append #$(this-package-input
                                                        "gcc-toolchain")
                                                     "/include")
                                      (string-append #$(this-package-input
                                                        "zlib") "/include")
                                      (string-append #$(this-package-input
                                                        "ncurses") "/include")
                                      (string-append #$(this-package-input
                                                        "sqlite") "/include")
                                      (string-append #$(this-package-input
                                                        "libffi") "/include")
                                      (string-append (assoc-ref inputs "libc")
                                                     "/lib")
                                      ;; Need an explicit path to <linux/errno.h>?
                                      (string-append (assoc-ref inputs
                                                      "kernel-headers")
                                                     "/include")))
                      (libs (list (string-append #$(this-package-input
                                                    "gcc-toolchain") "/lib")
                                  (string-append #$(this-package-input "zlib")
                                                 "/lib")
                                  (string-append #$(this-package-input
                                                    "ncurses") "/lib")
                                  (string-append #$(this-package-input
                                                    "sqlite") "/lib")
                                  (string-append #$(this-package-input
                                                    "libffi") "/lib")
                                  (string-append (assoc-ref inputs "libc")
                                                 "/lib"))))
                  (substitute* "bin/souffle-compile.py"
                    ;; Make C++ includes & linking work and remove embedded build path
                    (("(\"includes\"): \"([[[[:alnum:] -_.]+)\"," all option
                      prev-vals)
                     (string-append option ": \""
                                    (string-join includes " -I"
                                                 'prefix) " " "\","))
                    (("(\"link_options\"): \"([[:alnum:] -_.]+)\"," all option
                      prev-options)
                     (string-append option
                                    ": \""
                                    (string-join libs " -L"
                                                 'prefix)
                                    " "
                                    prev-options
                                    "\","))
                    ;; Remove embedded build path
                    (("(\"source_include_dir\"): \".*\"," all option)
                     (string-append option ": \"\","))))))))))
    ;; TODO: Figure out if we need to handle search paths!
    ;; (native-search-paths
    ;; (list (search-path-specification
    ;; (variable "C_INCLUDE_PATH")
    ;; (files '("include")))
    ;; (search-path-specification
    ;; (variable "CPLUS_INCLUDE_PATH")
    ;; (files '("include")))
    ;; (search-path-specification
    ;; (variable "LIBRARY_PATH")
    ;; (files '("lib")))))
    (home-page "https://souffle-lang.github.io")
    (synopsis "Compiler for a variant of Datalog using Horn clauses")
    (description
     "Souffle is a logic programming language inspired by Datalog by
crafting analyses in Horn clauses.  It overcomes some of the limitations in
classical Datalog.  For example, programmers are not restricted to finite
domains, and the usage of functors (intrinsic, user-defined,
records/constructors, etc.) is permitted.  Souffle has a component model so
that large logic projects can be expressed.")
    (license license:upl1.0)
    (properties `((timeout . ,(* 2 60 60))))))
