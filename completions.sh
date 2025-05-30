# Completions

comp_complete() {
	# We sadly need it to interpret backslashes for directory names
	line_array=($READLINE_LINE)
	line_array=( "${line_array[@]// /\\ }" )
	local comp_array=( )

	if [[ "${#line_array[@]}" -gt 1 ]]
	then
		case "${line_array[-1]}" in
			'-'*) 
				man_completion "${line_array[0]}" "${line_array[-1]}"
				readarray -t comp_array <<<"$return_args"
				_color="$_option_color" ;;
			*)
				dir_suggest "${line_array[-1]}"
				readarray -t comp_array <<<"$return_path"
				_color="$_directory_color" ;;
		esac
	else
		readarray -t comp_array <<<"$_commands"
		_color="$_command_color"
	fi

	_post_prompt=""
	for line in "${comp_array[@]}"
	do
		case "$line" in
			"${line_array[-1]}"*)
				line_array[-1]="$line"
				_post_prompt="${line_array[*]}"
				break ;;
		esac
	done
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
			_man_args=$(man "$man_string" | col -bx | grep -F '-' | tr ' ' $'\n') 2>/dev/null
		else
			_man_args=$(man -Tascii "$man_string" | col -bx | grep -F '-' | tr ' ' $'\n' ) 2>/dev/null
			# This take 0.3 seconds each for the bash page, of which 0.013 is the sorting
			# 0.190 IS RIDICULOUS, but also that bc bash's docs are 10,000 pages or smth
			# -Tascii take this down by ~0.030 but even then its borderline unusable, all bc of pointless formatting bs
		fi
		_man_args=$(<<< "${_man_args//[^[:alpha:]]$'\n'/$'\n'}" grep -- '^-'| uniq)
		_temp=''
		_man_args=$(printf '%s' "$_man_args" | sed -e 's/[^[:alnum:]]$//g')
	fi
	return_args="$_man_args"
}
