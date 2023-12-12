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
elif [[ "$(set -o | grep vi)" == *'on' ]]
then
	echo "You have vi-mode set!"
	echo "vi-mode is not currently implemented, so you will be forced to use your emacs mode currently"
fi

_linecomp_path="${BASH_SOURCE%/*}"
case "$_linecomp_path" in
	"linecomp.sh") _linecomp_path="" ;;
	*)	_linecomp_path="${_linecomp_path}/" ;;
esac

source "$_linecomp_path"readline_funcs.sh
source "$_linecomp_path"completions.sh

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
	readarray -t _hist_array < <(history | awk '{$1=""; print $0}')
	HISTORY_POINT="${#_hist_array[@]}"
}

# Meta

print_command_line() {
	local whole_line part_line

	whole_line="${READLINE_LINE//$'\n'/$'\n'${PS2@P}}"
	whole_line="${whole_line//$'\e'/^[}"

	part_line="${READLINE_LINE:0:$READLINE_POINT}"
	part_line="${part_line//$'\n'/$'\n'${PS2@P}}"
	part_line="${part_line//$'\e'/^[}"

	printf '\e8%s%s\e[%sm%s\e[0m\e[K\e8%s%s' \
		"${PS1@P}" \
		"$whole_line" \
		"$_color" \
		"${_post_prompt:${#READLINE_LINE}}" \
		"${PS1@P}" \
		"$part_line"
}

# Other

main_func() {
	history_get
	HISTORY_POINT="${#_hist_array[@]}"
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
