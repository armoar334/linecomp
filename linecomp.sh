#!/usr/bin/env bash

# linecomp
# readline "replacment" for bash

# ABANDON ALL HOPE YE WHO ENTER HERE!
# If you inted to commit code, i hope you have the patience of a saint, because
# I am NOT a good programmer, and i'm an even worse social programmer
# Style guides? no
# Consistent and readable comments? You wish!

# ALSO although it __is__ open contribution, its a personal project really
# (and idk how git works), so stuff may not be merged in a timely manner
#FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
# ^^^^ dont worry about this, its just an 80 column ruler

# Check that current shell is bash
# This works under zsh and crashes out on fish, so p much serves its purpose
if [[ "$0" != *"bash"* ]];
then
	echo "Your current shell is not bash!"
	echo "Many features will not work!"
	return
fi

trap "echo linecomp exited" EXIT
trap 'ctrl-c' INT SIGINT

if [[ -z "$HISTFILE" ]];
then
	HISTFILE="~/.bash_history"
fi

new_line=$(printf "\n")
back_space=$(printf $'\177')
delete_char="[3"
post_prompt=""
curpos=0
suggest=""
histmax=$(wc -l "$HISTFILE" | awk '{print $1}')

for code in {0..7}
do
	declare c$code=$(printf "\e[3"$code"m")
done

printf '\e7'

ctrl-c() {
	# I think how this works in normal bash is that reading
	# the input is a subprocess and Ctrl-c'ing it just kills the process
	# We have to do a lot of incomplete mimicry
	echo "^C"
	string=''
	suggest=''
	post_prompt=''
	printf '\e[s'
	print_command_line
}

search_escape() {
	search_term=$(printf '%q' "$search_term" )
}

history_completion() {
	history_args=$( < "$HISTFILE" tac | grep -m1 '^'"$string")
	history_args="${history_args%%$'\n'*}"
	rem_str="${string% *}"
	history_args="${history_args/$rem_str}"
	history_args="${history_args:1}"
}

subdir_completion() {
	search_term=''
	dir_suggest="${string##* }"
	# Subdirectories or pwd
	if [[ -d "${dir_suggest%'/'*}" ]] && [[ "$dir_suggest" == *"/"* ]];
	then
		folders="${dir_suggest%'/'*}/"
		search_term="${dir_suggest/$folders}"
		search_escape
		files="$folders"$(ls "${dir_suggest%'/'*}" | grep -v '\.$' | grep -- '^'"$search_term" | sort -n)
	elif [[ "$dir_suggest" == "/"* ]];
	then
		search_term="${dir_suggest/\/}"
		search_escape
		files=$(ls / | grep -v '\.$' | grep -- '^'"$search_term" | sort -n | sed 's/^/\//g')
	else # Directory in current pwd
		search_term="$dir_suggest"
		search_escape
		files=$(ls | grep -v '\.$' | grep -- '^'"$search_term" | sort -n)
	fi
	files="${files%%$'\n'*}"
	files=$(printf '%q' "$files")
	files="$files/" # Fix files with spaces
	# Remove / if not directory or string empty
	if ! [[ -d "$files" ]] || [[ -z "$files" ]];
	then
		files="${files:0:-1}"
	fi
}

man_completion() {
	command_one="${string%% *}"
	if [[ "${string##* }" == '-'* ]]; # IK there are commands that dont start with this but thats for later
	then
		man_args=$(man -Tascii "$command_one" | col -bx | grep -F '-' | tr ' ' $'\n' | sed 's/[^[:alpha:]]$//g' | grep -- '^-' | uniq)
		# tested on a few things. SSD's work fine, but on my X230 w/ HDD
		# This take 0.2 seconds each, of which 0.013 is the sorting
		# 0.190 IS RIDICULOUS, but also that bc bash's docs are 10,000 pages or smth
	fi
}

command_completion() {
	case "$string" in
	*' '|*' '*)
		man_completion 2>/dev/null
		subdir_completion 2>/dev/null
		history_completion 2>/dev/null
		args="$history_args"$'\n'"$files"$'\n'"$man_args"
		args=$(grep -F -m1 -- "${string##* }" <<<"$args")
		suggest="${string% *} $args" ;;
	*)
		subdir_completion 2>/dev/null
		history_completion 2>/dev/null
		args="$history_args"$'\n'"$files"$'\n'"$commands"
		suggest=$(grep -F -- "${string##* }" <<<"$args")
		suggest="${suggest%%$'\n'*}";;
	esac
	post_prompt="$suggest"
}

add_to_string() {
	string="${string:0:$curpos}$mode${string:$curpos}"
	((curpos+=1))
}

del_from_string() {
	if [[ $curpos -ge 0 ]];
	then
		string="${string:0:$curpos}${string:$(( curpos + 1 ))}"
	fi
}


backspace_from_string() {
	if [[ ${#string} -gt 0 ]] && [[ $curpos -gt 0 ]];
	then
		if [[ $curpos -ge 1 ]];
		then
			((curpos-=1))
		fi
		if [[ $curpos -ge 0 ]];
		then
			if [[ $curpos -ge $(( ${#string} - 1 )) ]];
			then
				string="${string:0:-1}"
			else
				string="${string:0:$curpos}${string:$(( curpos + 1 ))}"
			fi
		fi
	fi
}

hist_down() {
	if [[ $histpos -le $histmax ]]; then ((histpos+=1)); fi
	if [[ $histpos -le $histmax ]];
	then
		suggest="$(sed -n "$histpos"p "$HISTFILE")"
	else
		suggest=""
	fi
	post_prompt="$suggest"
}

hist_up() {
	if [[ $histpos -gt 0 ]]; then ((histpos-=1)); fi
	if [[ $histpos == 0 ]]; then histpos=1; fi
	suggest=$(sed -n "$histpos"p "$HISTFILE")
	post_prompt="$suggest"
}

finish_complete() {
	if [[ ! -z "${post_prompt:${#string}}" ]];
	then
		string="$post_prompt"
		curpos=${#string}
	fi
}

multi_check() {
	#need to make this less suck
	case "$string" in
		*"EOM"*"EOM"*|*"EOF"*"EOF"*) reading=false ;;
		*'\'|*"EOM"*|*"EOF"*) string+=$'\n'
			((curpos+=1)) ;;
		*) reading=false ;;
	esac
}

print_command_line() {
	# This doesnt technichally need to be a different function but it
	# reduced jitter to run it all into a variable and print all at once

	temp_str="${string//$'\n'/$'\n'$PS2exp}"
	printf "\e8\e[?25l\e[K"

	printf '%s\e[K\e8%s' "$prompt$temp_str$color${post_prompt:${#string}}" "$prompt"

	temp_str="${string:0:$curpos}"
	#echo -n "${temp_str//$'\n'/$'\n'$PS2exp}"

	printf '%s\e[0m\e[?25h' "${temp_str//$'\n'/$'\n'$PS2exp}"
}

prev-word() {
	ctrl_left="${string:0:$curpos}"
	ctrl_left="${ctrl_left%[^[:alnum:]]*}"
	curpos="${#ctrl_left}"
}

next-word() {
	ctrl_right="${string:$(( curpos + 1 ))} "
	ctrl_right="${ctrl_right#*[^[:alnum:]]}"
	curpos="$(( ${#string} - ${#ctrl_right} ))"
}

cursor_move() {
	case "$mode" in
		"[C") ((curpos+=1)) ;;
		"[D") ((curpos-=1)) ;;
	esac
	if ((curpos<=0)); then curpos=0; fi
	if ((curpos>=${#string})); then curpos=${#string}; fi
}

main_loop() {
	comp_running=true
	while [[ $comp_running == true ]];
	do
		reading="true"
		prompt="${PS1@P}"
		PS2exp="${PS2@P}"
		string=''
		histmax=$(( $(wc -l "$HISTFILE" | awk '{print $1}') + 1 ))
		histpos=$histmax

		oldifs=$IFS
		IFS=''
		while [[ "$reading" == "true" ]];
		do
			printed_var=$(print_command_line)
			echo -n "$printed_var"
			read -rsn1 mode
			case "$mode" in
				# Escape characters
				$'\e')
					read -rsn2 mode
					case "$mode" in # Read 1 more to discard some stuff
						# Cursor
						"[C") if [[ "$curpos" -ge "${#string}" ]]; then finish_complete; fi && cursor_move ;;
						"[D") cursor_move ;;
						'[A') hist_up ;;
						'[B') hist_down ;;
						'[1')	# Ctrl + arrows
							read -rsn3 mode
							case "$mode" in
								';5C') next-word ;;
								';5D') prev-word ;;
							esac ;;
						'[3')
							if [[ ${#string} -gt 0 ]]; then
								del_from_string
							fi
							read -rsn1 _ ;; # Get rid of ~ after delete
					esac ;;
				# Ctrl characters
				$'\ca') curpos=0 ;;
				$'\cc') ctrl-c ;; # This is mostly fallback, the actual thing for Ctrl c is the SIGINT trap above
				$'\cd') [[ -z "$string" ]] && exit ;;
				$'\ce') curpos=${#string} ;;
				$'\c?'|$'\ch') backspace_from_string ;;
				$'\co') reading=0 ;;
				$'\c'*) printf '' ;; # This is redundant, ctrl codes cant be wildcarded
				# Rest
				$'\t') finish_complete && curpos=${#string} ;;
				"$newline") multi_check ;; # $'\n' doesnt work idk y
				"$delete_char")	if [[ ${#string} -gt 0 ]]; then del_from_string; fi ;;
				*) add_to_string && command_completion ;;
			esac
			color=$c1
		done
		printf "\n"
		if ! [[ -z "$string" ]]; then echo "${string//\\$'\n'/}" >> "$HISTFILE"; fi
		# Pretend stuff just works

		set -o history
		stty echo
		eval -- "$string" # I hate this, and you should know that i hate it
		stty -echo
		set +o history

		printf '\e7'
		IFS=$oldifs
		suggest=""
		post_prompt=""
		curpos=0
	done
}

commands=$(compgen -c | sort -u | awk '{ print length, $0 }' | sort -n -s | cut -d" " -f2- )
stty -echo
main_loop
stty echo
printf "\nlinecomp exited"


