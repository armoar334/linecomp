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
			$'\004') [[ -z "$_string" ]] && exit ;;
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
	_string="${_string:0:$_curpos}$_char${_string:$_curpos}"
	((_curpos+=1))
	comp_complete
}

quoted-insert() {
	read -rsn1 _char
	read -rsn5 -t 0.005 _temp
	_char="$_char$_temp"
	_string="${_string:0:$_curpos}$_char${_string:$_curpos}"
	((_curpos+=${#_char}))
}

bracketed-paste-begin() {
	_temp=''
	until [[ "$_temp" == *$'\e[201~' ]]
	do
		IFS= read -rsn1 -t 0.01 _char
		_temp+="$_char"
	done
	_temp="${_temp:0:-6}"
	_string="${_string:0:$_curpos}$_temp${_string:$_curpos}"
	((_curpos+="${#_temp}"))
}

backward-delete-char() {
	if [[ $_curpos -gt 0 ]];
	then
		_string="${_string:0:$((_curpos-1))}${_string:$_curpos}"
		((_curpos-=1))
	fi
}

delete-char() {
	_string="${_string:0:$_curpos}${_string:$((_curpos+1))}"
}

kill-word() {
	_string="${_string% *}"
}

tilde-expand() {
	if [[ "${_string:$_curpos:1}" == '~' ]];
	then
		_string="${_string:0:$((_curpos))}$HOME${_string:$((_curpos+1))}"
		((_curpos+=${#HOME}))
	elif [[ "${_string:$((_curpos-1)):1}" == '~' ]];
	then
		_string="${_string:0:$((_curpos-1))}$HOME${_string:$((_curpos))}"
		((_curpos+=${#HOME}))
	fi
}

# Cursor
forward-char() {
	if [[ $_curpos -lt ${#_string} ]];
	then
		((_curpos+=1))
	fi
}

forward-word() {
	_temp="${_string:$(( _curpos + 1 ))} "
	_temp="${_temp#*[^[:alnum:]]}"
	_curpos="$(( ${#_string} - ${#_temp} ))"
}

backward-char() {
	if [[ $_curpos -gt 0 ]];
	then
		((_curpos-=1))
	fi
}

backward-word() {
	_temp="${_string:0:$_curpos}"
	_temp="${_temp%[^[:alnum:]]*}"
	if ! [[ "$_temp" == *' '* ]];
	then
		_curpos=0
	else
		_curpos=${#_temp}
	fi
}

beginning-of-line() {
	_curpos=0
}

end-of-line() {
	_curpos=${#_string}
}

kill-line() {
	_string="${_string:0:$_curpos}"
}

complete() {
	if [[ "$_post_prompt" != *' ' ]];
	then
		_string="$_post_prompt"
		_curpos=${#_string}
	fi
}


# Not text
next-history() {
	((_comp_hist-=1))
	if [[ $_comp_hist -le 0 ]]; then _comp_hist=0; fi
	_string="$(history_get)"
	_curpos=${#_string}
}

previous-history() {
	((_comp_hist+=1))
	if [[ $_comp_hist -gt $_histmax ]];
	then
		_comp_hist=$_histmax
	fi
	_string="$(history_get)"
	_curpos=${#_string}
}

operate-and-get-next() {
	_string="$(history_get)"
	accept-line	
	((_comp_hist+=1))
	_string="$(history_get)"	
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
	case "$_string" in
		*"EOM"*"EOM"*|*"EOF"*"EOF"*) _reading=false ;;
		*'\'|*"EOM"*|*"EOF"*) _string+=$'\n'
			((_curpos+=1)) ;;
		*)
			if [[ $(bash -nc "$_string" 2>&1) == *'unexpected end of file'* ]];
			then
				_string+=$'\n'
				((_curpos+=1))
			else
				echo
				if [[ -n "$_string" ]];
				then
					history -s "$_string"
				fi
				stty "$_default_term_state"
				eval -- "$_string" # This continues to be bad
				stty "$_linecomp_term_state"
				printf '\e7'
				_reading=false
				[[ "$_string" == *'bind'* ]] && compose_case # Recreate the case statement if the command has bind
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

	temp_str="${_string//$'\n'/$'\n'$_PS2exp}"
	printf '\e8\e[?25l\e[K%s' "$_prompt"
	printf '%s' "$temp_str" | cat -v 
	printf '\e[%sm%s\e[K\e8%s' "$_color" "${_post_prompt:${#_string}}" "$_prompt"

	#[[ $_curpos -ge 1 ]] && printf '\e[%sC' "$_curpos"

	printf '\e[0m\e[?25h'
	temp_str="${_string:0:$_curpos}"
	temp_str="${temp_str//$'\n'/$'\n'$_PS2exp}"
	printf '%s' "$temp_str" | cat -v

}

# Completions

comp_complete() {
	# We sadly need it to interpret backslashes for directory names
	read -a line_array <<<"$_string"
	line_array=( "${line_array[@]// /\\ }" )
	case "${line_array[-1]}" in
		'-'*) 
			man_completion "${line_array[0]}" "${line_array[-1]}"
			_post_prompt="${line_array[*]:0:${#line_array[@]}-1} $return_args" ;; # Fix after pipes later
		*)
			dir_suggest "${line_array[-1]}"
			_post_prompt="${line_array[*]:0:${#line_array[@]}-1} $return_path" ;;
	esac
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
	_curpos=0
	_reading="true"
	_prompt="${PS1@P}"
	_PS2exp="${PS2@P}"
	_string=''
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
