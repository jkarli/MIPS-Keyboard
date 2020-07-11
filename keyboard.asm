# Project for CS447 Spring 2020
# Credit to Professor Jarrett Billingsley for project idea and starting code

.include "macros.asm"
.eqv INPUT_SIZE 2
.eqv DURATION 500
.eqv VOLUME 100

.data
# maps from ASCII to MIDI note numbers, or -1 if invalid.
key_to_note_table: .byte
	-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
	-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
	-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 60 -1 -1 -1
	75 -1 61 63 -1 66 68 70 -1 73 -1 -1 -1 -1 -1 -1
	-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
	-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1
	-1 -1 55 52 51 64 -1 54 56 72 58 -1 -1 59 57 74
	76 60 65 49 67 71 53 62 50 69 48 -1 -1 -1 -1 -1

demo_notes: .byte
	67 67 64 67 69 67 64 64 62 64 62
	67 67 64 67 69 67 64 62 62 64 62 60
	60 60 64 67 72 69 69 72 69 67
	67 67 64 67 69 67 64 62 64 65 64 62 60
	-1

demo_times: .word
	250 250 250 250 250 250 500 250 750 250 750
	250 250 250 250 250 250 500 375 125 250 250 1000
	375 125 250 250 1000 375 125 250 250 1000
	250 250 250 250 250 250 500 250 125 125 250 250 1000
	0
	
recorded_notes: .byte  -1:1024
recorded_times: .word 250:1024

input: .space INPUT_SIZE
currInstrument: .word 0

.text

# -----------------------------------------------

.globl main
main:
	_main_loop:
	print_str "Enter a command: [k]eyboard, [d]emo, [r]ecord, [p]lay, [q]uit: "
	la a0, input
	li a1, INPUT_SIZE
	li v0, 8
	syscall # gets user input
	print_str "\n"
	lw t0, input
	beq t0, 'k', _case_keyboard
	beq t0, 'd', _case_demo
	beq t0, 'r', _case_record
	beq t0, 'p', _case_play
	beq t0, 'q', _case_quit
	println_str "Invalid command, try again"
		j _main_loop
		
	_case_keyboard:
		jal keyboard
		j _main_loop
	_case_demo:
		jal demo
		j _main_loop
	_case_record:
		jal record
		j _main_loop
	_case_play:
		jal play
		j _main_loop
	_case_quit:
		li v0, 10
		syscall

# -----------------------------------------------
keyboard:
	push ra
	println_str "play notes with letters and numbers, ` to change instrument, and enter to stop"
	
	_keyboard_loop:
		li v0, 12
		syscall #reads character from user
		beq v0, '\n', _keyboard_end #if they hit enter, exit keyboard
		beq v0, '`', _change_instrument #if they hit `, allow user to change instrument
		move a0, v0 #moves read ascii character into a0 and calls translate_note
		jal translate_note #translates the ascii character to the correct note
		move a0, v0
		bne a0, -1, _to_play_note #calls play note as long as note is != -1
		j _keyboard_loop
		
	_to_play_note:
		jal play_note
		j _keyboard_loop
		
	_change_instrument:
		print_str "\n"
		
		_loop:
		print_str "Enter instrument number (1..128): "
		li v0, 5
		syscall #reads instrument number from user
		blt v0, 1, _loop #if instrument number < 1, prompt again
		bgt v0, 128, _loop #if instrument number > 128, prompt again
		sub v0, v0, 1 #if instrument number is valid, subtract 1 from it
		sw currInstrument, v0 #set currentInstrument to user input value
		j _keyboard_loop
				
	_keyboard_end:
		pop ra
		jr ra
# -----------------------------------------------
demo:
	push ra
	
	la a0, demo_notes #gets address of demo_notes array
	la a1, demo_times #gets address of demo_times array
	jal play_song #passes those addresses to play_song as arguments
	
	_demo_end:
		pop ra
		jr ra
# -----------------------------------------------
record:
	push ra
	push s0
	push s1
	la s0, recorded_notes #gets address of recorded_notes array 
	la s1, recorded_times #gets address of recorded_times array
	println_str "play notes with letters and numbers and push enter to stop"
	
	_record_loop:
		li v0, 12
		syscall #reads character from user
		beq v0, '\n', _get_times #if they hit enter, jumps to _get_times
		move a0, v0 #moves read ascii character into a0	
		li v0, 30
		syscall #gets the time that the key was pressed
		sw v0, (s1) #stores time into recorded_times array
		add s1, s1, 4 #increments pointer to recorded_times array
		jal translate_note #translates the ascii character to the correct note
		move a0, v0 #moves note from v0 into a0
		sb a0, (s0) #stores note into recorded_notes array
		add s0, s0, 1 #increments pointer
		bne a0, -1, _go_play_note #calls play note as long as note is != -1
		j _record_loop
		
	_go_play_note:
		jal play_note
		j _record_loop
		
	_get_times:
		li t0, -1
		sb t0, (s0) #store -1 at the note pointer to ensure the song ends
		li v0, 30
		syscall #get time that \n was pressed
		sw v0, (s1) #store time \n was pressed into recorded_times array
		la s0, recorded_notes #set pointer back to start of array
		la s1, recorded_times #will be recorded_times[i]
		la s2, recorded_times #will be recorded_times[i + 1]
		add s2, s2, 4 #moves pointer from [i] to [i + 1] for s2
		_get_times_loop:
			lb t0, (s0) #get note from array
			beq, t0, -1, _record_end #if note = -1, go to _record_end
			lw t1, (s1) #get ecorded_times[i]
			lw t2, (s2) #get recorded_times[i + 1]
			sub t3, t2, t1 #get recorded_times[i + 1] - recorded_times[i]
			sw t3, (s1) #store above difference in recorded_times[i]
			add s0, s0, 1 #increment pointer for recorded_notes
			add s1, s1, 4 #increment pointer for recorded_times[i]
			add s2, s2, 4 #increment pointer for recorded_times[i + 1]
			j _get_times_loop
							
	_record_end:
		pop s1
		pop s0
		pop ra
		jr ra
# -----------------------------------------------
play:
	push ra
	
	la a0, recorded_notes #gets address of recorded_notes array 
	la a1, recorded_times #gets address of recorded_times array
	jal play_song #passes array addresses to play_song as arguments

	pop ra
	jr ra
# -----------------------------------------------
# a0 = note to play
play_note:
	push ra
	
	li a1, DURATION
	lw a2, currInstrument
	li a3, VOLUME
	li v0, 31
	syscall #plays note passed in
	
	_play_note_end:
		pop ra
		jr ra
# -----------------------------------------------
# a0 = ascii
translate_note:
	push ra
	
	blt a0, 0, _invalid_key #if ascii < 0, it's invalid
	bge a0, 127, _invalid_key #if ascii > 127,it's invalid
	la t0, key_to_note_table #loads address of ascii-to-note table
	add t0, t0, a0 #moves to correct index of table to retrieve corresponding note
	lb v0, (t0) #loads note into v0 and returns
	j _translate_note_end
	
	_invalid_key:
	li v0, -1 #-1 represents an invalid key
	
	_translate_note_end:
		pop ra
		jr ra	
# -----------------------------------------------
#a0 = address of given notes array
#a1 = address of given times array (time to sleep)
play_song:
	push ra
	push s0
	push s1
	move s0, a0 #moves given notes array address to s0 
	move s1, a1 #moves given times array address to s1
	
	_play_song_loop:
		lb a0, (s0) #gets note to play and store it in a0
		beq a0, -1, _end_play_song #if note to play = -1, song is over
		jal play_note #otherwise, play the note
		lw a0, (s1) #gets the time to sleep between notes
		li v0, 32
		syscall #program sleeps for given time (in milliseconds)
		add s0, s0, 1 #increments pointer to given notes array by 1 (.byte)
		add s1, s1, 4 #increments pointer to given times array by 4 (.word)
		j _play_song_loop
			
	_end_play_song:
		pop s1
		pop s0
		pop ra
		jr ra
