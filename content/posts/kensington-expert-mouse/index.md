+++
title = "How I learnt to love trackballs"
date = "2025-11-16"

[taxonomies]
tags=["linux", "trackball", "libinput"]

[extra]
repo_view = false
comment = false
+++

I fell in love with trackballs since I got my first one several years ago.
What I love about trackballs is that they take so little desk space.
I use my desk for reading and writing notes, so any extra space is welcome.
And, nothing compares to the aesthetics of a bare wooden desk.
I highly encourage you to try a trackball mouse. It is a lot of fun!

My first trackball was a Logitech MX Ergo.
I discovered that scrolling for a long period of time
using the mouse wheel (e.g. while reading documents) made my right hand hurt badly.
Unfortunately, I had to drop the Logitech trackball for the Logitech MX Master.
I decided to go with the MX Master mouse because it has a feature called "MagSpeed scrolling".
This feature automatically switches the mouse wheel from ratched mode to free-spin mode,
which helped me a lot with the RSI.

Despite the Logitech MX Master being an excellent productivity mouse,
I still missed using a trackball. Few months later, I discovered 
the Kensington Expert Wireless, a trackball that instead of a scrolling with
a regular mouse wheel it used the ring surronding the movement ball.

![Kensington Expert Mouse](kensington_trackball.jpg) 

To be honest, I did not like the mouse at the beginning.
The main feature, the scrolling ring, wasn't great.
It does not provided a smooth scrolling experience.
Lucky for me, I discovered that on Linux
you can also scroll by pressing a designated mouse button 
and moving the cursor on the direction of the scroll. Here is the script to achieve that

```bash
#!/usr/bin/env bash

mouse_name="Kensington Expert Wireless TB Mouse"
mouse_id=$(xinput | grep "$mouse_name" | sed 's/^.*id=\([0-9]*\)[ \t].*$/\1/')

xinput set-button-map $mouse_id 1 8 2 4 5 6 7 3 9
xinput set-prop $mouse_id "libinput Natural Scrolling Enabled" 1
xinput set-prop $mouse_id "libinput Accel Profile Enabled" 0, 1
xinput set-prop $mouse_id "libinput Scroll Method Enabled" 0, 0, 1
xinput set-prop $mouse_id "libinput Button Scrolling Button" 3
```

This small change, made me fall in love with the mouse.

The only remaining problem was that this script was only executed once right after logging in.
If I missed connecting the mouse, or switches the mouse to another computer, it reset to default. 
At first, I re-executed the script manually every time this happened.
But it became a pain, and eventually decided to stop using the trackball and move back to the MX Master.
Until today, when I discovered that you can have _X11_ apply the _libinput_ options
automatically to the device every time it connected.
The set up is very simple, create a file `40-libinput.conf` with the following content
(you can obtain the name with `libinput list-devices`):

```
Section "InputClass"
        Identifier "Kensington Expert Wireless TB Mouse"
        MatchProduct "Kensington Expert Wireless TB Mouse"
        MatchIsPointer "on"
        Driver "libinput"
        Option "ButtonMapping" "1 8 2 4 5 6 7 3 9"
        Option "NaturalScrolling" "true"
        Option "AccelProfile" "flat"
        Option "ScrollMethod" "button"
        Option "ScrollButton" "3"
EndSection
```

and drop it in `/etc/X11/xorg.conf.d/`. Restart the _X_ session and that's it.
Now, the custom mappings will be applied every time the mouse is connected without
having to execute a manual script.

This is the end of my little journey with trackballs in Linux.
If you liked this story, feel free to reach out to me via email 
and I promise to share more such experiences.

**P.S.** Anyone knows how to achieve the same on macOS?
I tried Karabiner, but natural scrolling only applied to the scrolling wheel, not the scrolling button.
