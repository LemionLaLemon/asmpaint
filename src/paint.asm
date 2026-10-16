default rel

global _start

extern malloc ; C probably has way better malloc than i'll ever be able to write :<

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
extern XDefaultVisual
extern XDefaultDepth
extern XPending
extern XDefaultScreen
extern WindowCreateImage
extern WindowPutImage

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

    struc Tool
        .shapeSelect equ 0
        .rectSelect equ 1
        .eraser equ 2
        .bucket equ 3
        .dropper equ 4
        .magnify equ 5
        .pencil equ 6
        .brush equ 7
        .spray equ 8
        .text equ 9
        .line equ 10
        .curve equ 11
        .rectangle equ 12
        .polygon equ 13
        .circle equ 14
        .roundrect equ 15
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

    CanvasWidth resd 1
    CanvasHeight resd 1
    Canvas resq 1 ; *Canvas
    CanvasImage resq 1

    WorkingBuffer resq 1

    SelectedColor resd 1
    SecondarySelectedColor resd 1
    SelectedTool resb 1

    MouseDown: resb 1

    ; fill in the gaps
    LastX resd 1
    LastY resd 1
    Dirty resb 1

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

    mov rdi, rax
    call XDefaultScreen
    mov [screen_num], eax

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
    
    mov dword [CanvasWidth], 640
    mov dword [CanvasHeight], 480

    call NewCanvas
    call CreateCanvasImage
    call DrawCanvas

    mov dword [SelectedColor], 0x000000
    mov byte [SelectedTool], Tool.pencil
    mov byte [MouseDown], 0

    mainloop:
        cmp byte [Dirty], 0
        je .wait
        mov rdi, [dpy]
        call XPending
        
        test eax, eax
        jnz .wait

        call DrawCanvas
        mov byte [Dirty], 0

        .wait:
            mov rdi, [dpy]
            lea rsi, [ev]
            call XNextEvent

            cmp dword [ev], 22
            je .configure

            cmp dword [ev], 12
            je .redraw

            ; Button Press Event
            cmp dword [ev], 4
            je onMouseDown

            ; Button Release Event
            cmp dword [ev], 5
            je onMouseUp

            ; "motionnotify" probably mouse move i give up
            cmp dword [ev], 6
            je onMouseMove

    jmp mainloop
    
    .redraw:
        call DrawGUI
        call DrawCanvas
        jmp mainloop

    .configure:
        mov eax, [ev + XConfigureEvent.width]
        mov [width], eax
        
        mov eax, [ev + XConfigureEvent.height]
        mov [height], eax

        call DrawGUI
        call DrawCanvas
    jmp mainloop

    %define Toolbar_Width 80
    %define Colorpicker_Height 68
    %define Statusbar_Height 20
    %define Border_Width 1
    %define ColorCols 14
    %define Margin 8 
    %define PaletteOffset 31
    %define ColorPickWidth 16 ; do not change this it wont work
    %define CanvasMargin 3

    struc Mouse
        .type resd 1
        .pad0 resb 60
        .x resd 1
        .y resd 1
        .xroot resd 1
        .yroot resd 1
        .state resd 1
        .button resd 1
    endstruc

    onMouseMove:
        cmp byte [MouseDown], 0
        je mainloop
        test dword [ev + Mouse.state], 0x100
        jz mainloop

        mov edx, [ev + Mouse.x]
        sub edx, Toolbar_Width + Border_Width + CanvasMargin
        mov ecx, [ev + Mouse.y]
        sub ecx, Statusbar_Height + Border_Width + CanvasMargin
        mov edi, [LastX]
        mov esi, [LastY]
        mov [LastX], edx
        mov [LastY], ecx
        call DrawLine

        mov byte [Dirty], 1
        jmp mainloop

    onMouseUp:
        cmp byte [MouseDown], 0
        je mainloop
        
        mov byte [MouseDown], 0

        mov rsi, [WorkingBuffer]
        mov rdi, [Canvas]
        mov ecx, [CanvasWidth]
        imul ecx, [CanvasHeight]
        cld
        rep movsd
        jmp mainloop

    onMouseDown:
            cmp dword [ev + Mouse.button], 1
            jne mainloop

            mov eax, [ev + Mouse.x]
            sub eax, PaletteOffset
            jl .not_palette
            cmp eax, ColorCols * ColorPickWidth
            jge .not_palette

            mov ecx, [ev + Mouse.y]
            mov edx, [height]
            sub edx, Colorpicker_Height
            add edx, Margin
            sub ecx, edx
            jl .not_palette
            cmp ecx, 2 * ColorPickWidth
            jge .not_palette

            shr eax, 4
            shr ecx, 4
            imul ecx, ColorCols
            add eax, ecx
            lea rdx, [Colors]
            mov eax, [rdx + rax * 4]
            mov [SelectedColor], eax

            call RedrawSelectedColor
            
            jmp mainloop

            .not_palette:
            cmp byte [SelectedTool], Tool.pencil
            jne mainloop

            mov edx, [ev + Mouse.x]
            sub edx, Toolbar_Width + Border_Width + CanvasMargin

            mov ecx, [ev + Mouse.y]
            sub ecx, Statusbar_Height + Border_Width + CanvasMargin

            cmp edx, [CanvasWidth]
            jae mainloop
            cmp ecx, [CanvasHeight]
            jae mainloop

            mov byte [MouseDown], 1
            mov [LastX], edx
            mov [LastY], ecx
            mov edi, edx
            mov esi, ecx
            call DrawLine

            mov byte [Dirty], 1
            jmp mainloop

    DrawLine:
        push rbx
        push r12

        mov r8d, edx
        sub r8d, edi
        mov r10d, 1
        jns .sign_pos

        neg r8d
        mov r10d, -1

        ; r8d abs delt x, r10d sx
        .sign_pos:
            mov r9d, ecx
            sub r9d, esi
            mov r11d, 1
            jns .sy_ok

            neg r9d
            mov r11d, -1
        
        ; r9d neg abs delt y, r11d sy
        .sy_ok:
            neg r9d
            lea ebx, [r8 + r9]

        .loop:
            cmp edi, [CanvasWidth]
            jae .skip
            cmp esi, [CanvasHeight]
            jae .skip
            mov eax, esi
            imul eax, [CanvasWidth]
            add eax, edi
            mov r12, [WorkingBuffer]
            lea r12, [r12 + rax * 4]
            mov eax, [SelectedColor]
            mov [r12], eax

        .skip:
            cmp edi, edx
            jne .step
            cmp esi, ecx
            je .done

        .step: 
            lea eax, [rbx + rbx]
            cmp eax, r9d
            jl .kaput
            add ebx, r9d
            add edi, r10d

        .kaput:
            cmp eax, r8d
            jg .loop
            add ebx, r8d
            add esi, r11d
            jmp .loop

        .done:  
            pop r12
            pop rbx
            ret

    NewEmptyCanvas:
        sub rsp, 8
        mov edi, [CanvasWidth]
        imul edi, [CanvasHeight]
        shl edi, 2
        call malloc

        test rax, rax
        jz exit

        mov [rsp], rax
        mov rdi, rax
        mov ecx, [CanvasWidth]
        imul ecx, [CanvasHeight]
        mov eax, 0x00FFFFFF
        cld
        rep stosd

        mov rax, [rsp]
        add rsp, 8
        ret

    NewCanvas:
        sub rsp, 8
        call NewEmptyCanvas
        mov [Canvas], rax
        call NewEmptyCanvas
        mov [WorkingBuffer], rax
        add rsp, 8
        ret

    CreateCanvasImage:
        push r12
        push r13
        sub rsp, 40

        mov rdi, [dpy]
        mov esi, [screen_num]
        call XDefaultVisual
        mov r12, rax

        mov rdi, [dpy]
        mov esi, [screen_num]
        call XDefaultDepth
        mov r13d, eax

        mov eax, [CanvasWidth]
        mov [rsp], rax
        
        mov eax, [CanvasHeight]
        mov [rsp+8], rax

        mov qword [rsp + 16], 32

        mov eax, [CanvasWidth]
        shl eax, 2
        mov [rsp+24], rax

        mov rdi, [dpy]
        mov rsi, r12
        mov edx, r13d
        mov ecx, 2
        xor r8d, r8d
        mov r9, [WorkingBuffer]

        call WindowCreateImage
        test rax, rax
        jz exit

        mov [CanvasImage], rax

        add rsp, 40

        pop r13
        pop r12
        ret

    DrawCanvas:
        sub rsp, 40

        mov eax, Toolbar_Width + Border_Width + CanvasMargin
        mov [rsp], rax
        mov eax, Statusbar_Height + Border_Width + CanvasMargin
        mov [rsp + 8], rax
        mov eax, [CanvasWidth]
        mov [rsp + 16], rax
        mov eax, [CanvasHeight]
        mov [rsp + 24], rax

        mov rdi, [dpy]
        mov rsi, [win]
        mov rdx, [gc]
        mov rcx, [CanvasImage]

        xor r8d, r8d
        xor r9d, r9d

        call WindowPutImage

        add rsp, 40
        ret

    DrawGUI:
        sub rsp, 8

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

        DrawFilledRectangle 0, Statusbar_Height, [width], Border_Width


        add rsp, 8

        RedrawSelectedColor:
        sub rsp, 8
        SetForeground 0xA6A6A6
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        add r10d, 21
        DrawFilledRectangle 12, r10d, 15, 15

        SetForeground 0xF5F5F5
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        add r10d, 21
        DrawFilledRectangle 12, r10d, 14, 14

        SetForeground [SecondarySelectedColor]
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        add r10d, 22
        DrawFilledRectangle 13, r10d, 12, 12

        SetForeground 0xA6A6A6
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        add r10d, 14
        DrawFilledRectangle 5, r10d, 15, 15

        SetForeground 0xF5F5F5
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        add r10d, 14
        DrawFilledRectangle 5, r10d, 14, 14

        SetForeground [SelectedColor]
        mov r10d, [height]
        sub r10d, Colorpicker_Height
        add r10d, 15
        DrawFilledRectangle 6, r10d, 12, 12
        add rsp, 8

        ; SetForeground 0xFF0000
        ; DrawFilledRectangle (Toolbar_Width - Button_Size)/2, (Toolbar_Width - Button_Size)/2 + 0, Button_Size, Button_Size ; TODO: brush tool

        ; Fall through to DrawColorSelection

    DrawColorSelection: 
        push r12
        push r13
        push rbx

        xor ebx, ebx ; counter

        .loop:
            cmp ebx, ColorsCount
            jae .exit

            SetForeground 0xFFFFFF
            ; White background 16x16
            mov eax, ebx
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
            lea rax, [Colors]
            SetForeground [rax + rbx * 4]
            inc r12d
            inc r13d
            DrawFilledRectangle r12d, r13d, 12, 12

            inc ebx
        jmp .loop

        .exit:
            pop rbx
            pop r13
            pop r12
            ret

    exit:
        mov eax, 60
        xor rdi, rdi
        syscall