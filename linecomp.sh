#!/usr/bin/env bash

# linecomp
# posix readline "replacment" for bash
# arguments for command in ~/.local/share/linecomp.txt with syntax
# git add,push,commit,etc

trap "echo linecomp exited" EXIT
trap 'echo "^C" && string='' && printf "$prompt"' INT SIGINT

escape_char=$(printf "\u1b")
new_line=$(printf "\n")
back_space=$(printf "\177")
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
	commands=("$(compgen -c | sort -u )" ) # Add ones at the beginning to prioritise
}

search_escape() {
	#printf ''
	#search_term=$(sed 's/[^^]/[&]/g; s/\^/\\^/g; s/\\ / /g' <<<"$search_term") # Escape regex chars for grep
	# This is horribly, awfully inefficient. fix later
	search_term="${search_term//\\ / }"
	search_term="${search_term//[/'['}"
}

subdir_completion() {
	arg_completion
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
	all="$files$args"
	two="${all%%$'\n'*}/"
	two="${two// /\\ }" # Fix files with spaces
	if ! [[ -d "$two" ]] || [[ -z "$two" ]]; # Remove / if not directory or string empty
	then
		two="${two:0:-1}"
	fi

}

arg_completion() {
	search_term="$command"
	search_escape
	args=$(cat ~/.local/share/linecomp.txt | grep -- "$search_term" | cut -d ' ' -f2 | tr ',' '\n' )
	if [[ "$args" == *'$commands'* ]];
	then
		args="$commands"
	fi
	search_term="$two"
	search_escape
	args=$(echo "$args" | tr ' ' "\n" | grep -- "$search_term" )
}

command_completion() {
	case "$string" in
		"./"*) # Executable in current directory
			one="./"
			two="${string:2}"
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
			subdir_completion 2>/dev/null # Just throws grep errors away, they mostly dont  break anything anyway (stuff with [ in the filename wont get suggested but thats such an edge case that idc)
			suggest="$one $two" ;;
		*) # GLobally available commands
			search_term="$string"
			search_escape
			tabbed=$(grep -- '^'"$search_term" <<<"${commands[@]}")" " 2>/dev/null # Same here
			suggest="${tabbed%%$'\n'*}" ;;
	esac
	if [[ -z "$string" ]];
	then
		post_prompt=""
	else
		post_prompt="${suggest:${#string}}"
	fi
}

add_to_string() {
	string="${string:0:$curpos}$mode${string:$curpos}"
	((curpos+=1))
}

del_from_string() {
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
	if [[ $histpos -lt $histmax ]]; then ((histpos+=1)); fi
	suggest="$(sed -n "$histpos"p ~/.bash_history)"
}

hist_up() {
	if [[ $histpos -gt 0 ]]; then ((histpos-=1)); fi
	if [[ $histpos == 0 ]]; then histpos=1; fi
	suggest="$(sed -n "$histpos"p ~/.bash_history)"
}


print_command_line() {
	running=true
	while [[ $running == true ]];
	do
		prompt="${PS1@P}"
		reading="true"
		string=()
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
			printf "$color$post_prompt\e[0m\e8"
			read -rsn1 mode
			if [[ "$mode" == "$escape_char" ]]; # Stuff like arrow keys etc
			then
				read -rsn2 mode
			fi
			case "$mode" in
				# Specials
				"$new_line")	reading="false";;
				"$back_space")	if [[ ${#string} -gt 0 ]]; then del_from_string; fi ;;
				"$tab_char") string="$suggest" && curpos=${#string} ;;
				# Cursor
				"[C") if [[ "$curpos" -ge "${#string}" ]] && [[ "${#suggest}" -gt 1 ]]; then string="$suggest"; curpos=${#string}; fi && if [[ $curpos -lt ${#string} ]]; then ((curpos+=1)); fi ;;
				"[D") [[ "$curpos" -gt 0 ]] && ((curpos-=1)) ;;
				# Discardabl regexes
				#"^[A-Z]"*) printf ;;
				'[A') ;; #hist_up ;;
				'[B') ;; #hist_down ;;
				# Control characters, may vary by system but idk
				$'\001') curpos=0 ;;
				$'\002') printf "\n" && string='' ;; # This is a placeholder, the actual thing for \C-c is the SIGINT trap above
				$'\004') [[ -z "$string" ]] && exit ;;
				$'\005') curpos=${#string} ;;
				$'\027') string="" ;;
				# Catch undefined escapes
				$'\01'*) printf "C 1 caught" ;;
				$'\02'*) printf "C 2 caught" ;;
				*) 	add_to_string && post_prompt="${suggest:${#string}}" ;;
			esac
			command_completion
		done
		printf '\n'
		eval "$string" # I hate this, and you should know that i hate it pls
		IFS=$oldifs
		echo "$string" >> ~/.bash_history
		suggest=""
		post_prompt=""
	done
}

# ble.sh uses bind -x

#key_binds
commands_get
print_command_line
echo "linecomp exited"
