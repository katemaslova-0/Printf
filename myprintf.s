section     .code

global _start

_start:     
            push 13d                        ; arguments for MyPrintf in reverse order
            push String                     ;

            call MyPrintf

            mov eax, 1                      ; syscall number for exit
            xor ebx, ebx                    ; exit code = 0
            int 0x80                        ; call kernel
    
MyPrintf: 
            pop esi                         ; save return address
            pop eax                         ; eax = string offset
            mov ecx, Length                 ; ecx = string length --- ??? 

        FindSpcf:
            cmp byte [eax], '%'              
            jne NoSpcf
            call PrintSpcf
            jmp NextSym

        NoSpcf:
            call PrintSym

        NextSym:
            inc eax                         ; go to the next sym in line
            
        loop FindSpcf

            push esi                        ; restore return address
            ret

PrintSpcf:  
            pop edi                         ; save return address

            inc eax                         ; move to next sym
            mov ebx, [eax]                  ; put symbol to bx
            and ebx, 0FFh
            sub ebx, 'b'

            jmp [SpecifierSwitch + ebx * 4]

        caseB:
            call PrintBinary
            jmp caseNoSpcf

        caseC:
            call PrintChar
            jmp caseNoSpcf

        caseD:
            call PrintDecimal
            jmp caseNoSpcf

        caseF:
            ;call PrintFloat
            jmp caseNoSpcf

        caseO:
            call PrintOctal
            jmp caseNoSpcf
        
        caseS:
            call PrintString
            jmp caseNoSpcf

        caseX:
            call PrintHex
            jmp caseNoSpcf

        caseNoSpcf:
            push edi
            ret 


PrintDecimal:
            pop ebx                         ; save return address

            pop edx                         ; get decimal number
            push eax                        ; save string position
            push ecx                        ; save the counter
            push esi

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

        RegToDec:
            mov ecx, 10d                    ; as a counter
            mov ebp, 10d                    ; as a const value for division
            mov esi, 1000000000d                 

        PrintDecNum:
            mov eax, edx
            xor edx, edx
            div esi

            add eax, '0'
            mov [Buffer], eax
            mov eax, Buffer
            call PrintSym

            push edx
            mov eax, esi
            xor edx, edx
            div ebp
            mov esi, eax
            pop edx

        loop PrintDecNum

            pop esi
            pop ecx                         ; restore the counter
            dec ecx                         ; for loop in MyPrintf
            pop eax                         ; restore string position
            push ebx                        ; restore return address
            ret

PrintOctal:
            pop ebx                         ; save return address

            pop edx                         ; get octal number
            push eax                        ; save string position
            push ecx                        ; save the counter
            push esi                        ; save reg value
            xor esi, esi                    ; to use as a flag

            push edx                        ; 
            and edx, 0C0000000h
            shr edx, 30d                    ; leave only the first two bits              
            cmp edx, 0
            je NullFirstBits
            mov esi, 1
            add edx, '0'
            
            mov [Buffer], edx
            mov eax, Buffer
            call PrintSym

        NullFirstBits:
            pop edx
            shl edx, 2                     

            mov ecx, 10d                    ; num of 3-bit(= one octal num) combinations in a reg(without the first bit)

        PrintThreeBits:
            push edx
            and edx, 0E0000000h
            shr edx, 29d                    ; leave only 3 bytes
            cmp edx, 0
            je NullBit
            mov esi, 1
            jmp PrintOctBit

        NullBit:
            cmp esi, 0
            je NoOctPrint
            
        PrintOctBit:
            add edx, '0'
            mov [Buffer], edx
            mov eax, Buffer
            call PrintSym
        
        NoOctPrint:
            pop edx
            shl edx, 3d
        loop PrintThreeBits

            pop esi                         ; restore reg value
            pop ecx                         ; restore the counter
            dec ecx                         ; for loop in MyPrintf
            pop eax                         ; restore string position
            push ebx                        ; restore return address
            ret

PrintString:
            pop ebx                         ; save return address

            xchg ebp, eax                   ; save eax value
            pop eax                         ; get argument string offset
            pop edx                         ; get argument string length
            push ecx                        ; save the counter

            call PrintSizedString

            xchg eax, ebp                   ; restore eax value
            pop ecx                         ; restore the counter
            dec ecx                         ; for loop in MyPrintf
            push ebx                        ; restore return address
            ret

PrintHex:  
            pop ebx                         ; save return address

            pop edx                         ; get the hex value
            push eax                        ; save string position
            push ecx                        ; save the counter

            mov ecx, 8d                     ; num of 4-bit(= one hex num) combinations in a reg

        PrintHalfOfAByte:
            push edx
            and edx, 0F0000000h
            shr edx, 8 * 3d + 4               ; leave only halh of one byte
            cmp edx, 9d
            jg IsLetter
            add edx, '0'
            jmp HexIsReady

        IsLetter:
            add edx, 'A' - 0Ah
        HexIsReady:
            mov [Buffer], edx
            mov eax, Buffer
            call PrintSym

            pop edx
            shl edx, 4d
        loop PrintHalfOfAByte

            pop ecx                         ; restore the counter
            dec ecx                         ; for loop in MyPrintf
            pop eax                         ; restore string position
            push ebx                        ; restore return address
            ret

PrintChar:
            pop ebx                         ; save return address

            pop edx                         ; get the char value
            push eax                        ; save string position

            mov [Buffer], edx
            mov eax, Buffer
            call PrintSym
            dec ecx                         ; for loop in MyPrintf                   

            pop eax                         ; restore string position
            push ebx                        ; restore the return address
            ret

PrintBinary:
            pop ebx                         ; save return address

            pop edx                         ; get the binary number
            push ecx                        ; save the counter
            push eax                        ; save string position
            push esi                        ; save the reg value
            xor esi, esi                    ; will be used as flag

            mov ecx, 32d                    ; num of bits in 4 bytes
            
        PrintOneBit:
            shl edx, 1
            jnc IsZero

            mov byte [Buffer], '1'
            mov esi, 1                      
            jmp BitIsSet           

        IsZero:
            cmp esi, 0                      ; if there wasn't '1' before, no '0' printing
            je SkipPrint
            mov byte [Buffer], '0'          ; put the ASCII to memory  

        BitIsSet:                       
            mov eax, Buffer
            push edx
            call PrintSym
            pop edx

        SkipPrint:
        loop PrintOneBit

            pop esi                         ; restore reg value
            pop eax                         ; restore string position
            pop ecx                         ; restore the counter
            dec ecx                         ; for loop in MyPrintf
            push ebx                        ; restore return address
            ret

PrintSizedString:

            push ecx                        ; save the counter
            push ebx                        ; the previous ret address is stored there

            mov ecx, eax                    ; [ecx] = sym
            mov eax, 4                      ; write (ebx, ecx, edx)
            mov ebx, 1                      ; stdout
            int 80h

            mov eax, ecx                   ; [eax] = sym
            pop ebx                        ; restore ebx
            pop ecx                        ; ecx = counter
            ret

PrintSym:
            push ecx                        ; save the counter
            push ebx                        ; the previous ret address is stored there

            mov ecx, eax                    ; [ecx] = sym
            mov eax, 4                      ; write (ebx, ecx, edx)
            mov ebx, 1                      ; stdout
            mov edx, 1                      ; only one symbol
            int 80h

            mov eax, ecx                   ; [eax] = sym
            pop ebx                        ; restore ebx
            pop ecx                        ; ecx = counter
            ret
        
section     .data

String:     db "Hello world %d abc" 
Length      equ $ - String
Buffer      db 0                          ; reserve 1 byte  
TestString: db "TestString123"

SpecifierSwitch:
    dd caseB
    dd caseC
    dd caseD
    dd caseNoSpcf
    dd caseF
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseO
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseS
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseNoSpcf
    dd caseX