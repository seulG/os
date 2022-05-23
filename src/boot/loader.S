%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
  LOADER_STACK_TOP  equ LOADER_BASE_ADDR
  jmp loader_start
  
  ; 构建GDT及其内部的描述符
  GDT_BASE:
    dd 0x0000_0000
    dd 0x0000_0000
  CODE_DESC:
    dd 0x0000_FFFF
    dd DESC_CODE_HIGH4
  DATA_STACK_DESC:
    dd 0x0000_FFFF
    dd DESC_DATA_HIGH4
  VIDEO_DESC:
    dd 0x8000_0007 ; limit = (0xbffff - 0xb8000) / 4k = 0x7
    dd DESC_VIDEO_HIGH4 ; 此时dpl为0

  GDT_SIZE  equ $ - GDT_BASE
  GDT_LIMIT equ GDT_SIZE - 1

  ; 预留60个描述符位置
  times 60 dq 0

  ; 相当于(CODE_DESC - GDT_BASE) / 8 + TI_GDT + RPL0
  SELECTOR_CODE equ (0x0001 << 3) + TI_GDT + RPL0
  SELECTOR_DATA equ (0x0002 << 3) + TI_GDT + RPL0
  SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0
  
  ; GDT指针，前2字节是GDT界限，后4字节是GDT起始地址
  
  gdt_ptr:
    dw GDT_LIMIT
    dd GDT_BASE

  loadermsg db '2 loader in real.'
  
  loader_start:
    mov sp, LOADER_BASE_ADDR
    mov bp, loadermsg
    mov cx, 17
    mov ax, 0x1301
    mov bx, 0x001f
    mov dx, 0x1800
    int 0x10

  ; 准备进入保护模式
  ; 1 打开A20
  ; 2 加载GDT
  ; 3 将cr0的pe置为1

  ; NOTE 打开A20
  in al, 0x92
  or al, 0000_0010b
  out 0x92, al

  ; NOTE 加载GDT
  lgdt [gdt_ptr]

  ; NOTE cr0第0位置为1
  mov eax, cr0
  or eax, 0x0000_0001
  mov cr0, eax

  ; 刷新流水线
  jmp dword SELECTOR_CODE: p_mode_start

  [bits 32]
  p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    mov byte [gs:160], 'P'
    mov byte [gs:162], 'E'
    jmp $
