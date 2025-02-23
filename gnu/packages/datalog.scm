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
       (list git-minimal ncurses doxygen))
      (inputs
       (list bison flex libffi
             gcc-toolchain
             graphviz-minimal
             mcpp
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
            (add-after 'install 'wrap-programs
              (lambda* (#:key inputs #:allow-other-keys)
                (wrap-program (string-append #$output "/bin/souffle")
                  `("PATH" ":" prefix
                    ;; Souffle has a "build system" that will run the souffle
                    ;; compiler to produce a C++ program and then run g++ to
                    ;; build the final binary.
                    ,(list (string-append (assoc-ref inputs "gcc") "/bin")
                           (string-append (assoc-ref inputs "mcpp") "/bin")
                           (string-append (assoc-ref inputs "python-minimal") "/bin")))
                  `("C_INCLUDE_PATH" ":" prefix
                    ,(list (string-append (assoc-ref inputs "gcc-toolchain") "/include")
                           ;; Need access to things like errno.h
                           (string-append (assoc-ref inputs "libc") "/include")))
                  `("CPLUS_INCLUDE_PATH" ":" prefix
                    ;; Souffle needs to know where its own headers are.
                    ,(list (string-append #$output "/include")
                           (string-append (assoc-ref inputs "gcc-toolchain") "/include")
                           ;; Need access to things like errno.h
                           (string-append (assoc-ref inputs "libc") "/include")
                           ;; Also need linux/errno.h
                           (string-append (assoc-ref inputs "kernel-headers") "/include")))))))))
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
