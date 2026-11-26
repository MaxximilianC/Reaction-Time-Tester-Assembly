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

    ; Configure LEDs as outputs
    sbi     DDRD, DDD6
    sbi     DDRD, DDD7
    sbi     DDRB, DDB0

    ; Set initial LED states
    sbi     PORTD, PD6
    cbi     PORTD, PD7
    cbi     PORTB, PB0

    ; Configure pushbutton
    cbi     DDRD, DDD2
    sbi     PORTD, PD2

    ; Initialize state
    ldi     r18, RED_STATE

    ; Initialize millisecond counter
    clr     r24
    clr     r25

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

    ; NEW: Check green state
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