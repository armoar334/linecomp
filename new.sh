trap 'magic' DEBUG
set -T
shopt -s extdebug

#readarray -t files < <(ls "$PWD")

files=("uno" "dos" "tres")

magic() {
	if [[ -z $numba ]]; then numba=1; fi
	if [[ -z "$oldpwd" ]]; then oldpwd="$PWD"; fi
	if [[ "$oldpwd" != "$PWD" ]]; then readarray -t files < <(ls "$PWD"); fi
	printf "ock" 
	((numba+=1))
}
