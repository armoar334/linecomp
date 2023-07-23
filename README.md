# linecomp
Beta readline replacement and command suggestion in/for ``bash 4.0+``  


##23/07/23
linecomp v3 is now here!  
Features:  
 - Better support for Directory names with escaped spaces
 - Independant coloring for each option! not everything is red now, and as ```$_color``` is just set to an ansi color code, suggestions can be cutomised to any color you would like
 - _string and _curpos are now $READLINE_LINE and $READLINE_POINT, so that any custom function you may have affecting the content or cursor position in your prompt will now be functional


##14/04/23
linecomp is now completely dependant on env for keybinds. This allows it to be easily used without having to go and manually modify the input case structure  
It also means that implementing new readline commands is as easy as writing a fucntion of the same name, allowing features to be added at a much faster rate than previously possible!


~~##31/01/23~~
~~We now have support for `bash-completions`!~~  
~~Unfortunately its a little slow, but that should be fixed in the coming weeks~~  
This has been removed temporarily in favor of a faster, more reliable manpage-based approach  

# usage
source linecomp.sh at the end of your bashrc e.g  
```
source ~/Repos/linecomp/linecomp.sh
```

# Features
Subdirectory / Directory suggestion  
Command option suggestion  
History based suggestion  
Drop in readline replacement - programmatically grabs all your keybinds, so you dont have to worry about interrupting your workflow

# Goals [percentages are estiamtes]
Emacs mode bindings - ~10% (Most basic shortcuts are implemented, such as forward/backward-word/char, EOL and such)  
Suggestions - ~75%  
	History - 100%  
	Directory - 80%, only a few edge cases to work out  
	Argument - 50%, manpage-parsing is fully functional but not as flexible as bash completions.  
Vi mode + keybindings - 0%  (don't personally use so might never implement)  

# Todo's ( in order of priority (should probably put somewhere else))
## URGENT
 - Re-implement ``bash-completions``. It was previously implemented, however as it was slow, unreliable and not even guaranteed to work, i have decided to move to a manpage parsing approach. This is also not yet completely working, but as it is far faster and more reliable than bash-completions (not to mention technichally closer to how fish does it), this will be the primary approach for the time being.  

## Todo
 - Figure out why and prevent bash-completions from freezing the prompt when it encounters an issue
 - Add all remaining readline functions
 - start vi mode implementation

## Done / very low priority
 - ~~Grab keybinds from env instead of hardcoding, making it a drop in replacement~~ ( It took an almost ground up rewrite, but we now have it!s)
 - ~~Stop commiting directly to main~~ (You can't make me)
 - ~~Multi-line statements with escapes (works basically, need to do more work on it)~~ (Done, but slow)
 - ~~Replace grep with something less susceptible to regex injections / Fix my awful regex's~~ (not really necessary)
 - ~~Switch all if/else ladders to case statements for speed~~ (done as much as can be for now)
 - ~~Figure out why it runs awful on macos~~ (nvm its just the terminal)
 - ~~Implement using ``bash-completions`` scripts for suggesting parameters~~ ~~(done, but still __really__ slow)~~ (re-implement at a later date)
 - ~~Stop handling history ourselves and use ``history`` for it~~ (did this ages ago and forgot to change)

Issues / Suggestions more than welcome! (im practically begging actually)
