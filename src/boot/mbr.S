%include "boot.inc"
SECTION MBR vstart=0x7c00
  ; 初始化寄存器
  mov ax, cs
  mov ds, ax
  mov es, ax
  mov es, ax
  mov fs, ax
  mov sp, 0x7c00
  mov ax, 0xb800
  mov gs, ax

; 清屏，利用0x06号功能，上卷全部行，则可清屏
; INT 0x10 功能号0x06 功能描述 上卷窗口
; 输入：
; AH 功能号 0x06
; AL 上卷行数 0 为全部行
; BH 上卷行属性
; (CL,CH) 窗口左上角(X,Y)位置
; (DL,DH) 窗口右下(X,Y)位置
; 无返回值
  mov ax, 0x600
  mov bx, 0x700
  mov cx, 0
  mov dx, 0x184f
  int 0x10

  mov byte [gs:0x00], '1'
  mov byte [gs:0x01], 0xA4

  mov byte [gs:0x02], ' '
  mov byte [gs:0x03], 0xA4

  mov byte [gs:0x04], 'M'
  mov byte [gs:0x05], 0xA4

  mov byte [gs:0x06], 'B'
  mov byte [gs:0x07], 0xA4

  mov byte [gs:0x08], 'R'
  mov byte [gs:0x09], 0xA4

  mov eax, LOADER

  jmp $

  times 510-($-$$) db "0"
  db 0x55,0xaa
