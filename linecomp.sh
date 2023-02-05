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
if [[ "$(ps -p $$)" != *"bash"* ]];
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


escape_char=$(printf "\u1b")
new_line=$(printf "\n")
back_space=$(printf $'\177')
delete_char="[3"
tab_char=$(printf "\t")
post_prompt=""
curpos=0
suggest=""
histmax=$(wc -l "$HISTFILE" | awk '{print $1}')

read -r -d R p_start < <(printf '\e[6n')

for code in {0..7}
do
	declare c$code=$(printf "\e[3"$code"m")
done

printf '\e7'

ctrl-c() { # I think how this works in normal bash is that reading the input is a subprocess and Ctrl-c'ing it just kills the process
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
	history_args=$(cat "$HISTFILE" | tac | grep -m1 -F "$string")
	history_args="${history_args%%$'\n'*}"
	history_args="${history_args##* }"
}

subdir_completion() {
	search_term=''
	dir_suggest="${string##* }"
	if [[ -d "${dir_suggest%'/'*}" ]] && [[ "$dir_suggest" == *"/"* ]]; # Subdirectories
	then
		folders="${dir_suggest%'/'*}/"
		search_term="${dir_suggest/$folders}"
		search_escape
		files="$folders"$(ls "${dir_suggest%'/'*}" | grep -v '\.$' | grep -- '^'"$search_term" | sort -n)
	else # Directory in current pwd
		search_term="$dir_suggest"
		search_escape
		files=$(ls | grep -v '\.$' | grep -- '^'"$search_term" | sort -n)
	fi
	files="${files%%$'\n'*}" # THis looks more wasteful than it is
	files=$(printf '%q' "$files")
	files="$files/" # Fix files with spaces
	if ! [[ -d "$files" ]] || [[ -z "$files" ]]; # Remove / if not directory or string empty
	then
		files="${files:0:-1}"
	fi
}

man_completion() {
	command_one="${string%% *}"
	man_args=$(man "$command_one" | col -bx | grep '-' | tr ' ' $'\n' | sed 's/[^[:alpha:]]$//g' | grep '^-' )
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
	case "$string" in
		*"EOM"*"EOM"*|*"EOF"*"EOF"*) reading=false ;;
		*'\'|*"EOM"*|*"EOF"*) string+=$'\n'
			((curpos+=1)) ;;
		*) reading=false ;;
	esac
}

print_command_line() {
	# This doesnt technichally need to be a different function but it reduced jitteriness to run all of it into a variable and print it all at once
	# This is slow as a mf (urgent fix)

	temp_str="${string//$'\n'/$'\n'${PS2@P}}"
	printf "\e8\e[?25l\e[K"

#	echo -n "$prompt$string"
	echo -n "$prompt$temp_str$color${post_prompt:${#string}}"
	printf '\e[K\e8'
	newline_count=$(grep -c $'\n' <<<"${string:0:$curpos}")
	cur_temp=$((curpos + $(( newline_count * 2 )) ))
	echo -n "$prompt${temp_str:0:$curpos}" # Very wasteful, will cause a speed issue
			# ^^^^^^^^ Its cut by temp_str so cursor displacement is from the 1 char \n becoming a 2 char '> '
	printf '\e[0m\e[?25h'
	#^^^^^^^^^^^^^^^^^^^^Making all of this a one-liner would be heaven for performance, unfortunately its pretty hard if not impossible
	# Add to target list
}

ctrl-left() {
	ctrl_left="${string:0:$curpos}"
	ctrl_left="${ctrl_left% *}"
	curpos="$(( ${#ctrl_left} ))"
}

ctrl-right() {
	ctrl_right="${string:$(( curpos + 1 ))} "
	ctrl_right="${ctrl_right#* }"
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
			if [[ "$mode" == "$escape_char" ]]; # Stuff like arrow keys etc
			then
				read -rsn2 mode
				case "$mode" in # Read 1 more to discard some stuff
					'[3') read -rsn1 discard ;; # Pg up / down, discard for now
					'[1') read -rsn3 mode ;; # Ctrl + arrows
				esac
			fi
			case "$mode" in
				# Specials
				"$new_line")	multi_check ;; #reading="false";;
				"$back_space"|''|'')	backspace_from_string ;;
				"$delete_char")	if [[ ${#string} -gt 0 ]]; then del_from_string; fi ;;
				"$tab_char") 	finish_complete  && curpos=${#string} ;;
				# Cursor
				*';5C') ctrl-right ;;
				*';5D') ctrl-left ;;
				*';'*'A'|*';'*'B'|*';'*'C'|*';'*'D') printf '' ;; # Non-ctrl arrow modifiers
				"[C") if [[ "$curpos" -ge "${#string}" ]]; then finish_complete; fi && cursor_move ;;
				"[D") cursor_move ;;
				'[A') hist_up ;;
				'[B') hist_down ;;
				# Control characters, may vary by system but idk
				$'\001') curpos=0 ;;
				$'\002') ctrl-c ;; # This is mostly fallback, the actual thing for Ctrl c is the SIGINT trap above
				$'\004') [[ -z "$string" ]] && exit ;;
				$'\005') curpos=${#string} ;;
				# Ctrl sequences (many unknown)
				$'\017') reading=0 ;; # Ctrl O
				$'\022') printf '' ;; # Ctrl R
				$'\027') string="" ;;
				# Catch undefined escapes (doesnt work)
				$'\01'*) printf "C 1 caught" ;;
				$'\02'*) printf "C 2 caught" ;;
				$'\v'*) printf "" ;; # Ctrl K
				$'\b'*) printf "" ;; # Ctrl H
				$'\f'*) printf "" ;; # Ctrl L
				'['[:alpha:]|'['[0-9]) printf '' ;; # discard unknown
				[a-zA-Z0-9]) add_to_string &&  command_completion ;; # Only autocomplete on certain characters for performance
				*) add_to_string ;;
			esac
			color=$c1
		done
		printf "\n"
		if ! [[ -z "$string" ]]; then echo "${string//$'\n'/; }" >> "$HISTFILE"; fi
		# Pretend stuff just works

		set -o history
		stty echo
		eval -- "$string" # I hate this, and you should know that i hate it pls
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


