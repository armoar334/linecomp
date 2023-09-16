#!/usr/bin/env bash


# linecomp V2
# readline "replacment" for bash

_directory_color='34'
_history_color='35'
_command_color='90'
_option_color='33'
_file_color='32'


# Check that current shell is bash
# This works under zsh and crashes out on fish, so p much serves its purpose
if [[ "$0" != *"bash"* ]];
then
	echo "Your current shell is not bash, or you did not source the script!"
	echo "You must run '. linecomp.sh' and not './linecomp.sh'!"
	exit
fi

_histmax=$(wc -l "$HISTFILE" | awk '{print $1}')

_linecomp_path="$BASH_SOURCE"
source "${_linecomp_path%/*}"/readline_funcs.sh

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
		cat <<-'EOF'
		_key_done=false
		_temp=""
		while [[ $_key_done = false ]]
		do
		IFS= read -rsn1 -d '' _char
		_key_done=true
		_temp="$_temp$_char"
		case $_temp in
		EOF

		# Uncustomisables (EOF, Ctrl-c, etc)
		cat <<-'EOF'
			$'\004') [[ -z "$READLINE_LINE" ]] && exit ;;
			$'\cc')
				printf '%s\n' '^C'
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


# Not text

history_get() {
	set -o history
	if [[ $_comp_hist == 0 ]];
	then
		printf ""
	else
		printf '%s' "$(history $_comp_hist | head -1 | cut -c 8-)"
	fi
}

# Meta

print_command_line() {
	local temp_str

	# This doesnt technichally need to be a different function but it
	# reduced jitter to run it all into a variable and print all at once
	# cat -v (considered harmful) is so that quoted inserts can work
	# Also makes it slow, but thats for later
	#temp_str="${line_array[*]:0:${#line_array[@]}-1}"
	#echo; echo "${#temp_str}"
	#echo "${#line_array[-1]}"

	#temp_str="${READLINE_LINE//$'\n'/$'\n'$_PS2exp}"
	#printf '\e8\e[?25l\e[K%s' "$_prompt"
	#printf '%s' "$temp_str" | cat -v 
	#printf '\e[%sm%s\e[K\e8%s' "$_color" "${_post_prompt:${#READLINE_LINE}}" "$_prompt"

	#[[ $READLINE_POINT -ge 1 ]] && printf '\e[%sC' "$READLINE_POINT"

	#printf '\e[0m\e[?25h'
	#temp_str="${READLINE_LINE:0:$READLINE_POINT}"
	#temp_str="${temp_str//$'\n'/$'\n'$_PS2exp}"
	#printf '%s' "$temp_str" | cat -v

	printf '\e8%s%s\e[%sm%s\e[0m\e[K\e8%s%s' \
		"${PS1@P}" \
		"$READLINE_LINE" \
		"$_color" \
		"${_post_prompt:${#READLINE_LINE}}" \
		"${PS1@P}" \
		"${READLINE_LINE:0:$READLINE_POINT}"
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
		dir_suggest "${line_array[-1]}"
		_post_prompt=$(printf '%s' "$return_path"$'\n'"$_commands" | grep -m1 -- "^$READLINE_LINE") 2>/dev/null
		_color="$_command_color"
	fi
	temp_hist=$(history | cut -c 8- | tac | grep -m1 -- "^$READLINE_LINE") 2>/dev/null
	if [ -n "$temp_hist" ]
	then
		_post_prompt="$temp_hist"
		_color="$_history_color"
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
	elif [[ "$temp_path" == '/' ]]; then
		temp_path='/'
	fi
	
	complete_path="${temp_path%/*}"
	unfinish_path="${temp_path##*/}"

	# If its a directory
	if [ -d "${complete_path//\\ / }"/ ]; then
		files=$(printf '%q\n' "${complete_path//\\ / }"/*/ "${complete_path//\\ / }"/* )
	# If it isnt yet (current folder)
	else
		files=$(printf '%q\n' */ *)
	fi
	return_path=$(while IFS= read -r line; do if [[ "$line" == "$temp_path"* ]]; then printf '%s\n' "$line"; break; fi; done <<<"$files") # This is probably ass but grep is annoying bc of requiring regex escaping
	if [ -d "${return_path//\\/}" ]; then
		_color="$_directory_color"
	else
		_color="$_file_color"
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
		else
			_man_args=$(man -Tascii "$man_string" | col -bx | grep -F '-' | tr ' ' $'\n' )
			# This take 0.3 seconds each for the bash page, of which 0.013 is the sorting
			# 0.190 IS RIDICULOUS, but also that bc bash's docs are 10,000 pages or smth
			# -Tascii take this down by ~0.030 but even then its borderline unusable, all bc of pointless formatting bs
		fi
		_man_args=$(<<< "${_man_args//[^[:alpha:]]$'\n'/$'\n'}" grep -- '^-'| uniq)
		_temp=''
		_man_args=$(printf '%s' "$_man_args" | sed -e 's/[^[:alnum:]]$//g')
	fi
	return_args=$(printf '\n%s' "$_man_args" | grep -m1 -F -- "$opt_string") 2>/dev/null
	_color="$_option_color"
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
		eval "$PROMPT_COMMAND"
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
