#!/usr/bin/env bash

# Readline functions for linecomp

#abort
accept-line() {
	case "$READLINE_LINE" in
		*"EOM"*"EOM"*|*"EOF"*"EOF"*) _reading=false ;;
		*'\'|*"EOM"*|*"EOF"*) READLINE_LINE+=$'\n'
			((READLINE_POINT+=1)) ;;
		*)
			if [[ $(bash -nc "$READLINE_LINE" 2>&1) == *'unexpected end of file'* ]];
			then
				READLINE_LINE+=$'\n'
				((READLINE_POINT+=1))
			else
				echo
				if [[ -n "$READLINE_LINE" ]];
				then
					history -s "$READLINE_LINE"
				fi
				stty "$_default_term_state"
				eval -- "$READLINE_LINE" # This continues to be bad
				stty "$_linecomp_term_state"
				printf '\e7'
				_reading=false
				[[ "$READLINE_LINE" == *'bind'* ]] && compose_case # Recreate the case statement if the command has bind
			fi ;;
	esac
}
#alias-expand-line
#arrow-key-prefix
#backward-byte
backward-char() {
	if [[ $READLINE_POINT -gt 0 ]];
	then
		((READLINE_POINT-=1))
	fi
}
backward-delete-char() {
	if [[ $READLINE_POINT -gt 0 ]];
	then
		READLINE_LINE="${READLINE_LINE:0:$((READLINE_POINT-1))}${READLINE_LINE:$READLINE_POINT}"
		((READLINE_POINT-=1))
	fi
}
#backward-kill-line
#backward-kill-word
backward-word() {
	_temp="${READLINE_LINE:0:$READLINE_POINT}"
	_temp="${_temp%[^[:alnum:]]*}"
	if ! [[ "$_temp" == *' '* ]];
	then
		READLINE_POINT=0
	else
		READLINE_POINT=${#_temp}
	fi
}
#beginning-of-history
beginning-of-line() {
	READLINE_POINT=0
}
bracketed-paste-begin() {
	_temp=''
	until [[ "$_temp" == *$'\e[201~' ]]
	do
		IFS= read -rsn1 -t 0.01 _char
		_temp+="$_char"
	done
	_temp="${_temp:0:-6}"
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$_temp${READLINE_LINE:$READLINE_POINT}"
	((READLINE_POINT+="${#_temp}"))
}
#call-last-kbd-macro
#capitalize-word
#character-search
#character-search-backward
#clear-display
clear-screen() {
	clear
	printf '\e7'
}
complete() {
	if [[ "$_post_prompt" != *' ' ]];
	then
		READLINE_LINE="$_post_prompt"
		READLINE_POINT=${#READLINE_LINE}
	fi
}
#complete-command
#complete-filename
#complete-hostname
#complete-into-braces
#complete-username
#complete-variable
#copy-backward-word
#copy-forward-word
#copy-region-as-kill
#dabbrev-expand
delete-char() {
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${READLINE_LINE:$((READLINE_POINT+1))}"
}
#delete-char-or-list
#delete-horizontal-space
#digit-argument
#display-shell-version
#do-lowercase-version
#downcase-word
#dump-functions
#dump-macros
#dump-variables
#dynamic-complete-history
#edit-and-execute-command
#emacs-editing-mode
#end-kbd-macro
#end-of-history
end-of-line() {
	READLINE_POINT=${#READLINE_LINE}
}
#exchange-point-and-mark
#fetch-history
#forward-backward-delete-char
#forward-byte
forward-char() {
	if [[ $READLINE_POINT -lt ${#READLINE_LINE} ]];
	then
		((READLINE_POINT+=1))
	fi
}
#forward-search-history
forward-word() {
	_temp="${READLINE_LINE:$(( READLINE_POINT + 1 ))} "
	_temp="${_temp#*[^[:alnum:]]}"
	READLINE_POINT="$(( ${#READLINE_LINE} - ${#_temp} ))"
}
#glob-complete-word
#glob-expand-word
#glob-list-expansions
#history-and-alias-expand-line
#history-expand-line
#history-search-backward
#history-search-forward
#history-substring-search-backward
#history-substring-search-forward
#insert-comment
#insert-completions
#insert-last-argument
kill-line() {
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}"
}
#kill-region
#kill-whole-line
kill-word() {
	READLINE_LINE="${READLINE_LINE% *}"
}
#magic-space
#menu-complete
#menu-complete-backward
next-history() {
	((_comp_hist-=1))
	if [[ $_comp_hist -le 0 ]]; then _comp_hist=0; fi
	READLINE_LINE="$(history_get)"
	READLINE_POINT=${#READLINE_LINE}
}
#next-screen-line
#non-incremental-forward-search-history
#non-incremental-forward-search-history-again
#non-incremental-reverse-search-history
#non-incremental-reverse-search-history-again
#old-menu-complete
operate-and-get-next() {
	READLINE_LINE="$(history_get)"
	accept-line	
	((_comp_hist+=1))
	READLINE_LINE="$(history_get)"	
}
#overwrite-mode
#possible-command-completions
#possible-completions
#possible-filename-completions
#possible-hostname-completions
#possible-username-completions
#possible-variable-completions
previous-history() {
	((_comp_hist+=1))
	if [[ $_comp_hist -gt $_histmax ]];
	then
		_comp_hist=$_histmax
	fi
	READLINE_LINE="$(history_get)"
	READLINE_POINT=${#READLINE_LINE}
}
#previous-screen-line
#print-last-kbd-macro
quoted-insert() {
	read -rsn1 _char
	read -rsn5 -t 0.005 _temp
	_char="$_char$_temp"
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$_char${READLINE_LINE:$READLINE_POINT}"
	((READLINE_POINT+=${#_char}))
}
#re-read-init-file
#redraw-current-line
#reverse-search-history
#revert-line
self-insert() {
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$_char${READLINE_LINE:$READLINE_POINT}"
	((READLINE_POINT+=1))
	comp_complete
}
#set-mark
#shell-backward-kill-word
#shell-backward-word
#shell-expand-line
#shell-forward-word
#shell-kill-word
#shell-transpose-words
#skip-csi-sequence
#spell-correct-word
#start-kbd-macro
#tab-insert
tilde-expand() {
	if [[ "${READLINE_LINE:$READLINE_POINT:1}" == '~' ]];
	then
		READLINE_LINE="${READLINE_LINE:0:$((READLINE_POINT))}$HOME${READLINE_LINE:$((READLINE_POINT+1))}"
		((READLINE_POINT+=${#HOME}))
	elif [[ "${READLINE_LINE:$((READLINE_POINT-1)):1}" == '~' ]];
	then
		READLINE_LINE="${READLINE_LINE:0:$((READLINE_POINT-1))}$HOME${READLINE_LINE:$((READLINE_POINT))}"
		((READLINE_POINT+=${#HOME}))
	fi
}
#transpose-chars
#transpose-words
#tty-status
#undo
#universal-argument
#unix-filename-rubout
#unix-line-discard
#unix-word-rubout
#upcase-word
#vi-append-eol
#vi-append-mode
#vi-arg-digit
#vi-bWord
#vi-back-to-indent
#vi-backward-bigword
#vi-backward-word
#vi-bword
#vi-change-case
#vi-change-char
#vi-change-to
#vi-char-search
#vi-column
#vi-complete
#vi-delete
#vi-delete-to
#vi-eWord
#vi-edit-and-execute-command
#vi-editing-mode
#vi-end-bigword
#vi-end-word
#vi-eof-maybe
#vi-eword
#vi-fWord
#vi-fetch-history
#vi-first-print
#vi-forward-bigword
#vi-forward-word
#vi-fword
#vi-goto-mark
#vi-insert-beg
#vi-insertion-mode
#vi-match
#vi-movement-mode
#vi-next-word
#vi-overstrike
#vi-overstrike-delete
#vi-prev-word
#vi-put
#vi-redo
#vi-replace
#vi-rubout
#vi-search
#vi-search-again
#vi-set-mark
#vi-subst
#vi-tilde-expand
#vi-undo
#vi-unix-word-rubout
#vi-yank-arg
#vi-yank-pop
#vi-yank-to
#yank
#yank-last-arg
#yank-nth-arg
#yank-pop
