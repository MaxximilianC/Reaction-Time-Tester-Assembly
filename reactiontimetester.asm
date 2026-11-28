;
; reactiontimetester.asm
;
; Created: 11/25/2026 4:35:41 PM
; Authors : Brendan Flavin, Justin Moon, Woody Sylvain
;
;---------------------------------------
; State definitions

.equ RED_STATE = 0
.equ YELLOW_STATE = 1
.equ GREEN_STATE = 2
.equ FINISHED_STATE = 3
.equ FAULT_STATE = 4
;---------------------------------------
; LCD pin definitions

.equ LCD_RS = 4
.equ LCD_E  = 5

;---------------------------------------
; Interrupt vector table

.org 0x0000
    jmp     main

.org INT0addr
    jmp     button_isr

.org OC1Aaddr
    jmp     timer1_isr

.org INT_VECTORS_SIZE

;---------------------------------------
; Main initialization

main:
    ; Initialize stack pointer
    ldi     r16, high(RAMEND)
    out     SPH, r16
    ldi     r16, low(RAMEND)
    out     SPL, r16

    ;-----------------------------------
    ; Configure LCD

    ; Configure PC0-PC5 as outputs
    ldi     r16, 0b00111111
    out     DDRC, r16

    ; Clear LCD output pins
    clr     r16
    out     PORTC, r16

    ; Initialize LCD
    rcall   lcd_init

    ;-----------------------------------
    ; Configure LEDs

    ; Configure LEDs as outputs
    sbi     DDRD, DDD6
    sbi     DDRD, DDD7
    sbi     DDRB, DDB0

    ; Set initial LED states
    sbi     PORTD, PD6
    cbi     PORTD, PD7
    cbi     PORTB, PB0

    ;-----------------------------------
    ; Configure pushbutton

    cbi     DDRD, DDD2
    sbi     PORTD, PD2

    ; Initialize current state
    ldi     r18, RED_STATE

    ; Initialize previous LCD state
    ldi     r17, 0xFF

    ; Initialize millisecond counter
    clr     r24
    clr     r25

    ; Initialized Timer0 as a free running hardware counter n=64
    ldi r16 (1<<CS01)|(1<<CS00)
    out TCCR0B,r16
    ;-----------------------------------
    ; Configure INT0

    ; Falling edge interrupt
    ldi     r16, (1<<ISC01)
    sts     EICRA, r16

    ; Clear pending INT0 flag
    ldi     r16, (1<<INTF0)
    out     EIFR, r16

    ; Enable INT0
    sbi     EIMSK, INT0

    ;-----------------------------------
    ; Configure Timer1

    ; Clear Timer1 control registers
    ldi     r16, 0
    sts     TCCR1A, r16
    sts     TCCR1B, r16

    ; Initialize Timer1 counter
    sts     TCNT1H, r16
    sts     TCNT1L, r16

    ; Set compare value to 249
    ldi     r16, high(249)
    sts     OCR1AH, r16

    ldi     r16, low(249)
    sts     OCR1AL, r16

    ; Clear pending compare match flag
    ldi     r16, (1<<OCF1A)
    out     TIFR1, r16

    ; Enable compare match A interrupt
    ldi     r16, (1<<OCIE1A)
    sts     TIMSK1, r16

    ; CTC mode, prescaler of 64
    ldi     r16, (1<<WGM12)|(1<<CS11)|(1<<CS10)
    sts     TCCR1B, r16

    ; Enable global interrupts
    sei

;---------------------------------------
; Main loop

main_loop:
    ; Check whether state has changed
    cp      r17, r18
    breq    main_loop

    ; Save the new state
    mov     r17, r18

    ; Clear LCD
    ldi     r16, 0x01
    rcall   lcd_command

    ; Determine which message to display
    cpi     r17, RED_STATE
    breq    display_red

    cpi     r17, YELLOW_STATE
    breq    display_yellow

    cpi     r17, GREEN_STATE
    breq    display_green

    cpi     r17, FINISHED_STATE
    breq    display_finished

    rjmp    main_loop

;---------------------------------------
; Red state message

display_red:
    ; Display first row
    ldi     ZH, high(red_message * 2)
    ldi     ZL, low(red_message * 2)
    rcall   lcd_string

    ; Move cursor to second row
    ldi     r16, 0xC0
    rcall   lcd_command

    ; Display instructions
    ldi     ZH, high(wait_message * 2)
    ldi     ZL, low(wait_message * 2)
    rcall   lcd_string

    rjmp    main_loop

;---------------------------------------
; Yellow state message

display_yellow:
    ; Display first row
    ldi     ZH, high(yellow_message * 2)
    ldi     ZL, low(yellow_message * 2)
    rcall   lcd_string

    ; Move cursor to second row
    ldi     r16, 0xC0
    rcall   lcd_command

    ; Display instructions
    ldi     ZH, high(wait_message * 2)
    ldi     ZL, low(wait_message * 2)
    rcall   lcd_string

    rjmp    main_loop

;---------------------------------------
; Green state message

display_green:
    ; Display first row
    ldi     ZH, high(green_message * 2)
    ldi     ZL, low(green_message * 2)
    rcall   lcd_string

    ; Move cursor to second row
    ldi     r16, 0xC0
    rcall   lcd_command

    ; Display instructions
    ldi     ZH, high(press_message * 2)
    ldi     ZL, low(press_message * 2)
    rcall   lcd_string

    rjmp    main_loop

;---------------------------------------
; Finished state message

display_finished:
    ; Display reaction time heading
    ldi     ZH, high(finished_message * 2)
    ldi     ZL, low(finished_message * 2)
    rcall   lcd_string

    ; Move cursor to second row
    ldi     r16, 0xC0
    rcall   lcd_command

    ; Display measured reaction time
    rcall   display_time

    rjmp    main_loop

;---------------------------------------
; Timer1 interrupt service routine

timer1_isr:
    ; Save temporary register and SREG
    push    r16
    in      r16, SREG
    push    r16

    ; Check current state
    cpi     r18, RED_STATE
    breq    red_countdown

    cpi     r18, YELLOW_STATE
    breq    yellow_countdown

    cpi     r18, GREEN_STATE
    breq    green_countdown

    rjmp    timer_done

;---------------------------------------
; Red countdown

red_countdown:
    ; Increment millisecond counter
    adiw    r24, 1

    ; Check if 2000 ms have passed
    cpi     r24, low(2000)
    ldi     r16, high(2000)
    cpc     r25, r16
    brne    timer_done

    ; Reset millisecond counter
    clr     r24
    clr     r25

    ; Switch from red to yellow
    cbi     PORTD, PD6
    sbi     PORTD, PD7

    ; Change state to yellow
    ldi     r18, YELLOW_STATE

    rjmp    timer_done

;---------------------------------------
; Yellow countdown

yellow_countdown:
    ; Increment millisecond counter
    adiw    r24, 1

    ; Check if 1000 ms have passed
    cpi     r24, low(1000)
    ldi     r16, high(1000)
    cpc     r25, r16
    brne    timer_done

    ; Reset counter for reaction time
    clr     r24
    clr     r25

    ; Switch from yellow to green
    cbi     PORTD, PD7
    sbi     PORTB, PB0

    ; Change state to green
    ldi     r18, GREEN_STATE

    rjmp    timer_done

;---------------------------------------
; Reaction time measurement

green_countdown:
    ; Check for maximum counter value
    cpi     r24, 0xFF
    ldi     r16, 0xFF
    cpc     r25, r16
    breq    timer_done

    ; Increment reaction time by 1 ms
    adiw    r24, 1

    rjmp    timer_done

;---------------------------------------
; Restore registers and return

timer_done:
    pop     r16
    out     SREG, r16
    pop     r16

    reti

;---------------------------------------
; Button interrupt service routine

button_isr:
    ; Save temporary register and SREG
    push    r16
    in      r16, SREG
    push    r16

    ; Only accept button press during green
    cpi     r18, GREEN_STATE
    brne    button_done

    ; Stop Timer1
    ldi     r16, 0
    sts     TCCR1B, r16

    ; Disable Timer1 interrupts
    sts     TIMSK1, r16

    ; Turn off green LED
    cbi     PORTB, PB0

    ; Mark attempt as finished
    ldi     r18, FINISHED_STATE

    ; Reaction time is preserved in r25:r24

button_done:
    ; Restore registers and SREG
    pop     r16
    out     SREG, r16
    pop     r16

    reti

;---------------------------------------
; Display 16-bit reaction time
; Input: r25:r24

display_time:
    ; Preserve original reaction time
    push    r24
    push    r25

    ; No nonzero digits printed yet
    clr     r23

    ; Ten-thousands digit
    ldi     r26, low(10000)
    ldi     r27, high(10000)
    rcall   extract_digit

    ; Thousands digit
    ldi     r26, low(1000)
    ldi     r27, high(1000)
    rcall   extract_digit

    ; Hundreds digit
    ldi     r26, low(100)
    ldi     r27, high(100)
    rcall   extract_digit

    ; Tens digit
    ldi     r26, low(10)
    ldi     r27, high(10)
    rcall   extract_digit

    ; Ones digit
    mov     r16, r24
    subi    r16, -0x30
    rcall   lcd_data

    ; Display units
    ldi     r16, ' '
    rcall   lcd_data

    ldi     r16, 'm'
    rcall   lcd_data

    ldi     r16, 's'
    rcall   lcd_data

    ; Restore original reaction time
    pop     r25
    pop     r24

    ret

;---------------------------------------
; Extract one decimal digit

extract_digit:
    clr     r19

subtract_loop:
    cp      r24, r26
    cpc     r25, r27

    brlo    digit_finished

    sub     r24, r26
    sbc     r25, r27

    inc     r19
    rjmp    subtract_loop

digit_finished:
    ; Suppress leading zeros
    tst     r19
    brne    print_digit

    tst     r23
    breq    skip_digit

print_digit:
    ldi     r23, 1

    ; Convert digit to ASCII
    mov     r16, r19
    subi    r16, -0x30
    rcall   lcd_data

skip_digit:
    ret

;---------------------------------------
; LCD initialization

lcd_init:
    ; Wait for LCD power-up
    ldi     r20, 50
    rcall   delay_ms

    ; Select command mode
    cbi     PORTC, LCD_RS

    ; First initialization nibble
    ldi     r16, 0x03
    rcall   lcd_nibble

    ldi     r20, 5
    rcall   delay_ms

    ; Second initialization nibble
    ldi     r16, 0x03
    rcall   lcd_nibble

    ldi     r20, 1
    rcall   delay_ms

    ; Third initialization nibble
    ldi     r16, 0x03
    rcall   lcd_nibble

    ldi     r20, 1
    rcall   delay_ms

    ; Switch to 4-bit mode
    ldi     r16, 0x02
    rcall   lcd_nibble

    ldi     r20, 1
    rcall   delay_ms

    ; 4-bit mode, two lines, 5x8 font
    ldi     r16, 0x28
    rcall   lcd_command

    ; Display off
    ldi     r16, 0x08
    rcall   lcd_command

    ; Clear display
    ldi     r16, 0x01
    rcall   lcd_command

    ; Automatically increment cursor
    ldi     r16, 0x06
    rcall   lcd_command

    ; Display on, cursor off
    ldi     r16, 0x0C
    rcall   lcd_command

    ret

;---------------------------------------
; Send LCD command

lcd_command:
    ; RS = 0 for command
    cbi     PORTC, LCD_RS
    rcall   lcd_byte

    ret

;---------------------------------------
; Send LCD character

lcd_data:
    ; RS = 1 for character
    sbi     PORTC, LCD_RS
    rcall   lcd_byte

    ret

;---------------------------------------
; Send complete 8-bit value

lcd_byte:
    push    r16

    ; Send high nibble
    swap    r16
    andi    r16, 0x0F
    rcall   lcd_nibble

    ; Send low nibble
    pop     r16
    andi    r16, 0x0F
    rcall   lcd_nibble

    ; Wait for LCD to process data
    ldi     r20, 2
    rcall   delay_ms

    ret

;---------------------------------------
; Send one 4-bit nibble

lcd_nibble:
    ; Preserve previous LCD state
    push    r17

    ; Preserve upper PORTC bits
    in      r17, PORTC
    andi    r17, 0xF0

    ; Place data on PC0-PC3
    andi    r16, 0x0F
    or      r17, r16
    out     PORTC, r17

    ; Pulse enable pin
    nop
    sbi     PORTC, LCD_E

    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    cbi     PORTC, LCD_E
    nop

    ; Restore previous LCD state
    pop     r17

    ret

;---------------------------------------
; Approximate millisecond delay
; Input: r20

delay_ms:
    push    r21
    push    r22

delay_outer:
    ldi     r21, 21

delay_middle:
    ldi     r22, 250

delay_inner:
    dec     r22
    brne    delay_inner

    dec     r21
    brne    delay_middle

    dec     r20
    brne    delay_outer

    pop     r22
    pop     r21

    ret

;---------------------------------------
; Display string from program memory
; Input: Z pointer

lcd_string:
    ; Load next character
    lpm     r16, Z+

    ; Check for end of string
    tst     r16
    breq    string_done

    ; Display character
    rcall   lcd_data

    ; Continue to next character
    rjmp    lcd_string

string_done:
    ret

;---------------------------------------
; LCD messages stored in program memory

red_message:
    .db "Get Ready...", 0, 0

yellow_message:
    .db "Get Set...", 0, 0

green_message:
    .db "GO!", 0

finished_message:
    .db "Reaction Time:", 0, 0

wait_message:
    .db "Wait for Green", 0, 0

press_message:
    .db "Press Button!", 0
