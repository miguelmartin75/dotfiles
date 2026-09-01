;;; mig-one-light-theme.el --- Compact One Light theme -*- lexical-binding: t; -*-

;; This theme is derived from Doom One Light at:
;; https://github.com/doomemacs/themes/tree/556598955c67540eac8811835b327f299ffb58c7
;; Source revision: 556598955c67540eac8811835b327f299ffb58c7
;; Doom One Light was ported by ztlevi from Atom One Light.
;; Copyright (c) 2016-2024 Henrik Lissner.
;;
;; The MIT License (MIT)
;;
;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; "Software"), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
;; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
;; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
;; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

;;; Commentary:

;; A standalone subset of Doom One Light for the workflows retained by this
;; Emacs configuration.  Package faces inherit from stable core faces wherever
;; that keeps the theme small.  Pale Git backgrounds and direct heading colors
;; intentionally replace Doom's runtime color blending and Org helper macros.
;; Direct RGB colors are kept compact and exact on graphical and true-color
;; terminals; lower-color terminals intentionally use Emacs's nearest-color
;; approximation instead of tripling every face with 256- and 16-color specs.

;;; Code:

(deftheme mig-one-light
  "A compact light theme derived from Doom One Light.")

(custom-theme-set-faces
 'mig-one-light

 ;; Core and syntax.
 '(default ((t (:background "#fafafa" :foreground "#383a42"))))
 '(bold ((t (:weight bold))))
 '(bold-italic ((t (:inherit (bold italic)))))
 '(italic ((t (:slant italic))))
 '(cursor ((t (:background "#4078f2"))))
 '(fringe ((t (:inherit default :foreground "#9ca0a4"))))
 '(region ((t (:background "#d8d8d8" :distant-foreground "#2c2e34" :extend t))))
 '(highlight ((t (:background "#4078f2" :foreground "#f0f0f0"))))
 '(secondary-selection ((t (:background "#9ca0a4" :extend t))))
 '(shadow ((t (:foreground "#9ca0a4"))))
 '(minibuffer-prompt ((t (:foreground "#4078f2" :weight bold))))
 '(tooltip ((t (:background "#e7e7e7" :foreground "#383a42"))))
 '(link ((t (:foreground "#4078f2" :underline t :weight bold))))
 '(link-visited ((t (:inherit link :foreground "#a626a4"))))
 '(error ((t (:foreground "#e45649"))))
 '(warning ((t (:foreground "#986801"))))
 '(success ((t (:foreground "#50a14f"))))
 '(escape-glyph ((t (:foreground "#0184bc"))))
 '(trailing-whitespace ((t (:background "#e45649"))))
 '(vertical-border ((t (:background "#c6c7c7" :foreground "#c6c7c7"))))
 '(match ((t (:background "#f0f0f0" :foreground "#50a14f" :weight bold))))
 '(lazy-highlight ((t (:background "#c2d3f7" :foreground "#f0f0f0" :distant-foreground "#1b2229"))))
 '(isearch ((t (:inherit lazy-highlight :weight bold))))
 '(isearch-fail ((t (:background "#e45649" :foreground "#f0f0f0" :weight bold))))
 '(show-paren-match ((t (:background "#f0f0f0" :foreground "#e45649" :weight ultra-bold))))
 '(show-paren-mismatch ((t (:background "#e45649" :foreground "#f0f0f0" :weight ultra-bold))))
 '(font-lock-builtin-face ((t (:foreground "#a626a4"))))
 '(font-lock-comment-face ((t (:foreground "#9ca0a4"))))
 '(font-lock-comment-delimiter-face ((t (:inherit font-lock-comment-face))))
 '(font-lock-doc-face ((t (:inherit font-lock-comment-face :foreground "#84888b" :slant italic))))
 '(font-lock-constant-face ((t (:foreground "#b751b6"))))
 '(font-lock-function-name-face ((t (:foreground "#a626a4"))))
 '(font-lock-keyword-face ((t (:foreground "#e45649"))))
 '(font-lock-number-face ((t (:foreground "#da8548"))))
 '(font-lock-preprocessor-face ((t (:foreground "#4078f2" :weight bold))))
 '(font-lock-string-face ((t (:foreground "#50a14f"))))
 '(font-lock-type-face ((t (:foreground "#986801"))))
 '(font-lock-variable-name-face ((t (:foreground "#6a1868"))))
 '(font-lock-warning-face ((t (:inherit warning))))
 '(line-number ((t (:inherit default :foreground "#aaaeb1" :distant-foreground unspecified
                   :weight normal :slant unspecified :underline unspecified
                   :strike-through unspecified))))
 '(line-number-current-line
   ((t (:inherit (hl-line default) :foreground "#1b2229" :distant-foreground unspecified
        :weight normal :slant unspecified :underline unspecified
        :strike-through unspecified))))
 '(hl-line ((t (:background "#f0f0f0" :extend t))))

 ;; Selection and frame chrome.
 '(icomplete-first-match ((t (:foreground "#4078f2" :weight bold))))
 '(icomplete-selected-match ((t (:background "#dfdfdf" :foreground "#383a42"))))
 '(completions-common-part ((t (:foreground "#4078f2" :weight bold))))
 '(completions-first-difference ((t (:foreground "#e45649"))))
 '(xref-file-header ((t (:inherit success))))
 '(xref-line-number ((t (:foreground "#4078f2"))))
 '(xref-match ((t (:background "#f0f0f0" :foreground "#50a14f" :weight bold))))
 '(mode-line ((t (:background "#e7e7e7" :foreground "#383a42"))))
 '(mode-line-active ((t (:inherit mode-line))))
 '(mode-line-inactive ((t (:background "#e1e1e1" :foreground "#a190a7"))))
 '(mode-line-emphasis ((t (:foreground "#4078f2"))))
 '(mode-line-highlight ((t (:inherit highlight))))
 '(mode-line-buffer-id ((t (:weight bold))))
 '(header-line ((t (:inherit mode-line))))
 '(tab-bar ((t (:background "#f0f0f0" :foreground "#f0f0f0"))))
 '(tab-bar-tab ((t (:background "#fafafa" :foreground "#383a42"))))
 '(tab-bar-tab-inactive ((t (:background "#f0f0f0" :foreground "#9ca0a4"))))

 ;; Terminal, compilation, diagnostics, and diffs.
 '(ansi-color-black ((t (:foreground "#fafafa" :background "#fafafa"))))
 '(ansi-color-red ((t (:foreground "#e45649" :background "#e45649"))))
 '(ansi-color-green ((t (:foreground "#50a14f" :background "#50a14f"))))
 '(ansi-color-yellow ((t (:foreground "#986801" :background "#986801"))))
 '(ansi-color-blue ((t (:foreground "#4078f2" :background "#4078f2"))))
 '(ansi-color-magenta ((t (:foreground "#a626a4" :background "#a626a4"))))
 '(ansi-color-cyan ((t (:foreground "#0184bc" :background "#0184bc"))))
 '(ansi-color-white ((t (:foreground "#383a42" :background "#383a42"))))
 '(ansi-color-bright-black ((t (:foreground "#9ca0a4" :background "#9ca0a4"))))
 '(ansi-color-bright-red ((t (:foreground "#e86b60" :background "#e86b60"))))
 '(ansi-color-bright-green ((t (:foreground "#69ae68" :background "#69ae68"))))
 '(ansi-color-bright-yellow ((t (:foreground "#a77f27" :background "#a77f27"))))
 '(ansi-color-bright-blue ((t (:foreground "#5d8bf4" :background "#5d8bf4"))))
 '(ansi-color-bright-magenta ((t (:foreground "#b247b0" :background "#b247b0"))))
 '(ansi-color-bright-cyan ((t (:foreground "#2696c6" :background "#2696c6"))))
 '(ansi-color-bright-white ((t (:foreground "#1b2229" :background "#1b2229"))))
 '(compilation-column-number ((t (:inherit font-lock-comment-face))))
 '(compilation-line-number ((t (:foreground "#4078f2"))))
 '(compilation-error ((t (:inherit error :weight bold))))
 '(compilation-warning ((t (:inherit warning :slant italic))))
 '(compilation-info ((t (:inherit success))))
 '(flymake-error ((t (:underline (:style wave :color "#e45649")))))
 '(flymake-note ((t (:underline (:style wave :color "#50a14f")))))
 '(flymake-warning ((t (:underline (:style wave :color "#da8548")))))
 '(flyspell-incorrect ((t (:underline (:style wave :color "#e45649")))))
 '(flyspell-duplicate ((t (:underline (:style wave :color "#986801")))))
 '(css-proprietary-property ((t (:foreground "#da8548"))))
 '(css-property ((t (:foreground "#50a14f"))))
 '(css-selector ((t (:foreground "#4078f2"))))
 '(diff-added ((t (:background "#eef7ee" :foreground "#50a14f" :extend t))))
 '(diff-changed ((t (:foreground "#b751b6"))))
 '(diff-context ((t (:foreground "#6f7377"))))
 '(diff-removed ((t (:background "#f7e2e0" :foreground "#e45649" :extend t))))
 '(diff-header ((t (:foreground "#0184bc"))))
 '(diff-file-header ((t (:foreground "#4078f2" :weight bold))))
 '(diff-hunk-header ((t (:foreground "#b751b6"))))

 ;; Files and prose.
 '(dired-directory ((t (:foreground "#a626a4"))))
 '(dired-ignored ((t (:foreground "#9ca0a4"))))
 '(dired-flagged ((t (:foreground "#e45649"))))
 '(dired-header ((t (:foreground "#4078f2" :weight bold))))
 '(dired-mark ((t (:foreground "#da8548" :weight bold))))
 '(dired-marked ((t (:foreground "#a626a4" :weight bold :inverse-video t))))
 '(dired-perm-write ((t (:foreground "#383a42" :underline t))))
 '(dired-symlink ((t (:foreground "#0184bc" :weight bold))))
 '(markdown-header-face ((t (:inherit bold :foreground "#e45649"))))
 '(markdown-header-delimiter-face ((t (:inherit markdown-header-face))))
 '(markdown-markup-face ((t (:foreground "#383a42"))))
 '(markdown-metadata-key-face ((t (:foreground "#e45649"))))
 '(markdown-list-face ((t (:foreground "#e45649"))))
 '(markdown-link-face ((t (:foreground "#4078f2"))))
 '(markdown-url-face ((t (:foreground "#a626a4" :weight normal))))
 '(markdown-italic-face ((t (:inherit italic :foreground "#b751b6"))))
 '(markdown-bold-face ((t (:inherit bold :foreground "#da8548"))))
 '(markdown-blockquote-face ((t (:inherit italic :foreground "#6f7377"))))
 '(markdown-pre-face ((t (:foreground "#50a14f"))))
 '(markdown-code-face ((t (:background "#e7e7e7" :extend t))))
 '(markdown-reference-face ((t (:foreground "#6f7377"))))
 '(markdown-inline-code-face ((t (:inherit (markdown-code-face markdown-pre-face) :extend nil))))

 ;; Org uses direct heading colors in place of doom-themes-org-config.
 '(org-archived ((t (:foreground "#6f7377"))))
 '(org-block ((t (:background "#e7e7e7" :extend t))))
 '(org-block-begin-line ((t (:inherit org-block :foreground "#383a42" :slant italic))))
 '(org-block-end-line ((t (:inherit org-block-begin-line))))
 '(org-code ((t (:inherit org-block :foreground "#da8548"))))
 '(org-date ((t (:foreground "#986801"))))
 '(org-document-info ((t (:foreground "#a626a4"))))
 '(org-document-title ((t (:foreground "#a626a4" :weight bold))))
 '(org-done ((t (:foreground "#383a42" :weight bold))))
 '(org-drawer ((t (:foreground "#9ca0a4"))))
 '(org-ellipsis ((t (:background "#fafafa" :foreground "#e45649" :underline nil))))
 '(org-footnote ((t (:foreground "#da8548"))))
 '(org-formula ((t (:foreground "#0184bc"))))
 '(org-headline-done ((t (:foreground "#383a42"))))
 '(org-hide ((t (:foreground "#fafafa"))))
 '(org-level-1 ((t (:foreground "#e45649" :weight bold))))
 '(org-level-2 ((t (:foreground "#da8548" :weight bold))))
 '(org-level-3 ((t (:foreground "#986801" :weight bold))))
 '(org-level-4 ((t (:foreground "#50a14f" :weight bold))))
 '(org-level-5 ((t (:foreground "#0184bc" :weight bold))))
 '(org-level-6 ((t (:foreground "#4078f2" :weight bold))))
 '(org-level-7 ((t (:foreground "#a626a4" :weight bold))))
 '(org-level-8 ((t (:foreground "#b751b6" :weight bold))))
 '(org-link ((t (:inherit link :foreground "#4078f2"))))
 '(org-meta-line ((t (:foreground "#6f7377"))))
 '(org-priority ((t (:foreground "#e45649"))))
 '(org-quote ((t (:inherit org-block :slant italic))))
 '(org-special-keyword ((t (:foreground "#6f7377"))))
 '(org-table ((t (:foreground "#b751b6"))))
 '(org-tag ((t (:foreground "#6f7377" :weight normal))))
 '(org-todo ((t (:foreground "#50a14f" :weight bold))))
 '(org-verbatim ((t (:foreground "#50a14f"))))
 '(org-warning ((t (:inherit warning))))
 '(org-agenda-date ((t (:foreground "#b751b6" :weight ultra-bold))))
 '(org-agenda-date-today ((t (:foreground "#d396d3" :weight ultra-bold))))
 '(org-agenda-date-weekend ((t (:foreground "#6d306d" :weight ultra-bold))))
 '(org-agenda-structure ((t (:foreground "#383a42" :weight ultra-bold))))
 '(org-scheduled ((t (:foreground "#383a42"))))
 '(org-scheduled-today ((t (:foreground "#1c1f24"))))
 '(org-scheduled-previously ((t (:foreground "#1b2229"))))
 '(org-upcoming-deadline ((t (:foreground "#5e6066"))))
 '(org-upcoming-distant-deadline ((t (:foreground "#999a9e"))))
 '(org-cite ((t (:foreground "#4aa8b0"))))
 '(org-cite-key ((t (:foreground "#44838b" :underline t))))
 '(org-ref-acronym-face ((t (:foreground "#b751b6"))))
 '(org-ref-cite-face ((t (:foreground "#986801" :weight light :underline t))))
 '(org-ref-glossary-face ((t (:foreground "#a626a4"))))
 '(org-ref-label-face ((t (:foreground "#4078f2"))))
 '(org-ref-ref-face ((t (:inherit link :foreground "#4db5bd"))))

 ;; Magit keeps One Light's semantic colors with fixed pale backgrounds.
 '(magit-branch-current ((t (:foreground "#4078f2" :weight bold))))
 '(magit-branch-local ((t (:foreground "#0184bc"))))
 '(magit-branch-remote ((t (:foreground "#50a14f"))))
 '(magit-diff-added ((t (:background "#e9f1e8" :foreground "#40803f" :extend t))))
 '(magit-diff-added-highlight ((t (:background "#d8e8d7" :foreground "#50a14f" :weight bold :extend t))))
 '(magit-diff-base ((t (:background "#faeee6" :foreground "#ae6a39" :extend t))))
 '(magit-diff-base-highlight ((t (:background "#f6ddcc" :foreground "#da8548" :weight bold :extend t))))
 '(magit-diff-context ((t (:background "#fafafa" :foreground "#9ca0a4" :extend t))))
 '(magit-diff-context-highlight ((t (:background "#f0f0f0" :foreground "#383a42" :extend t))))
 '(magit-diff-file-heading ((t (:foreground "#383a42" :weight bold :extend t))))
 '(magit-diff-file-heading-selection ((t (:background "#a0bcf8" :foreground "#a626a4" :weight bold :extend t))))
 '(magit-diff-hunk-heading ((t (:background "#e5c7e5" :foreground "#fafafa" :extend t))))
 '(magit-diff-hunk-heading-highlight ((t (:background "#b751b6" :foreground "#fafafa" :weight bold :extend t))))
 '(magit-diff-removed ((t (:background "#f7e9e8" :foreground "#b6443a" :extend t))))
 '(magit-diff-removed-highlight ((t (:background "#f5d9d6" :foreground "#e45649" :weight bold :extend t))))
 '(magit-dimmed ((t (:foreground "#c6c7c7"))))
 '(magit-hash ((t (:foreground "#9ca0a4"))))
 '(magit-filename ((t (:foreground "#b751b6"))))
 '(magit-log-author ((t (:foreground "#da8548"))))
 '(magit-log-date ((t (:foreground "#4078f2"))))
 '(magit-log-graph ((t (:foreground "#9ca0a4"))))
 '(magit-process-ng ((t (:inherit error))))
 '(magit-process-ok ((t (:inherit success))))
 '(magit-section-heading ((t (:foreground "#4078f2" :weight bold :extend t))))
 '(magit-section-heading-selection ((t (:foreground "#da8548" :weight bold :extend t))))
 '(magit-section-highlight ((t (:inherit hl-line))))
 '(magit-section-secondary-heading ((t (:foreground "#b751b6" :weight bold :extend t))))
 '(magit-tag ((t (:foreground "#986801"))))

 ;; Retained UI packages.
 '(which-key-key-face ((t (:foreground "#50a14f"))))
 '(which-key-group-description-face ((t (:foreground "#b751b6"))))
 '(which-key-command-description-face ((t (:foreground "#4078f2"))))
 '(which-key-local-map-description-face ((t (:foreground "#a626a4"))))
 '(evil-ex-info ((t (:foreground "#e45649" :slant italic))))
 '(evil-ex-search ((t (:background "#4078f2" :foreground "#f0f0f0" :weight bold))))
 '(evil-ex-substitute-matches ((t (:background "#f0f0f0" :foreground "#e45649" :weight bold :strike-through t))))
 '(evil-ex-substitute-replacement ((t (:background "#f0f0f0" :foreground "#50a14f" :weight bold))))
 '(gptel-context-highlight-face ((t (:background "#e7e7e7" :foreground "#383a42"))))
 '(gptel-context-deletion-face ((t (:background "#f7e2e0" :foreground "#e45649" :strike-through t))))
 '(gptel-rewrite-highlight-face ((t (:background "#dce7fd" :foreground "#202328")))))

(custom-theme-set-variables
 'mig-one-light
 '(frame-background-mode 'light))

(provide-theme 'mig-one-light)

;;; mig-one-light-theme.el ends here
