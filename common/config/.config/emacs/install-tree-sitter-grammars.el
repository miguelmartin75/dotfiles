;; Provision native Tree-sitter grammars outside normal startup.  -*- lexical-binding: t; -*-
(require 'treesit)

(setq treesit-language-source-alist
      '((c "https://github.com/tree-sitter/tree-sitter-c.git"
           :commit "b780e47fc780ddc8da13afa35a3f4ed5c157823d")
        (cpp "https://github.com/tree-sitter/tree-sitter-cpp.git"
             :commit "8b5b49eb196bec7040441bee33b2c9a4838d6967")
        (rust "https://github.com/tree-sitter/tree-sitter-rust.git"
              :commit "77a3747266f4d621d0757825e6b11edcbf991ca5")
        (lua "https://github.com/tree-sitter-grammars/tree-sitter-lua.git"
             :commit "10fe0054734eec83049514ea2e718b2a56acd0c9")
        (python "https://github.com/tree-sitter/tree-sitter-python.git"
                :commit "26855eabccb19c6abf499fbc5b8dc7cc9ab8bc64")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript.git"
                    :source-dir "typescript/src"
                    :commit "75b3874edb2dc714fb1fd77a32013d0f8699989f")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript.git"
             :source-dir "tsx/src"
             :commit "75b3874edb2dc714fb1fd77a32013d0f8699989f")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript.git"
                    :commit "58404d8cf191d69f2674a8fd507bd5776f46cb11")
        (jsdoc "https://github.com/tree-sitter/tree-sitter-jsdoc.git"
               :commit "b253abf68a73217b7a52c0ec254f4b6a7bb86665")
        (zig "https://github.com/tree-sitter-grammars/tree-sitter-zig.git"
             :commit "6479aa13f32f701c383083d8b28360ebd682fb7d")
        (nim "https://github.com/alaviss/tree-sitter-nim.git"
             :commit "ac72ba30d16edf0be021588a9301ede4accd6cf4")
        (odin "https://github.com/tree-sitter-grammars/tree-sitter-odin.git"
              :commit "d2ca8efb4487e156a60d5bd6db2598b872629403")
        (markdown "https://github.com/tree-sitter-grammars/tree-sitter-markdown.git"
                  :source-dir "tree-sitter-markdown/src"
                  :commit "a0a00f817d02412bd92c54d316f164d827b57b5c")
        (markdown-inline "https://github.com/tree-sitter-grammars/tree-sitter-markdown.git"
                         :source-dir "tree-sitter-markdown-inline/src"
                         :commit "a0a00f817d02412bd92c54d316f164d827b57b5c")))

;; Requires Git, a C/C++ compiler, a linker, and network access.  Grammars are
;; installed under user-emacs-directory/tree-sitter and never during startup.
(let ((out-dir (locate-user-emacs-file "tree-sitter"))
      (extension (car dynamic-library-suffixes)))
  (unless extension
    (error "Emacs cannot determine the Tree-sitter library extension"))
  (make-directory out-dir t)

  (let ((staging-dir
         (make-temp-file (expand-file-name ".grammar-stage-" out-dir) t)))
    (unwind-protect
        (progn
          (let ((treesit-extra-load-path (list staging-dir)))
            (dolist (recipe treesit-language-source-alist)
              (let* ((language (car recipe))
                     (staged-library
                      (expand-file-name
                       (format "libtree-sitter-%s%s" language extension)
                       staging-dir))
                     (isolated-user-dir
                      (expand-file-name "isolated-user" staging-dir))
                     (function-name
                      (format "tree_sitter_%s"
                              (replace-regexp-in-string
                               "-" "_" (symbol-name language))))
                     (validation-form
                      (prin1-to-string
                       `(progn
                          (require 'treesit)
                          (setq user-emacs-directory ,isolated-user-dir
                                treesit-extra-load-path (list ,staging-dir)
                                treesit-load-name-override-list
                                '((,language
                                   ,(file-name-sans-extension staged-library)
                                   ,function-name)))
                          (unless (treesit-ready-p ',language t)
                            (kill-emacs 1))))))
                (treesit-install-language-grammar language staging-dir)
                (unless (file-exists-p staged-library)
                  (error "Staged Tree-sitter grammar is missing: %s" language))
                (let ((validation-buffer
                       (generate-new-buffer " *tree-sitter-validation*")))
                  (unwind-protect
                      (unless (zerop
                               (call-process
                                (expand-file-name invocation-name
                                                  invocation-directory)
                                nil validation-buffer nil
                                "-Q" "--batch" "--eval" validation-form))
                        (error "Staged Tree-sitter grammar failed validation: %s\n%s"
                               language
                               (with-current-buffer validation-buffer
                                 (buffer-string))))
                    (kill-buffer validation-buffer))))))

          (dolist (recipe treesit-language-source-alist)
            (let* ((language (car recipe))
                   (staged-library
                    (expand-file-name
                     (format "libtree-sitter-%s%s" language extension)
                     staging-dir))
                   (library (expand-file-name
                             (file-name-nondirectory staged-library)
                             out-dir))
                   (backup (concat library ".pre-install"))
                   had-library
                   swapped)
              (when (file-exists-p backup)
                (if (file-exists-p library)
                    (delete-file backup)
                  (rename-file backup library)))
              (setq had-library (file-exists-p library))
              (when had-library
                (copy-file library backup))
              (unwind-protect
                  (progn
                    (rename-file staged-library library t)
                    (unless (file-exists-p library)
                      (error "Tree-sitter grammar swap failed: %s" language))
                    (setq swapped t))
                (cond
                 (swapped
                  (when had-library
                    (delete-file backup)))
                 (had-library
                  (rename-file backup library t)))))))
      (delete-directory staging-dir t))))

(princ "TREE_SITTER_GRAMMARS_INSTALLED\n")
