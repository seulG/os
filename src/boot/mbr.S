%include "boot.inc"
SECTION MBR vstart=0x7c00
  ; 设置为文本模式，清屏
  mov ax, 3
  int 0x10

  ; 初始化寄存器
  mov ax, cs
  mov ds, ax
  mov es, ax
  mov es, ax
  mov fs, ax
  mov sp, 0x7c00

  ; 打印字符
  mov si, message
  call print

  ; 起始扇区LBA地址
  mov eax, LOADER_START_SECTOR
  ; 写入内存地址, loader不能超过64KB
  mov bx, LOADER_BASE_ADDR
  ; 待读入扇区数
  mov cx, 4
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
  ; 读数据到内存
  .go_on_read:
    in ax, dx
    mov [bx], ax
    add bx, 2
    ; 循环计数器为cx
    loop .go_on_read
    ret

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

  message:
    db "Into MBR, read loader from disk.", 10, 13, 0

  times 510 - ($-$$) db 0
  db 0x55,0xaa
