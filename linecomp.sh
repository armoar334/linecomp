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
	search_term=$(sed 's/[^^]/[&]/g; s/\^/\\^/g' <<<"$search_term") # Escape regex chars for grep
}

subdir_completion() {
	arg_completion
	search_term=''
	if [[ -d "${two%'/'*}" ]];
	then
		if [[ "$two" == *"/"* ]];
		then
			folders="${two%'/'*}/"
			search_term="${two/$folders}"
			search_escape
			files="$folders"$(ls ${two%'/'*} | grep -v '\.$' | grep -i '^'"$search_term" )
		fi
	else
		search_term="$two"
		#search_term=$(sed 's/[^^]/[&]/g; s/\^/\\^/g' <<<"$search_term") # Escape regex chars for grep
		files=$(ls | grep -v '\.$' | grep -i '^'"$search_term" )
	fi
	all="$files$args"
	two="${all%%$'\n'*}/"
	two="${two// /\\ }" # Fix files with spaces
	if ! [[ -d "$two" ]]; # Remove / if not directory
	then
		two="${two:0:-1}"
	fi
}

arg_completion() {
	args=$(cat ~/.local/share/linecomp.txt | grep -- "$command" | cut -d ' ' -f2 | tr ',' '\n' )
	if [[ "$string" == *'$commands'* ]];
	then
		args+="HUGECOCK"
	fi
	args=$(echo "$args" | tr ' ' "\n" | grep -- "$two" )
}

command_completion() {
	if [[ "$string" == "./"* ]]; # Executable in current directory
	then
		one="./"
		two="${string:2}"
		subdir_completion
		suggest="$one$two"
	elif [[ "$string" == *" "* ]] && [[ ${#string} -ge 2 ]] ; # Files/folders/arguments
	then
		# This doesnt like filenames with space, but tbf neither does bash normally so idc
		command="${string%%' '*}"
		one="${string%' '*}"
		two="${string/$one }"
		subdir_completion
		suggest="$one $two"
	else # Globally available command
		search_term=$(sed 's/[^^]/[&]/g; s/\^/\\^/g' <<<"$string") # Escape regex chars for grep
		tabbed="$( awk '/'"^$search_term"'/' <<<"${commands[@]}") "
		#tabbed="$( echo $tabbed | sort -n -s )"
		#echo "$tabbed"
		suggest="${tabbed%%$'\n'*}"
	fi
	post_prompt="${suggest:${#string}}"
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
		#prompt="CompMagic "
		reading="true"
		string=()
		histpos=$histmax

		oldifs=$IFS
		IFS=''
		while [[ "$reading" == "true" ]];
		do
			printf "\e[2K\r$prompt" # Yeah, yeah, its slower to split it, bu its way easier to debug
			echo -n "${string:0:$curpos}" # Needs to be seperate for certain characters
			printf "\e7" # Save cursor position
			echo -n "${string:$curpos}"
			printf "$c1$post_prompt\e[0m\e8"
			read -rsn1 mode
			if [[ "$mode" == "$escape_char" ]]; # Stuff like arrow keys etc
			then
				read -rsn2 mode
				if [[ "$mode" == "[1" ]]; # Ctrl + arrows
				then
					read -rsn2 mode
				fi
			fi
			case "$mode" in
				# Specials
				"$new_line")	reading="false";;
				"$back_space")	if [[ ${#string} -gt 0 ]]; then del_from_string; fi ;;
				"$tab_char") string="$suggest" && curpos=${#string} ;;
				# Cursor
				"[C") if [[ $curpos -ge ${#string} ]] && [[ ! -z "$suggest" ]]; then string="$suggest"; curpos=${#string}; fi && if [[ $curpos -lt ${#string} ]]; then ((curpos+=1)); fi ;;
				"[D") [[ $curpos -gt 0 ]] && ((curpos-=1)) ;;
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
				*) 	add_to_string && post_prompt="${suggest:${#string}}" ;;
			esac
			command_completion
		done
		printf '\n'
		eval "$string" # I hate this, and you should know that i hate it pls
		IFS=$oldifs
		echo "$string" >> ~/.bash_history
		suggest=""
		#post_prompt=""
	done
}

# ble.sh uses bind -x

#key_binds
commands_get
print_command_line
echo "linecomp exited"
