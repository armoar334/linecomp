# linecomp
A WIP (see: early alpha / POC) readline "replacement" in/for bash  

# Why hasnt someone else done this?
They have! and if we're being honest, the other version of this are far, far ahead.  
One of the big reasons is that __this isn't completion built into bash__. This awful amalgam of stackexchange snippets is a faux prompt, written as a bash script, whereas all the other attempts use ``bind`` and other similar programs to truly read the contents of the prompt and amend to it. This does however have some pros and cons:  
Pros:  
 - We can much more easily case the whole prompt and the cursors position within it  

Cons:  
 - Potentially much slower
 - Have to contend with ``read`` and escape character issues  

It is worth noting therefore, that this might as well just be a new shell running bash under the hood  
yknow  
like every other shell?  

# usage
source linecomp.sh at the end of your bashrc, and add linecomp.txt in ~/.local/share. This is for custom command completion  
if it ever breaks something _really_ bad, you can set the variable ``running`` to anything other than ``true``  

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

# Todo's ( in order of priority (should probably put somewhere else))
## Todo
 - Multi-line statements with escapes (works basically, need to do more work on it)
 - Figure out why it runs awful on macos
 - Stop handling history ourselves and use ``history`` for it
 - Add all remaining emacs bindings
 - start vi mode implementation
 - Config for keybinds instead of hardcoding
 - Stop commiting directly to main (more of a personal note tbh)

## Done / very low priority
 - ~~Replace grep with something less susceptible to regex injections / Fix my awful regex's~~ (not really necessary)
 - ~~Switch all if/else ladders to case statements for speed~~ (done as much as can be for now)


Issues / Suggestions more than welcome! (im practically begging actually)
