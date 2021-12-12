# MIPS32-Snake-Game
Implementation of a snake game using MIPS32, Bitmap Display, and MMIO Simulator.

I have created a video demonstrating my program: https://youtu.be/RXYWGLDyLR0

The game currently does not have a win scenario implemented, primarily because I hope no one ever tries to win.

Food generations could be optimized for games where players get far in but it has been left in this brute force implementation for time's sake.

Game logic works in this regard but there is an unresolved graphical error when the player moves the head to a space that was occupied by the tail on the previous round.

Time between moves is reduced by 1 from 500 for every food eaten. This will lead to the game having a negative sleep time after those 500 "eats", could have unexpected results.
