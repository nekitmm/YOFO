<br/>
<h1 align="center">YOFO</h1>
<h2 align="center">YOFO: You Only Focus Once</h2>
<br/>


YOFO is a script for Magic Lantern that allows you to use your lens' internal focusing motor to achieve precise and repeatable focus on infinity.

The short idea is: you move your lens to hard stop beyond infinity, count how many steps it takes your focusing motor to get to infinity and save this value. After that, when you are in the field, you can achieve perfect focus in just a few simple steps:

1. Move your lens to infinity
2. Turn on AF
2. Goto to YOFO menu and activate pre-set position
3. Turn off AF
4. ?
5. Profit!

At the moment this procedure assumes that the focusing point does not depend on the temperature, which should be tested, but probably true for most lens, except telephoto ones.

## Installation and dependencies

Dependencies: This script requires the latest experimental version of Magic Lantern (2020-12-28 18:15), which you can find here.

Note that this is for Canon cameras. I only tested this on my Canon 6D.

    Disclaimer: The software is provided as-is without any guaranties.
    I am absolutely not responsible any damage caused by Magic Lantern or this script.
    Magic Lantern is not officially supported by Canon and in pronciple can damage or even brick your camera.
    Be sure you know what you are doing before proceeding!

1. First install Magic Lantern (ML). Refer to instructions elsewhere to find out how.
2. Open ML/scripts folder on your SD or CF card and copy YOFO.lua script there.
3. Load the card into the camera, go to Scripts menu of ML and activate the script by setting Autorun to ON.
4. Restart your camera. The Focus menu should have YOFO items added:

<br/>
<p align="center">
    <img width="50%" src="https://github.com/nekitmm/YOFO/blob/main/screenshots/VRAM10.jpg" alt="YOFO installed into Focus menu">
</p>
<br/>