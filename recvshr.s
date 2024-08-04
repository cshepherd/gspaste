*
* recvSHR - Send current contents of SHR
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
            stz   $0a
            stz   $0b

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
            jsr   recv_shr     ; recv SHR screen

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

recv_shr    lda   #00
            pha
            pha                ; x=0 on stack
            lda   $00
            clc
            adc   #3
            sta   $08
            lda   $01
            sta   $09          ; set $08 to data line (adrl)
]chunk      ldy   #1
            lda   #$04
            sta   [00],y
            iny
            lda   #$28
            sta   [00],y       ; S0_RX_RD (un-translated rx base)
            iny
            lda   [00],y
            sta   rx_rd+1      ; +1 to reverse endianness
            sta   rx_rd_orig+1
            lda   [00],y
            sta   rx_rd
            sta   rx_rd_orig

            lda   #<msg_rx_rd
            sta   $04
            lda   #>msg_rx_rd
            sta   $05
            jsr   print

            clc
            xce
            rep   $30          ; longa longm
            lda   rx_rd
            and   #$1FFF       ; 8KB
            clc
            adc   #$6000       ; RX base
            sta   rx_rd        ; NOTE storing it little-endian here
            sec
            xce
            sep   $30          ; shorta shortm

            jsr   printrcvd    ; sets rx_rcvd

            lda   #<msg_rx_base
            sta   $04
            lda   #>msg_rx_base
            sta   $05
            jsr   print

            lda   rx_rd+1
            ldy   #1
            sta   [00],y
            iny
            lda   rx_rd
            sta   [00],y       ; start at this base address

            clc
            xce
            rep   $10          ; shorta longx

            plx
            ldy   #00
]l1         lda   [08]
            stal  $e12000,x
            inx
            iny
            cpy   rx_rcvd      ; end of this packet/chunk
            beq   _pkt
            cpx   #$7FFF       ; end of SHR page
            beq   alldone
            bra   ]l1          ; else keep transferring data

_pkt        phx

            clc
            xce
            rep   $30          ; longa longx
            lda   rx_rd_orig
            clc
            adc   rx_rcvd
            sta   rx_rd_orig   ; this is what we'll write back to rx_rd

            sec
            xce
            sep   $30          ; shorta shortx

            ldy   #1
            lda   #$04
            sta   [00],y
            iny
            lda   #$28         ; add rx_rcvd to rx_rd_orig and store back in $0428
            sta   [00],y
            iny
            lda   rx_rd_orig+1
            sta   [00],y
            lda   rx_rd_orig
            sta   [00],y

            ldy   #2
            lda   #$01
            sta   [00],y       ; S0 command register
            iny
            lda   #$40
            sta   [00],y       ; RECV command to signal we processed the last chunk

            pla
            plx
            cpx   #$80         ; x = $8000
            beq   alldone

            phx
            pha
            jsr   printrcvd
            jmp   ]chunk

alldone     sec
            xce
            sep   $30
            rts

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

            jsr   printrcvd

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
            lda   rx_rd+1
            phy
            jsr   $fdda
            lda   rx_rd
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

printrcvd   lda   #<msg_rxspace
            sta   $04
            lda   #>msg_rxspace
            sta   $05
            jsr   print
            ldy   #1
            lda   #$04
            sta   [00],y
            iny
            lda   #$26
            sta   [00],y       ; rx size = $0426
            iny
            lda   [00],y
            pha
            phy
            sta   rx_rcvd+1
            jsr   $fdda
            ply
            lda   [00],y
            sta   rx_rcvd
            jsr   $fdda
            lda   #$8d
            jsr   $fded
            pla
            beq   printrcvd    ; loop until something to receive
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
dest_port   ddb   6570         ; dw would be little-endian
                               ; wiznet is bigendian. $19AA = 6570

* for sysfail
initFailErr str   'Unable to init Wiznet'

rx_rd       db    00,00        ; socket rx read ptr
rx_rd_orig  db    00,00        ; untranslated
rx_ptr      db    00,00
rx_rcvd     db    00,00

* status / debug messages
msg_init      asc "Initializing Wiznet and socket...",8d,00
msg_initfail  asc "Unable to Initialize Wiznet!",8d,00
msg_sockfail  asc "Unable to Initialize socket.",8d,00
msg_initpass  asc "Initialization complete.",8d,00
msg_conn      asc "Connecting to Server...",8d,00
msg_connected asc "Connected.",8d,00
msg_connfail  asc "Connection failed.",8d,00
msg_rx_rd     asc "Initial S0_RX_RD: $",8d,00
msg_rx_base   asc "Derived S0_RX Base: $",8d,00
msg_splines   asc "Reticulating Splines...",8d,00
msg_fudgie    asc "Flatlander!",8d,00
msg_sending   asc "Reading 8K to VGC RAM...",8d,00
msg_closing   asc "Closing connection...",8d,00
msg_exiting   asc "Exiting",8d,00
msg_rxspace   asc "RX Size: ",00
