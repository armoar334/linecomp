#!/usr/bin/env bash

# linecomp V2
# readline "replacment" for bash

# Check that current shell is bash
# This works under zsh and crashes out on fish, so p much serves its purpose
if [[ "$0" != *"bash"* ]];
then
	echo "Your current shell is not bash, or you did not source the script!"
	echo "You must run '. linecomp.sh' and not './linecomp.sh'!"
	exit
fi

_histmax=$(wc -l "$HISTFILE" | awk '{print $1}')


#trap "" INT SIGINT
trap "history -a && echo linecomp exited" EXIT

compose_case() {
	# This function composes the case statement used by linecomp for input
	# it does this by reading the current session keybinds and turning them into a 
	# statement that can be used for the users input, therefore allowing for linecomp
	# to be a drop in replacement for the default line-editor
	local raw_binds
	
	raw_binds=$(
		bind -p | grep -a -v '^#' | tr "'\"" "\"'"
	)

	linecomp_case=$(
		# yeah i know this could be all one printf, fuck off
		printf '%s\n' '_key_done=false'
		printf '%s\n' '_temp=""'
		printf '%s\n%s\n' 'while [[ $_key_done = false ]]' 'do'
		printf '%s\n' "IFS= read -rsn1 -d '' _char"
		printf '%s\n' '_key_done=true'
		printf '%s\n' '_temp="$_temp$_char"'
		printf '%s\n' 'case $_temp in'

		# Uncustomisables (EOF, Ctrl-c, etc)
		cat <<-'EOF'
			$'\004') [[ -z "$READLINE_LINE" ]] && exit ;;
			$'\cc')
				echo '^C'
				printf '\e7'
				_reading='false'
				echo -n "$(print_command_line)" ;;
		EOF
		raw_binds="${raw_binds/$'\n'}"
		raw_binds="${raw_binds//$'\n'/$'\n'\$}"
		raw_binds="${raw_binds//\\C-/\\c}"
		raw_binds="${raw_binds//: /) }"
		raw_binds="${raw_binds//$'\n'/ ;;$'\n'}"
		printf '%s\n' "$raw_binds ;;"

		printf '%s\n' '*) _key_done=false ;;'
		printf '%s\n' 'esac'
		printf '%s\n' '[[ ${#_temp} -gt 6 ]] && _temp=""'
		#printf '%s\n' 'echo $_temp'
		printf '%s\n' 'done'
		printf '%s\n' '_temp='
	)

}


# Text manipulation

self-insert() {
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$_char${READLINE_LINE:$READLINE_POINT}"
	((READLINE_POINT+=1))
	comp_complete
}

quoted-insert() {
	read -rsn1 _char
	read -rsn5 -t 0.005 _temp
	_char="$_char$_temp"
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}$_char${READLINE_LINE:$READLINE_POINT}"
	((READLINE_POINT+=${#_char}))
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

backward-delete-char() {
	if [[ $READLINE_POINT -gt 0 ]];
	then
		READLINE_LINE="${READLINE_LINE:0:$((READLINE_POINT-1))}${READLINE_LINE:$READLINE_POINT}"
		((READLINE_POINT-=1))
	fi
}

delete-char() {
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}${READLINE_LINE:$((READLINE_POINT+1))}"
}

kill-word() {
	READLINE_LINE="${READLINE_LINE% *}"
}

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

# Cursor
forward-char() {
	if [[ $READLINE_POINT -lt ${#READLINE_LINE} ]];
	then
		((READLINE_POINT+=1))
	fi
}

forward-word() {
	_temp="${READLINE_LINE:$(( READLINE_POINT + 1 ))} "
	_temp="${_temp#*[^[:alnum:]]}"
	READLINE_POINT="$(( ${#READLINE_LINE} - ${#_temp} ))"
}

backward-char() {
	if [[ $READLINE_POINT -gt 0 ]];
	then
		((READLINE_POINT-=1))
	fi
}

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

beginning-of-line() {
	READLINE_POINT=0
}

end-of-line() {
	READLINE_POINT=${#READLINE_LINE}
}

kill-line() {
	READLINE_LINE="${READLINE_LINE:0:$READLINE_POINT}"
}

complete() {
	if [[ "$_post_prompt" != *' ' ]];
	then
		READLINE_LINE="$_post_prompt"
		READLINE_POINT=${#READLINE_LINE}
	fi
}


# Not text
next-history() {
	((_comp_hist-=1))
	if [[ $_comp_hist -le 0 ]]; then _comp_hist=0; fi
	READLINE_LINE="$(history_get)"
	READLINE_POINT=${#READLINE_LINE}
}

previous-history() {
	((_comp_hist+=1))
	if [[ $_comp_hist -gt $_histmax ]];
	then
		_comp_hist=$_histmax
	fi
	READLINE_LINE="$(history_get)"
	READLINE_POINT=${#READLINE_LINE}
}

operate-and-get-next() {
	READLINE_LINE="$(history_get)"
	accept-line	
	((_comp_hist+=1))
	READLINE_LINE="$(history_get)"	
}

history_get() {
	set -o history
	if [[ $_comp_hist == 0 ]];
	then
		printf ""
	else
		printf '%s' "$(history $_comp_hist | head -1 | cut -c 8-)"
	fi
}

clear-screen() {
	clear
	printf '\e7'
}

# Meta
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

print_command_line() {
	local temp_str

	# This doesnt technichally need to be a different function but it
	# reduced jitter to run it all into a variable and print all at once
	# cat -v (considered harmful) is so that quoted inserts can work
	# Also makes it slow, but thats for later
	#temp_str="${line_array[*]:0:${#line_array[@]}-1}"
	#echo; echo "${#temp_str}"
	#echo "${#line_array[-1]}"

	temp_str="${READLINE_LINE//$'\n'/$'\n'$_PS2exp}"
	printf '\e8\e[?25l\e[K%s' "$_prompt"
	printf '%s' "$temp_str" | cat -v 
	printf '\e[%sm%s\e[K\e8%s' "$_color" "${_post_prompt:${#READLINE_LINE}}" "$_prompt"

	#[[ $READLINE_POINT -ge 1 ]] && printf '\e[%sC' "$READLINE_POINT"

	printf '\e[0m\e[?25h'
	temp_str="${READLINE_LINE:0:$READLINE_POINT}"
	temp_str="${temp_str//$'\n'/$'\n'$_PS2exp}"
	printf '%s' "$temp_str" | cat -v

}

# Completions

comp_complete() {
	# We sadly need it to interpret backslashes for directory names
	read -a line_array <<<"$READLINE_LINE"
	line_array=( "${line_array[@]// /\\ }" )
	if [ "${#line_array[@]}" -gt 1 ]; then
		case "${line_array[-1]}" in
			'-'*) 
				man_completion "${line_array[0]}" "${line_array[-1]}"
				_post_prompt="${line_array[*]:0:${#line_array[@]}-1} $return_args" ;; # Fix after pipes later
			*)
				dir_suggest "${line_array[-1]}"
				_post_prompt="${line_array[*]:0:${#line_array[@]}-1} $return_path" ;;
		esac
	else
		_post_prompt=$(printf '%s' "$_commands" | grep -m1 -F -- "$READLINE_LINE")
		_color='31'
	fi
}

dir_suggest() {
	local temp_path="$1"
	local tilde_yes=false
	local complete_path
	local unfinish_path
	local files
	
	if [[ "$temp_path" == '~/'* ]]; then
		tilde_yes=true
		temp_path="${temp_path/~\//"$HOME"\/}"
	fi
	
	complete_path="${temp_path%/*}"
	unfinish_path="${temp_path##*/}"

	# If its a directory
	if [ -d "${complete_path//\\ / }" ]; then
		files=$(printf '%q\n' "${complete_path//\\ / }"/*/ "${complete_path//\\ / }"/* )
	# If it isnt yet (current folder)
	else
		files=$(printf '%q\n' */ *)
	fi
	return_path=$(printf '\n%s' "$files" | grep -m1 -F -- "$unfinish_path")

	if [ -d "${return_path//\\ / }" ]; then
		_color='34'
	else
		_color='32'
	fi

	if [ "$tilde_yes" = true ]; then
		return_path="${return_path/"$HOME"\//~\/}"
	fi

}

man_completion() {
	local man_string
	local opt_string

	man_string="$1"
	opt_string="$2"

	if [[ "${#opt_string}" -le 1 ]];
	# Command length just makes sure it doesnt re-check every time, mega speed increase
	then
		if [[ "$OSTYPE" == *darwin* ]];
		then
			_man_args=$(man "$man_string" | col -bx | grep -F '-' | tr ' ' $'\n')
			_man_args=$(<<< "${_man_args//[^[:alpha:]]$'\n'/$'\n'}" grep -- '^-'| uniq)
		else
			_man_args=$(man -Tascii "$man_string" | col -bx | grep -F '-' | tr ' ' $'\n' )
			_man_args=$(<<< "${_man_args//[^[:alpha:]]$'\n'$'\n'}" grep -- '^-'| uniq)
			# This take 0.3 seconds each for the bash page, of which 0.013 is the sorting
			# 0.190 IS RIDICULOUS, but also that bc bash's docs are 10,000 pages or smth
			# -Tascii take this down by ~0.030 but even then its borderline unusable, all bc of pointless formatting bs
		fi
		_temp=''
		_man_args=$(printf '%s' "$_man_args" | sed -e 's/[^[:alnum:]]$//g')
	fi
	return_args=$(printf '\n%s' "$_man_args" | grep -m1 -F -- "$opt_string")
	_color='33'
}

# Other

main_func() {
	_comp_hist=0
	READLINE_POINT=0
	_reading="true"
	_prompt="${PS1@P}"
	_PS2exp="${PS2@P}"
	READLINE_LINE=''
	_color='31'
	_post_prompt=''

	while [[ "$_reading" == "true" ]];
	do
		set -o history
		echo -n "$(print_command_line)"
		eval -- "$linecomp_case"
	done
}

main_loop() {
	while true;
	do
		main_func
	done
	echo "$linecomp_case"
}

printf '\e7'
echo -n "${PS1@P}"

_commands=$(compgen -c | sort -u | awk '{ print length, $0 }' | sort -n -s | cut -d' ' -f2- )

_default_term_state="$(stty -g)"

printf '\e[?2004h' # enable bracketed paste so we can handle rselves
stty -echo
stty intr ''
shopt -s dotglob
shopt -s nullglob
_linecomp_term_state="$(stty -g)"

compose_case
main_loop
stty "$_default_term_state"
#echo "$linecomp_case"
