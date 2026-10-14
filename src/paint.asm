default rel

global _start

extern WindowOpenDisplay
extern WindowSetupWindow
extern WindowMaximizeWindow
extern WindowShowWindow
extern WindowTitleWindow
extern WindowCreateGraphicsContext
extern WindowSetForegroundColor
extern WindowSelectEvents
extern WindowDrawRectangle

extern XNextEvent

%define KeyPressMask (1 << 0)
%define ButtonPressMask (1 << 2)
%define ButtonReleaseMask (1 << 3)
%define ExposureMask (1 << 15)
%define PointerMotionMask (1 << 6)
%define LeaveWindowMask (1 << 5)
%define StructureNotifyMask (1 << 17)
EventMask equ KeyPressMask | ButtonPressMask | ButtonReleaseMask | ExposureMask | PointerMotionMask | LeaveWindowMask | StructureNotifyMask

section .data
    windowtitle db "Paint",0

    ; struc UndoRecord ; Unused for now, planned for future update
    ;     .x resd 1
    ;     .y resd 1
    ;     .width resd 1
    ;     .height resd 1
    ;     .bitmap resq 1 ; Bitmap pointer
    ; endstruc

    struc XConfigureEvent
        .type resd 1
        resb 44 ; padding
        .x resd 1
        .y resd 1
        .width resd 1
        .height resd 1
    endstruc

    struc ColorSelection
        .color resd 1
    endstruc

    Colors:
        ; row 1
        dd 0x000000
        dd 0x808080
        dd 0x800000
        dd 0x808000
        dd 0x008000
        dd 0x008080
        dd 0x000080
        dd 0x800080
        dd 0x808040
        dd 0x004040
        dd 0x0080FF
        dd 0x004080
        dd 0x4000FF
        dd 0x804000
        ; row 2
        dd 0xFFFFFF
        dd 0xC0C0C0
        dd 0xFF0000
        dd 0xFFFF00
        dd 0x00FF00
        dd 0x00FFFF
        dd 0x0000FF
        dd 0xFF00FF
        dd 0xFFFF80
        dd 0x00FF80
        dd 0x80FFFF
        dd 0x8080FF
        dd 0xFF0080
        dd 0xFF8040

    ColorsCount equ ($ - Colors) / 4 ; bytes

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
; Styles
%define canvas_color 0xFFFFFF
%define primary_color 0xD9E4F1
%define secondary_color 0xECF4FA
%define tertiary_color 0x648ABB
%define border_color 0x8E9CAD
; Macros
%macro SetForeground 1
    mov rdi, [dpy]
    mov rsi, [gc]
    mov edx, %1
    call WindowSetForegroundColor
%endmacro
%macro DrawFilledRectangle 4
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 16
    mov rdi, [dpy]
    mov rsi, [win]
    mov rdx, [gc]
    mov ecx, %1
    mov r8d, %2
    mov r9d, %3
    mov eax, %4
    mov [rsp], eax
    call WindowDrawRectangle
    add rsp, 16
    mov rsp, rbp
    pop rbp
%endmacro
_start:
    ; X setup
    call WindowOpenDisplay
    test rax, rax
    jz exit
    mov [dpy], rax

    mov rdi, [dpy]
    mov esi, 800
    mov edx, 800
    mov ecx, tertiary_color
    call WindowSetupWindow

    test rax, rax
    jz exit

    mov [win], rax

    mov rdi, [dpy]
    mov rsi, [win]
    call WindowCreateGraphicsContext

    mov [gc], rax

    mov rdi, [dpy]
    mov rsi, [win]
    call WindowMaximizeWindow

    mov rdi, [dpy]
    mov rsi, [win]
    call WindowShowWindow

    mov rdi, [dpy]
    mov rsi, [win]
    mov rdx, windowtitle
    call WindowTitleWindow

    mov rdi, [dpy]
    mov rsi, [win]
    mov edx, EventMask
    call WindowSelectEvents

    call DrawGUI

    mainloop:
        mov rdi, [dpy]
        lea rsi, [ev]
        call XNextEvent

        cmp dword [ev], 22
        je .configure

        cmp dword [ev], 12
        je .redraw

        .redraw:
            call DrawGUI
    jmp mainloop

    .configure:
        mov eax, [ev + XConfigureEvent.width]
        mov [width], eax
        
        mov eax, [ev + XConfigureEvent.height]
        mov [height], eax

        call DrawGUI
    
    jmp mainloop

    DrawGUI:
        %define Toolbar_Width 80
        %define Colorpicker_Height 68
        %define Statusbar_Height 20
        %define Border_Width 1
        sub rsp, 8

        ; TODO: draw canvas
        ; TODO: draw scrollbars

        ; Right toolbar border
        SetForeground border_color
        DrawFilledRectangle Toolbar_Width, 0, Border_Width, [height]

        ; Left toolbar
        SetForeground primary_color
        DrawFilledRectangle 0, 0, Toolbar_Width, [height] 

        ; Bottom toolbar
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        DrawFilledRectangle Toolbar_Width, r10d, [width], Colorpicker_Height 

        ; Top bar dunno
        DrawFilledRectangle 0, 0, [width], Statusbar_Height 

        ; Left toolbar border
        SetForeground border_color
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        sub r10d, Border_Width
        DrawFilledRectangle 0, r10d, [width], Border_Width 

        ; Left toolbar border
        mov r10d, [height]
        sub r10d, Statusbar_Height
        sub r10d, Border_Width
        DrawFilledRectangle 0, r10d, [width], Border_Width
        DrawFilledRectangle 0, r10d, [width], Border_Width

        DrawFilledRectangle 0, Statusbar_Height, [width], Border_Width

        SetForeground 0xFF0000
        ; DrawFilledRectangle (Toolbar_Width - Button_Size)/2, (Toolbar_Width - Button_Size)/2 + 0, Button_Size, Button_Size ; TODO: brush tool
        add rsp, 8

    DrawColorSelection: 
        push r12
        push r13

        %define ColorCols 14
        %define Margin 8 
        %define PaletteOffset 31
        %define ColorPickWidth 16 ; do not change this it wont work

        xor r11d, r11d ; counter

        .loop:
            cmp r11d, ColorsCount
            jae .exit

            SetForeground 0xFFFFFF
            ; White background 16x16
            mov eax, r11d
            xor edx, edx

            cmp eax, ColorCols
            jb .first_row

            sub eax, ColorCols
            mov edx, ColorPickWidth

            .first_row:
                imul eax, ColorPickWidth
                lea r12d, [eax + PaletteOffset]

                mov r13d, [height]
                sub r13d, Colorpicker_Height
                add r13d, Margin
                add r13d, edx
                DrawFilledRectangle r12d, r13d, 16, 16

            ; Gray background 15x15
            SetForeground 0xA6A6A6
            DrawFilledRectangle r12d, r13d, 15, 15

            ; Light gray background 14x14
            SetForeground 0xF5F5F5
            inc r12d
            inc r13d
            DrawFilledRectangle r12d, r13d, 14, 14

            ; Black inside border 13x13
            SetForeground 0x000000
            DrawFilledRectangle r12d, r13d, 13, 13

            ; Actual color 12x12
            mov eax, r11d
            mul eax, 4
            SetForeground [Colors + eax]
            inc r12d
            inc r13d
            DrawFilledRectangle r12d, r13d, 12, 12

            inc r11d
        jmp .loop

        .exit:
            pop r13
            pop r12
            ret

    exit:
        mov eax, 60
        xor rdi, rdi
        syscall