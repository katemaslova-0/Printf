section     .text

global _start

_start:
            push 66d
            push 65d
            mov r9, 65d
            mov r8, 65d
            mov rcx, 65d     
            mov rdx, 65d                        ; arguments for MyPrintf in reverse order
            mov rsi, TestString
            mov rdi, String

            call MyPrintf

            mov rax, 0x3C                       ; syscall number for exit
            xor rdi, rdi                        ; exit code = 0
            syscall                             ; call kernel

global MyPrintf
    
MyPrintf:
            push rbx
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

        FindSpcf:
            cmp byte [rdi], '%'             ; looking for specifier            
            jne NoSpcf                      ; if no '%' -> print sym
            call PrintSpcf                  ; else -> analyse specifier 
            inc r12
            jmp NextSym

        NoSpcf:
            ;call PrintSym
            call StoreSym

        NextSym:
            inc rdi                         ; go to the next sym in line
            
        loop FindSpcf

            call OutpTheRest

            pop r13
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
            push rbx

            mov rbx, rdi                    ; string offset to rbx
            xor rax, rax                    ; to use as a counter

        CheckSym:
            cmp byte [rbx], 0
            je EndOfLine
            inc rax
            inc rbx
            jmp CheckSym

        EndOfLine:
            pop rbx
            ret

;================================
;PrintSpcf
;
;Expected: string offset in rdi
;Destroys: rbx, ?
;Returns: ?
;================================

PrintSpcf:  
            inc rdi                         ; move to next sym
            mov rbx, [rdi]                  ; put symbol to bx
            and rbx, 0FFh                   ; leave only the last byte
            sub rbx, 'b'

            jmp [SpecifierSwitch + rbx * 8d]

        caseB:
            call PushArg
            call PrintBinary
            jmp caseNoSpcf

        caseC:
            call PushArg
            call PrintChar
            jmp caseNoSpcf

        caseD:
            call PushArg
            call PrintDecimal
            jmp caseNoSpcf

        caseF:
            ;call PushArg
            ;call PrintFloat
            jmp caseNoSpcf

        caseO:
            call PushArg
            call PrintOctal
            jmp caseNoSpcf
        
        caseS:
            call PushArg
            call PrintString
            jmp caseNoSpcf

        caseX:
            call PushArg
            call PrintHex
            jmp caseNoSpcf

        caseNoSpcf:
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

            cmp r12, 5d
            jge caseMore
            jmp [ArgSwitch + r12 * 8d]

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
            push rax
            ret  


PrintDecimal:
            pop rbx                         ; save return address

            pop rax                         ; get decimal number
            push rdi                        ; save string position
            push rcx                        ; save the counter
            push rsi
            push r12
            push rdx
            mov rdx, rax

        ;    push rax
        ;    and rax, 80000000h              ; check the first bit
        ;    cmp rax, 1
        ;    je NegativeNum
        ;    pop rax
        ;    jmp RegToDec
;
        ;NegativeNum:
        ;    pop rax
        ;    dec rax
        ;    not rax                         ; convert to positive equivalent

        RegToDec:
            mov rcx, 10d                    ; as a counter
            mov r12, 10d                    ; as a const value for division
            mov rsi, 1000000000d                 

        PrintDecNum:
            mov rax, rdx
            xor rdx, rdx
            div rsi

            add rax, '0'
            mov [SymBuff], al
            mov rdi, SymBuff

            call StoreSym

            push rdx
            mov rax, rsi
            xor rdx, rdx
            div r12
            mov rsi, rax
            pop rdx

        loop PrintDecNum

            pop rdx
            pop r12
            pop rsi
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            pop rdi                         ; restore string position

            push rbx                        ; restore return address
            ret

            ret

PrintOctal:
            pop rbx                         ; save return address

            pop rax                         ; get octal number
            push rdi                        ; save string position
            push rcx                        ; save the counter
            push rsi                        ; save reg value
            push rdx                        ; to use for 'and'

            xor rsi, rsi                    ; to use as a flag
            mov rdx, 0C000000000000000h     ; to use as const value

            push rax                        ; 
            and rax, rdx
            shr rax, 63d                    ; leave only the first bit             
            cmp rax, 0
            je NullFirstBits
            mov rsi, 1
            add rax, '0'
            
            mov [SymBuff], al
            mov rdi, SymBuff

            call StoreSym

        NullFirstBits:
            pop rax
            shl rax, 1                     

            mov rcx, 21d                    ; num of 3-bit(= one octal num) combinations in a reg(without the first bit)
            mov rdx, 0E000000000000000h     ; to use as const value

        PrintThreeBits:
            push rax
            and rax, rdx
            shr rax, 61d                    ; leave only 3 bytes
            cmp rax, 0
            je NullBit
            mov rsi, 1
            jmp PrintOctBit

        NullBit:
            cmp rsi, 0
            je NoOctPrint
            
        PrintOctBit:
            add rax, '0'
            mov [SymBuff], al
            mov rdi, SymBuff

            call StoreSym
        
        NoOctPrint:
            pop rax
            shl rax, 3d
        loop PrintThreeBits

            pop rdx                         ; restore reg value
            pop rsi                         ; restore reg value
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            pop rdi                         ; restore string position
            push rbx                        ; restore return address

            ret

PrintString:
            pop rbx                         ; save return address

            pop rax                         ; get argument string offset
            push rcx                        ; save the counter
            push rdx
            push rdi                        ; save main string offset

            mov rdi, rax

            call CalcLength
            mov qword [string_flag], 1
            call StoreSym
            mov qword [string_flag], 0

            pop rdi
            pop rdx
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf

            push rbx                        ; restore return address
            ret

PrintHex:  
            pop rbx                         ; save return address

            pop rax                         ; get the hex value
            push rdi                        ; save string position
            push rcx                        ; save the counter
            push rsi                        ; to use as const value
            push rdx                        

            xor rdx, rdx                    ; to use as a flag
            mov rcx, 16d                    ; num of 4-bit(= one hex num) combinations in a reg
            mov rsi, 0F000000000000000h     ; to use as const value

        PrintHalfOfAByte:
            push rax
            and rax, rsi
            shr rax, 8 * 7d + 4d            ; leave only halh of one byte
            cmp rax, 0
            je NullHexBits
            mov rdx, 1
        NullHexBits:
            cmp rdx, 0
            je NoHexPrint

            cmp rax, 9d
            jg IsLetter
            add rax, '0'
            jmp HexIsReady

        IsLetter:
            add rax, 'A' - 0Ah
        HexIsReady:
            mov [SymBuff], al
            mov rdi, SymBuff

            call StoreSym

        NoHexPrint:
            pop rax
            shl rax, 4d
        loop PrintHalfOfAByte

            pop rdx
            pop rsi
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            pop rdi                         ; restore string position
            push rbx                        ; restore return address
            ret

PrintChar:
            pop rbx                         ; save return address
            pop rax                         ; get the char value
            push rdi                        ; save string position

            mov [SymBuff], al
            mov rdi, SymBuff

            ;call PrintSym
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
;Destroys: rbx
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
            
        PrintOneBit:
            shl rax, 1
            jnc IsZero

            mov byte [SymBuff], '1'
            mov rbx, 1                      
            jmp BitIsSet           

        IsZero:
            cmp rbx, 0                      ; if there wasn't '1' before, no '0' printing
            je SkipPrint
            mov byte [SymBuff], '0'         ; put the ASCII to memory  

        BitIsSet:                       
            mov rdi, SymBuff

            call StoreSym

        SkipPrint:
        loop PrintOneBit

            pop rdi                         ; restore string position
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            ret

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

StoreSym:
            push rax
            push rcx                        ; save the counter
            push rdi                        ; save the arg
            push rsi                        ; save the arg
            push rdx                        ; save the arg

            mov rcx, [string_flag]
            cmp rcx, 1
            je IsString
            mov rcx, 1
            jmp StoreAll

        IsString:
            mov rcx, rax

        StoreAll:
            cmp r13, OutBuffSize
            jne NoPrintBuff
            
            push rdi
            push rcx
            mov rsi, OutputBuff             ; offset of the string 
            mov rax, 0x01                   ; write 
            mov rdi, 1                      ; stdout
            mov rdx, OutBuffSize            ; size
            syscall

            xor r13, r13
            pop rcx
            pop rdi

        NoPrintBuff:
            mov al, [rdi]
            mov byte [OutputBuff + r13], al
            inc r13
            inc rdi
        loop StoreAll

            pop rdx                         ; restore the arg
            pop rsi                         ; restore the arg
            pop rdi                         ; restore the arg
            pop rcx                         ; restore the counter
            pop rax
            ret

;PrintSym:
;            push rcx                        ; save the counter
;            push rdi                        ; save the arg
;            push rsi                        ; save the arg
;            push rdx                        ; save the arg
;            push rax
;
;            mov rsi, rdi                    ; offset of the string ([rdi] = current sym)
;            mov rax, 0x01                   ; write (rbx, rcx, rdx)
;            mov rdi, 1                      ; stdout
;            mov rdx, 1                      ; only one symbol
;            syscall
;
;            pop rax
;            pop rdx                         ; restore the arg
;            pop rsi                         ; restore the arg
;            pop rdi                         ; restore the arg
;            pop rcx                         ; restore the counter
;
;            ret
        
section     .data

String:      db "Hello world abc %s %c %x %o %d %c %c", 0h 
SymBuff:     db 0                           ; reserve 1 byte
OutBuffSize: equ 10d
OutputBuff:  db OutBuffSize dup(0)
  
TestString:  db "TestString123", 0h
TestBuff:    dq 0
string_flag: db 0

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