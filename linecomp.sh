#!/usr/bin/env bash

# linecomp
# readline "replacment" for bash

# If you inted to commit code, i hope you have the patience of a saint, because
# I am a bad programmer, and i'm an even worse social programmer

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

trap "history -a && echo linecomp exited" EXIT
trap 'ctrl-c' INT SIGINT


if [[ -z "$HISTFILE" ]];
then
	HISTFILE="~/.bash_history"
fi

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
	string=
	suggest=
	post_prompt=
	printf '\e[s'
	print_command_line
}

search_escape() {
	search_term=$(printf '%q' "$search_term" )
}

history_completion() {
	set -o history
	history_args=$( history | tac | cut -c 8- | grep -m1 '^'"$string")
	history_args=$(<<<"$history_args" cut -c $(( ${#string} + 1 ))- )
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
	elif [[ "$(ls)" == *"$dir_suggest"* ]]; # Directory in current pwd
	then
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
	local man_string
	man_string="$1"
	command_one="${man_string%% *}"
	command_end="${man_string##* }"
	if [[ "${man_string##* }" == '-'* ]] && [[ "${#command_end}" -le 1 ]];
	# IK there are commands that dont start with - but thats for later
	# Command length just makes sure it doesnt re-check every time, mega speed increase
	then
		if [[ "$OSTYPE" == *darwin* ]];
		then
			man_args=$(man "$command_one" | col -bx | grep -F '-' | tr ' ' $'\n' | sed 's/[^[:alpha:]]$//g' | grep -- '^-'| uniq)
		else
			man_args=$(man -Tascii "$command_one" | col -bx | grep -F '-' | tr ' ' $'\n' | sed 's/[^[:alpha:]]$//g' | grep -- '^-'| uniq)
			# This take 0.3 seconds each for the bash page, of which 0.013 is the sorting
			# 0.190 IS RIDICULOUS, but also that bc bash's docs are 10,000 pages or smth
			# -Tascii take this down by ~0.030 but even then its borderline unusable, all bc of pointless formatting bs
		fi
	fi
}

command_completion() {
	case "${string//[[:alpha:]]}" in
	*'| '*)
		has_pipe=true
		comp_string="${string##*| }" ;;
	*'$( '*)
		has_pipe=true
		comp_string="${string##*'$( '}" ;;
	*'& '*)
		has_pipe=true
		comp_string="${string##*'& '}" ;;
	*)
		has_pipe=false
		comp_string="$string" ;;
	esac
	subdir_completion 2>/dev/null
	history_completion #2>/dev/null
	case "$comp_string" in
	*' '|*' '*)
		man_completion "$comp_string" 2>/dev/null
		args="$history_args"$'\n'"$files"$'\n'"$man_args"
		args=$(grep -F -m1 -- "${string##* }" <<<"$args")
		suggest="${string% *} $args" ;;
	*)
		args="$history_args"$'\n'"$files"$'\n'"$commands"
		args=$(grep -F -m1 -- $'\n'"${comp_string##* }" <<<"$args")
		suggest="${string% *}$args" ;;
	esac
	post_prompt="$suggest"
}

self-insert() {
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

hist_suggest() {
	set -o history
	if [[ $histpos -le 0 ]]; then ((histpos=0)); fi
	if [[ $histpos -ge $histmax ]]; then ((histpos=histmax)); fi
	if [[ $histpos == 0 ]];
	then
		suggest=""
	else
		suggest="$(history $histpos | head -1 | cut -c 8-)"
	fi
	post_prompt="$suggest"
}

finish_complete() {
	if [[ -n "${post_prompt:${#string}}" ]];
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
		*)
			if [[ $(bash -nc "$string" 2>&1) == *'unexpected end of file'* ]];
			then
				string+=$'\n'
				((curpos+=1))
			else
				reading=false
			fi ;;
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

quoted-insert() {
	read -rsn1 mode
	self-insert
	while true;
	do
		read -rsn1 -t 0.001 mode
		if [[ -z "$mode" ]];
		then
			return
		else
			self-insert
		fi
	done	
}

read_in_paste() {
	# bad way to do direct read in, cry abt it
	echo
	echo 'reading in'
	while true;
	do
		read -rsn1 -t 0.001 mode
		if [[ -z "$mode" ]];
		then
			return
		else
			self-insert
		fi
	done
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
		histpos=0

		IFS=''
		oldifs=$IFS
		while [[ "$reading" == "true" ]];
		do
			printed_var=$(print_command_line)
			echo -n "$printed_var"
			read -rsn1 mode
			case "$mode" in
				# Escape characters
				$'\e')
					read -rsn2 mode
					case "$mode" in
						# Cursor
						"[C") if [[ "$curpos" -ge "${#string}" ]]; then finish_complete; fi && cursor_move ;;
						"[D") cursor_move ;;
						'[A') ((histpos+=1)) && hist_suggest ;;
						'[B') ((histpos-=1)) && hist_suggest ;;
						'[1')	# Ctrl + arrows
							read -rsn3 mode
							case "$mode" in
								';5C') next-word ;;
								';5D') prev-word ;;
							esac ;;
						'[2')
							clear
							read_in_paste ;;
						'[3')
							if [[ ${#string} -gt 0 ]]; then
								del_from_string
							fi
							read -rsn1 _ ;; # Get rid of ~ after delete
						'[5')
							histpos=$histmax
							hist_suggest
							read -rsn1 _ ;;
						'[6')
							histpos=0
							hist_suggest
							read -rsn1 _ ;;
						'')
							printf '' ;; # Single escape, useful for vi mode later
					esac ;;
				# Ctrl characters
				$'\ca') curpos=0 ;;
				$'\cc') ctrl-c ;; # This is mostly fallback, the actual thing for Ctrl c is the SIGINT trap above
				$'\cd') [[ -z "$string" ]] && exit ;;
				$'\ce') curpos=${#string} ;;
				$'\c?'|$'\ch') backspace_from_string ;;
				$'\cl') clear; printf '\e[H\e7' ;;
				$'\co') reading=0 ;;
				$'\cv') quoted-insert ;;
				$'\c'*) printf '' ;; # This is redundant, ctrl codes cant be wildcarded
				# Rest
				$'\t') finish_complete && curpos=${#string} ;;
				"") multi_check ;; # $'\n' doesnt work idk y
				[[:print:]])
					self-insert
					command_completion ;;
				#*) self-insert && command_completion ;;
			esac
			color=$c1
		done
		printf "\n"

		stty "$default_term_state"
		set -o history
		history -s "$string"
		eval -- "$string" # I hate this, and you should know that i hate it
		stty -echo

		printf '\e7'
		IFS=$oldifs
		suggest=""
		post_prompt=""
		curpos=0
	done
}

commands=$(compgen -c | sort -u | awk '{ print length, $0 }' | sort -n -s | cut -d" " -f2- )
default_term_state=$(stty -g)
stty -echo
main_loop
stty "$default_term_state"
printf "\nlinecomp exited"
