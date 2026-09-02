;;; markdown-parity-test.el --- Markdown parity behavior tests -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)

(load (expand-file-name "init.el" (file-name-directory (or load-file-name buffer-file-name)))
      nil nil nil t)
(require 'markdown-ts-mode)

(defun my/markdown-test-before-p (text first second)
  "Return non-nil when FIRST appears before SECOND in TEXT."
  (let ((first-position (string-match (regexp-quote first) text))
        (second-position (string-match (regexp-quote second) text)))
    (and first-position second-position (< first-position second-position))))

(defun my/markdown-test-return-result (mode text point-text &optional include-points)
  "Return the effective RET command and resulting text in MODE.
Point is placed immediately after POINT-TEXT before invoking the command.
When INCLUDE-POINTS is non-nil, also return its positions before and after RET
and whether it ends at the beginning of a line."
  (with-temp-buffer
    (insert text)
    (funcall mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (search-forward point-text)
    (evil-insert-state)
    (let ((before (point))
          (command (key-binding (kbd "RET"))))
      (call-interactively command)
      (if include-points
          (list command
                (buffer-substring-no-properties (point-min) (point-max))
                before
                (point)
                (bolp))
        (cons command
              (buffer-substring-no-properties (point-min) (point-max)))))))

(defun my/markdown-test-assert-boundary-unchanged
    (mode text point-text mark-text command &optional metadata)
  "Assert COMMAND rejects a Markdown boundary without changing buffer state."
  (with-temp-buffer
    (let ((before-text (if metadata "" "outside top\n")))
      (insert before-text text "outside bottom\n")
      (funcall mode)
      (font-lock-ensure)
      (when metadata
        (if (eq mode 'markdown-ts-mode)
            (should (equal (treesit-node-type
                            (treesit-node-child (treesit-buffer-root-node) 0 t))
                           "minus_metadata"))
          (should (get-text-property (point-min) 'markdown-yaml-metadata-begin))))
      (goto-char (+ (point-min) (length before-text)))
      (narrow-to-region (point) (- (point-max) (length "outside bottom\n")))
      (goto-char (point-min))
      (search-forward mark-text)
      (set-mark (point))
      (goto-char (point-min))
      (search-forward point-text)
      (setq-local transient-mark-mode t)
      (setq mark-active t)
      (let ((before
             (list (save-restriction
                     (widen)
                     (buffer-substring-no-properties (point-min) (point-max)))
                   (point) (mark) mark-active (point-min) (point-max))))
        (should-error (funcall command) :type 'user-error)
        (should
         (equal before
                (list (save-restriction
                        (widen)
                        (buffer-substring-no-properties (point-min) (point-max)))
                      (point) (mark) mark-active (point-min) (point-max))))))))

(ert-deftest my/markdown-parity-list-return-behavior ()
  (dolist (mode '(org-mode markdown-ts-mode markdown-mode))
    (let ((expected-command
           (cond
            ((eq mode 'org-mode) #'my/org-return)
            ((eq mode 'markdown-ts-mode) #'my/markdown-ts-return)
            (t #'my/markdown-return))))
      (should (eq (car (my/markdown-test-return-result mode "- item\n" "item"))
                  expected-command)))
    (should (equal (cdr (my/markdown-test-return-result mode "- item\n" "item"))
                   "- item\n- \n"))
    (should
     (equal
      (cdr (my/markdown-test-return-result mode "- before after\n" "before"))
      (if (eq mode 'markdown-mode)
          "- before\n-  after\n"
        "- before\n- after\n")))
    (should
     (equal
      (cdr (my/markdown-test-return-result
            mode "- first\n  before after\n" "before"))
      (if (eq mode 'markdown-mode)
          "- first\n  before\n-  after\n"
        "- first\n  before\n- after\n")))
    (should (equal (cdr (my/markdown-test-return-result mode "1. item\n" "item"))
                   "1. item\n2. \n"))
    (dolist (checkbox '("[ ]" "[X]"))
      (let ((heading (if (eq mode 'org-mode) "* Head\n" "# Head\n")))
        (should
         (equal
          (cdr (my/markdown-test-return-result
                mode (concat heading "- " checkbox " item\n") "item"))
          (concat heading "- " checkbox " item\n- [ ] \n")))))
    (should (equal (cdr (my/markdown-test-return-result mode "prose\n" "prose"))
                   "prose\n\n"))
    (dolist (fixture '(("- b\n" . "- b\n\n")
                       ("- b\n\n" . "- b\n\n\n")))
      (let ((result (my/markdown-test-return-result mode (car fixture) "\n" t)))
        (should (equal (nth 1 result) (cdr fixture)))
        (should (= (nth 3 result) (1+ (nth 2 result))))
        (should (nth 4 result))))
    (when (not (eq mode 'markdown-ts-mode))
      (let* ((table (if (eq mode 'org-mode)
                        "| a | b |\n|---+---|\n| c | d |\n"
                      "| a | b |\n|---|---|\n| c | d |\n"))
           (expected
              (if (eq mode 'org-mode)
                  "| a | b |\n|---+---|\n| c | d |\n|   |   |\n"
                "| a | b |\n|---|---|\n| c | d |\n|   |   |\n")))
        (should (equal (cdr (my/markdown-test-return-result mode table "d"))
                       expected))))
    (dolist (marker '("- " "1. " "- [ ] "))
      (let* ((text (if (and (eq mode 'org-mode)
                            (equal marker "- [ ] "))
                       (concat "* Head\n" marker "\n")
                     (concat marker "\n")))
             (expected (if (and (eq mode 'org-mode)
                                (equal marker "- [ ] "))
                           "* Head\n"
                         "")))
        (should (equal (cdr (my/markdown-test-return-result mode text marker))
                       expected))))
    (dolist (marker '("- " "1. " "- [ ] "))
      (should (equal (cdr (my/markdown-test-return-result mode marker marker))
                     "")))
    (should (equal (cdr (my/markdown-test-return-result
                         mode "- item\n- \n" "item\n- "))
                   "- item\n"))
    (should (equal (cdr (my/markdown-test-return-result mode "  - \n" "- "))
                   ""))
    (let ((result (cdr (my/markdown-test-return-result
                        mode "- \n  - child\n" "- "))))
      (should (equal result
                     (if (eq mode 'markdown-ts-mode)
                         "-\n- \n  - child\n"
                       "- \n- \n  - child\n")))))
  (should
   (equal (cdr (my/markdown-test-return-result
                'org-mode "- term :: \n" "term :: "))
          "- term ::\n-  :: \n"))
  (with-temp-buffer
    (insert "| a | b |\n|---|---|\n| c | d |\n| e | f |\n")
    (markdown-ts-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (search-forward "c")
    (evil-insert-state)
    (markdown-ts-in-table-mode 1)
    (should (eq (key-binding (kbd "RET")) #'my/markdown-ts-return))
    (should (eq (key-binding (kbd "<return>")) #'markdown-ts-table-next-row))
    (call-interactively (key-binding (kbd "<return>")))
    (should (equal (thing-at-point 'line t) "| e | f |\n")))
  (with-temp-buffer
    (insert "```sh\necho body\n```\n")
    (markdown-ts-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (search-forward "body")
    (evil-insert-state)
    (run-hooks 'post-command-hook)
    (should markdown-ts-code-block-in-context-mode)
    (should (eq (key-binding (kbd "RET")) #'markdown-ts--code-block-newline))
    (call-interactively (key-binding (kbd "RET")))
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "```sh\necho body\n\n```\n")))
  (with-temp-buffer
    (insert "    - \n")
    (markdown-ts-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (end-of-line)
    (evil-insert-state)
    (should (eq (key-binding (kbd "RET")) #'my/markdown-ts-return))
    (call-interactively (key-binding (kbd "RET")))
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "    - \n\n")))
  (dolist (fixture '(("---\n- \n---\n" . "---\n- \n\n---\n")
                     ("<div>\n- \n</div>\n" . "<div>\n- \n\n</div>\n")))
    (with-temp-buffer
      (insert (car fixture))
      (markdown-ts-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (forward-line 1)
      (end-of-line)
      (evil-insert-state)
      (should (eq (key-binding (kbd "RET")) #'my/markdown-ts-return))
      (call-interactively (key-binding (kbd "RET")))
      (should (equal (buffer-substring-no-properties (point-min) (point-max))
                     (cdr fixture))))))

(ert-deftest my/markdown-parity-structural-behavior ()
  (dolist (mode '(markdown-ts-mode markdown-mode))
    (with-temp-buffer
      (insert "# first\nfirst body\n## first child\nchild body\n\n# second\nsecond body\n")
      (funcall mode)
      (goto-char (point-min))
      (search-forward "# second")
      (beginning-of-line)
      (my/markdown-move-up)
      (should (my/markdown-test-before-p (buffer-string) "# second" "# first"))
      (should (my/markdown-test-before-p (buffer-string) "second body" "# first"))
      (should (my/markdown-test-before-p (buffer-string) "# first" "## first child"))
      (should (my/markdown-test-before-p (buffer-string) "## first child" "child body"))
      (my/markdown-move-down)
      (should (my/markdown-test-before-p (buffer-string) "# first" "# second"))
      (goto-char (point-min))
      (my/markdown-demote)
      (should (string-match-p "^## first\n" (buffer-string)))
      (my/markdown-promote)
      (should (string-match-p "^# first\n" (buffer-string))))
    (with-temp-buffer
      (insert "- first\n  first continuation\n  - first child\n- second\n  second continuation\n")
      (funcall mode)
      (goto-char (point-min))
      (search-forward "first")
      (my/markdown-move-down)
      (should (my/markdown-test-before-p (buffer-string) "- second" "- first"))
      (should (my/markdown-test-before-p (buffer-string) "second continuation" "- first"))
      (should (my/markdown-test-before-p (buffer-string) "- first" "first child"))
      (goto-char (point-min))
      (search-forward "first continuation")
      (my/markdown-move-up)
      (should (my/markdown-test-before-p (buffer-string) "- first" "- second")))
    (with-temp-buffer
      (insert "- parent\n- child\n")
      (funcall mode)
      (goto-char (point-min))
      (search-forward "child")
      (beginning-of-line)
      (my/markdown-demote)
      (should (string-match-p "^[ \t]+- child" (buffer-string)))
      (my/markdown-promote)
      (should-not (string-match-p "^[ \t]+- child" (buffer-string))))
    (with-temp-buffer
      (insert "| First | Second |\n| ----- | ------ |\n| one | two |\n| three | four |\n")
      (funcall mode)
      (goto-char (point-min))
      (search-forward "one")
      (search-backward "one")
      (my/markdown-move-down)
      (should (my/markdown-test-before-p (buffer-string) "three" "one"))
      (goto-char (point-min))
      (search-forward "one")
      (search-backward "one")
      (my/markdown-move-up)
      (should (my/markdown-test-before-p (buffer-string) "one" "three"))
      (goto-char (point-min))
      (search-forward "one")
      (search-backward "one")
      (my/markdown-demote)
      (should (my/markdown-test-before-p (buffer-string) "Second" "First"))
      (goto-char (point-min))
      (search-forward "one")
      (search-backward "one")
      (my/markdown-promote)
      (should (my/markdown-test-before-p (buffer-string) "First" "Second")))
    (with-temp-buffer
      (let ((original
             "# section\nfirst line\nfirst column\n\n   \n\t \nsecond line\nsecond column\n"))
        (insert original)
        (funcall mode)
        (goto-char (point-min))
        (search-forward "second line")
        (set-mark (point))
        (search-forward "second column")
        (backward-char 3)
        (let ((column (current-column)))
          (setq-local transient-mark-mode t)
          (setq mark-active t)
          (my/markdown-move-up)
          (should (equal (buffer-substring-no-properties (point-min) (point-max))
                         "# section\nsecond line\nsecond column\n\n   \n\t \nfirst line\nfirst column\n"))
          (should (= (current-column) column))
          (should (equal (thing-at-point 'line t) "second column\n"))
          (should (region-active-p))
          (should (equal (save-excursion
                           (goto-char (mark))
                           (thing-at-point 'line t))
                         "second line\n"))
          (deactivate-mark)
          (my/markdown-move-down)
          (should (equal (buffer-substring-no-properties (point-min) (point-max))
                         original)))))))

(ert-deftest my/markdown-parity-structural-boundaries ()
  (dolist (mode '(markdown-ts-mode markdown-mode))
    (dolist (fixture
             '(("section start" "# section\ncurrent prose\n"
                "current prose" "current prose" my/markdown-move-up)
               ("section end" "# section\ncurrent prose\n"
                "current prose" "current prose" my/markdown-move-down)
               ("heading" "# first\ncurrent prose\n\n# second\nother prose\n"
                "current prose" "current prose" my/markdown-move-down)
               ("list" "current prose\n\n- item\n"
                "current prose" "current prose" my/markdown-move-down)
               ("table" "current prose\n\n| a | b |\n|---|---|\n| c | d |\n"
                "current prose" "current prose" my/markdown-move-down)
               ("raw HTML block" "current prose\n\n<div>block</div>\n"
                "current prose" "current prose" my/markdown-move-down)
               ("raw HTML block current context" "<div>block</div>\n\ncurrent prose\n"
                "<div>block</div>" "<div>block</div>" my/markdown-move-down)
               ("reference definition" "current prose\n\n[ref]: https://example.com\n"
                "current prose" "current prose" my/markdown-move-down)
               ("reference definition current context"
                "[ref]: https://example.com\n\ncurrent prose\n"
                "[ref]: https://example.com" "[ref]: https://example.com"
                my/markdown-move-down)
               ("block quote" "current prose\n\n> quote\n"
                "current prose" "current prose" my/markdown-move-down)
               ("metadata" "---\ntitle: metadata\n---\n\ncurrent prose\n"
                "current prose" "current prose" my/markdown-move-up t)
               ("thematic break" "current prose\n\n***\n"
                "current prose" "current prose" my/markdown-move-down)
               ("fenced code" "current prose\n\n```sh\ncode\n```\n"
                "current prose" "current prose" my/markdown-move-down)
               ("indented code" "current prose\n\n    code\n"
                "current prose" "current prose" my/markdown-move-down)
               ("spanning selection" "first prose\n\ncurrent prose\n"
                "current prose" "first prose" my/markdown-move-up)))
      (my/markdown-test-assert-boundary-unchanged
       mode (nth 1 fixture) (nth 2 fixture) (nth 3 fixture) (nth 4 fixture)
       (nth 5 fixture)))))

(ert-deftest my/markdown-parity-access-and-binding-scope ()
  (let (normal-tab normal-control-i)
    (with-temp-buffer
      (evil-normal-state)
      (setq normal-tab (key-binding (kbd "TAB"))
            normal-control-i (key-binding (kbd "C-i"))))
    (dolist (mode '(markdown-ts-mode markdown-mode))
      (with-temp-buffer
        (funcall mode)
        (dolist (state '(evil-normal-state evil-visual-state))
          (funcall state)
          (dolist (binding '(("M-h" . my/markdown-promote)
                             ("M-j" . my/markdown-move-down)
                             ("M-k" . my/markdown-move-up)
                             ("M-l" . my/markdown-demote)
                             ("g TAB" . my/markdown-cycle)
                             ("g <tab>" . my/markdown-cycle)
                             ("g S-TAB" . my/markdown-cycle-buffer)
                             ("g <backtab>" . my/markdown-cycle-buffer)
                             ("C-x n s" . my/markdown-narrow-to-subtree)
                             ("SPC o m" . my/markdown-align-table)
                             ("SPC o RET" . my/send-markdown-fenced-code-to-last-target)
                             ("SPC t b" . my/send-markdown-fenced-code-to-last-target)
                             ("SPC t B" . my/send-markdown-fenced-code-to-target)))
            (should (eq (key-binding (kbd (car binding))) (cdr binding)))))
        (evil-normal-state)
        (should (eq (key-binding (kbd "TAB")) normal-tab))
        (should (eq (key-binding (kbd "C-i")) normal-control-i)))
      (with-temp-buffer
        (insert "# first\nbody\n## child\nchild body\n# second\nsecond body\n")
        (funcall mode)
        (evil-normal-state)
        (goto-char (point-min))
        (search-forward "body")
        (call-interactively (key-binding (kbd "g TAB")))
        (forward-line 1)
        (should (outline-invisible-p (point)))
        (outline-show-all)
        (goto-char (point-min))
        (search-forward "child body")
        (call-interactively (key-binding (kbd "C-x n s")))
        (should (buffer-narrowed-p))
        (should-not (string-match-p "# second" (buffer-string)))
        (widen)
        (should (string-match-p "# second" (buffer-string))))
      (with-temp-buffer
        (insert "|First|Second|\n|---|---|\n|one|two|\n|three|four|\n")
        (funcall mode)
        (evil-normal-state)
        (goto-char (point-min))
        (search-forward "one")
        (search-backward "one")
        (when (eq mode 'markdown-ts-mode)
          (markdown-ts-in-table-mode 1))
        (should (eq (key-binding (kbd "TAB")) #'evil-jump-forward))
        (should (eq (key-binding (kbd "C-i")) #'evil-jump-forward))
        (should (eq (key-binding (kbd "<tab>")) #'evil-jump-forward))
        (let ((start (point)))
          (call-interactively (key-binding (kbd "g TAB")))
          (should (/= start (point))))
        (goto-char (point-min))
        (search-forward "one")
        (search-backward "one")
        (let ((start (point)))
          (call-interactively (key-binding (kbd "g S-TAB")))
          (should (/= start (point))))
        (goto-char (point-min))
        (search-forward "one")
        (search-backward "one")
        (let ((start (point)))
          (call-interactively (key-binding (kbd "g <tab>")))
          (should (/= start (point))))
        (goto-char (point-min))
        (search-forward "one")
        (search-backward "one")
        (let ((start (point)))
          (call-interactively (key-binding (kbd "g <backtab>")))
          (should (/= start (point))))
        (let ((command (if (eq mode 'markdown-ts-mode)
                           'markdown-ts-table-align-table
                         'markdown-table-align))
              called)
          (cl-letf (((symbol-function command)
                     (lambda () (interactive) (setq called t))))
            (call-interactively (key-binding (kbd "SPC o m"))))
          (should called)))
      (with-temp-buffer
        (insert "# not a table\n")
        (funcall mode)
        (should-error (my/markdown-align-table) :type 'user-error))))
  (with-temp-buffer
    (org-mode)
    (evil-normal-state)
    (should (eq (key-binding (kbd "SPC o RET")) #'org-babel-execute-src-block))
    (should (eq (key-binding (kbd "SPC t R")) #'my/send-region-or-buffer)))
  (with-temp-buffer
    (evil-visual-state)
    (should (eq (key-binding (kbd "C-c C-c")) #'my/send-region-or-buffer))
    (should (eq (key-binding (kbd "C-c C-r"))
                #'my/send-region-or-buffer-to-last-target))))

(ert-deftest my/markdown-parity-fenced-code-extraction-and-delivery ()
  (dolist (mode '(markdown-ts-mode markdown-mode))
    (dolist (fixture '(("```python title\nprint(1)\nprint(2)\n```\n"
                        . "print(1)\nprint(2)\n")
                       ("~~~sh\necho tilde\n~~~\n" . "echo tilde\n")
                       ("```sh\n```\n" . "")
                       ("~~~\n~~~\n" . "")))
      (with-temp-buffer
        (insert (car fixture))
        (funcall mode)
        (goto-char (point-min))
        (unless (string-empty-p (cdr fixture))
          (forward-line 1))
        (should (equal (my/markdown-fenced-code-body) (cdr fixture)))))
    (dolist (fixture '("plain text\n"
                       "---\ntitle: metadata\n---\n"
                       "```python\nprint(1)\n"))
      (with-temp-buffer
        (insert fixture)
        (funcall mode)
        (should-error (my/markdown-fenced-code-body) :type 'user-error)))
    (with-temp-buffer
      (insert "```sh\necho sent\n```\n")
      (funcall mode)
      (goto-char (point-min))
      (forward-line 1)
      (let (replayed chosen)
        (cl-letf (((symbol-function 'my/send-text-send-to-last-target)
                   (lambda (text) (setq replayed text)))
                  ((symbol-function 'my/send-text-to-target)
                   (lambda (text) (setq chosen text))))
          (my/send-markdown-fenced-code-to-last-target)
          (my/send-markdown-fenced-code-to-target))
        (should (equal replayed "echo sent\n"))
        (should (equal chosen "echo sent\n"))))))

;;; markdown-parity-test.el ends here
