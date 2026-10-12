default rel

global WindowOpenDisplay
global WindowSetupWindow
global WindowShowWindow
global WindowTitleWindow

; X11 functions
extern XOpenDisplay
extern XDefaultScreen
extern XWhitePixel
extern XDefaultRootWindow
extern XCreateSimpleWindow
extern XSelectInput
extern XMapWindow
extern XNextEvent
extern XStoreName
extern XCreateGC
extern XSetForeground
extern XFillRectangle
extern XDefaultVisual
extern XDefaultColormap
extern XInternAtom
extern XSetWMProtocols
extern XCloseDisplay
extern XLookupString

; Xft functions
extern XftFontOpenName
extern XftDrawCreate
extern XftColorAllocValue
extern XftTextExtentsUtf8
extern XftDrawStringUtf8

; input masks
KeyPressMask equ 1 << 0
ButtonPressMask equ 1 << 2
ButtonReleaseMask equ 1 << 3
ExposureMask equ 1 << 15
PointerMotionMask equ 1 << 6
LeaveWindowMask equ 1 << 5
EventMask equ KeyPressMask | ButtonPressMask | ExposureMask | LeaveWindowMask | PointerMotionMask | ButtonReleaseMask

; Opens an X display
; @return rax *dpy (0 if failed)
WindowOpenDisplay:
    xor edi, edi
    call XOpenDisplay
    ret

; Sets up a new X window
; @param rdi Display* dpy
; @param esi width
; @param edx height
; @param ecx Background color
; @return rax Window ID (0 if failed)
WindowSetupWindow:
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13d, ecx
    mov r14d, esi
    mov r15d, edx

    mov rdi, r12
    call XDefaultRootWindow

    mov rsi, rax
    mov rdi, r12
    xor edx, edx
    xor ecx, ecx
    mov r8d, r14d
    mov r9d, r15d

    sub rsp, 32
    mov qword [rsp], 2
    mov qword [rsp+8], 0x000000
    mov qword [rsp+16], r13
    call XCreateSimpleWindow
    add rsp, 32

    .exit:
        add rsp, 8
        pop r15
        pop r14
        pop r13
        pop r12
        ret

; Shows an X window
; @param rdi Display* dpy
; @param rsi Window ID
WindowShowWindow:
    jmp XMapWindow

; Titles an X window
; @param rdi Display* dpy
; @param rsi Window ID
; @param rdx *Buf window title string
WindowTitleWindow:
    jmp XStoreName