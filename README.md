# linecomp
A WIP (see: early alpha / POC) readline "replacement" in/for ``bash 4.0+``  

# Why hasnt someone else done this?
They have! and if we're being honest, the other version of this are far, far ahead.  
One of the big reasons is seniority and support. This is a pretty new project, and it hasnt even got feature parity with the default readline as on now.  

##31/01/23
We now have support for `bash-completions`!  
Unfortunately its a little slow, but that should be fixed in the coming weeks  

# usage
source linecomp.sh at the end of your bashrc, and add linecomp.txt in ~/.local/share. This is for custom command completion  
if it ever breaks something _really_ bad, you can set the variable ``running`` to anything other than ``true``  

# Features
Subdirectory / Directory completion  
Some readline shortcuts re-implemented  

# Goals [percentages are estiamtes]
Feature parity with GNU Readline - ~50%  
Feature parity with bash-completions - ~25%  
bash-completions integration - ~95% (fully working, just slow)
Vi mode + keybindings - 0%  (don't personally use so might never implement)

# Why
The only existing readline replacement that achieves my desired results is ble.sh, and as much of a feat as it is, I felt like perhaps it could be a fun project to re-implement. As a result, I began to implement my own line-editor, and thats what linecomp has become since  
I mean yeah, i could just use zsh or fish but wheres the fun in that?  

# Todo's ( in order of priority (should probably put somewhere else))
## Todo
 - Figure out why and prevent bash-completions from freezing the prompt when it encounters an issue
 - Multi-line statements with escapes (works basically, need to do more work on it)
 - Add all remaining emacs bindings
 - start vi mode implementation
 - Config for keybinds instead of hardcoding
 - Stop commiting directly to main (more of a personal note tbh)

## Done / very low priority
 - ~~Replace grep with something less susceptible to regex injections / Fix my awful regex's~~ (not really necessary)
 - ~~Switch all if/else ladders to case statements for speed~~ (done as much as can be for now)
 - ~~Implement using ``bash-completions`` scripts for suggesting parameters~~ (done, but still __really__ slow)
 - ~~Figure out why it runs awful on macos~~ (nvm its just the terminal)
 - ~~Stop handling history ourselves and use ``history`` for it~~ (did this ages ago and forgot to change)


Issues / Suggestions more than welcome! (im practically begging actually)
