;; Author: Dominique Unruh

(require 'qrhl-input)

;;;###autoload
(defgroup qrhl nil "qRHL prover settings")

;;;###autoload
(defcustom qrhl-input-method "qrhl" "Input method to use when editing qRHL proof scripts"
  :type '(string) :group 'qrhl)

;;;###autoload
(defcustom qrhl-prog-name "qrhl" "Name/path of the qrhl-prover command"
  :type '(string) :group 'qrhl)

(defun qrhl-find-and-forget (span)
  (proof-generic-count-undos span))
  
;(defvar qrhl-home (file-name-directory (directory-file-name (file-name-directory (directory-file-name (file-name-directory load-file-name))))))

(defvar qrhl-focus-cmd-regexp
      (let* ((number "[0-9]+")
	     (white "[[:blank:]]*")
	     (number-or-range (concat number "\\(" white "-" white number "\\)?"))
	     (range-list (concat number-or-range "\\(" white "," white number-or-range "\\)*"))
	     (focus-label "\\({\\|}\\|[+*-]+\\)")
	     (focus-cmd (concat "\\(" range-list white ":" white "\\)?" focus-label))
	     )
	focus-cmd))

(defun qrhl-forward-regex (regex)
  "If text starting at point matches REGEX, move to end of the match and return t. 
   Otherwise return nil"
  (and (looking-at regex) (goto-char (match-end 0)) t))

(defun qrhl-parse-regular-command ()
  "Finds the period-terminated command starting at the point (and moves to its end).
   Returns t if this worked."
  (let ((pos 
	 (save-excursion 
	   (progn
	    (while (or
	              ; skip forward over regular chars, period with non-white, quoted string
		    (qrhl-forward-regex "\\([^.{(\"]+\\|\\.[^ \t\n]\\|\"\\([^\"]+\\)\"\\)")
		    (and (looking-at "[{(]") (forward-list))
		    ))
	    (and (qrhl-forward-regex "\\.") (point))
	    ))))
    (princ pos)
    (and pos (goto-char pos) t)))

(defun qrhl-parse-focus-command ()
  (and (looking-at qrhl-focus-cmd-regexp)
       (goto-char (match-end 0))))

(defun qrhl-proof-script-parse-function ()
  "Finds the command/comment starting at the point"
  (or (and (qrhl-forward-regex "#[^\n]*\n") 'comment)
      (and (qrhl-parse-focus-command) 'cmd)
      (and (qrhl-parse-regular-command) 'cmd)))

(proof-easy-config 'qrhl "qRHL"
		   proof-prog-name qrhl-prog-name
		   ; We need to give some option here, otherwise proof-prog-name is interpreted
		   ; as a shell command which leads to problems if the path contains spaces
		   ; (see the documentation for proof-prog-name)
		   qrhl-prog-args '("--emacs")
		   ;proof-script-command-end-regexp "\\.[ \t]*$"
		   proof-script-parse-function 'qrhl-proof-script-parse-function
		   proof-shell-annotated-prompt-regexp "^\\(\\.\\.\\.\\|qrhl\\)> "
		   ;proof-script-comment-start-regexp "#"
		   ;proof-script-comment-end "\n"
		   proof-shell-error-regexp "^\\(\\[ERROR\\]\\|Exception\\)"
		   proof-undo-n-times-cmd "undo %s."
		   proof-find-and-forget-fn 'qrhl-find-and-forget
		   proof-shell-start-goals-regexp "^[0-9]+ subgoals:\\|^Goal:\\|^No current goal\\.\\|^In cheat mode\\.\\|^No focused goals (use "
		   proof-shell-proof-completed-regexp "^No current goal.$"
		   proof-shell-eager-annotation-start "\\*\\*\\* "
		   proof-shell-eager-annotation-start-length 4
		   proof-no-fully-processed-buffer t
		   proof-shell-filename-escapes '(("\\\\" . "\\\\") ("\"" . "\\\""))
		   proof-shell-cd-cmd "changeDirectory \"%s\"."
		   proof-save-command-regexp "^adfuaisdfaoidsfasd" ; ProofGeneral produces warning when this is not set. But we don't want goal/save commands to be recognized because that makes ProofGeneral do an atomic undo.
		   proof-tree-external-display nil
		   )

; buttoning functions follow https://superuser.com/a/331896/748969
(define-button-type 'qrhl-find-file-button
  'follow-link t
  'action #'qrhl-find-file-button)

(defun qrhl-find-file-button (button)
  (find-file (buffer-substring (button-start button) (button-end button))))

(defun qrhl-buttonize-buffer ()
 "turn all include's into clickable buttons"
 (interactive)
 (remove-overlays)
 (save-excursion
  (goto-char (point-min))
  (while (re-search-forward "include\s*\"\\([^\"]+\\)\"\s*\\." nil t)
   (make-button (match-beginning 1) (match-end 1) :type 'qrhl-find-file-button))))

(add-hook 'qrhl-mode-hook
	  (lambda ()
	    (set-input-method qrhl-input-method)
	    (set-language-environment "UTF-8")
	    (set-variable 'electric-indent-mode nil)
	    (qrhl-buttonize-buffer)))

(provide 'qrhl)
