default rel

global WindowOpenDisplay
global WindowSetupWindow
global WindowShowWindow
global WindowTitleWindow
global WindowCreateGraphicsContext
global WindowSetForegroundColor
global WindowMaximizeWindow
global WindowSelectEvents
global WindowDrawRectangle
global WindowCreateImage
global WindowPutImage

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
extern XChangeProperty
extern XCreateImage
extern XPutImage

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

section .rodata
    wm_state_name db "_NET_WM_STATE", 0
    max_horz_name db "_NET_WM_MAXIMIZED_HORZ", 0
    max_vert_name db "_NET_WM_MAXIMIZED_VERT", 0

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

; Creates a Graphics Context
; @param rdi Display* dpy
; @param rsi Window ID
; @return rax Graphics Context (0 if failed)
WindowCreateGraphicsContext:
    xor edx, edx
    xor ecx, ecx
    jmp XCreateGC

; Sets Graphics Context Foreground Color
; @param rdi Display* dpy
; @param rsi Graphics Context
; @param rdx foreground
WindowSetForegroundColor:
    jmp XSetForeground

; Maximizes an X window
; @param rdi Display* dpy
; @param rsi Window ID
WindowMaximizeWindow:
    push rbx
    push r12
    push r13 ; wm_state atom

    mov rbx, rdi ; Display*
    mov r12, rsi ; Window ID

    sub rsp, 32

    %macro XInterAtomMacro 3
        mov rdi, %1 ; Display*
        mov rsi, %2 ; Atom name
        xor edx, edx
        call XInternAtom
        mov %3, rax
    %endmacro

    XInterAtomMacro rbx, wm_state_name, r13
    XInterAtomMacro rbx, max_horz_name, [rsp + 16]
    XInterAtomMacro rbx, max_vert_name, [rsp + 24]

    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov ecx, 4
    mov r8d, 32
    xor r9d, r9d
    lea rax, [rsp+16]
    mov [rsp], rax
    mov qword [rsp + 8], 2
    call XChangeProperty

    add rsp, 32

    .exit:
        pop r13
        pop r12
        pop rbx
        ret

; Selects input masks
; @param rdi Display* dpy
; @param rsi Window ID
; @param edx EventMask
WindowSelectEvents:
    jmp XSelectInput

; Draws a rectangle to a window
; @param rdi Display* dpy
; @param rsi Window ID
; @param rdx gc
; @param rcx X Position
; @param r8 Y Position
; @param r9 Width
; @param stack Height
WindowDrawRectangle:
    jmp XFillRectangle

; Creates an X image
; @param rdi Display* dpy
; @param rsi Visual*
; @param rdx uint depth
; @param rcx int format
; @param r8 int offset
; @param r9 char* data
; @param stack uint width
; @param stack uint height
; @param stack int bitmap pad
; @param stack int bytes_per_line
WindowCreateImage: ; vade retro satana! (function so cursed with stack args an exorcism had to be carried out)
    jmp XCreateImage

; Draws an XImage 
; @param rdi Display* dpy
; @param rsi Drawable
; @param rdx gc
; @param rcx Ximage*
; @param r8d int src_x
; @param r9d int src_y
; @param stack int dest_x
; @param stack int dest_y
; @param stack uint width
; @param stack uint height
WindowPutImage:
    jmp XPutImage