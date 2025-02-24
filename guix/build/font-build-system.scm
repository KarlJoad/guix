;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2017, 2022 Arun Isaac <arunisaac@systemreboot.net>
;;; Copyright © 2017 Alex Griffin <a@ajgrf.com>
;;; Copyright © 2024 宋文武 <iyzsong@envs.net>
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

(define-module (guix build font-build-system)
  #:use-module ((guix build gnu-build-system) #:prefix gnu:)
  #:use-module (guix build utils)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:export (%standard-phases
            %license-file-regexp
            font-build))

;; Commentary:
;;
;; Builder-side code of the build procedure for font packages.
;;
;; Code:

(define gnu:unpack (assoc-ref gnu:%standard-phases 'unpack))

(define* (unpack #:key source #:allow-other-keys)
  "Unpack SOURCE into the build directory.  SOURCE may be a compressed
archive, or a font file."
  (if (any (cut string-suffix? <> source)
           (list ".ttf" ".otf"))
      (begin
        (mkdir "source")
        (chdir "source")
        (copy-file source (strip-store-file-name source)))
      (gnu:unpack #:source source)))

(define* (install #:key outputs #:allow-other-keys)
  "Install the package contents."
  (let* ((out (assoc-ref outputs "out"))
         (source (getcwd))
         (truetype-dir (string-append (or (assoc-ref outputs "ttf") out)
                                      "/share/fonts/truetype"))
         (opentype-dir (string-append (or (assoc-ref outputs "otf") out)
                                      "/share/fonts/opentype"))
         (web-dir (string-append (or (assoc-ref outputs "woff") out)
                                 "/share/fonts/web"))
         (otb-dir (string-append (or (assoc-ref outputs "otb") out)
                                 "/share/fonts/misc"))
         (bdf-dir (string-append (or (assoc-ref outputs "bdf") out)
                                 "/share/fonts/misc"))
         (pcf-dir (string-append (or (assoc-ref outputs "pcf") out)
                                 "/share/fonts/misc"))
         (psf-dir (string-append (or (assoc-ref outputs "psf") out)
                                 "/share/consolefonts")))
    (for-each (cut install-file <> truetype-dir)
              (find-files source "\\.(ttf|ttc)$"))
    (for-each (cut install-file <> opentype-dir)
              (find-files source "\\.(otf|otc)$"))
    (for-each (cut install-file <> web-dir)
              (find-files source "\\.(woff|woff2)$"))
    (for-each (cut install-file <> otb-dir)
              (find-files source "\\.otb$"))
    (for-each (cut install-file <> bdf-dir)
              (find-files source "\\.bdf$"))
    (for-each (cut install-file <> pcf-dir)
              (find-files source "\\.pcf$"))
    (for-each (cut install-file <> psf-dir)
              (find-files source "\\.psfu$"))))

(define %license-file-regexp
  ;; Regexp matching license files commonly found in font packages.
  "^((COPY(ING|RIGHT)|LICEN[CS]E).*\
|(([Cc]opy[Rr]ight|[Ll]icen[cs]es?|IPA_.*|OFL(-?1\\.?1)?)(\\.(txt|md)?))$)")

(define %standard-phases
  (modify-phases gnu:%standard-phases
    (replace 'unpack unpack)
    (delete 'bootstrap)
    (delete 'configure)
    (delete 'check)
    (delete 'build)
    (replace 'install install)))

(define* (font-build #:key inputs (phases %standard-phases)
                      #:allow-other-keys #:rest args)
  "Build the given font package, applying all of PHASES in order."
  (apply gnu:gnu-build #:inputs inputs #:phases phases args))

;;; font-build-system.scm ends here
