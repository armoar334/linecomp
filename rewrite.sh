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
		bind -p | grep -v '^#'
	)
	
	escape_binds=$(
		<<<"$raw_binds" grep -F '"\e'
	)
	
	ctrl_binds=$(
		<<<"$raw_binds" grep -F '"\C'		
	)
	
	insert_binds=$(
		<<<"$raw_binds" grep -F 'self-insert'
	)

	linecomp_case=$(
		echo 'case $_char in'
		# Escapes
		echo -ne '\t' 
		echo '$'"'\e') echo escpae ;;"

		# Sub-escapes
		# None of this technichally needs to be indented but its easier to read for debugging
		#echo -e '\t\t_temp=""'
		#echo -e '\t\tuntil [[ -z "$_char" ]]; do'
		#echo -e '\t\t\tread -rsn1 _char'
		#echo -e '\t\t\t_temp+="$_char"'
		#echo -e '\t\tdone'
		#echo -e '\t\tcase "$_char" in'
		#echo "${escape_binds//\"\\e/}" | grep -v -F '\C' | sed -e "s/^/\t\t\t'/g" -e 's/": /) /g'
		# Multi ctrl/esc sequences are too much hassle atm, so ignore
		#echo -e '\t\tesac'

		echo -ne '\t'
		echo "'q') _reading='false' && return ;;"
		# Self-insertion characters
		echo "${insert_binds//\"\\2/\$\"\\2}" | sed -e 's/^/\t/g' -e 's/: /) /g' -e 's/$/ ;;/g' -e 's/`/\\\`/g'
		
		echo 'esac'
	)

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

self-insert() {
	_string+="$_char"
}

main_loop() {
	comp_running=true
	while [[ $comp_running == true ]];
	do
		_reading="true"
		_prompt="${PS1@P}"
		_PS2exp="${PS2@P}"
		_string=''
		_color="$(printf '\e[31m')"
		_post_prompt='placeholder'

		while [[ "$_reading" == "true" ]];
		do
			echo -n "$(print_command_line)"
			read -rsn1 _char
			eval -- "$linecomp_case"
		done
	done
}

echo
printf '\e[7'
compose_case
#main_loop
echo "$linecomp_case"

