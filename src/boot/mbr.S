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

  ; 起始扇区LBA地址
  mov eax, LOADER_START_SECTOR
  ; 写入内存地址, loader不能超过64KB
  mov bx, LOADER_BASE_ADDR
  ; 待读入扇区数
  mov cx, 1
  call rd_disk_m_16

  jmp LOADER_BASE_ADDR
; 读取硬盘连续n个扇区
rd_disk_m_16:
  ; 备份eax和cx 起始扇区和读取个数
  mov esi, eax
  mov di, cx

  ;NOTE 第一步: 设置要读取的扇区数
  ; 设置端口号
  mov dx, 0x1f2
  ; 读取数量存于cx寄存器
  mov al, cl
  out dx, al

  ; 恢复ax
  mov eax, esi

  ; NOTE 第二步: 将LBA地址写入 0x1f3~0x1f6
  ; LBA 7~0位 写入0x1f3
  mov dx, 0x1f3
  out dx, al

  ; LAB 15~8位 写入0x1f4
  mov cl, 8
  ; 地址右移8位
  shr eax, cl
  mov dx, 0x1f4
  out dx, al

  ; LAB 23~16位 写入0x1f5
  ; 地址右移8位
  shr eax, cl
  mov dx, 0x1f5
  out dx, al

  shr eax, cl
  ; 获取lba 24~27位
  and al, 0x0f
  ; 7~4位设置为1110，lba模式
  or al, 0xe0
  mov dx, 0x1f6
  out dx, al

  ; NOTE 第三步: 向0x1f7端口写入读命令 0x20
  mov dx, 0x1f7
  mov al, 0x20
  out dx, al

  ; NOTE 第四步: 检测硬盘状态
  .not_ready:
    ; 同一端口，写时表示写入命令字，读时表示硬盘状态
    ; 延迟
    nop
    in al, dx
    ; 第四位为1表示硬盘控制器已准备好数据传输
    ; 第七位为1表示硬盘正忙
    and al, 0x88
    cmp al, 0x08
    ; 未准备好，继续等待
    jnz .not_ready
    
  ; NOTE 第五步: 0x1f0读取数据
  ; di为读取扇区数
  mov ax, di
  ; 每次读入一个字，需要512/2 = 256次
  mov dx, 256
  ; di*256=总的读取次数
  mul dx
  ; 将总读取次数存入cx counter register
  mov cx, ax

  mov dx, 0x1f0
  .go_on_read:
    in ax, dx
    mov [bx], ax
    add bx, 2
    ; 循环计数器为cx
    loop .go_on_read
    ret

  times 510 - ($-$$) db 0
  db 0x55,0xaa
