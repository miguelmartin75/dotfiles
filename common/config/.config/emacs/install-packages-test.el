;; Focused behavior tests for reviewed completion package provisioning.  -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'ert)

(defvar my/install-packages-run-entrypoint)

(let ((my/install-packages-run-entrypoint nil))
  (load (expand-file-name "install-packages.el"
                          (file-name-directory load-file-name))
        nil nil t))

(defun my/install-packages-test-valid-descriptors ()
  "Return reviewed VC descriptors for every direct completion package."
  (mapcar (lambda (entry)
            (cons (car entry) (list (list 'vc (nth 2 entry)))))
          my/reviewed-completion-vc-packages))

(defun my/install-packages-test-run (descriptors install-missing)
  "Run provisioning against DESCRIPTORS without package-network operations."
  (let ((package-alist descriptors)
        (installs nil)
        condition
        output)
    (cl-letf (((symbol-function 'package-vc-p)
               (lambda (descriptor)
                 (eq (car descriptor) 'vc)))
              ((symbol-function 'package-vc-commit)
               (lambda (descriptor)
                 (nth 1 descriptor)))
              ((symbol-function 'package-vc-install)
               (lambda (spec revision)
                 (push (list spec revision) installs)
                 (when install-missing
                   (setf (alist-get (car spec) package-alist)
                         (list (list 'vc revision))))))
              ((symbol-function 'package-get-descriptor)
               (lambda (_name _sources &optional _predicate)
                 nil)))
      (with-temp-buffer
        (let ((standard-output (current-buffer)))
          (condition-case err
              (my/provision-reviewed-completion-vc-packages)
            (error
             (setq condition err)))
          (setq output (buffer-string)))))
    (list :condition condition
          :installs (nreverse installs)
          :output output)))

(ert-deftest my/install-packages-reviewed-completion-vc-valid ()
  (let ((result
         (my/install-packages-test-run
          (my/install-packages-test-valid-descriptors) nil)))
    (should-not (plist-get result :condition))
    (should-not (plist-get result :installs))
    (dolist (entry my/reviewed-completion-vc-packages)
      (should (string-match-p
               (regexp-quote
                (format "PACKAGE_VC_ACCEPTED %s %s"
                        (car entry) (nth 2 entry)))
               (plist-get result :output))))))

(ert-deftest my/install-packages-reviewed-completion-vc-missing ()
  (let ((descriptors (my/install-packages-test-valid-descriptors)))
    (setf (alist-get 'ivy descriptors) nil)
    (let* ((result (my/install-packages-test-run descriptors nil))
           (message (error-message-string (plist-get result :condition))))
      (should (plist-get result :condition))
      (should (string-match-p "ivy: missing after package-vc-install" message))
      (should (equal (mapcar (lambda (install) (car (car install)))
                             (plist-get result :installs))
                     '(ivy))))))

(ert-deftest my/install-packages-reviewed-completion-vc-archive-only-attempts-install ()
  (let ((descriptors (my/install-packages-test-valid-descriptors)))
    (setf (alist-get 'consult descriptors) '((archive)))
    (let* ((result (my/install-packages-test-run descriptors nil))
           (message (error-message-string (plist-get result :condition))))
      (should (plist-get result :condition))
      (should (string-match-p
               "consult: archive-only after package-vc-install" message))
      (should (equal (mapcar (lambda (install) (car (car install)))
                             (plist-get result :installs))
                     '(consult))))))

(ert-deftest my/install-packages-reviewed-completion-vc-accepts-archive-with-exact-vc ()
  (let ((descriptors (my/install-packages-test-valid-descriptors)))
    (setf (alist-get 'ivy descriptors)
          `((vc ,(nth 2 (assq 'ivy my/reviewed-completion-vc-packages)))
            (archive)))
    (let ((result (my/install-packages-test-run descriptors nil)))
      (should-not (plist-get result :condition))
      (should-not (plist-get result :installs)))))

(ert-deftest my/install-packages-reviewed-completion-vc-mismatch ()
  (let ((descriptors (my/install-packages-test-valid-descriptors)))
    (setf (alist-get 'embark descriptors) '((vc "unreviewed")))
    (let* ((result (my/install-packages-test-run descriptors nil))
           (message (error-message-string (plist-get result :condition))))
      (should (plist-get result :condition))
      (should (string-match-p "embark: VC revision unreviewed" message))
      (should-not (plist-get result :installs)))))

(ert-deftest my/install-packages-reviewed-completion-vc-conflicting-revisions ()
  (let ((descriptors (my/install-packages-test-valid-descriptors)))
    (setf (alist-get 'embark descriptors)
          `((vc ,(nth 2 (assq 'embark my/reviewed-completion-vc-packages)))
            (vc "unreviewed")))
    (let* ((result (my/install-packages-test-run descriptors nil))
           (message (error-message-string (plist-get result :condition))))
      (should (plist-get result :condition))
      (should (string-match-p "embark: conflicting VC revisions" message))
      (should-not (plist-get result :installs)))))

(ert-deftest my/install-packages-reviewed-completion-vc-installs-missing ()
  (let ((descriptors (my/install-packages-test-valid-descriptors)))
    (setf (alist-get 'embark-consult descriptors) nil)
    (let* ((result (my/install-packages-test-run descriptors t))
           (install (car (plist-get result :installs))))
      (should-not (plist-get result :condition))
      (should (equal (car install)
                     '(embark-consult
                       :url "https://github.com/oantolin/embark.git")))
      (should (equal (nth 1 install)
                     "87e53827cf6659dcc4ac4e54be9af34aeca44f6e")))))
