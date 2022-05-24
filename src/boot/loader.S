%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
  LOADER_STACK_TOP  equ LOADER_BASE_ADDR
  ; jmp loader_start

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

  ; 内存检测，保存结果
  ; 该地址位0xb00，进入内核后会使用
  total_mem_bytes dd 0

  ; GDT指针，前2字节是GDT界限，后4字节是GDT起始地址
  gdt_ptr:
    dw GDT_LIMIT
    dd GDT_BASE

  ; 手工对齐
  ; total_mem_bytes 4字节
  ; gdt_ptr 6字节
  ; ards_buf 244 字节
  ; ards_nr 2字节
  ; 一共256字节
  ards_buf times 244 db 0
  ards_nr dw 0

  loader_start:
    mov sp, LOADER_BASE_ADDR
    mov si, loadermsg
    call print

    ; int 15h eax = E820h edx = 534D4150h SMAP 获取内存布局
    xor ebx, ebx ; ebx置0
    mov edx, 0x534d4150
    mov di, ards_buf
    .e820_mem_get_loop:
      ; 执行int 0x15后,eax值变为0x534d4150,所以每次执行int前都要更新为子功能号
      mov eax, 0x0000e820
      mov ecx, 20
      int 0x15
      jc .e820_faild_so_try_e801
      add di, cx
      inc word [ards_nr]
      cmp ebx, 0 ; ebx为0，且cf不为1，这说明ards全部返回，当前已是最后一个
      jnz .e820_mem_get_loop
      ; 在所有ards结构中，找出(base_add_low + length_low)最大值
      mov cx, [ards_nr]
      mov ebx, ards_buf
      xor edx, edx ; 用edx暂存最大容量，先置0
    .find_max_mem_area:
      mov eax, [ebx] ; base_add_low
      add eax, [ebx + 8] ; length_low
      add ebx, 20 ; 指向缓冲区下一个ards结构
      cmp edx, eax ; 冒泡排序, 找出最大
      jge .next_ards
      mov edx, eax
    .next_ards:
      loop .find_max_mem_area
      jmp .mem_get_ok
    ; int 15 ax = E801h 最大支持4G
    .e820_faild_so_try_e801:
      mov ax, 0xe801
      int 0x15
      jc .e801_failed_so_try88

      ; note 先算出低15M内存，ax和cx以Kb为单位，将其转换为byte
      mov cx, 0x400
      mul cx
      shl edx, 16
      and eax, 0x0000FFFF
      or edx, eax
      add edx, 0x100000 ; 加1M内存
      mov esi, edx
      ; note 将16M以上的内存转换为byte单位，bx和dx以64KB为单位
      xor eax, eax
      mov ax, bx
      mov ecx, 0x10000 ; 64KB
      mul ecx ; 32位乘法
      add esi, eax
      mov edx, esi
      jmp .mem_get_ok
    ; int 0x15 ah = 0x88 只能获取64M之内的
    .e801_failed_so_try88:
      mov ah, 0x88
      int 0x15
      jc .error_hlt
      and eax, 0x0000FFFF
      ; 16 位乘法
      mov cx, 0x400 ; 转换为byte 乘1M
      mul cx,
      shl edx, 16
      or edx, eax
      add edx, 0x100000 ; 加1M
    .mem_get_ok:
      mov [total_mem_bytes], edx

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

;打印信息
.error_hlt:
  hlt
; 实模式打印函数
print: 
  mov ah, 0x0e
.next:
  mov al, [si]
  cmp al, 0
  jz .done
  int 0x10
  inc si
  jmp .next
.done:
  ret

loadermsg:
  db 'decteding memory.', 0


  [bits 32]
  p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    mov byte [gs:320], 'P'
    mov byte [gs:321], 0x0c
    mov byte [gs:322], 'E'
    mov byte [gs:323], 0x0c
    jmp $
