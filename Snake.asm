# Program: Snake
# Author: Cameron Baker
# Date Created: 2021-12-07
# Description: Implementation of Snake game using bitmap display and MMIO simulator.
# Usage: Launch and connect the Bitmap Display and the Keyboard and Display MMIO Simulator. 
#        Set Bitmap Display unit width/height to 8, display width/height to 512, and base address to heap. 
#			Set MMIO Simulator to have a Delay Length of 1
#			Leave run speed at max.
#        Control snake using w, a, s, and d for up, left, down, and right respectively inside the keyboard portion of the simulator. 
#			Program will initialize the game then wait for first user input to begin.

.eqv HEAP_ADDR 0x10040000 # Address of bitmap display when allocated in heap
.eqv KEYBOARD_INTERUPT_BIT_ADDR 0xffff0000 # Keyboard interupt control addr
.eqv KEYBOARD_DATA_ADDR 0xffff0004 # Keyboard interupt ascii data
.eqv PIXEL_COUNT 4096 # 64x64 pixel bitmap display size
.eqv COLOR_WHITE 0x00ffffff # Hex white
.eqv COLOR_DARK_GREY 0x005d5d5d # Hex grey
.eqv COLOR_GREEN 0x0053760a # Hex green
.eqv COLOR_RED 0x00ff0000 # Hex red

.data
	Sleep_Time: .word 500 # Time between moves. Default 500
	Snake_Heap_Base_Addr: .word 0 # SET TO MIDDLE ADDR
	Snake_Heap_Head_Addr: .word 0 # SET EQUAL TO Snake_Heap_Base_Addr
	Direction: .word 0 # Address adjustment amount. Dependent on direction input by user.

.text
	.globl main
main:
	jal Enable_Interrupts # Enables keyboard interrupts
	jal Heap_Alloc # Bitmap Display Heap Allocation
	jal Heap_Alloc # Snake Tracking Heap Allocation
	sw $v0, Snake_Heap_Base_Addr # Retreive Snake Tracking Heap Location
	sw $v0, Snake_Heap_Head_Addr # Retreive Snake Tracking Heap Location
	
	jal Initialize_Game # Draw background, draw border, set starting snake location and set location to white
	
	
	# Pauses the game until the first input is given
	WHILE_WAIT:
		lw $t0, Direction # Get most recent input
		
		li $a0, 500 # Sleep time for wait
		li $v0, 32 # Sleep syscall code
		syscall
		
		bne $t0, 0, WHILE_WAIT_END # Break when input received
		b WHILE_WAIT
	WHILE_WAIT_END:
	
	
	# Handles game logic and end conditions
	Inf_Loop:
	jal Update_Snake
	lw $a0, Sleep_Time # Sleep time between moves
	li $v0, 32 # Sleep syscall code
	syscall
	b Inf_Loop

.text
Update_Snake:
	addi $sp, $sp, -12
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	sw $ra, 0($sp)

	lw $t0, Snake_Heap_Head_Addr # Get the address of the current head
	lw $t1, ($t0) # Get the bitmap location of the current head
	move $s1, $t1 # Save location of last head for update loop
	lw $t2, Direction # Get the directon to move
	add $t1, $t1, $t2 # Add direction to head bitmap location to get next location address
	move $s0, $t1 # Save next location
	lw $t3, ($t1) # Load color from next location
	
	# Check for border. If border is hit: fail game.
	bne $t3, COLOR_DARK_GREY, NOT_BORD # Branch if color isn't dark grey, otherwise fail
		jal End_Game
	NOT_BORD:
	
	# Check for snake food. If food is hit: grow snake, generate new food, decrement time between round
	bne $t3, COLOR_RED, NOT_FOOD # Branch if color isn't red, otherwise grow.
		addi $t0, $t0, 4 # New head address offset
		sw $t0, Snake_Heap_Head_Addr # Store updated head addr
		sw $t1, ($t0) # Store bitmap location of new head
		li $t4, COLOR_WHITE
		sw $t4, ($t1) # Update color of new snake head
		
		jal Make_Food
		
		lw $t7, Sleep_Time
		addi $t7, $t7, -1
		sw $t7, Sleep_Time
		
		b SKIP_UPDATE # Don't run snake update
	NOT_FOOD:
	
	# Snake Update. Set next location to white, all snake locations get updated to the next location in the line, tail is returned to the color green.
		lw $t0, Snake_Heap_Head_Addr # Get head addr. $t0 will be starting current address.
		lw $t3, Snake_Heap_Base_Addr # Get base addr
		move $t2, $s0 # Get the next location for head
		li $t4, COLOR_WHITE
		sw $t4, ($t2) # Set next bitmap location of head to white
#		ble $t0, $t3, SKIP_UPDATE_LOOP # While current address $t0 does not equal or is greater than base address $t3
		UPDATE_LOOP:
			ble $t0, $t3, UPDATE_LOOP_END # While current address $t0 does not equal or is greater than base address $t3
			lw $t1, ($t0) # Load bitmap current location in current address
			sw $t2, ($t0) # Set location for current addr ($t0) to next location $t2
			move $t2, $t1 # Move current location $t1 to next location $t2
			addi $t0, $t0, -4 # Decrement current address $t0 by 4
			b UPDATE_LOOP # Loop
		UPDATE_LOOP_END:
		lw $t1, ($t0) # Save location at ($t0) into $t1
		sw $t2, ($t0) # Store bitmap location $t2 into ($t0)
		
		# Set previous bitmap location $t1 to green as long as bitmap location of base ($t3) and bitmap location of $t1 don't match
		lw $t4, ($t3) # Load bitmap location of tail
		beq $t4, $t1, SKIP_TAIL # If current head location is the same as the previous tail location, then skip. Otherwise color old tail location green.
		li $t3, COLOR_GREEN
		sw $t3, ($t1) # Set previous tail location to green
		SKIP_TAIL:
	
	SKIP_UPDATE:	
		# Self eat check
		lw $t5, Snake_Heap_Head_Addr # Get head addr
		lw $t6, Snake_Heap_Base_Addr # Get base addr
		lw $t1, ($t5) # Load bitmap location of head
		SELF_EAT_LOOP:
		ble $t5, $t6, SELF_EAT_LOOP_END # Exit loop if current link addr matches base addr
		addi $t5, $t5, -4 # Access previous snake link
		lw $t7, ($t5) # Load bitmap location from that previous snake link
		beq $t1, $t7, SELF_EAT # Branch if head location and previous link location are matching.
		b SELF_EAT_LOOP
		SELF_EAT:
		jal End_Game
		SELF_EAT_LOOP_END:
	

	lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	addi $sp, $sp, 12
	jr $ra

.text	
End_Game:
	li $a0, COLOR_RED
	jal Fill_Screen
	
	li $v0, 10 # Terminate syscall code
	syscall
	
	jr $ra # Pointless lil guy

.text
Make_Food:
	GEN_LOOP:
	li $a1, 4097 # Random gen range
	li $v0, 42 # Random gen with range syscall code
	syscall
	move $t0, $a0 # Retrieve random number
	mul $t0, $t0, 4 # Word size adjustment
	li $t1, HEAP_ADDR # Get bitmap heap address
	add $t0, $t0, $t1 # Add offset to address
	lw $t1, ($t0) # Load color code from calculated address
	li $t2, COLOR_GREEN
	bne $t1, $t2, GEN_LOOP # Repeat if location is not green
	li $t3, COLOR_RED
	sw $t3, ($t0) # Store red it space was green
	jr $ra
	
.text
Heap_Alloc: # Allocates memory for bitmap display, 4,096 words.
	li $a0, PIXEL_COUNT # 4,096 words in bitmap display
	mul $a0, $a0, 4 # 4 bytes per word correction
	li $v0, 9 # Heap allocate syscall code
	syscall
	jr $ra

.text
Enable_Interrupts:
	li $t0, 2
	sb $t0, KEYBOARD_INTERUPT_BIT_ADDR
	jr $ra
	
.text
Initialize_Game: # Draw border and background, set snake to center, and set start direction
	add $sp, $sp, -4
	sw $ra, 0($sp)
	
	#Fill green background
	li $a0, COLOR_GREEN
	jal Fill_Screen

	# Make border
	li $t0, 0 # Loop counter
	li $t1, COLOR_DARK_GREY # Background Color
	li $t3, 63 # Top bits
	li $t4, 4031 # Bottom bits
	li $t5, 64
	li $t7, 127
	INIT_FOR_BORD: # Set background to white
		bge $t0, PIXEL_COUNT, INIT_FOR_BORD_END # Loop conditional
		ble $t0, $t3, DRAW_BORD_PIXEL # Top pixel line check
		bge $t0, $t4, DRAW_BORD_PIXEL # Bottom pixel line check
		div $t0, $t7 # Mod (%) for pixel location in right column. beq would have also sufficed but I already wrote this.
		mfhi $t6 
		beqz $t6, DRAW_BORD_PIXEL_RIGHT # Right pixel line check
		div $t0, $t5 # Mod (%) for pixel location in left column.
		mfhi $t6
		beqz $t6, DRAW_BORD_PIXEL # Left pixel line check
		b SKIP_DRAW_BORD_PIXEL # If no conditions met then increment and loop
		DRAW_BORD_PIXEL_RIGHT:
		addi $t7, $t7, 64 # Border correction for right side comparison.
		DRAW_BORD_PIXEL:
		mul $t2, $t0, 4 # Word size correction
		add $t2, $t2, HEAP_ADDR # Pixel location
		sw $t1, ($t2) # Store color in pixel
		SKIP_DRAW_BORD_PIXEL:
		addi $t0, $t0, 1 # Increment counter
		b INIT_FOR_BORD # Restart loop
	INIT_FOR_BORD_END:
	
	# Initialize start location and snake tracking heap location
	li $t1, 2080 # Center pixel
	mul $t1, $t1, 4 # Word offset
	li $t0, HEAP_ADDR # Load address of bitmap display
	add $t0, $t0, $t1 # Add center pixel address offset to base address of bitmap heap
	lw $t2, Snake_Heap_Base_Addr # Load address of snake head
	sw $t0, ($t2) # Store bitmap location into snake head
	
	# Color snake head white
	li $t2, COLOR_WHITE
	sw $t2, ($t0)
	
	# Generate first food
	jal Make_Food
	
	lw $ra, 0($sp)
	add $sp, $sp, 4
	
	jr $ra

.text 	
Fill_Screen: # $a0 for color
	li $t0, 0 # Loop counter
	add $t1, $a0, $0 # Background Color
	INIT_FOR_BACK: # Set background to white
		bge $t0, PIXEL_COUNT, INIT_FOR_BACK_END # Loop conditional
		mul $t2, $t0, 4 # Word size correction
		add $t2, $t2, HEAP_ADDR # Pixel location
		sw $t1, ($t2) # Store color in pixel
		addi $t0, $t0, 1 # Increment counter
		b INIT_FOR_BACK # Restart loop
	INIT_FOR_BACK_END:
	jr $ra	

.ktext 0x80000180
	addi $sp, $sp, -12
	sw $ra, 0($sp)
	sw $s0, 4($sp)
	sw $s1, 8($sp)
	jal Handle_Input
	lw $ra, 0($sp)
	lw $s0, 4($sp)
	lw $s1, 8($sp)
	addi $sp, $sp, 12
	eret
	
Handle_Input:
	lw $s0, KEYBOARD_DATA_ADDR # Get ascii char
	
	# Handle 'a'
	bne $s0, 97, NEXT1
	li $s1, -4
	sw $s1, Direction
	b NEXT4
	
	# Handle 's'
	NEXT1:
	bne $s0, 119, NEXT2
	li $s1, -256
	sw $s1, Direction
	b NEXT4
	
	# Handle 'w'
	NEXT2:
	bne $s0, 115, NEXT3
	li $s1, 256
	sw $s1, Direction
	b NEXT4
	
	# Handle 'd'
	NEXT3:
	bne $s0, 100, NEXT4
	li $s1, 4
	sw $s1, Direction
	
	NEXT4:
	jr $ra
