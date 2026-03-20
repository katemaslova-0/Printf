section     .text

global _start

_start:
            push 66d
            push 65d
            mov r9, 65d
            mov r8, 65d
            mov rcx, 65d
            mov rdx, -65d     
            mov rsi, TestString                   ; arguments for MyPrintf in reverse order
            mov rdi, String

            call MyPrintf

            mov rax, 0x3C                   ; syscall number for exit
            xor rdi, rdi                    ; exit code = 0
            syscall                         ; call kernel

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

;================================
;CalcLength
;
;Expected: string offset in rdi
;Destroys: -
;Returns: string length in rax
;================================

CalcLength:
            push rbx                        ; save return address

            mov rbx, rdi                    ; string offset to rbx
            xor rax, rax                    ; to use as a counter

        .CheckSym:                          ; looking for '\0' symbol
            cmp byte [rbx], 0
            je EndOfLine
            inc rax                         ; increase the counter
            inc rbx                         ; move to the next sym in string
        jmp .CheckSym

        EndOfLine:
            pop rbx                         ; restore return address
            ret

;================================
;PrintSpcf
;
;Expected: string offset in rdi
;Destroys: rbx, ?
;Returns: ?
;================================

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
            call PrintBinary
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
            call PrintOctal
            jmp EndPrintSpcf
        
        caseS:
            call PushArg
            call PrintString
            jmp EndPrintSpcf

        caseX:
            call PushArg
            call PrintHex
            jmp EndPrintSpcf

        caseNoSpcf:
            call ErrAndExit                 ; display error message and end the programm

        EndPrintSpcf:
            ret 

;================================
;ErrAndExit
;
;Expected: -
;Destroys: rax, rdi, rsi, rdx
;Returns: -
;================================

ErrAndExit:
        mov rax, 0x01                       ; write (rdi, rsi, rdx)
        mov rdi, 1                          ; stdout
        mov rsi, InvalidSpcf                ; error message offset
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

;================================
;PushArg
;
;Expected: -
;Destroys: rax
;Returns: -
;================================

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
;PrintDecimal
;
;Expected: arg on the top of the stack
;Destroys: rbx, rax
;Returns: -
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
            mov rdi, SymBuff                ; put the offset to rdi

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


;======================================
;PrintOctal
;
;Expected: arg on the top of the stack
;Destroys: rbx, rax
;Returns: -
;======================================

PrintOctal:
            pop rbx                         ; save return address

            pop rax                         ; get octal number
            push rdi                        ; save string position
            push rcx                        ; save the counter
            push rsi                        ; save reg value

            xor rsi, rsi                    ; to use as a flag

            push rax                        ; save rax
            shr rax, 63d                    ; leave only the first bit             
            cmp rax, 0                      ; check null bit
            je .NullFirstBit
            mov rsi, 1                      ; if non-zero bit -> set flag

            add rax, '0'                    ; convert to ascii
            mov [SymBuff], al               ; store sym in buffer
            mov rdi, SymBuff                ; put offset to rdi

            call StoreSym

        .NullFirstBit:
            pop rax                         ; restore rax
            shl rax, 1                      ; move to next bits                     

            mov rcx, 21d                    ; num of 3-bit(= one octal num) combinations in a reg(without the first bit)

        .PrintThreeBits:                    
            push rax                        ; store the octal value
            shr rax, 61d                    ; leave only 3 bits

            cmp rax, 0                      ; check null bit
            je .NullBit
            mov rsi, 1
            jmp .PrintOctNum

        .NullBit:
            cmp rsi, 0
            je .SkipNumPrint
            
        .PrintOctNum:
            add rax, '0'
            mov [SymBuff], al
            mov rdi, SymBuff

            call StoreSym
        
        .SkipNumPrint:
            pop rax
            shl rax, 3d                     ; move to next 3 bits

        loop .PrintThreeBits

            pop rsi                         ; restore reg value
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            pop rdi                         ; restore string position
            push rbx                        ; restore return address

            ret

;======================================
;PrintString
;
;Expected: arg on the top of the stack
;Destroys: rbx, rax
;Returns: -
;======================================

PrintString:
            pop rbx                         ; save return address

            pop rax                         ; get argument string offset
            push rcx                        ; save the counter(for loop in MyPrintf)
            push rdx                        ; save reg value        
            push rdi                        ; save main string offset

            mov rdi, rax                    ; move string offset to rdi

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

;======================================
;PrintHex
;
;Expected: arg on the top of the stack
;Destroys: rbx, rax
;Returns: -
;======================================

PrintHex:  
            pop rbx                         ; save return address

            pop rax                         ; get the hex value
            push rdi                        ; save string position
            push rcx                        ; save the counter
            push rdx                        

            xor rdx, rdx                    ; to use as a flag
            mov rcx, 16d                    ; num of 4-bit(= one hex num) combinations in a reg

        .PrintHexNum:
            push rax
            shr rax, 8 * 7d + 4d            ; leave only 4 bits
            cmp rax, 0                      ; check null bit
            je .NullBit
            mov rdx, 1

        .NullBit:
            cmp rdx, 0
            je .SkipPrint

            cmp rax, 9d
            jg .IsLetter
            add rax, '0'
            jmp .StoreHexNum

        .IsLetter:
            add rax, 'A' - 0Ah
        .StoreHexNum:
            mov [SymBuff], al
            mov rdi, SymBuff

            call StoreSym

        .SkipPrint:
            pop rax
            shl rax, 4d
        loop .PrintHexNum

            pop rdx
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            pop rdi                         ; restore string position
            push rbx                        ; restore return address
            ret

;======================================
;PrintChar
;
;Expected: arg on the top of the stack
;Destroys: rbx, rax
;Returns: -
;======================================

PrintChar:
            pop rbx                         ; save return address
            pop rax                         ; get the char value
            push rdi                        ; save string position

            mov [SymBuff], al               ; store sym to buff
            mov rdi, SymBuff                ; move buffer offset to rdi

            call StoreSym

            dec rcx                         ; for loop in MyPrintf                   

            pop rdi                         ; restore string position
            push rbx                        ; restore the return address
            ret

;=====================================
;PrintBinary
;
;Expected: string offset in rdi
;          arg on the top of the stack
;Destroys: rbx, rax
;Returns:  -
;=====================================

PrintBinary:
            pop rbx                         ; save the ret address

            pop rax                         ; get the binary number
            push rbx                        ; restore the ret address
            push rcx                        ; save the counter
            push rdi                        ; save string position
            xor rbx, rbx                    ; will be used as flag

            mov rcx, 64d                    ; num of bits in 8 bytes
            
        .PrintOneBit:
            shl rax, 1
            jnc .IsZero

            mov byte [SymBuff], '1'
            mov rbx, 1                      
            jmp .BitIsSet           

        .IsZero:
            cmp rbx, 0                      ; if there wasn't '1' before, no '0' printing
            je .SkipPrint
            mov byte [SymBuff], '0'         ; put the ASCII to memory  

        .BitIsSet:                       
            mov rdi, SymBuff

            call StoreSym

        .SkipPrint:
        loop .PrintOneBit

            pop rdi                         ; restore string position
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            ret

;========================================
;OutpTheRest
;
;Expected: num of symbols to print in r13
;Destroys: -
;Returns:  -
;========================================

OutpTheRest:
            push rcx                        ; save the counter
            push rdi                        ; save the arg
            push rsi                        ; save the arg
            push rdx                        ; save the arg
            push rax

            mov rsi, OutputBuff             ; offset of the string
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

;========================================
;StoreSym
;
;Expected: string flag set
;Destroys: -
;Returns:  -
;========================================

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

            mov rsi, OutputBuff             ; offset of the string 
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

String:      db "Hello world abc %s %d %o %b %c %x %c", 0h 
SymBuff:     db 0                           ; reserve 1 byte
OutBuffSize  equ 10d
OutputBuff:  db OutBuffSize dup(0)
  
TestString:  db "TestString123", 0h
TestBuff:    dq 0
string_flag: db 0
InvalidSpcf: db 0Ah, "Invalid specifier!", 0Ah, 0h
InvalidSpcfLen equ $ - InvalidSpcf

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