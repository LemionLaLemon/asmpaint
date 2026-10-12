default rel

global _start

extern WindowOpenDisplay
extern WindowSetupWindow
extern WindowShowWindow
extern WindowTitleWindow

extern XNextEvent

section .data
    windowtitle db "Paint",0

    %define background_color 0xD9E4F1

section .bss
    screen_num resb 4
    width resb 4
    height resb 4

    border resb 8
    win resb 8
    dpy resb 8
    wm_delete_atom resq 1

    ev resb 192

    ec resb 192 ; XEvent

    gc resb 8 ; Graphics context

    font_struct resq 1
    
    xft_font resq 1
    xft_draq resq 1
    xft_color resb 16

section .text
_start:
    ; X setup
    call WindowOpenDisplay
    test rax, rax
    jz exit
    mov [dpy], rax

    mov rdi, [dpy]
    mov esi, 800
    mov edx, 800
    mov ecx, background_color
    call WindowSetupWindow
    test rax, rax
    jz exit

    mov [win], rax

    mov rdi, [dpy]
    mov rsi, [win]
    call WindowShowWindow

    mov rdi, [dpy]
    mov rsi, [win]
    mov rdx, windowtitle
    call WindowTitleWindow

    mainloop:
        mov rdi, [dpy]
        lea rsi, [ev]
        call XNextEvent

    jmp mainloop

    exit:
        mov eax, 60
        xor rdi, rdi
        syscall   

