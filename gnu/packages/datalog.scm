(define-module (gnu packages datalog)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix build-system cmake)
  #:use-module (guix utils)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cpp)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages flex)
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
  ;; 2.4.1 is the most recent tagged commit, but is from 2023. A commit from
  ;; 2024 fixes the last 2 unit test failures that 2.4.1 experienced. So we use
  ;; a more recent commit hash instead.
  (let ((commit "040a962f3f880f1bef7fb66559c4816d4902bd74")
        (revision "0"))
    (package
      (name "souffle")
      (version (string-append "2.4.1-" revision "."
                              (string-take commit 7)))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/souffle-lang/souffle")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0py16ng46v88p8qxz1bdfq9vlwlf18kjl4plcvqjyjbhkzxnrhn5"))))
      (native-inputs
       (list doxygen))
      (inputs
       (list bison flex libffi
             gcc-toolchain
             graphviz-minimal
             mcpp
             ncurses
             python-minimal
             sqlite
             swig
             ;; I'm not sure which output of openjdk is needed.
             openjdk `(,openjdk "jdk")
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
           ;; Generate HTML & man documentation.
           "-DSOUFFLE_GENERATE_DOXYGEN=html;man"
           "-DSOUFFLE_BASH_COMPLETION=on"
           (string-append "-DBASH_COMPLETION_COMPLETIONSDIR=" #$output "/etc/bash_completion.d"))
        #:phases
        #~(modify-phases %standard-phases
            ;; Allow for parallel testing. The -j in the "make check" command does
            ;; not propagate to ctest. With 4500+ tests, and some taking multiple
            ;; minutes to finish, parallelism really helps.
            (replace 'check
              (lambda* (#:key tests? parallel-tests? #:allow-other-keys)
                (setenv "CTEST_OUTPUT_ON_FAILURE" "1")
                (when tests? (invoke "ctest" "--output-on-failure" "-j"
                                     (if parallel-tests?
                                         (number->string (parallel-job-count))
                                         "1")))))
            ;; Clean up various files and wrap binaries.
            ;; The compiler wrapper script takes many of its values from an
            ;; embedded JSON string rather than environment variables, which
            ;; makes some of our wrapping ineffective.
            (add-after 'install 'wrap-programs
              (lambda* (#:key inputs #:allow-other-keys)
                ;; Wrap the compiled binaries that point to the libraries
                ;; souffle needs at runtime.
                (wrap-program (string-append #$output "/bin/souffle")
                  `("PATH" ":" prefix
                    ;; Souffle has a "build system" that will run the souffle
                    ;; compiler to produce a C++ program and then run g++ to
                    ;; build the final binary.
                    ,(list (string-append (assoc-ref inputs "swig") "/bin")
                           (string-append (assoc-ref inputs "python-minimal") "/bin")
                           (string-append (assoc-ref inputs "mcpp") "/bin")
                           (string-append (assoc-ref inputs "gcc-toolchain") "/bin")))
                  `("C_INCLUDE_PATH" ":" prefix
                    ,(list (string-append #$output "/include")
                           (string-append (assoc-ref inputs "gcc-toolchain") "/include")
                           (string-append (assoc-ref inputs "zlib") "/include")
                           (string-append (assoc-ref inputs "ncurses") "/include")
                           (string-append (assoc-ref inputs "sqlite") "/include")
                           (string-append (assoc-ref inputs "libffi") "/include")
                           (string-append (assoc-ref inputs "libc") "/lib")
                           ;; Need an explicit path to <linux/errno.h>?
                           (string-append (assoc-ref inputs "kernel-headers") "/include")))
                  `("CPLUS_INCLUDE_PATH" ":" prefix
                    ;; Souffle needs to know where its own headers are.
                    ,(list (string-append #$output "/include")
                           (string-append (assoc-ref inputs "gcc-toolchain") "/include/c++")
                           (string-append (assoc-ref inputs "gcc-toolchain") "/include")
                           (string-append (assoc-ref inputs "zlib") "/include")
                           (string-append (assoc-ref inputs "ncurses") "/include")
                           (string-append (assoc-ref inputs "sqlite") "/include")
                           (string-append (assoc-ref inputs "libffi") "/include")
                           (string-append (assoc-ref inputs "libc") "/lib")
                           ;; Need an explicit path to <linux/errno.h>?
                           (string-append (assoc-ref inputs "kernel-headers") "/include")))
                  ;; Make sure g++ and co. can find necessary files when
                  ;; compiling the souffle-generated C++ program. In particular,
                  ;; crt1.o and crti.o need to be found.
                  ;; The final compiled program has rpaths set to libraries by
                  ;; the compiler script. So no LD_LIBRARY_PATH changes are
                  ;; needed.
                  `("LIBRARY_PATH" ":" prefix
                    ,(list (string-append #$output "/lib") ; Technically Souffle has no /lib
                           (string-append (assoc-ref inputs "gcc-toolchain") "/lib")
                           (string-append (assoc-ref inputs "zlib") "/lib")
                           (string-append (assoc-ref inputs "ncurses") "/lib")
                           (string-append (assoc-ref inputs "sqlite") "/lib")
                           (string-append (assoc-ref inputs "libffi") "/lib")
                           (string-append (assoc-ref inputs "libc") "/lib"))))
                ;; And now we must "wrap" souffle's compiler wrapper script's
                ;; internal JSON config file, so the invoked g++ can find
                ;; everything it needs.
                (with-directory-excursion #$output
                  (let ((includes (list (string-append #$output "/include")
                           (string-append (assoc-ref inputs "gcc-toolchain") "/include/c++")
                           (string-append (assoc-ref inputs "gcc-toolchain") "/include")
                           (string-append (assoc-ref inputs "zlib") "/include")
                           (string-append (assoc-ref inputs "ncurses") "/include")
                           (string-append (assoc-ref inputs "sqlite") "/include")
                           (string-append (assoc-ref inputs "libffi") "/include")
                           (string-append (assoc-ref inputs "libc") "/lib")
                           ;; Need an explicit path to <linux/errno.h>?
                           (string-append (assoc-ref inputs "kernel-headers") "/include")))
                        (libs (list (string-append (assoc-ref inputs "gcc-toolchain") "/lib")
                                    (string-append (assoc-ref inputs "zlib") "/lib")
                                    (string-append (assoc-ref inputs "ncurses") "/lib")
                                    (string-append (assoc-ref inputs "sqlite") "/lib")
                                    (string-append (assoc-ref inputs "libffi") "/lib")
                                    (string-append (assoc-ref inputs "libc") "/lib"))))
                    (substitute* "bin/souffle-compile.py"
                      ;; Make C++ includes work, and remove embedded build path
                      (("(\"includes\"): \"([[[[:alnum:] -_.]+)\"," all option prev-vals)
                       (string-append option ": \""
                                      (string-join includes " -I" 'prefix) " "
                                      "\","))
                      ;; C++ linking
                      (("(\"link_options\"): \"([[:alnum:] -_.]+)\"," all option prev-options)
                       (string-append option ": \""
                                      (string-join libs " -L" 'prefix) " "
                                      prev-options
                                      "\","))
                      ;; Remove embedded build path
                      (("(\"source_include_dir\"): \".*\"," all option)
                       (string-append option ": \"\","))))))))))
      ;; (native-search-paths
      ;;  (list (search-path-specification
      ;;         (variable "C_INCLUDE_PATH")
      ;;         (files '("include")))
      ;;        (search-path-specification
      ;;         (variable "CPLUS_INCLUDE_PATH")
      ;;         (files '("include")))
      ;;        (search-path-specification
      ;;         (variable "LIBRARY_PATH")
      ;;         (files '("lib")))))
      (home-page "https://souffle-lang.github.io")
      (synopsis "A compiler for a variant of Datalog for tool designers crafting
analyses in Horn clauses")
      (description
       "Souffle is a logic programming language inspired by Datalog.  It
overcomes some of the limitations in classical Datalog.  For example,
programmers are not restricted to finite domains, and the usage of functors
(intrinsic, user-defined, records/constructors, etc.) is permitted.  Souffle
has a component model so that large logic projects can be expressed.")
      (license license:upl1.0))))
