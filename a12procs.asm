;  Example Smith Number Count for 1 to 200: 8
;	4	22	27	58
;	85	94	121	166

; ***************************************************************

section	.data

; -----
;  Define standard constants.

LF		equ	10			; line feed
NULL		equ	0			; end of string
ESC		equ	27			; escape key

TRUE		equ	1
FALSE		equ	0

SUCCESS		equ	1			; Successful operation
NOSUCCESS	equ	0			; Unsuccessful operation

STDIN		equ	0			; standard input
STDOUT		equ	1			; standard output
STDERR		equ	2			; standard error

SYS_read	equ	0			; call code for read
SYS_write	equ	1			; call code for write
SYS_open	equ	2			; call code for file open
SYS_close	equ	3			; call code for file close
SYS_fork	equ	57			; call code for fork
SYS_exit	equ	60			; call code for terminate
SYS_creat	equ	85			; call code for file open/create
SYS_time	equ	201			; call code for get time

; -----
;  Globals (used by threads)

currentIndex	dq	1
myLock		dq	0

; -----
;  Local variables for thread function(s).

msgThread1	db	" ...Thread starting...", LF, NULL

; -----
;  Local variables for getArgs function

THREAD_MIN	equ	1
THREAD_MAX	equ	8
LIMIT_MIN	equ	10
LIMIT_MAX	equ	4000000000

errUsage	db	"Usage: ./smithNums -t <senaryNumber> ",
		db	"-l <senaryNumber>", LF, NULL
errOptions	db	"Error, invalid command line options."
		db	LF, NULL
errLSpec	db	"Error, invalid limit specifier."
		db	LF, NULL
errLValue	db	"Error, invalid limit value."
		db	LF, NULL
errLRange	db	"Error, limit out of range."
		db	LF, NULL
errTSpec	db	"Error, invalid thread count specifier."
		db	LF, NULL
errTValue	db	"Error, invalid thread count value."
		db	LF, NULL
errTRange	db	"Error, thread count out of range."
		db	LF, NULL

; -----
;  Local variables for aSenary2int function

qSix		dq	6
qTen		dq	10
tmpNum		dq	0


; ***************************************************************

section	.text

; ******************************************************************
;  Function getArgs()
;	Get, check, convert, verify range, and return the
;	sequential/parallel option and the limit.

;  Example HLL call:
;	stat = getArgs(argc, argv, &thdCount, &userLimit)

;  This routine performs all error checking, conversion of ASCII/senary
;  to integer, verifies legal range.
;  For errors, applicable message is displayed and FALSE is returned.
;  For good data, all values are returned via addresses with TRUE returned.

;  Command line format (fixed order):
;	-t <senaryNumber> -l <senaryNumber>

; -----
; *WARNING:*	The aSenary2int funciton returns a quad.
;		When returning the userLimit, return the full quad value.
;		When returning the thread count, return only the dword
;		portion of the quad result.

; -----
;  Arguments:
;	1) ARGC, value
;	2) ARGV, address
;	3) thread count (dword), address
;	4) user limit (qword), address

global getArgs
getArgs:

	push rbx
	push r12
	push r13
	push r14
	push r15
	push rcx
	push rdx

	mov rax, 0
	mov rbx, 0	;holds counter for arguments
	mov r12, 0
	mov r13, 0
	mov r15, rsi	;holds argv location

	;check number of command line args
	cmp rdi, 1
	je commandLineUsageError

	cmp rdi, 5
	jne commandLineInvalid

	;goes to 2nd argument
	inc rbx
	mov r12, qword[r15 + rbx * 8]	;move 2nd argument into a register

	;check 1st char, should be a '-'
	mov r14, 0
	mov al, byte[r12 + r14]
	mov r13b, '-'
	inc r14
	cmp al, r13b
	jne threadCountSpecifierInvalid

	;check 2nd char for 't'
	mov al, byte[r12 + r14]	;2nd char
	mov r13b, 't'
	inc r14
	cmp al, r13b
	jne threadCountSpecifierInvalid

	;too many chars check
	mov al, byte[r12 + r14]
	cmp al, NULL
	jne threadCountSpecifierInvalid

	;if arg 1 -t is fine, convert senary number
	inc rbx
	mov rdi, qword[r15 + rbx * 8]	;move 3rd arg into rdi to call convert function
	call aSenary2int
	;this returns the number in &num in rdi

	cmp rax, NOSUCCESS	;check if rax is NOSUCCESS
	jne threadCountNoError
	;if rax is NOSUCCESS, print error and end program
	mov rdi, errTValue
	push rax
	call printString
	pop rax
	pop rdx
	pop rcx
	jmp endGetArgs
	threadCountNoError:	;otherwise, continue

	;error check converted thread count
	mov r12, 0
	mov r12, qword[rsi]
	mov r13, THREAD_MIN
	cmp r12, r13
	jl threadCountRangeError

	mov r13, THREAD_MAX
	cmp r12, r13
	jg threadCountRangeError	

	;if thread count is okay
	pop rdx
	mov dword[rdx], r12d
	;check next command line arg

	;goes to 4th argument
	inc rbx
	mov r12, qword[r15 + rbx * 8]	;move 4th argument into a register

	;check 1st char, should be a '-'
	mov r14, 0
	mov al, byte[r12 + r14]
	mov r13b, '-'
	inc r14
	cmp al, r13b
	jne limitSpecifierInvalid

	;check 2nd char for 'l'
	mov al, byte[r12 + r14]	;2nd char
	mov r13b, 'l'
	inc r14
	cmp al, r13b
	jne limitSpecifierInvalid

	;too many chars check
	mov al, byte[r12 + r14]
	cmp al, NULL
	jne limitSpecifierInvalid

	;if limit specifier is ok, conver senary to int
	inc rbx
	mov rdi, qword[r15 + rbx * 8]	;move last arg into rdi to call convert function
	call aSenary2int

	cmp rax, NOSUCCESS	;check if rax is NOSUCCESS
	jne limitCountNoError
	;if rax is NOSUCCESS, print error and end program
	mov rdi, errLValue
	push rax
	call printString
	pop rax
	pop rcx
	jmp endGetArgs
	limitCountNoError:	;otherwise, continue

	;error check converted limit
	mov r12, 0
	mov r12, qword[rsi]
	mov r13, LIMIT_MIN
	cmp r12, r13
	jl limitRangeError

	mov r13, LIMIT_MAX
	cmp r12, r13
	jg limitRangeError

	;if limit is okay
	pop rcx
	mov dword[rcx], r12d

	jmp endGetArgs

	;Error Checking
	commandLineUsageError:
	pop rdx
	pop rcx
	mov rdi, errUsage
	call printString
	mov rax, NOSUCCESS
	jmp endGetArgs

	commandLineInvalid:
	pop rdx
	pop rcx
	mov rdi, errOptions
	call printString
	mov rax, NOSUCCESS
	jmp endGetArgs

	threadCountSpecifierInvalid:
	pop rdx
	pop rcx
	mov rdi, errTSpec
	call printString
	mov rax, NOSUCCESS
	jmp endGetArgs

	threadCountRangeError:
	pop rdx
	pop rcx
	mov rdi, errTRange
	call printString
	mov rax, NOSUCCESS
	jmp endGetArgs

	limitSpecifierInvalid:
	pop rcx
	mov rdi, errLSpec
	call printString
	mov rax, NOSUCCESS
	jmp endGetArgs

	limitRangeError:
	pop rcx
	mov rdi, errLRange
	call printString
	mov rax, NOSUCCESS
	jmp endGetArgs

	endGetArgs:

	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx

ret

; ******************************************************************
;  Function: Check and convert ASCII/senary to integer.

;  Example HLL Call:
;	bool = aSenary2int(senaryStr, &num);

global aSenary2int
aSenary2int:

	push rbx
	push r13
	push r15

	mov rbx, 0
	mov r13, 0	;count = 0
	mov r15, 0 	;summing reg

	startSenaryToInt:
	mov rax, 0
	movzx eax, byte[rdi + r13]

	;check if valid char if the current char isnt a space
	cmp eax, 32
	je validChar3
	cmp eax, '0'
	jae validChar4
	mov rax, NOSUCCESS	;if its below 0, aka not valid char, error
	jmp endSenaryToInt
	validChar4:
	cmp eax, '5'
	jbe validChar3
	mov rax, NOSUCCESS	;if its above 5 aka not valid char, error
	jmp endSenaryToInt

	validChar3:
	inc r13
	movzx ebx, byte[rdi + r13]
	cmp rbx, 0
	je endS2ILoop
	cmp eax, 32
	je startSenaryToInt
	sub rax, '0'
	add r15, rax
	mov rax, r15
	mul qword[qSix]
	mov r15, 0
	mov r15, rax
	jmp startSenaryToInt 

	endS2ILoop:
	sub rax, '0'
	add r15, rax

	mov qword[rsi], r15
	mov rax, SUCCESS

	endSenaryToInt:

	pop r15
	pop r13
	pop rbx

	ret


; ******************************************************************
;  Thread function, findSmithNumberCount()
;	Determine count of smith numbers for all values between
;	1 and userLimit (globally available)

; -----
;  Arguments:
;	N/A (global variable accessed)
;  Returns:
;	N/A (global variable accessed)

common	userLimit		1:8
common	smithNumberCount	1:8

global    findSmithNumberCount
findSmithNumberCount:
    push    rbx
    push    rdi


    mov        rdi, msgThread1
    call    printString

underUserLimit:
    call    spinLock

    mov        rbx, qword[currentIndex]
    inc        qword[currentIndex]

	call    spinUnlock
	
    cmp        rbx, qword[userLimit]
    ja        aboveUserLimit

    

    mov        rdi, rbx
    call    isSmithNum

    cmp        rax, TRUE
    jne        underUserLimit

    lock    inc    qword[smithNumberCount]    ;operates hardware

    ; call    spinUnlock
    jmp    underUserLimit
aboveUserLimit:

    pop    rdi
    pop    rbx

    ret


global isSmithNum
isSmithNum:
	push rbx
	push r12
	push r13

	mov rbx, rdi
	mov rdi, rbx
	call isPrime
	cmp eax, TRUE
	je notSmithNumber
	mov rdi, rbx
	call findSumOfDigits
	mov r12, rax
	mov rdi, rbx
	call findSumPrimeFactors
	mov r13, rax
	cmp r12, r13
	je isSmithNumber	
	jmp notSmithNumber

	isSmithNumber:
	mov eax, TRUE
	jmp isSmithNumEpilogue

	notSmithNumber:
	mov eax, FALSE

	isSmithNumEpilogue:
	pop r13
	pop r12
	pop rbx
	ret
; ******************************************************************
;  Check if prime function -> isPrime()

;	if (n <= 1)
;		return false;
;	for (int i = 2; i <= n/2; i++)
;		if (n % i == 0)
;			return false;
;	return true;

; -----
; Arguments
;	number

; Returns
;	TRUE / FALSE

global isPrime
isPrime:

	push r12
	push r13

	mov r12, 2
	mov rax, rdi
	cqo
	idiv r12
	mov r13, rax	;r13 holds n/2

	cmp rdi, 1
	jg numberGreaterThanOne
	;if n <= 1, return false
	mov rax, FALSE
	jmp endIsPrime

	numberGreaterThanOne:

	;for (int i = 2; i <= n/2; i++)
	startIsPrimeForLoop:
	cmp r12, r13 ;compare i with n/2
	jg endIsPrimeForLoop	;if i> n/2, end for loop
	;	if (n % i == 0)
		mov rax, rdi
		cqo
		idiv r12
		cmp rdx, 0
		jne notAFactor
	;		return false;
			mov rax, FALSE
			jmp endIsPrime
		notAFactor:
		inc r12
		jmp startIsPrimeForLoop
	endIsPrimeForLoop:
	mov rax, TRUE
	
	endIsPrime:
	pop r13
	pop r12

ret

; ******************************************************************
;  Find sum of digits for given number -> findSumOfDigits()
;  Sum digits for number.
;	set sumDigits = 0
;	set tmp = n
;	while tmp > 0 repeat
;		set sumDigits = sumDigits + (tmp mod 10)
;		set tmp = tmp / 10

; -----
;  Arguments:
;	number

;  Returns
;	sum (in rax)

global findSumOfDigits
findSumOfDigits:

	push r14
	push r15

	mov r15, 0		;set SumDigits = 0
	mov r14, rdi	;set tmp = n

	startFindSumWhileLoop:
	cmp r14, 0
	jle endFindSumWhileLoop	;while tmp > 0
	;if tmp > 0
	;sumDigits = sumDigits + (tmp mod 10)
	mov rax, r14
	cqo
	idiv qword[qTen]
	add r15, rdx
	
	;tmp = tmp / 10
	mov rax, r14
	cqo
	idiv qword[qTen]
	mov r14, rax

	jmp startFindSumWhileLoop	;hits end brackets of while loop, loop back and check condition

	endFindSumWhileLoop:
	mov rax, r15	;return sumDigits

	pop r15
	pop r14

ret

; ******************************************************************
;  Find sum of prime factors -> findSumPrimeFactors()

;	int i = 2, sum = 0;
;	while (n > 1) {
;		if (n % i == 0) {
;			sum = sum + findSumOfDigit(i);
;			n = n / i;
;		} else {
;			do {
;				i++;
;			} while (!isPrime(i));
;		}
;	}
;	return sum;

; -----
;  Arguments:
;	number

;  Returns
;	sum (in rax)

global findSumPrimeFactors
findSumPrimeFactors:
	push	rbx
	push	r12
	push	r13

	mov	rbx, rdi			; save n
	mov	r12, 2				; i=2
	mov	r13, 0				; sum=0

;	while (n > 1) {
primeFactorsLoop:
	cmp	rbx, 1
	jle	primeFactorsDone

;	if ((n % i) == 0) {
	mov	rax, rbx
	mov	rdx, 0
	div	r12
	cmp	rdx, 0
	jne	notDivisible

primeDigitsLoop:
	mov	rdi, r12
	call	findSumOfDigits
	add	r13, rax			; sum += findSumOfDigit(i);

;	n = n / i;
	mov	rax, rbx
	mov	rdx, 0
	div	r12
	mov	rbx, rax
	jmp	primeIfDone

notDivisible:					; } else {
;	do { i++; } while (!isPrime(i));
	inc	r12
	mov	rdi, r12
	call	isPrime
	cmp	rax, TRUE
	jne	notDivisible

primeIfDone:
	jmp	primeFactorsLoop		;; // end while

primeFactorsDone:
	mov	rax, r13			; return sum;

	pop	r13
	pop	r12
	pop	rbx
	ret

; ******************************************************************
;  Mutex lock
;	checks lock (shared global variable)
;		if unlocked, sets lock
;		if locked, lops to recheck until lock is free

global	spinLock
spinLock:
	mov	rax, 1			; Set the REAX register to 1.

lock	xchg	rax, qword [myLock]	; Atomically swap the RAX register with
					;  the lock variable.
					; This will always store 1 to the lock, leaving
					;  the previous value in the RAX register.

	test	rax, rax	        ; Test RAX with itself. Among other things, this will
					;  set the processor's Zero Flag if RAX is 0.
					; If RAX is 0, then the lock was unlocked and
					;  we just locked it.
					; Otherwise, RAX is 1 and we didn't acquire the lock.

	jnz	spinLock		; Jump back to the MOV instruction if the Zero Flag is
					;  not set; the lock was previously locked, and so
					; we need to spin until it becomes unlocked.
	ret

; ******************************************************************
;  Mutex unlock
;	unlock the lock (shared global variable)

global	spinUnlock
spinUnlock:
	mov	rax, 0			; Set the RAX register to 0.

	xchg	rax, qword [myLock]	; Atomically swap the RAX register with
					;  the lock variable.
	ret

; ******************************************************************
;  Generic function to display a string to the screen.
;  String must be NULL terminated.
;  Algorithm:
;	Count characters in string (excluding NULL)
;	Use syscall to output characters

;  Arguments:
;	- address, string
;  Returns:
;	nothing

global	printString
printString:

; -----
; Count characters to write.

	mov	rdx, 0
strCountLoop:
	cmp	byte [rdi+rdx], NULL
	je	strCountLoopDone
	inc	rdx
	jmp	strCountLoop
strCountLoopDone:
	cmp	rdx, 0
	je	printStringDone

; -----
;  Call OS to output string.

	mov	rax, SYS_write			; system code for write()
	mov	rsi, rdi			; address of characters to write
	mov	rdi, STDOUT			; file descriptor for standard in
						; rdx=count to write, set above
	syscall					; system call

; -----
;  String printed, return to calling routine.

printStringDone:
	ret

; ******************************************************************

