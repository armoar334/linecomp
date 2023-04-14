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


trap "_reading='false' && return" INT SIGINT
trap "history -a && echo linecomp exited" EXIT

compose_case() {
	# This function composes the case statement used by linecomp for input
	# it does this by reading the current session keybinds and turning them into a 
	# statement that can be used for the users input, therefore allowing for linecomp
	# to be a drop in replacement for the default line-editor
	local raw_binds
	local escape_binds
	local ctrl_binds
	local other_binds
	
	raw_binds=$(
		bind -p | grep -v '^#' | tr "'\"" "\"'"
	)
	
	escape_binds=$(
		<<<"$raw_binds" grep -F '\e'
	)
	
	ctrl_binds=$(
		<<<"$raw_binds" grep -- '\''\C'		
	)
	
	insert_binds=$(
		<<<"$raw_binds" grep -F 'self-insert'
	)

	linecomp_case=$(
		echo 'case $_char in'

		# Uncustomisables (EOF, tab complete)
		cat <<-'EOF'
			$'\cd') [[ -z "$_string" ]] && exit ;;
			$'\t') _string="$_post_prompt" && _curpos=${#_string} ;;
		EOF

		# Escapes
		echo -ne '\t' 
		echo '$'"'\e')"

		# Sub-escapes
		# None of this technichally needs to be indented but its easier to read for debugging
		echo -e '\t\tread -rsn1 _char ' # Read one more untimed for manually input esc seqs
		echo -e '\t\tread -rsn5 -t 0.005 _temp ' # Read 5 more timed for stuff like ctrl+arrows 
		echo -e '\t\t_char="$_char$_temp"' # Not elegant, but mostly functional
		echo -e '\t\tcase "$_char" in'
		echo "${escape_binds//$'\n'\'\\e/$'\n'\'}" | sed -e "s/^/\t\t\t/g" -e 's/: /) /g' -e 's/\C-/\c/g' -e 's/$/ ;;/g'
		# Multi ctrl/esc sequences are too much hassle atm, so ignore
		echo -e '\t\tesac ;;'

		

		echo -ne '\t'
		# Ctrl characters
		echo "${ctrl_binds//\\C-/\\c}" | sed -e 's/^/\t\$/g' -e 's/: /) /g' -e 's/$/ ;;/g' | tr '"' "'"
		# Self-insertion characters

		echo "${insert_binds//\"\\2/\$\"\\2}" | sed -e 's/^/\t/g' -e 's/: /) /g' -e 's/$/ ;;/g' -e 's/`/\\\`/g' | sed -e 's/" "/'\'' '\''/g' -e "s/'.''/\"\\'\"/g"

		echo -ne '\t'
		echo '*) echo && echo "$_char" ;;' 
		
		echo 'esac'
	)

}


# Text manipulation

self-insert() {
	_string="${_string:0:$_curpos}$_char${_string:$_curpos}"
	((_curpos+=1))
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

complete() {
	if ! [[ -z "$_post_prompt" ]];
	then
		_string="$_post_prompt"
		_curpos=${#_string}
	fi
}

# Not text
next-history() {
	((_comp_hist-=1))
	if [[ $_comp_hist -le 0 ]]; then _comp_hist=0; fi
	history_get
	_string="$_hist_args"
}

previous-history() {
	((_comp_hist+=1))
	if [[ $_comp_hist -gt $_histmax ]];
	then
		_comp_hist=$_histmax
	fi
	history_get
	_string="$_hist_args"
}

history_get() {
	set -o history
	if [[ $_comp_hist == 0 ]];
	then
		_hist_args=""
	else
		_hist_args="$(history $_comp_hist | head -1 | cut -c 8-)"
	fi
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
				stty echo
				history -s "$_string"
				eval -- "$_string" # This continues to be bad
				stty -echo
				_reading=false
				printf '\e7'
			fi ;;
	esac
}

print_command_line() {
	local temp_str
	# This doesnt technichally need to be a different function but it
	# reduced jitter to run it all into a variable and print all at once
	temp_str="${_string//$'\n'/$'\n'$_PS2exp}"
	printf "\e8\e[?25l\e[K"
	printf '%s%s%s%s\e[K\e8%s' "$_prompt" "$temp_str" "$_color" "${_post_prompt:${#_string}}" "$_prompt"
	temp_str="${_string:0:$_curpos}"
	printf '%s\e[0m\e[?25h' "${temp_str//$'\n'/$'\n'$_PS2exp}"
}

# Completions
man_completions() {
	local man_string
	local command_one
	local command_end

	man_string="$_string"
	command_one="${man_string%% *}"
	command_end="${man_string##* }"
	if [[ "${man_string##* }" == '-'* ]] && [[ "${#command_end}" -le 1 ]];
	# IK there are commands that dont start with - but thats for later
	# Command length just makes sure it doesnt re-check every time, mega speed increase
	then
		if [[ "$OSTYPE" == *darwin* ]];
		then
			_man_args=$(man "$command_one" | col -bx | grep -F '-' | tr ' ' $'\n' | sed 's/[^[:alpha:]]$//g' | grep -- '^-'| uniq)
		else
			_man_args=$(man -Tascii "$command_one" | col -bx | grep -F '-' | tr ' ' $'\n' | sed 's/[^[:alpha:]]$//g' | grep -- '^-'| uniq)
			# This take 0.3 seconds each for the bash page, of which 0.013 is the sorting
			# 0.190 IS RIDICULOUS, but also that bc bash's docs are 10,000 pages or smth
			# -Tascii take this down by ~0.030 but even then its borderline unusable, all bc of pointless formatting bs
		fi
		_temp=''
		while IFS= read -r line; do
			_temp+=$'\n'"${man_string% *} $line"
		done <<< "$_man_args"
	fi
	_man_args="$_temp"
}

subdir_completion() {
	local dir_suggest
	local search_term
	
	dir_suggest="${_string##* }"
	# Subdirectories or pwd
	if [[ -d "${dir_suggest%'/'*}" ]] && [[ "$dir_suggest" == *"/"* ]];
	then
		folders="${dir_suggest%'/'*}/"
		search_term=$( printf '%q' "${dir_suggest/$folders}")
		files="$folders"$(ls "${dir_suggest%'/'*}" | grep -v '\.$' | grep -- '^'"$search_term" | sort -n)
	elif [[ "$dir_suggest" == "/"* ]];
	then
		search_term=$( printf '%q' "${dir_suggest/\/}")
		files=$(ls / | grep -v '\.$' | grep -- '^'"$search_term" | sort -n | sed 's/^/\//g')
	elif [[ "$(ls)" == *"$dir_suggest"* ]]; # Directory in current pwd
	then
		search_term=$( printf '%q' "$dir_suggest" )
		files=$(ls | grep -v '\.$' | grep -- '^'"$search_term" | sort -n)
	fi
	# Remove / if not directory or string empty
	_file_args=''
	while IFS= read -r line;
	do
		line=$(printf '%q' "$line")
		if [[ -d "$line" ]] && [[ "$line" != *'/' ]];
		then
			line="$line/"
		fi
		_file_args+=$'\n'"${_string% *} $line"
	done <<< "$files"
}

# Other

main_loop() {
	while true;
	do
		_comp_hist=0
		_curpos=0
		_reading="true"
		_prompt="${PS1@P}"
		_PS2exp="${PS2@P}"
		_string=''
		_color="$(printf '\e[31m')"
		_post_prompt=''

		while [[ "$_reading" == "true" ]];
		do
			echo -n "$(print_command_line)"
			IFS= read -rsn1 -d '' _char
			eval -- "$linecomp_case" #2>/dev/null
			man_completions
			subdir_completion
			_post_prompt=$( <<<$'\n'"$_man_args"$'\n'"$_commands"$'\n'"$_file_args" grep -F -m1 -- "$_string")
		done

	done
	echo "$linecomp_case"
}

_commands=$(compgen -c | sort -u | awk '{ print length, $0 }' | sort -n -s | cut -d" " -f2- )
_default_term_state=$(stty -g)
printf '\e7'
stty -echo
compose_case
main_loop
stty "$_default_term_state"
