# linecomp
A WIP readline "replacement" in/for bash  

# usage
source linecomp.sh at the end of your bashrc, and add linecomp.txt in ~/.local/share. This is for custom command completion  

# Features
Subdirectory / Directory completion  
Command completion  
Some readline shortcuts re-implemented  

# Goals [percentages are estiamtes]
Feature parity with GNU Readline - ~50%  
Feature parity with bash-completions - ~25%  
Vi mode + keybindings - 0%  (don't personally use so might never implement)

# Why
The only existing readline replacement that achieves my desired results is ble.sh, and as much of a feat as it is, its far too bloated and slow for my liking. as a result, I began to implement my own line-editor, and thats what linecomp has become since  
I mean yeah, i could just use zsh or fish but wheres the fun in that?  

# Todo's (should probably put somewhere else)
 - Replace grep with something less susceptible to regex injections
 - Switch all if/else ladders to case statements for speed
 - Add all remaining emacs bindings
 - start vi mode implementation
