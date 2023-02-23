# linecomp
Beta readline replacement and command suggestion in/for ``bash 4.0+``  


~~##31/01/23~~
~~We now have support for `bash-completions`!~~  
~~Unfortunately its a little slow, but that should be fixed in the coming weeks~~  
This has been removed temporarily in favor of a faster, more reliable manpage-based approach  

# usage
source linecomp.sh at the end of your bashrc, and add linecomp.txt in ~/.local/share  
I WOULD ADVISE AGAINST USING THIS ON A HARD DISK
Its usable in my experience, but still a bit slow

# Features
Subdirectory / Directory suggestion  
Command option suggestion  
History based suggestion  
Some readline shortcuts re-implemented  

# Goals [percentages are estiamtes]
Feature parity with GNU Readline - ~50%  
Vi mode + keybindings - 0%  (don't personally use so might never implement)  

# Why
The only existing readline replacement that achieves my desired results is ble.sh, and as much of a feat as it is, I felt like perhaps it could be a fun project to re-implement. As a result, I began to implement my own line-editor, and thats what linecomp has become since  
I mean yeah, i could just use zsh or fish but wheres the fun in that?  

# Todo's ( in order of priority (should probably put somewhere else))
## URGENT
 - Re-implement ``bash-completions``. It was previously implemented, however as it was slow, unreliable and not even guaranteed to work, i have decided to move to a manpage parsing approach. This is also not yet completely working, but as it is far faster and more reliable than bash-completions (not to mention technichally closer to how fish does it), this will be the primary approach for the time being.  
 - Grab keybinds from env instead of hardcoding, making it a drop in replacement

## Todo
 - Figure out why and prevent bash-completions from freezing the prompt when it encounters an issue
 - Add all remaining readline functions
 - start vi mode implementation

## Done / very low priority
 - ~~Stop commiting directly to main (more of a personal note tbh)~~ (You cant make me)
 - ~~Multi-line statements with escapes (works basically, need to do more work on it)~~ (Done, but slow)
 - ~~Replace grep with something less susceptible to regex injections / Fix my awful regex's~~ (not really necessary)
 - ~~Switch all if/else ladders to case statements for speed~~ (done as much as can be for now)
 - ~~Implement using ``bash-completions`` scripts for suggesting parameters~~ ~~(done, but still __really__ slow)~~ (re-implement at a later date)
 - ~~Figure out why it runs awful on macos~~ (nvm its just the terminal)
 - ~~Stop handling history ourselves and use ``history`` for it~~ (did this ages ago and forgot to change)

Issues / Suggestions more than welcome! (im practically begging actually)
