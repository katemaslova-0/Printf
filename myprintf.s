section     .text

global _start

;_start:
;            push 66d
;            push 65d
;            mov r9, 65d
;            mov r8, 65d
;            mov rcx, 65d
;            mov rdx, -65d     
;            mov rsi, TestString             ; arguments for MyPrintf in reverse order
;            mov rdi, String
;
;            call MyPrintf
;
;            mov rax, 0x3C                   ; syscall number for exit
;            xor rdi, rdi                    ; exit code = 0
;            syscall                         ; call kernel

global MyPrintf
    
MyPrintf:
            push rbx                        ; save registers according to system v abi         
            push rbp
            push r12
            push r13

            mov r10, rcx                    ; to use rcx as a counter; 4th argument now in in r10
            xor r12, r12                    ; to use as a pointer on current argument
            xor r13, r13                    ; to use as OutputBuff counter
            mov rbp, rsp
            add rbp, 5 * 8d                 ; where arguments start

            call CalcLength
            mov rcx, rax

        .FindSpcf:
            cmp byte [rdi], '%'             ; looking for specifier            
            jne .NoSpcf                     ; if no '%' -> print sym
            call PrintSpcf                  ; else -> analyse specifier 
            inc r12
            jmp .NextSym

        .NoSpcf:
            call StoreSym                   ; put sym to buffer

        .NextSym:
            inc rdi                         ; go to the next sym in line
            
        loop .FindSpcf

            call OutpTheRest                ; output symbols stored in the buffer

            pop r13                         ; restore saved registers
            pop r12
            pop rbp
            pop rbx

            ret

;=======================================
; CalcLength
;
; Calculates the length of the string
; stored in rdi and puts it to rax
;
; Expected: string address in rdi
; Destroys: -
; Returns: string length in rax
;=====================================

CalcLength:
            push rbx                        ; save rbx value

            mov rbx, rdi                    ; string address to rbx
            xor rax, rax                    ; to use as a counter

        .CheckSym:                          ; looking for '\0' symbol
            cmp byte [rbx], 0
            je EndOfLine
            inc rax                         ; increase the counter
            inc rbx                         ; move to the next sym in string
        jmp .CheckSym

        EndOfLine:
            pop rbx                         ; restore rbx value
            ret

;============================================
; PrintSpcf
;
; Checks the letter after '%' and calls
; the function according to it
;
; Expected: string address in rdi([rdi] = '%')
; Destroys: rbx, rdi
; Returns: -
;============================================

PrintSpcf:  
            inc rdi                         ; move to next sym(the one after '%')
            mov rbx, [rdi]                  ; put symbol to bx
            and rbx, 0FFh                   ; leave only the last byte
            sub rbx, 'b'                    ; calculate ascii of the specifier

            cmp rbx, 0                      ; checking the boundaries of the jump table(min value)
            jl caseNoSpcf

            cmp rbx, 88d                    ; checking the boundaries of the jump table(max value)
            jg caseNoSpcf
            
            jmp [SpecifierSwitch + rbx * 8d] ; address = 8 bytes

        caseB:
            call PushArg
            mov byte [num_system_flag], 0d
            call PrintBixOctHex
            jmp EndPrintSpcf

        caseC:
            call PushArg
            call PrintChar
            jmp EndPrintSpcf

        caseD:
            call PushArg
            call PrintDecimal
            jmp EndPrintSpcf

        caseF:
            ;call PushArg
            ;call PrintFloat
            jmp EndPrintSpcf

        caseO:
            call PushArg
            mov byte [num_system_flag], 1d
            call PrintBixOctHex
            jmp EndPrintSpcf
        
        caseS:
            call PushArg
            call PrintString
            jmp EndPrintSpcf

        caseX:
            call PushArg
            mov byte [num_system_flag], 2d
            call PrintBixOctHex
            jmp EndPrintSpcf

        caseNoSpcf:
            call ErrAndExit                 ; display error message and end the programm

        EndPrintSpcf:
            ret 

;================================
; ErrAndExit
; 
; Displays error message and ends
; the programm
;
; Expected: -
; Destroys: rax, rdi, rsi, rdx
; Returns: -
;================================

ErrAndExit:
        mov rax, 0x01                       ; write (rdi, rsi, rdx)
        mov rdi, 1                          ; stdout
        mov rsi, InvalidSpcf                ; error message address
        mov rdx, InvalidSpcfLen             ; error messsage length
        syscall                             ; call kernel

        sub rsp, 2 * 8d                     ; remove ErrAndExit and PrintSpcf ret adresses from stack
        pop r13                             ; restore registers according to system v abi
        pop r12
        pop rbp
        pop rbx

        mov rax, 0x3C                       ; end the programm
        xor rdi, rdi
        syscall

        ret

;=====================================
; PushArg
;
; Finds the arg according to system v
; ABI and pushes it to stack
; 
; Expected: args counter in r12
; Destroys: rax
; Returns: -
;====================================

PushArg:
            pop rax                         ; save return address

            cmp r12, 5d                     ; 5d is num of arduments stored in regs(without the string itself)
            jge caseMore                    ; if more -> take the arg from stack
            jmp [ArgSwitch + r12 * 8d]      ; address = 8 bytes

        case2:      
            push rsi
            jmp EndPush

        case3:      
            push rdx
            jmp EndPush

        case4:
            push r10
            jmp EndPush

        case5:
            push r8
            jmp EndPush

        case6: 
            push r9
            jmp EndPush

        caseMore:
            push qword [rbp + (r12 - 5d) * 8d]

        EndPush:
            push rax                        ; restore return address
            ret  

;======================================
; PrintDecimal
;
; Converts the argument from the top of
; the stack to decimal and stores it in
; OutputBuff
; 
; Expected: arg on the top of the stack
; Destroys: rbx, rax
; Returns: -
;======================================

PrintDecimal:
            pop rbx                         ; save return address

            pop rax                         ; get decimal number
            push rdi                        ; save string position
            push rcx                        ; save the counter(loop in MyPrintf)
            push rsi                        ; will be used for storing a const value
            push r12                        ; will be used for storing a const value
            push r14                        ; will be used as a flag
            push rdx

            mov rdx, rax
            xor r14, r14

            test rdx, rdx                   ; check the sign
            js .NegativeNum
            jmp .RegToDec

        .NegativeNum:
            neg rdx                         ; convert to positive equivalent
            mov byte [SymBuff], 45d         ; print '-' before the num
            mov rdi, SymBuff
            call StoreSym

        .RegToDec:
            mov rcx, 10d                    ; max value of decimal places
            mov r12, 10d                    ; as a const value for division
            mov rsi, 1000000000d            ; as a const value for division 

        .PrintDecNum:
            mov rax, rdx                 
            xor rdx, rdx
            div rsi                         ; result in rax, remainder in rdx

            cmp rax, 0                      ; check if bit is null
            je .NullBit
            mov r14, 1d

        .NullBit:
            cmp r14, 0                      ; if there wasn't any non-zero bits before -> skip printing
            je .SkipNumPrint

            add rax, '0'                    ; convert result to ascii
            mov [SymBuff], al               ; store it to the buffer
            mov rdi, SymBuff                ; put the address to rdi

            call StoreSym

        .SkipNumPrint:
            push rdx                        ; save rdx
            mov rax, rsi                    
            xor rdx, rdx                    
            div r12                         ; result in rax, remainder in rdx; division by 10d
            mov rsi, rax                    ; move result to rsi
            pop rdx

        loop .PrintDecNum

            pop rdx
            pop r14
            pop r12
            pop rsi
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            pop rdi                         ; restore string position

            push rbx                        ; restore return address
            ret

;==========================================
; PrintDecimal
;
; Takes the string address from the top of
; the stack and stores it in OutputBuff
; 
; Expected: arg on the top of the stack
; Destroys: rbx, rax
; Returns: -
;==========================================

PrintString:
            pop rbx                         ; save return address

            pop rax                         ; get argument string address
            push rcx                        ; save the counter(for loop in MyPrintf)
            push rdx                        ; save reg value        
            push rdi                        ; save main string address

            mov rdi, rax                    ; move string address to rdi

            call CalcLength                 ; the length is in rax
            mov qword [string_flag], 1      ; set the flag
            call StoreSym
            mov qword [string_flag], 0      ; unset

            pop rdi
            pop rdx                         ; restore reg value
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf

            push rbx                        ; restore return address
            ret

;=========================================
; PrintBixOctHex
;
; Checks the num_system_flag, converts
; the argument from the top of the stack
; according to it and stores it in
; OutputBuff
; 
; Expected: arg on the top of the stack
; Destroys: rbx, rax
; Returns: -
;=========================================

PrintBixOctHex:
            
            pop rbx                         ; save return address
            pop rax                         ; get the number
            push rbx                        ; restore the ret address

            push rcx                        ; save the counter
            push rdi                        ; save string position
            push rsi                        ; will be used as a flag(for null bits)
            push rdx                        ; will be used for storing num_system_flag
            push r12                        ; will be used for storing a const value

            xor rbx, rbx                    
            xor rsi, rsi
            
            mov bl, [num_system_flag]       
            cmp rbx, 1
            jne .NoBitSkip                  ; if not octal -> no first bit check

            shl rax, 1d                           
            jnc .NoBitSkip
            mov rsi, 1                      ; if non-zero bit -> set flag

            add rax, '0'                    ; convert to ascii
            mov [SymBuff], al               ; store sym in buffer
            mov rdi, SymBuff                ; put address to rdi

            call StoreSym

        .NoBitSkip: 
            cmp rbx, 0                      ; check num_system_flag
            je .Binary                      ; 0 is for binary
            cmp rbx, 1                  
            je .Octal                       ; 1 is for octal
            jmp .Hex                       

        .Binary:    
            mov rdx, 1d                     ; = bit shift size
            mov rcx, 64d                    ; = places in one num
            jmp .PrintNum

        .Octal:
            mov rdx, 3d                     ; = bit shift size
            mov rcx, 21d                    ; = places in one num
            jmp .PrintNum

        .Hex:
            mov rdx, 4d                     ; = bit shift size
            mov rcx, 16d                    ; = places in one num
        
        .PrintNum:
            mov r12, 64d                    ; = 8 bytes

            push rax                        ; save rax value

            sub r12, rdx                    ; r12 = 64d - rdx
            push rcx                        ; save rcx value(can only use cl for bit shift)
            mov cl, r12b
            shr rax, cl                     ; leave only _ bits
            pop rcx                         ; restore rcx value

            cmp rax, 0                      ; check null bit
            je .NullBit
            mov rsi, 1                      ; set the flag

        .NullBit:
            cmp rsi, 0                      ; check the flag
            je .SkipPrint

            cmp rax, 9d                     ; check if letter
            jg .IsLetter
            add rax, '0'                    ; convert num to ascii
            jmp .StoreNum

        .IsLetter:
            add rax, 'A' - 0Ah              ; convert letter to ascii
        .StoreNum:
            mov [SymBuff], al               ; store sym in buffer
            mov rdi, SymBuff

            call StoreSym

        .SkipPrint:
            pop rax                         ; restore rax value

            push rcx                        ; save rcx value(can only use cl for bit shift)
            mov cl, dl                      ; rdx = bit shift each cycle
            shl rax, cl
            pop rcx                         ; restore rcx value

        loop .PrintNum

            pop r12                         ; restore r12 value
            pop rdx                         ; restore rdx value
            pop rsi                         ; restore rsi value
            pop rdi                         ; restore string position
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf

            ret

;======================================
; PrintChar
;
; Converts the argument from the top of
; the stack to char and stores it in
; OutputBuff
; 
; Expected: arg on the top of the stack
; Destroys: rbx, rax
; Returns: -
;======================================

PrintChar:
            pop rbx                         ; save return address
            pop rax                         ; get the char value
            push rdi                        ; save string position

            mov [SymBuff], al               ; store sym to buff
            mov rdi, SymBuff                ; move buffer address to rdi

            call StoreSym

            dec rcx                         ; for loop in MyPrintf                   

            pop rdi                         ; restore string position
            push rbx                        ; restore the return address
            ret

;==========================================
; OutpTheRest
;
; Displays remaining symbols in OutputBuff
; 
; Expected: num of symbols to print in r13
; Destroys: -
; Returns:  -
;==========================================

OutpTheRest:
            push rcx                        ; save the counter
            push rdi                        ; save the arg
            push rsi                        ; save the arg
            push rdx                        ; save the arg
            push rax

            mov rsi, OutputBuff             ; address of the string
            mov rax, 0x01                   ; write (rbx, rcx, rdx)
            mov rdi, 1                      ; stdout
            mov rdx, r13                    ; size
            syscall

            pop rax
            pop rdx                         ; restore the arg
            pop rsi                         ; restore the arg
            pop rdi                         ; restore the arg
            pop rcx                         ; restore the counter

            ret

;=====================================================
; StoreSym
;
; Stores the symbol(or the whole line if the
; argument is string) to OutputBuff. Displays
; the buffer if it's full.
; 
; Expected: string flag set if needed
;           sym/string address in rdi
;           string length in rax if the arg is string
; Destroys: -
; Returns:  -
;=====================================================

StoreSym:
            push rax                        ; save reg value
            push rcx                        ; save the counter
            push rdi                        ; save the arg
            push rsi                        ; save the arg
            push rdx                        ; save the arg

            mov rcx, [string_flag]          ; check if string
            cmp rcx, 1
            je .IsString
            mov rcx, 1                      ; if not string -> only one sym
            jmp .StoreAll                   

        .IsString:
            mov rcx, rax                    ; string length is returned by CalcLength in rax

        .StoreAll:
            cmp r13, OutBuffSize            ; r13 is an OutBuff counter
            jne .NoPrintBuff                ; if OutBuff isn't full -> store the sym, else -> output
            
            push rdi                        ; save regs values                   
            push rcx

            mov rsi, OutputBuff             ; address of the string 
            mov rax, 0x01                   ; write 
            mov rdi, 1                      ; stdout
            mov rdx, OutBuffSize            ; size
            syscall

            xor r13, r13                    ; OutBuff is empty now

            pop rcx                         ; restore reg values
            pop rdi

        .NoPrintBuff:
            mov al, [rdi]                   ; move sym to al
            mov byte [OutputBuff + r13], al ; store it in OutputBuff
            inc r13                         ; increase the buff counter
            inc rdi                         ; go to next sym(needed for string)
        loop .StoreAll

            pop rdx                         ; restore the arg
            pop rsi                         ; restore the arg
            pop rdi                         ; restore the arg
            pop rcx                         ; restore the counter
            pop rax                         ; restore reg value

            ret
        
section     .data

String:             db "Hello world abc %s %d %o %b %c %x %c", 0h 
TestString:         db "TestString123", 0h

SymBuff:            db 0 

OutBuffSize:        equ 10d
OutputBuff:         db OutBuffSize dup(0)
  
string_flag:        db 0
num_system_flag:    db 0

InvalidSpcf:        db 0Ah, "Invalid specifier!", 0Ah, 0h
InvalidSpcfLen:     equ $ - InvalidSpcf

ArgSwitch:
    dq case2
    dq case3
    dq case4
    dq case5
    dq case6

SpecifierSwitch:
    dq caseB
    dq caseC
    dq caseD
    dq caseNoSpcf
    dq caseF
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseO
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseS
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseNoSpcf
    dq caseX