*
* sendSHR - Send current contents of SHR
*           framebuffer via TCP
* requires: Uthernet II (W5100)
*

* teh registarz
* c0f4 for slot 7
* +0 = mode_reg
* +1 = addr_hi
* +2 = addr_lo
* +3 = data_reg

            org   $2000
            mx    %11         ; ie as bloaded A$2000 or p8 .SYSTEM

            stz   $02
            stz   $03
            stz   $06
            stz   $07          ; setup for long addressing

            lda   #<msg_init
            sta   $04
            lda   #>msg_init
            sta   $05
            jsr   print
            jsr   init_card    ; set up environment and card
            bcs   quittin

            lda   #<msg_conn
            sta   $04
            lda   #>msg_conn
            sta   $05
            jsr   print
            jsr   tcp_connect  ; connect to endpoint
            bcs   quittin

            lda   #<msg_sending
            sta   $04
            lda   #>msg_sending
            sta   $05
            jsr   print
            jsr   send_shr     ; send SHR screen

            lda   #<msg_closing
            sta   $04
            lda   #>msg_closing
            sta   $05
            jsr   print
            jsr   close_tcp    ; close tcp connection

quittin     lda   #<msg_exiting
            sta   $04
            lda   #>msg_exiting
            sta   $05
            jsr   print
            rts                ; quit to monitor/basic

send_shr    lda   #00
            pha
            pha
]chunk      ldy   #1
            lda   #$04
            sta   [00],y
            iny
            lda   #$24
            sta   [00],y       ; S0_TX_WR
            iny
            lda   [00],y
            sta   tx_wr+1      ; +1 to reverse endianness
            sta   tx_ptr+1
            lda   [00],y
            sta   tx_wr        ; tx_wr is the translated 5100 address we write to
            sta   tx_ptr       ; tx_ptr will be the exact original value
                               ; + 4KB, 8KB etc without translation

            lda   #<msg_tx_wr
            sta   $04
            lda   #>msg_tx_wr
            sta   $05
            jsr   print

            clc
            xce
            rep   $30          ; 16 bit math because i can
            lda   tx_wr
            and   #$1FFF       ; 8KB
            clc
            adc   #$4000       ; TX base
            sta   tx_wr        ; NOTE storing it little-endian here
            sec
            xce
            sep   $30

            jsr   printfree

            lda   #<msg_tx_base
            sta   $04
            lda   #>msg_tx_base
            sta   $05
            jsr   print

            lda   tx_wr+1
            ldy   #1
            sta   [00],y
            iny
            lda   tx_wr
            sta   [00],y       ; start at this base address

            clc
            xce
            rep   $10          ; M is $20 X is $10
            ldy   #3

            plx

]l1         ldal  $e12000,x    ; 8KB loop
            sta   [00],y
            inx
            cpx   #$2000
            beq   _8kb
            cpx   #$4000
            beq   _8kb
            cpx   #$6000
            beq   _8kb
            cpx   #$8000
            bne   ]l1

_8kb        phx

            rep   $30
            lda   tx_ptr
            clc
            adc   #$2000
            sta   tx_ptr
            sec
            xce
            sep   $30

            lda   #$04
            ldy   #1
            sta   [00],y
            iny
            lda   #$24
            sta   [00],y
            iny
            lda   tx_ptr+1
            sta   [00],y
            lda   tx_ptr
            sta   [00],y       ; inc S0_TX_WR to add 8KB

            lda   #$04
            ldy   #1
            sta   [00],y
            iny
            lda   #$01
            sta   [00],y       ; S0 command register
            iny
            lda   #$20
            sta   [00],y       ; SEND command

            jsr   printfree

            lda   #<msg_waiting
            sta   $04
            lda   #>msg_waiting
            sta   $05
            jsr   print

            ldy   #3
]wt         nop
            lda   [00],y
            bne   ]wt          ; wait for send completion

            pla
            plx
            cpx   #$80         ; x = $8000
            beq   alldone

            phx
            pha
            jmp   ]chunk

alldone     rts

close_tcp   lda   #$04
            ldy   #1
            sta   [00],y
            iny
            lda   #$01
            sta   [00],y       ; S0 command register
            iny
            lda   #$08         ; DISCON
            sta   [00],y

            lda   #$04
            ldy   #1
            sta   [00],y
            iny
            lda   #$01
            sta   [00],y
            iny
            lda   #$10         ; CLOSE
            sta   [00],y

            jsr   printfree

            rts

tcp_connect ldy   #1           ; addr_hi
            lda   #$04
            sta   [00],y
            iny                ; addr_lo
            lda   #$0C
            sta   [00],y       ; $040C = dest ip + port via auto increment
            iny                ; data
            ldx   #0
]dest       lda   dest_ip,x
            sta   [00],y
            inx
            cpx   #4+2
            bne   ]dest        ; dest ip and port now set

            ldy   #1
            lda   #$04
            sta   [00],y
            iny
            lda   #$01
            sta   [00],y       ; $0401 = socket command register
            iny
            lda   #04
            sta   [00],y       ; $04 = CONNECT

]cke        ldy   #1
            lda   #$04
            sta   [00],y
            iny
            lda   #$03
            sta   [00],y       ; $0403 = socket status register
            iny
            lda   [00],y
            beq   closed
            cmp   #$17         ; established?
            beq   connected
            jsr   $fdda
            lda   #$8d
            jsr   $fded
            bra   ]cke

connected   lda   #<msg_connected
            sta   $04
            lda   #>msg_connected
            sta   $05
            jsr   print
            clc
            rts

closed      lda   #<msg_connfail
            sta   $04
            lda   #>msg_connfail
            sta   $05
            jsr   print
            sec
            rts

initfail2   jmp   initfail     ; trampoline

init_card   ldy   cardslot
            tya
            asl
            asl
            asl
            asl
            clc
            adc   #$84
            sta   $00
            lda   #$C0
            sta   $01

            lda   #$80         ; $80 = reset
            sta   [00]

            lda   [00]
            bne   initfail2

            lda   #$03         ; Indirect Bus IF mode, Address Auto-Increment
            sta   [00]

            ldy   #1
            lda   #00
            sta   [00],y
            iny
            inc
            sta   [00],y       ; #0001 - Gateway address

            iny                ; set gw(4)+mask(4)+mac(6)+ip(4)
            ldx   #00
]gw         lda   my_gw,x
            sta   [00],y
            inx
            cpx   #18+1
            bne   ]gw

            lda   #00
            ldy   #1
            sta   [00],y
            iny
            lda   #$1a
            sta   [00],y       ; rx mem

            lda   #$03
            iny
            sta   [00],y

            sta   [00],y       ; tx mem (via auto inc). 8k for one socket

            lda   #$04
            ldy   #1
            sta   [00],y
            lda   #$04
            iny
            sta   [00],y       ; $0404 = S0 source port
            iny
            lda   dest_port
            sta   [00],y
            lda   dest_port+1
            sta   [00],y       ; (same as dest because who cares)

            lda   #$04
            ldy   #1
            sta   [00],y
            iny
            lda   #$00
            sta   [00],y       ; $0400 = S0 mode port
            iny
            lda   #$01
            sta   [00],y       ; $01 = TCP

            lda   #$04
            ldy   #1
            sta   [00],y
            iny
            lda   #$01
            lda   [00],y       ; $0401 = S0 command port
            iny
            lda   #$01         ;
            sta   [00],y       ; send OPEN command

]slp        lda   #$04
            ldy   #1
            sta   [00],y
            iny
            lda   #$03
            sta   [00],y       ; $0403 = S0 status register
            iny
            lda   [00],y
            beq   sockfail
            cmp   #$13
            beq   initpass
            jsr   $fdda
            lda   #$a0
            jsr   $fded
            bra   ]slp

sockfail    lda   #<msg_sockfail
            sta   $04
            lda   #>msg_sockfail
            sta   $05
            jsr   print
            sec
            rts

initpass    lda   #<msg_initpass
            sta   $04
            lda   #>msg_initpass
            sta   $05
            jsr   print
            clc
            rts

initfail    lda   #<msg_initfail
            sta   $04
            lda   #>msg_initfail
            sta   $05
            jsr   print
            rts

* die with sysfailmgr (currently unused)
sysFail     clc
            xce
            rep   $30
            pea   $0000        ; WORD: Error Code
            pea   $0000        ; addr_hi
            pea   #initFailErr ; addr_lo
            ldx   #$1503       ; SysFailMgr
            jsl   $e10000

* quit to p8 (currently unused)
            mx    %11
quit        jsr   $bf00
            db    $65
            dw    quitparms

* msg ptr in $04
print       ldy   #0
]plp        lda   [$04],y
            beq   eos
            cmp   #"$"
            bne   char
            lda   tx_wr+1
            phy
            jsr   $fdda
            lda   tx_wr
            jsr   $fdda
            ply
            iny
            bra   ]plp
char        phy
            jsr   $fded
            ply
            iny
            bra   ]plp
eos         rts

printfree   lda   #<msg_txspace
            sta   $04
            lda   #>msg_txspace
            sta   $05
            jsr   print
            ldy   #1
            lda   #$04
            sta   [00],y
            iny
            lda   #$20
            sta   [00],y       ; tx free space = $0420 blaze it
            iny
            lda   [00],y
            pha
            phy
            jsr   $fdda
            ply
            lda   [00],y
            jsr   $fdda
            lda   #$8d
            jsr   $fded
            pla
            cmp   #$20
            bne   printfree    ; loop until 2000 free
            rts

cardslot    db    07           ; uthernet ii slot

quitparms   db    04           ; P8 QUIT parameters
            db    0
            dw    0
            db    0
            dw    0

* these go into wiznet registers in exactly this order
my_gw       db    192,168,0,1
my_mask     db    255,255,255,0
mac_addr    db    $08,00,$20,$C0,$10,$20
my_ip       db    192,168,0,254

dest_ip     db    192,168,0,183
dest_port   ddb   6569         ; dw would be little-endian
                               ; wiznet is bigendian. $19A9 = 6569

* for sysfail
initFailErr str   'Unable to init Wiznet'

tx_wr       db    00,00        ; socket tx write ptr
tx_ptr      db    00,00

* status / debug messages
msg_init      asc "Initializing Wiznet and socket...",8d,00
msg_initfail  asc "Unable to Initialize Wiznet!",8d,00
msg_sockfail  asc "Unable to Initialize socket.",8d,00
msg_initpass  asc "Initialization complete.",8d,00
msg_conn      asc "Connecting to Server...",8d,00
msg_connected asc "Connected.",8d,00
msg_connfail  asc "Connection failed.",8d,00
msg_tx_wr     asc "Initial S0_TX_WR: $",8d,00
msg_tx_base   asc "Derived S0_TX Base: $",8d,00
msg_splines   asc "Reticulating Splines...",8d,00
msg_fudgie    asc "Flatlander!",8d,00
msg_sending   asc "Sending 8K from VGC RAM...",8d,00
msg_closing   asc "Closing connection...",8d,00
msg_exiting   asc "Exiting",8d,00
msg_waiting   asc "Waiting for SEND completion...",8d,00
msg_txspace   asc "TX Free Space: ",00
