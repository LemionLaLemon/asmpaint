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

    struc UndoRecord
        .x resd 1
        .y resd 1
        .width resd 1
        .height resd 1
        .bitmap resq 1 ; Bitmap pointer
    endstruc

    struc XConfigureEvent
        .type resd 1
        resb 44 ; padding
        .x resd 1
        .y resd 1
        .width resd 1
        .height resd 1
    endstruc

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
%define background_color 0xFFFFFF
%define primary_color 0xD9E4F1
%define secondary_color 0xECF4FA
%define tertiary_color 0xE1E6EA
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
        %define Colorpicker_Height 44
        %define Border_Width 1
        sub rsp, 8

        ; TODO: draw canvas
        ; TODO: draw scrollbars

        ; Left toolbar border
        SetForeground border_color
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        sub r10d, Border_Width
        DrawFilledRectangle 0, r10d, [width], Border_Width 

        ; Left toolbar
        SetForeground primary_color
        DrawFilledRectangle 0, 0, Toolbar_Width, [height] 

        ; Bottom toolbar
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        DrawFilledRectangle Toolbar_Width, r10d, [width], Colorpicker_Height 

         ; Right toolbar border
        SetForeground border_color
        DrawFilledRectangle Toolbar_Width, 0, Border_Width, [height]

        SetForeground 0xFF0000
        ; DrawFilledRectangle (Toolbar_Width - Button_Size)/2, (Toolbar_Width - Button_Size)/2 + 0, Button_Size, Button_Size ; TODO: brush tool
        add rsp, 8
        ret

    exit:
        mov eax, 60
        xor rdi, rdi
        syscall