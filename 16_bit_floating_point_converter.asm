;This program takes a decimal input and converts it into a 16bit floating point number
;according to IEE754 formatting specifications.
;There are some slight limitations to this process, it does not allow for sub-normal
;exponents (00000) and only allow a decimal input of up to 4 decimal places.
;IEEE format is as follows:
;1-bit sign, 5-bit exponent, [1 hidden bit], 10-bit fraction

.ORIG		x3000
	LEA		R0, FIRST_MESSAGE
	PUTS
	BRnzp	BEGINNING
FIRST_MESSAGE	.STRINGZ	"This program converts a decimal number into a \n16-bit floating point according to IEEE standards\n"
BEGINNING		
	LEA		R0, WELCOME
	PUTS
	AND		R0, R0, #0
	ST		R0, WN_LENGTH					;These are the memory locations where work is done to
	ST		R0, DEC_LENGTH					;create the floating point.  They need to be zeroed
	ST		R0, SIGN						;before calcuations begin
	ST		R0, DECIMAL
	ST		R0, DEC_SPACE
	ST		R0, WHOLE_NUMBER
	ST		R0, DECIMAL_NUMBER
	ST		R0, FLOATING_POINT
	ST		R0, EXPONENT
	ST		R0, MANTILLA

;First get the user input. Store the whole number and decimal separately
MAIN_GET_WHOLE_NUM
	LD		R5, USER_NUM_PTR
	GETC
	JSR		CHECK_VALID_INPUT_FIRST
	OUT
	JSR		STORE_INT
CONTINUE_INPUT
	GETC
	JSR		VALIDATE_DEC
	OUT
	JSR		STORE_INT
	BRnzp	CONTINUE_INPUT

;The whole number has been acquired, now get the decimal
MAIN_GET_DECIMAL
	GETC
	JSR		VALIDATE_DEC
	OUT
	JSR		STORE_INT
	LD		R1, DEC_LENGTH
	ADD		R1, R1, #-4
	BRz		STORE_DECIMAL				;If we have 4 decimal points then we can't take anymore
	BRnzp	MAIN_GET_DECIMAL

;This loop is only run once because a negative can only be entered the first pass
CHECK_VALID_INPUT_FIRST
	LD		R1, NEGATIVE
	LD		R2, POINT
	ADD		R1, R0, R1					;See if the first input is a negative sign
	BRz		SET_NEGATIVE
	ADD		R2, R0, R2					;See if the first input is a decimal point
	BRz		SET_WHOLE_NUM_ZERO
	BRnzp	VALIDATE_DEC				;See if the input is a number

;set the negative bit in memory
SET_NEGATIVE
	LD		R2, SIGN
	BRp		MAIN_GET_WHOLE_NUM			;don't allow user to enter negative twice
	ADD		R1, R1, #1
	ST		R1, SIGN
	OUT
	BRnzp	MAIN_GET_WHOLE_NUM

;if the number is just a decimal then store zero to the whole number
SET_WHOLE_NUM_ZERO
	LD		R4, WHOLE_NUMBER
	STR		R2, R4, #0					;Store 0 to the whole number
	ADD		R2, R2, #1
	ST		R2, WN_LENGTH				;set length of whole number
	ST		R2, DECIMAL
	LD		R5, USER_NUM_PTR			
	LD		R0, ASCII
	OUT
	LD		R0, POINT
	JSR		MAKE_NEGATIVE
	OUT
	BRnzp	MAIN_GET_DECIMAL

;print the decimal point, store the decimal bit in memory and store the whole number to memory
PRINT_DECIMAL
	LD		R2, DECIMAL
	BRp		MAIN_GET_DECIMAL				;do not allow user to enter multiple decimal points
	OUT
	ADD		R2, R2, #1
	ST		R2, DECIMAL
	JSR		INVALID_CHECK			;See if whole number is too big
	JSR		DEC_TO_BIN					;create the whole number
	ST		R0, WHOLE_NUMBER
	LD		R5, USER_NUM_PTR			;reset the pointer for building the decimal next
	JSR		MAIN_GET_DECIMAL

;Validate user input before printing, check to see if return has been pressed
VALIDATE_DEC	
	ADD		R1, R0,#-10
	BRz		BREAK
	LD		R1, POINT
	ADD		R1, R0, R1
	BRz		PRINT_DECIMAL			;a decimal has been typed
	AND		R6, R6, #0
	LD		R6, ASCII
	NOT		R6, R6
	ADD		R6, R6, #1
	ADD		R1, R0, R6
	BRn		MAIN_RET				;if negative then less than zero
	ADD		R1, R1, #-9				; (do not allow bad input)
	BRp		MAIN_RET				;if positive then greater than 9
	RET
;Breakout for when Enter is pressed
BREAK
	LD		R1, WN_LENGTH
	BRz		MAIN_GET_WHOLE_NUM
	LD		R1, DECIMAL
	BRp		STORE_DECIMAL			;If there is a decimal then store the decimal #
	JSR		INVALID_CHECK			;See if whole number is too big
	JSR		DEC_TO_BIN				;If not, then store the whole number before continuing
	ST		R0, WHOLE_NUMBER
	JSR		WHOLE_TO_FLT
STORE_DECIMAL
	LD		R5, USER_NUM_PTR
	ADD		R5, R5, #4				;The decimal will be 4 digits long
	JSR		DEC_TO_BIN				;convert the decimal to binary
	ST		R0, DECIMAL_NUMBER
	LD		R0, WHOLE_NUMBER		;Whole_To_Float takes input of R0
	JSR		WHOLE_TO_FLT
MAIN_RET
	LD		R1, WN_LENGTH			;check to see if we're getting the first number or not
	BRz		MAIN_GET_WHOLE_NUM
	BRnzp	CONTINUE_INPUT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Store the number found at R0 into memory location stored at R5
STORE_INT
	AND		R6, R6, #0
	LD		R6, ASCII
	NOT		R6, R6
	ADD		R6, R6, #1
	ADD		R0, R0, R6
	STR		R0, R5, #0
	ADD		R5, R5, #1					;increment the pointer
	LD		R1, DECIMAL					;see if we're working on the decimal or the integer
	BRp		DEC_LEN_PLUS
INT_LEN_PLUS
	LD		R4, WN_LENGTH				;increment the length
	ADD		R4, R4, #1
	ST		R4, WN_LENGTH
	RET
DEC_LEN_PLUS
	LD		R4, DEC_LENGTH				;increment the length
	ADD		R4, R4, #1
	ST		R4, DEC_LENGTH
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Convert the integers found at memory location R5 (working backwards)
;store into a single binary number at R6
;Return the binary number to R0
DEC_TO_BIN
	STI			R7, _R6				;Save R7 so we can return to main
	AND			R6, R6, #0			;Store the final binary value in R6
	LD			R0, USER_NUM_PTR
	JSR			MAKE_NEGATIVE
	ADD			R4, R0, #0			;R4 will hold the pointer location so we can see when we're done building the number
	AND			R1, R1, #0			;R1 will store the number from each memory location
	ADD			R5, R5, #-1
	LDR			R1, R5, #0			;Put memory contents into R1
	AND			R2, R2, #0			;R2 will store the multiplier: 1, 10, 100 etc.
	STR			R2, R5, #0				;Erase the memory location
	ADD			R2, R2, #1
	JSR			MULTIPLY
	ADD			R6, R6, R0			;store result from first multiplication
DB_LOOP
	LD			R1, TEN				;increment the decimal place: 1,10,1000 etc
	JSR			MULTIPLY			
	ADD			R2, R0, #0
	ADD			R5, R5, #-1
	LDR			R1, R5, #0
	AND			R3, R3, #0
	STR			R3, R5, #0			;Erase this memory location
	ADD			R7, R4, R5			;see if pointer has passed its start
	BRn			BREAK_DB_LOOP
	JSR 		MULTIPLY
	ADD			R6, R6, R0
	BRnzp		DB_LOOP
BREAK_DB_LOOP
	ADD			R0, R6, #0			;Put final value in R0
	LDI			R7, _R6
	RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;multiplies the numbers stored at R1 & R2 and returns at R0
MULTIPLY		STI			R7, _R7
				;JSR			SAVE_R1
				;JSR			SAVE_R2
				AND			R0, R0, #0
				ADD			R2, R2, #0
MULTILOOP		BRz			RETURN
				ADD			R0, R0, R2
				ADD			R1, R1, #-1
				BRnzp		MULTILOOP
				;JSR			RESTORE_R1
				;JSR			RESTORE_R2
				LDI			R7, _R7
RETURN			RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Make R0 negative
MAKE_NEGATIVE	NOT			R0, R0
				ADD			R0, R0, #1
				RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INVALID_CHECK
	LD		R0, WN_LENGTH
	ADD		R0, R0, #-6
	BRzp	INVALID_TRUE
	LD		R1, USER_NUM_PTR
	LDR		R0, R1, #0
	ADD		R0, R0, #-6
	BRp		INVALID_TRUE
	BRn		INVALID_FALSE
	LDR		R0, R1, #1
	ADD		R0, R0, #-5
	BRp		INVALID_TRUE
	BRn		INVALID_FALSE
	LDR		R0, R1, #2
	ADD		R0, R0, #-5
	BRp		INVALID_TRUE
	BRn		INVALID_FALSE
	LDR		R0, R1, #3
	ADD		R0, R0, #-0
	BRp		INVALID_TRUE
	LDR		R0, R1, #4
	ADD		R0, R0, #-4
	BRp		INVALID_TRUE
	BRnz	INVALID_FALSE
INVALID_TRUE
	LEA		R0, INVALID_INPUT
	PUTS
	JSR		BEGINNING
INVALID_FALSE
	RET
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WELCOME				.STRINGZ	"\nPlease enter a decimal value no greater than 65,504\n"
WHOLE_NUMBER		.BLKW		#1				;store the whole number in binary here
DECIMAL_NUMBER		.BLKW		#1				;store the decimal portion in binary here
FLOATING_POINT		.BLKW		#1				;Store the floating point here
EXPONENT_RAW		.BLKW		#1				;Create the 5-bit exponent here
EXPONENT			.BLKW		#1				;Create the actual exponent for the floating point here
MANTILLA			.BLKW		#1				;Create the Mantilla (fraction) here
SIGN				.FILL		#0				;The sign of the number is positive(0) unless changed by user
WN_LENGTH			.FILL		#0				;Length of the whole number
DEC_LENGTH			.FILL		#0				;Length of the decimal
ENTER				.FILL		#-10			;check for user pressing enter
NEGATIVE			.FILL		#-45			;check for negative
POINT				.FILL		#-46			;check for decimal
DECIMAL				.FILL		#0				;A one means we already have a decimal
DEC_SPACE			.FILL		#0
ASCII				.FILL		x0030
USER_NUM_PTR		.FILL		x4000
TEN					.FILL		x000A
TENK				.FILL		#10000
LB_CHECK			.FILL		x8000
BITMASK6			.FILL		x03FF
SPACE				.FILL		x0020
NEWLINE				.FILL		x000A
HIDDEN_BIT			.FILL		#1
_R0					.FILL		x6000
_R1					.FILL		x6001
_R2					.FILL		x6002
_R3					.FILL		x6003
_R4					.FILL		x6004
_R5					.FILL		x6005
_R6					.FILL		x6006
_R7					.FILL		x6007
_MAIN				.FILL		x6008
INVALID_INPUT		.STRINGZ	"\nSorry, that number is invalid\n"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Take an input at R0 representing the whole number portion of the number
;find out the exponent number if R0 > 0.
;if R0 == 0, set fraction space to 10 and create fraction before finding exponent
;Set Exponent (if possible)
;Set fraction space
;Add Whole Num to Mantilla
WHOLE_TO_FLT
	AND		R6, R6, #0			;Count the number of bit-shifts in R6
	ADD		R0, R0, #0			;see if the whole number input is zero
	BRz		WN_ZERO

WTF_LOOP
	LD		R1, LB_CHECK		;see if R0 is fully shifted
	AND		R2,R1,R0			;
	BRn		WN_SHIFTED			;if positive, the number has been fully shifted
	ADD		R0, R0, R0			;Bitshift R0 and increment
	ADD		R6, R6, #1
	BRnzp	WTF_LOOP
WN_ZERO
	JSR		DEC_TO_FLT_NWN		
	LD		R0, DECIMAL_NUMBER
	BRz		OUTPUT_ZERO
	LD		R0, EXPONENT_RAW
	NOT		R0, R0
	ADD		R0, R0, #1
	ADD		R0, R0, #15
	ST		R0, EXPONENT
	LD		R0, FRACTION16		;Load the input for BIT_SHIFT_ADD
	AND		R1, R1, #0
	ADD		R1, R1, #10
	LD		R2, EXPONENT
	BRnzp	FFP2
	
WN_SHIFTED						;15-#shifts = actual exponent value
	ADD		R6, R6, #-15		;negative of actual exponent
	NOT		R6, R6
	ADD		R6, R6, #1
	ST		R6, EXPONENT		;This is the exponent value
	ADD		R6, R6, #15			;ADD actual exponent to 15 to create the correct formatting
	ST		R6, EXPONENT_RAW	;exponent is now stored and is final
	ADD		R0, R0, R0			;bit shift whole_num one last time to account for hidden bit
	ST		R0, MANTILLA		;WN portion of mantilla is stored starting on left to right
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;push exponent left, check mantilla, add it to exponent
;add sign at end
;store into floating point
FORM_FLOATING_POINT
	LD		R0, MANTILLA
	LD		R2, EXPONENT
	ADD		R1, R2, #-10
	BRzp	EXP10
	NOT		R1, R1
	ADD		R1, R1, #1
	ST		R1, DEC_SPACE
	ADD		R1, R2, #0			;The exponent is the number of shifts to add, no greater than 10
	LD		R2, EXPONENT_RAW
	JSR		BIT_SHIFT_ADD
	ST		R2, FLOATING_POINT
	JSR		DEC_TO_FLT			;Create the decimal portion of the mantilla
	LD		R0, FRACTION16
	LD		R1, DEC_SPACE
	LD		R2, FLOATING_POINT
FFP2
	JSR		BIT_SHIFT_ADD
	ST		R2, FLOATING_POINT
	BRnzp	ADD_SIGN
EXP10
	AND		R1, R1, #0
	ADD		R1, R1, #10
	LD		R2, EXPONENT_RAW
	JSR		BIT_SHIFT_ADD
	ST		R2, FLOATING_POINT
ADD_SIGN
	LD		R2, FLOATING_POINT
	LD		R1, LB_CHECK
	LD		R0, SIGN
	BRz		FFP_END
	ADD		R0, R1, R2			;add sign to floating point
	ST		R0, FLOATING_POINT	
FFP_END
	LD		R2, FLOATING_POINT
	BRnzp	PRINT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;The number to print is stored in R2
;adds spaces where necessary for readability
PRINT
	AND		R4, R4, #0
	ADD		R4, R4, #15
	LD		R0, NEWLINE
	OUT
PRINT_LOOP
	LD		R6, ASCII
	LD		R1, LB_CHECK
	AND		R3, R2, R1
	BRn		PRINT1
	BRz		PRINT0
PRINT0
	AND		R0, R0, #0
	ADD		R0, R0, R6
	OUT
	BRnzp	SPACE_CHECK
PRINT1
	AND		R0, R0, #0
	ADD		R0, R0, #1
	ADD		R0, R0, R6
	OUT
	BRNZP	SPACE_CHECK
SPACE_CHECK
	ADD		R5, R4, #-15
	BRz		PRINT_SPACE
	ADD		R5, R4, #-10
	BRz		PRINT_SPACE
	BRnzp	PRINT_SHIFT
PRINT_SPACE
	LD		R0, SPACE 				;Print the space
	OUT
	ADD		R5, R4, #-10			;see if we need to print the hidden bit
	BRnp	PRINT_SHIFT
	LD		R0, HIDDEN_BIT
	ADD		R0, R0, R6
	OUT								;print hidden bit
	LD		R0, POINT				;Print decimal
	NOT		R0, R0
	ADD		R0, R0, #1
	OUT
PRINT_SHIFT
	ADD		R2, R2, R2				;Shift number to print Left
	ADD		R4, R4, #-1
	BRzp	PRINT_LOOP
	BRnzp	RESTART_MAIN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
OUTPUT_ZERO
	AND		R0, R0, #0
	ST		R0, FLOATING_POINT
	ST		R0, HIDDEN_BIT
	LD		R0, SIGN
	BRp		NEGATIVE_ZERO
	ADD		R2, R0, #0
	BRnzp	PRINT
NEGATIVE_ZERO
	LD		R2, LB_CHECK
	BRnzp	PRINT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DEC_TO_FLT
	STI		R7, _R7
	LD		R0, DECIMAL_NUMBER
	JSR		MAKE_FRACTION
	LDI		R7, _R7
	RET

DEC_TO_FLT_NWN
	STI		R7, _R7
	LD		R0, DECIMAL_NUMBER
	JSR		MAKE_FRACTION
	LDI		R7, _R7
	RET
	
;Take an input at R0 with a decimal number representing a fraction
;e.g. 1234 = .1234
;Return a 16bit fraction representation of the number in R1 into FRACTION16
MAKE_FRACTION
	AND		R6, R6, #0			;R6 will be the counter
	LD		R2, TENK			;Test value, -10000
	NOT		R2, R2
	ADD		R2, R2, #1
	AND		R1, R1, #0			;Build the fraction in R1
	AND		R4, R4, #0			;Counter
	ADD		R4, R4, #15
MF_LOOP
	ADD		R0, R0, R0			;Double the fraction value
	ADD		R3, R0, R2			;If greater than test value (or equal), add a bit
	BRzp	ADD_BIT
	ADD		R1, R1, R1			;Left shift without adding bit
	ADD		R4, R4, #-1
	BRzp	MF_LOOP
	BRn		MF_ROUND
ADD_BIT
	ADD		R1, R1, R1			;Shift the number, then add 1
	ADD		R1, R1, #1
	ADD		R0, R3, #0
	ADD		R4, R4, #-1
	BRzp	MF_LOOP
	BRn		MF_ROUND
MF_ROUND
	LD		R5, WHOLE_NUMBER
	BRz		SHIFT_DEC			;If there isn't a whole number then the exponent is calculated differently
	ADD		R0, R0, R0			;Double the fraction value
	ADD		R3, R0, R2			;If greater than test value (or equal), add a bit for rounding
	BRn		MF_END
	ADD		R1, R1, #1			;ADD rounding bit if necessary
	BRnzp	MF_END

SHIFT_DEC
	ST		R0, _R0
	ADD		R0, R0, #0
	BRz		MF_END				;If the fraction is zero then the whole thing is zero
	ST		R1, FRACTION16		;Store the current 16bit decimal
	AND		R4, R4, #0			;count number of shifts
	LD		R0, FRACTION16		;this is reloading R0 so we dont enter an infinite loop
SD_LOOP
	LD		R1, LB_CHECK
	AND		R1, R0, R1			;See if there is a leading bit
	BRn		SD2
	ADD		R4, R4, #1
	ADD		R0, R0, R0
	BRnzp	SD_LOOP
SD2
	ADD		R4, R4, #1
	LD		R1, FRACTION16
	LD		R0, _R0
	ST		R4, EXPONENT_RAW	;The number of shifts here is the NEGATIVE exponent
	AND		R6, R6, #0
	ADD		R6, R6, #1
	ST		R6, WHOLE_NUMBER	;corrupts the original whole number, but prevents repetition through this loop
	ADD		R4, R4, #-1
	BRnzp	MF_LOOP
	
MF_END
	
	ST		R1, FRACTION16
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Take an input R0 and shift it a certain number of times to the left
;the counter is from R1
;Return those values from R0 to R2, R2 may already contain a value
BIT_SHIFT_ADD
	STI		R2, _R2
BSA_LOOP
	ADD		R2, R2, R2			;Shift the location where num will be stored to make room for new input
	LD		R3, LB_CHECK
	AND		R3, R0, R3			;see if there is a bit present in the input
	BRz		BSA_SHIFT			;if a bit is not present in R0 left side
	ADD		R2,R2,#1			;if a bit is present (BRn) then add it
BSA_SHIFT
	ADD		R0, R0, R0			;shift the input value
	ADD		R1, R1, #-1			;decrease counter
	BRz		BSA_RET				;
BIT_SHIFT
	;ADD		R0, R0, R0			;only shift input if the counter is still positive
	BRnzp	BSA_LOOP
BSA_RET
	LD		R3, LB_CHECK
	AND		R3, R0, R3
	BRn		BSA_ROUND
	RET
BSA_ROUND
	ADD		R2, R2, #1
	RET


FRACTION16		.BLKW		#1		;store the fraction here

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Place a tag at the top of your program called 'BEGINNING'
;Edit the message as needed
RESTART_MESSAGE		.STRINGZ		"\nWould you like to make another calculation (y/n)?  "
END_MESSAGE			.STRINGZ		"\nThank you for using this program, come back soon"
RESTART_MAIN	LEA			R0,RESTART_MESSAGE
				PUTS

RESTART_LOOP	GETC
				JSR			VALIDATE_YN
				OUT
				ADD			R6, R6, #0		;Load the result from the validation subroutine
				BRz			QUIT_PROGRAM
				JSR			RESET_REGISTERS


;validates the user input for either y / n.  
;returns in R6 a 1 (yes), or 0 (no)
VALIDATE_YN	LD			R6, ASCIIy
				NOT			R6, R6
				ADD			R6, R6, #1
				ADD			R1, R0, R6
				BRz			YES
				LD			R6, ASCIIn
				NOT			R6, R6
				ADD			R6, R6, #1
				ADD			R1, R0, R6
				BRz			NO
				BRnzp		RESTART_LOOP
YES				AND			R6, R6, #0
				ADD			R6, R6, #1
				RET
NO				AND			R6, R6, #0
				RET

RESET_REGISTERS	AND			R0, R0, #0
				AND			R1, R1, #0
				AND			R2, R2, #0
				AND			R3, R3, #0
				AND			R4, R4, #0
				AND			R5, R5, #0
				AND			R6, R6, #0
				AND			R7, R7, #0
				JSR			BEGINNING
				
QUIT_PROGRAM	LEA			R0, END_MESSAGE
				PUTS
				HALT
				
ASCIIy			.FILL		x0079
ASCIIn			.FILL		x006E


.END
