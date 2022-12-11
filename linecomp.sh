#!/usr/bin/env bash

# linecomp
# readline "replacment" for bash
# arguments for command in ~/.local/share/linecomp.txt with syntax
# git add,push,commit,etc

# Check that current shell is bash
if [[ "$(ps -p $$)" != *"bash"* ]];
then
	echo "Your current shell is not bash!"
	echo "Many features will not work!"
fi



trap "echo linecomp exited" EXIT
trap 'ctrl-c' INT SIGINT

if [[ -z "$HISTFILE" ]];
then
	HISTFILE="~/.bash_history"
fi


escape_char=$(printf "\u1b")
new_line=$(printf "\n")
back_space=$(printf "\177")
delete_char="[3"
tab_char=$(printf "\t")
post_prompt=""
curpos=0
suggest=""
histmax=$(wc -l "$HISTFILE" | cut -d ' ' -f1 )

for code in {0..7}
do
	declare c$code=$(printf "\e[3"$code"m")
done

commands_get() {
	commands=$(compgen -c | sort -u | awk '{ print length, $0 }' | sort -n -s | cut -d" " -f2- )
}

ctrl-c() { # I think how this works in normal bash is that reading the input is a subprocess and Ctrl-c'ing it just kills the process
	echo "^C"
	string=''
	printf "$prompt"
	curpos=0
}

search_escape() {
	#search_term=$(sed 's/[^^]/[&]/g; s/\^/\\^/g; s/\\ / /g' <<<"$search_term") # Escape regex chars for grep
	# This is horribly, awfully inefficient. fix later
	search_term="${search_term//\\ / }"
}

subdir_completion() {
	search_term=''
	if [[ -d "${two%'/'*}" ]]; # Subdirectories
	then
		if [[ "$two" == *"/"* ]];
		then
			folders="${two%'/'*}/"
			search_term="${two/$folders}"
			search_escape
			files="$folders"$(ls "${two%'/'*}" | grep -v '\.$' | grep -- '^'"$search_term" )
		fi
	else # Directory in current pwd
		search_term="$two"
		search_escape
		files=$(ls | grep -v '\.$' | grep -- '^'"$search_term" )
	fi
	files="${files%%$'\n'*}/"
	files="${files// /\\ }" # Fix files with spaces
	if ! [[ -d "$files" ]] || [[ -z "$files" ]]; # Remove / if not directory or string empty
	then
		files="${files:0:-1}"
	fi
}

arg_completion() {
	args=''
	files=''
	search_term="$command"
	search_escape
	args=$(cat ~/.local/share/linecomp.txt | grep -v '^#' | grep -- '^'"$search_term" | cut -d ' ' -f2 | tr ',' '\n' )
	if [[ "$args" == *'$commands'* ]];
	then
		args="$commands"
	fi
	if [[ "$args" == *'$files'* ]] || [[ -z "$arg" ]]; # if command isnt listed or has files enabled as suggestions then add subdir
	then
		args="${args//'$files'/}"
		subdir_completion
	fi

	search_term="$two"
	search_escape
	all=$(printf "$args\n$files" | grep -- '^'"$search_term" )
	two="${all%%$'\n'*}"
}

command_completion() {
	case "$string" in
		*"|"*) # Pipes
			one="${string%'|'*}| "
			two="${string/$one}"
			if [[ "$two" == *"./"* ]]; # In case of local execuatable
			then
				one="${string%'|'*}| ./"
				two="${string/$one}"
				arg_completion
				color=$c2
				suggest="$one$two"
			else
				search_term="$two"
				tabbed=$(grep -F "$search_term" <<<"${commands[@]}")" " 2>/dev/null # grep errors
				suggest="$one${tabbed%%$'\n'*}"
			fi ;;
		"./"*) # Executable in current directory
			one="./"
			two="${string:2}"
			arg_completion
			color=$c2
			suggest="$one$two" ;;
		*" "*) # Files/folders/arguments
			command="${string%%' '*}"
			one="${string%' '*}"
			two="${string/$one }"
			arg_completion 2>/dev/null # Just throws grep errors away, they mostly dont  break anything anyway (stuff with [ in the filename wont get suggested but thats such an edge case that idc)
			suggest="$one $two" ;;
		*) # Globally available commands
			search_term="$string"
			tabbed=$(grep -F "$search_term" <<<"${commands[@]}")" " 2>/dev/null # Same here
			suggest="${tabbed%%$'\n'*}" ;;
	esac
	if ! [[ -z "$string" ]];
	then
		post_prompt="$suggest"
	fi
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

hist_search() {
	printf ''
}

finish_complete() {
	if [[ "${#post_prompt}" -gt 1 ]];
	then
		string="$post_prompt"
		curpos=${#string}
	fi
}

multi_check() {
	if [[ "${string:$(( ${#string} - 1 ))}" == '\' ]];
	then
		reading='false'
		#string="$( sed 's/\\$//g' <<<"$string")"
	else
		reading='false'
	fi
}

print_command_line() {
	running=true
	while [[ $running == true ]];
	do
		reading="true"
		prompt="${PS1@P}"
		string=''
		histmax=$(( $(wc -l "$HISTFILE" | cut -d ' ' -f1) + 1 ))
		histpos=$histmax

		oldifs=$IFS
		IFS=''
		while [[ "$reading" == "true" ]];
		do
			printf "\e[2K\r$prompt" # Yeah, yeah, its slower to split it, bu its way easier to debug
			echo -n "${string:0:$curpos}" # Needs to be seperate for certain characters
			printf "\e7" # Save cursor position
			echo -n "${string:$curpos}"
			echo -n "$color${post_prompt:${#string}}"
			printf '\e[0m\e8'

			read -rsn1 mode
			if [[ "$mode" == "$escape_char" ]]; # Stuff like arrow keys etc
			then
				read -rsn2 mode
				if [[ "$mode" == "[3" ]]; # Read 1 more to discard some stuff
				then
					read -rsn1 discard
				fi
			fi
			case "$mode" in
				# Specials
				"$new_line")	multi_check ;; #reading="false";;
				"$back_space")	if [[ ${#string} -gt 0 ]] && [[ $curpos -gt 0 ]]; then backspace_from_string; fi ;;
				"$delete_char")	if [[ ${#string} -gt 0 ]]; then del_from_string; fi ;;
				"$tab_char") finish_complete  && curpos=${#string} ;;
				# Cursor
				"[C")	if [[ "$curpos" -ge "${#string}" ]]; then finish_complete; fi
					if [[ $curpos -lt ${#string} ]]; then ((curpos+=1)); fi ;;
				"[D") [[ "$curpos" -gt 0 ]] && ((curpos-=1)) ;;
				# Discardabl regexes
				#"^[A-Z]"*) printf ;;
				'[A') hist_up ;;
				'[B') hist_down ;;
				# Control characters, may vary by system but idk
				$'\001') curpos=0 ;;
				$'\002') ctrl-c ;; # This is a placeholder, the actual thing for \C-c is the SIGINT trap above
				$'\004') [[ -z "$string" ]] && exit ;;
				$'\005') curpos=${#string} ;;
				$'\022') printf '' ;; # History search placeholder
				$'\027') string="" ;;
				# Catch undefined escapes
				$'\01'*) printf "C 1 caught" ;;
				$'\02'*) printf "C 2 caught" ;;
				*) 	add_to_string ;;
			esac
			color=$c1
			command_completion
		done
		printf '\n'
		if ! [[ -z "$string" ]]; then echo "$string" >> "$HISTFILE"; fi
		eval "${string//\\ / }" # I hate this, and you should know that i hate it pls ALSO the shell expansion for '\ ' removal could cause edgecase issues
		history >/dev/null # Trim history according to normal bash
		IFS=$oldifs
		suggest=""
		post_prompt=""
		curpos=0
	done
}

# ble.sh uses bind -x

#key_binds
commands_get
print_command_line
printf "\nlinecomp exited"
