;; Provision packages outside normal Emacs startup.  -*- lexical-binding: t; -*-
(require 'package)
(require 'package-vc)
(require 'seq)

(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)

(let* ((vc-packages
        '((ghostel
           (:url "https://github.com/dakra/ghostel.git")
           "7c4cbd9f487b545c3d0452ab749f65eaa3c18b7e")
          (term-sessions
           (:url "https://github.com/ArthurHeymans/emacs-term-sessions.git")
           "0815dbea006128df1d61e9d29e5a8ada53b349c1")
          (odin-mode
           (:url "https://github.com/mattt-b/odin-mode.git")
           "21c6ff8b49f5eaa2d3b9969feeb08de921f11e92")))
       (vc-packages
        (if (executable-find "difft")
            (append
             vc-packages
             '((difftastic
                (:url "https://github.com/pkryger/difftastic.el.git")
                "f94076985ba46bf629abc9615c9b1fefcc3390ef")))
          vc-packages))
       (package-vc-selected-packages
        (mapcar (lambda (entry)
                  (cons (car entry) (cadr entry)))
                vc-packages))
       (custom-state-file (make-temp-file "emacs-package-custom-" nil ".el"))
       (custom-file custom-state-file))
  (unwind-protect
      (progn
        (let ((missing-packages
               (seq-remove #'package-installed-p
                           '(dape php-mode yasnippet))))
          (when missing-packages
            (package-refresh-contents))
          (dolist (package missing-packages)
            (package-install package)))

        (dolist (entry vc-packages)
          (let* ((name (car entry))
                 (spec (cadr entry))
                 (revision (caddr entry))
                 (installed (package-get-descriptor name 'installed
                                                    #'package-vc-p)))
            (if installed
                (unless (equal (package-vc-commit installed) revision)
                  (error "%s is installed at %s instead of reviewed revision %s"
                         name (package-vc-commit installed) revision))
              (package-vc-install (cons name spec) revision))

            (setq installed
                  (package-get-descriptor name 'installed #'package-vc-p))
            (unless (and installed
                         (equal (package-vc-commit installed) revision))
              (error "%s was not installed at reviewed revision %s"
                     name revision))))

        (princ "PACKAGES_INSTALLED\n"))
    (delete-file custom-state-file)))
