#!/usr/bin/env bash

# linecomp
# readline "replacment" for bash
# arguments for command in ~/.local/share/linecomp.txt with syntax
# git add,push,commit,etc

trap "echo linecomp exited" EXIT
trap 'ctrl-c' INT SIGINT

escape_char=$(printf "\u1b")
new_line=$(printf "\n")
back_space=$(printf "\177")
delete_char="[3"
tab_char=$(printf "\t")
post_prompt=""
curpos=0
suggest=""
histmax=$(wc -l ~/.bash_history | cut -d ' ' -f1 )

for code in {0..7}
do
	declare c$code=$(printf "\e[3"$code"m")
done

commands_get() {
	commands=$(compgen -c | sort -u | awk '{ print length, $0 }' | sort -n -s | cut -d" " -f2- ) # Add ones at the beginning to prioritise
}

ctrl-c() {
	echo "^C"
	string=''
	printf "$prompt"
	curpos=0
}

search_escape() {
	#printf ''
	#search_term=$(sed 's/[^^]/[&]/g; s/\^/\\^/g; s/\\ / /g' <<<"$search_term") # Escape regex chars for grep
	# This is horribly, awfully inefficient. fix later
	search_term="${search_term//\\ / }"
	search_term="${search_term//[/'['}"
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
	args=$(cat ~/.local/share/linecomp.txt | grep -v '^#' | grep -- "$search_term" | cut -d ' ' -f2 | tr ',' '\n' )
	if [[ "$args" == *'$commands'* ]];
	then
		args="$commands"
	fi
	if [[ "$args" == *'$files'* ]] || [[ -z "$arg" ]]; # if command isnt listed or has files enabled as suggestions then add subdir
	then
		args="${args//'$files'/}"
		subdir_completion
	else
		files=""
	fi

	search_term="$two"
	search_escape
	all="$args $files"
	all=$(echo "$all" | tr ' ' "\n" | grep -- '^'"$search_term" )
	two="${all%%$'\n'*}"
}

command_completion() {
	case "$string" in
		"./"*) # Executable in current directory
			one="./"
			two="${string:2}"
			subdir_completion
			suggest="$one$two" ;;
		*"| ./"*) # Pipe to local executable
			# Having this hardcoded sucks but its fine until i fix the interpretation system
			one="${string%%'|'*}| ./"
			two="${string/$one}"
			subdir_completion
			suggest="$one$two" ;;
		*"|"*) # Pipes
			one="${string%%'|'*}| "
			two="${string/$one}"
			search_term="$two"
			search_escape
			tabbed=$(grep -- '^'"$search_term" <<<"${commands[@]}")" " 2>/dev/null # Same here
			suggest="$one${tabbed%%$'\n'*}" ;;
		*" "*) # Files/folders/arguments
			command="${string%%' '*}"
			one="${string%' '*}"
			two="${string/$one }"
			arg_completion 2>/dev/null # Just throws grep errors away, they mostly dont  break anything anyway (stuff with [ in the filename wont get suggested but thats such an edge case that idc)
			suggest="$one $two" ;;
		*) # GLobally available commands
			search_term="$string"
			search_escape
			tabbed=$(grep -- '^'"$search_term" <<<"${commands[@]}")" " 2>/dev/null # Same here
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
		suggest="$(sed -n "$histpos"p ~/.bash_history)"
	else
		suggest=""
	fi
	post_prompt="$suggest"
}

hist_up() {
	if [[ $histpos -gt 0 ]]; then ((histpos-=1)); fi
	if [[ $histpos == 0 ]]; then histpos=1; fi
	suggest=$(sed -n "$histpos"p ~/.bash_history)
	post_prompt="$suggest"
}

finish_complete() {
	if [[ "${#post_prompt}" -gt 1 ]];
	then
		string="$post_prompt"
		curpos=${#string}
	fi
}

print_command_line() {
	running=true
	while [[ $running == true ]];
	do
		prompt="${PS1@P}"
		reading="true"
		string=()
		histmax=$(( $(wc -l ~/.bash_history | cut -d ' ' -f1) + 1 ))
		histpos=$histmax
		color=$(printf '\e[31m')

		oldifs=$IFS
		IFS=''
		while [[ "$reading" == "true" ]];
		do
			printf "\e[2K\r$prompt" # Yeah, yeah, its slower to split it, bu its way easier to debug
			echo -n "${string:0:$curpos}" # Needs to be seperate for certain characters
			printf "\e7" # Save cursor position
			echo -n "${string:$curpos}"
			printf "$c1${post_prompt:$curpos}\e[0m\e8"
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
				"$new_line")	reading="false";;
				"$back_space")	if [[ ${#string} -gt 0 ]] && [[ $curpos -gt 0 ]]; then backspace_from_string; fi ;;
				"$delete_char")	if [[ ${#string} -gt 0 ]]; then del_from_string; fi ;;
				"$tab_char") finish_complete  && curpos=${#string} ;;
				# Cursor
				"[C")	if [[ $curpos -lt ${#string} ]]; then ((curpos+=1)); fi
					if [[ "$curpos" -ge "${#string}" ]]; then finish_complete; fi ;;
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
				$'\027') string="" ;;
				# Catch undefined escapes
				$'\01'*) printf "C 1 caught" ;;
				$'\02'*) printf "C 2 caught" ;;
				*) 	add_to_string ;;
			esac
			command_completion
		done
		printf '\n'
		eval "$string" # I hate this, and you should know that i hate it pls
		IFS=$oldifs
		echo "$string" >> ~/.bash_history
		suggest=""
		post_prompt=""
		curpos=0
	done
}

# ble.sh uses bind -x

#key_binds
commands_get
print_command_line
echo "linecomp exited"
