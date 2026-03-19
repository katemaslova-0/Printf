section     .text

global _start

_start:     
            ;mov rsi, 65d                       ; arguments for MyPrintf in reverse order
            mov rsi, TestString
            mov rdi, String                     ;

            call MyPrintf

            mov rax, 0x3C                       ; syscall number for exit
            xor rdi, rdi                        ; exit code = 0
            syscall                             ; call kernel
    
MyPrintf:
            push rbx
            push rbp
            push r12
            push r13

            xchg rcx, r10                   ; to use rcx as a counter; 4th argument now in in r10
            xor r12, r12                    ; to use as a pointer on current argument
            xor r13, r13                    ; to use as OutputBuff counter
            mov rbp, [rsp + 6 * 8d]         ; where arguments starts

            call CalcLength
            mov rcx, rax

        FindSpcf:
            cmp byte [rdi], '%'             ; looking for specifier            
            jne NoSpcf                      ; if no '%' -> print sym
            call PrintSpcf                  ; else -> analyse specifier 
            inc r12
            jmp NextSym

        NoSpcf:
            call PrintSym

        NextSym:
            inc rdi                         ; go to the next sym in line
            
        loop FindSpcf

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
;Returns: string length in rcx
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
            ;call PrintDecimal
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
            push qword [rbp + r11 * 8d]

        EndPush:
            push rax
            ret  


PrintDecimal:
        ;    pop ebx                         ; save return address

        ;    pop edx                         ; get decimal number
        ;    push eax                        ; save string position
        ;    push ecx                        ; save the counter
        ;    push esi
;
        ;    push edx
        ;    and edx, 80000000h              ; check the first bit
        ;    cmp edx, 1
        ;    je NegativeNum
        ;    pop edx
        ;    jmp RegToDec
;
        ;NegativeNum:
        ;    pop edx
        ;    dec edx
        ;    not edx                         ; convert to positive equivalent

        ;RegToDec:
        ;    mov ecx, 10d                    ; as a counter
        ;    mov ebp, 10d                    ; as a const value for division
        ;    mov esi, 1000000000d                 
;
        ;PrintDecNum:
        ;    mov eax, edx
        ;    xor edx, edx
        ;    div esi
;
        ;    add eax, '0'
        ;    mov [SymBuff], eax
        ;    mov eax, SymBuff
        ;    call PrintSym
;
        ;    push edx
        ;    mov eax, esi
        ;    xor edx, edx
        ;    div ebp
        ;    mov esi, eax
        ;    pop edx
;
        ;loop PrintDecNum
;
        ;    pop esi
        ;    pop ecx                         ; restore the counter
        ;    dec ecx                         ; for loop in MyPrintf
        ;    pop eax                         ; restore string position
        ;    push ebx                        ; restore return address
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
            
            mov [SymBuff], rax
            mov rdi, SymBuff
            call PrintSym

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
            mov [SymBuff], rax
            mov rdi, SymBuff
            call PrintSym
        
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
            mov rcx, rax
            ;mov rcx, 13d ; change!!!!!!!
            mov rdx, rcx
            call PrintSizedString

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
            push rsi

            mov rcx, 16d                    ; num of 4-bit(= one hex num) combinations in a reg
            mov rsi, 0F000000000000000h     ; to use as const value

        PrintHalfOfAByte:
            push rax
            and rax, rsi
            shr rax, 8 * 7d + 4d               ; leave only halh of one byte
            cmp rax, 9d
            jg IsLetter
            add rax, '0'
            jmp HexIsReady

        IsLetter:
            add rax, 'A' - 0Ah
        HexIsReady:
            mov [SymBuff], rax
            mov rdi, SymBuff
            call PrintSym

            pop rax
            shl rax, 4d
        loop PrintHalfOfAByte

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

            mov [SymBuff], rax
            mov rdi, SymBuff
            call PrintSym
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
            mov byte [SymBuff], '0'          ; put the ASCII to memory  

        BitIsSet:                       
            mov rdi, SymBuff
            call PrintSym

        SkipPrint:
        loop PrintOneBit

            pop rdi                         ; restore string position
            pop rcx                         ; restore the counter
            dec rcx                         ; for loop in MyPrintf
            ret

PrintSizedString:

            push rcx                        ; save the counter
            push rdi                        ; save the arg
            push rsi                        ; save the arg
            push rax

            mov rsi, rdi                    ; offset of the string ([rdi] = current sym)
            mov rax, 0x01                   ; write (rbx, rcx, rdx)
            mov rdi, 1                      ; stdout
            syscall

            pop rax
            pop rsi                         ; restore the arg
            pop rdi                         ; restore the arg
            pop rcx                         ; restore the counter
            ret

;================================
;PrintSym
;
;Expected: string offset in rdi
;Destroys: -
;Returns:  -
;================================

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
;            ret

OutpTheRest:
            cmp r13, 0
            je SkipOutTheRest

            push rcx                        ; save the counter
            push rdi                        ; save the arg
            push rsi                        ; save the arg
            push rdx                        ; save the arg
            push rax

            mov rsi, OutputBuff             ; offset of the string ([rdi] = current sym)
            mov rax, 0x01                   ; write (rbx, rcx, rdx)
            mov rdi, 1                      ; stdout
            mov rdx, r13                    ; size
            syscall

            pop rax
            pop rdx                         ; restore the arg
            pop rsi                         ; restore the arg
            pop rdi                         ; restore the arg
            pop rcx                         ; restore the counter

        SkipOutTheRest:
            ret

StoreSym:
            cmp r13, OutBuffSize
            je PrintBuff
            mov byte [OutputBuff + r13], rdi
            inc r13
            jmp SkipOutBuff

        PrintBuff:
            xor r13, r13

            push rcx                        ; save the counter
            push rdi                        ; save the arg
            push rsi                        ; save the arg
            push rdx                        ; save the arg
            push rax

            mov rsi, OutputBuff             ; offset of the string ([rdi] = current sym)
            mov rax, 0x01                   ; write (rbx, rcx, rdx)
            mov rdi, 1                      ; stdout
            mov rdx, OutBuffSize            ; size
            syscall

            pop rax
            pop rdx                         ; restore the arg
            pop rsi                         ; restore the arg
            pop rdi                         ; restore the arg
            pop rcx                         ; restore the counter

        SkipOutBuff:
            ret

        
section     .data

String:     db "Hello world %s abc", 0h 
Length      equ $ - String
SymBuff     db 0                            ; reserve 1 byte
OutBuffSize equ 10
OutputBuff: db OutBuffSize dup(0)
  
TestString: db "TestString123", 0h

ArgSwitch:
    dq case2
    dq case3
    dq case4
    dq case5
    dq case6
    dq caseMore

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