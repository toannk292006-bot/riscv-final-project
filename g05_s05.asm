
.eqv KEY_ROW    0xFFFF0012      # ghi: chon hang can quet
.eqv KEY_COL    0xFFFF0014      # doc: ma phim (hang|cot) hoac 0
.eqv SEG_RIGHT  0xFFFF0010      # LED 7 doan phai
.eqv SEG_LEFT   0xFFFF0011      # LED 7 doan trai
.eqv KEY_A      10              # phim 'A' (chi so 10) - vao che do doi mat khau
.eqv KEY_F      15              # phim 'F' (chi so 15) - ket thuc nhap
.eqv MAX_LEN    16              # do dai mat khau toi da (so bytes vung dem)
.eqv MIN_LEN    4               # do dai mat khau toi thieu
.eqv MAX_WRONG  3               # so lan sai lien tiep -> khoa treo
.eqv LOCK_MS    60000           # thoi gian treo khoa (ms) = 60 giay

#==============================================================================
.data
# Mat khau hien tai: 4 byte khoi tao + du cho toi 16 byte
password:   .byte 1, 2, 3, 4
            .space 12
pass_len:   .word 4             # do dai mat khau hien tai

input_buf:  .space 16           # vung dem chua mat khau nguoi dung vua nhap
wrong_cnt:  .word 0             # dem so lan nhap sai lien tiep

# Bang ma 7 doan cho chu so 0..9
seg_table:  .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F

# Cac thong bao ra man hinh console (de theo doi)
msg_welcome:  .asciz "=== KHOA DIEN TU RISC-V ===\nNhap mat khau roi nhan F de mo khoa.\nNhan A de doi mat khau. Mat khau mac dinh: 1234\n\n"
msg_ok:       .asciz "[OK] Mat khau dung -> Khoa MO (On)\n"
msg_wrong:    .asciz "[X ] Mat khau SAI (OF)\n"
msg_lock:     .asciz "[!!] Sai qua 3 lan -> KHOA TREO 60 giay...\n"
msg_unlock:   .asciz "[..] Het thoi gian treo. Co the nhap lai.\n"
msg_chg:      .asciz "[A ] Doi mat khau: nhap mat khau HIEN TAI roi nhan F.\n"
msg_chgok:    .asciz "     Dung! Nhap mat khau MOI (>= 4 chu so) roi nhan F.\n"
msg_chgwrong: .asciz "     Mat khau hien tai SAI -> huy doi mat khau.\n"
msg_short:    .asciz "     Mat khau moi qua ngan (>= 4 chu so) -> huy.\n"
msg_saved:    .asciz "     Da luu mat khau moi!\n"

#==============================================================================
.text
.globl main
main:
        la   a0, msg_welcome        # in huong dan
        jal  puts
        jal  show_idle              # LED hien "--" (trang thai cho)

# ---------------------------------------------------------------------------
# VONG LAP CHINH: cho phim dau tien de phan biet "doi mat khau" hay "mo khoa"
# ---------------------------------------------------------------------------
main_loop:
        jal  get_key                # a0 = chi so phim (0..15)
        li   t0, KEY_A
        beq  a0, t0, change_pw      # neu la 'A' -> di doi mat khau

        # Neu khong phai 'A': a0 la phim dau tien cua lan nhap mo khoa.
        jal  collect                # nhap not mat khau (a0 = do dai)
        jal  compare                # a0 = 1 neu trung, 0 neu sai
        beq  a0, zero, unlock_fail

        # ----- Mat khau dung -> mo khoa -----
        la   a0, msg_ok
        jal  puts
        jal  show_on                # LED hien "On"
        la   t0, wrong_cnt          # dat lai bo dem sai = 0
        sw   zero, 0(t0)
        li   a0, 2000               # giu man hinh "On" 2 giay
        li   a7, 32
        ecall
        jal  show_idle
        j    main_loop

# ---------------------------------------------------------------------------
# MO KHOA THAT BAI: hien "OF", tang bo dem, treo khoa neu du 3 lan
# ---------------------------------------------------------------------------
unlock_fail:
        la   a0, msg_wrong
        jal  puts
        jal  show_off               # LED hien "OF"
        li   a0, 2000
        li   a7, 32
        ecall

        la   t0, wrong_cnt          # wrong_cnt = wrong_cnt + 1
        lw   t1, 0(t0)
        addi t1, t1, 1
        sw   t1, 0(t0)
        li   t2, MAX_WRONG
        blt  t1, t2, uf_back        # chua du MAX_WRONG -> tiep tuc

        sw   zero, 0(t0)            # da du -> dat lai bo dem
        jal  lockout                # treo khoa 60 giay
uf_back:
        jal  show_idle
        j    main_loop

# ---------------------------------------------------------------------------
# DOI MAT KHAU: kiem tra mat khau cu -> nhap mat khau moi -> luu de
# ---------------------------------------------------------------------------
change_pw:
        la   a0, msg_chg
        jal  puts

        li   a0, -1                 # -1 = doc phim moi tu dau
        jal  collect                # nhap mat khau hien tai
        jal  compare
        beq  a0, zero, chg_wrong    # sai mat khau cu -> huy

        la   a0, msg_chgok          # dung -> yeu cau nhap mat khau moi
        jal  puts
        li   a0, -1
        jal  collect                # nhap mat khau moi (a0 = do dai)
        mv   s0, a0                 # s0 = do dai mat khau moi

        li   t0, MIN_LEN            # kiem tra do dai toi thieu
        blt  s0, t0, chg_short

        # ----- Sao chep input_buf -> password, cap nhat pass_len -----
        la   t1, input_buf
        la   t2, password
        li   t3, 0                  # i = 0
cp_copy:
        bge  t3, s0, cp_done
        add  t4, t1, t3
        lb   t5, 0(t4)
        add  t6, t2, t3
        sb   t5, 0(t6)
        addi t3, t3, 1
        j    cp_copy
cp_done:
        la   t0, pass_len
        sw   s0, 0(t0)              # luu do dai moi
        la   a0, msg_saved
        jal  puts
        jal  show_on                # bao thanh cong bang "On"
        li   a0, 1500
        li   a7, 32
        ecall
        jal  show_idle
        j    main_loop

chg_wrong:                          # mat khau cu sai
        la   a0, msg_chgwrong
        jal  puts
        jal  show_off
        li   a0, 1500
        li   a7, 32
        ecall
        jal  show_idle
        j    main_loop

chg_short:                          # mat khau moi qua ngan
        la   a0, msg_short
        jal  puts
        jal  show_off
        li   a0, 1500
        li   a7, 32
        ecall
        jal  show_idle
        j    main_loop

#==============================================================================
#  CHUONG TRINH CON
#==============================================================================

# -----------------------------------------------------------------------------
# collect: thu thap cac chu so vao input_buf cho den khi nhan F.
#   Vao : a0 = phim dau tien da co san (hoac -1 = tu doc phim dau)
#   Ra  : a0 = so chu so da nhap; cac chu so nam o input_buf
#   Bo qua moi phim khong phai chu so (A..E); chi nhan 0..9; F ket thuc.
# -----------------------------------------------------------------------------
collect:
        addi sp, sp, -16
        sw   ra, 12(sp)
        sw   s0,  8(sp)             # s0 = do dai dang dem
        sw   s1,  4(sp)             # s1 = phim dau tien duoc truyen vao
        sw   s2,  0(sp)             # s2 = chu so hien hanh

        mv   s1, a0		   
        li   s0, 0                  # do dai = 0
        li   t0, -1
        beq  s1, t0, c_read         # neu -1 thi doc phim dau tu ban phim
        mv   a0, s1                 # nguoc lai dung phim da co
        j    c_proc
c_read:
        jal  get_key
c_proc:
        li   t0, KEY_F
        beq  a0, t0, c_done         # nhan F -> ket thuc
        li   t0, 10
        bge  a0, t0, c_read         # phim A..E (>=10) khong phai so -> bo qua

        # a0 la chu so 0..9
        mv   s2, a0                 # giu lai chu so de hien thi
        li   t0, MAX_LEN
        bge  s0, t0, c_echo         # neu dem da day thi khong luu them
        la   t0, input_buf          # input_buf[s0] = chu so
        add  t0, t0, s0
        sb   s2, 0(t0)
        addi s0, s0, 1              # tang do dai
c_echo:
        mv   a0, s2                 # hien chu so vua bam len LED phai
        jal  show_digit
        j    c_read
c_done:
        mv   a0, s0                 # tra ve do dai
        lw   ra, 12(sp)
        lw   s0,  8(sp)
        lw   s1,  4(sp)
        lw   s2,  0(sp)
        addi sp, sp, 16
        jalr zero, 0(ra)

# -----------------------------------------------------------------------------
# compare: so sanh input_buf voi mat khau dang luu.
#   Vao : a0 = do dai chuoi vua nhap
#   Ra  : a0 = 1 neu trung khop, 0 neu khong
# -----------------------------------------------------------------------------
compare:
        la   t0, pass_len
        lw   t1, 0(t0)              # t1 = do dai mat khau dung
        bne  a0, t1, cmp_no         # khac do dai -> sai ngay
        la   t2, input_buf
        la   t3, password
        li   t4, 0                  # i = 0
cmp_loop:
        bge  t4, t1, cmp_yes        # so sanh xong het -> trung
        add  t5, t2, t4
        lb   t5, 0(t5)             # input_buf[i]
        add  t6, t3, t4
        lb   t6, 0(t6)             # password[i]
        bne  t5, t6, cmp_no
        addi t4, t4, 1
        j    cmp_loop
cmp_yes:
        li   a0, 1
        jalr zero, 0(ra)
cmp_no:
        li   a0, 0
        jalr zero, 0(ra)

# -----------------------------------------------------------------------------
# get_key: cho den khi co MOT phim duoc nhan ROI nha (chong rung).
#   Ra  : a0 = chi so phim 0..15
# -----------------------------------------------------------------------------
get_key:
        addi sp, sp, -8
        sw   ra, 4(sp)
        sw   s0, 0(sp)
gk_press:
        jal  scan_keypad           # cho phim duoc nhan
        li   t0, -1
        beq  a0, t0, gk_press
        mv   s0, a0                # ghi nho phim
gk_release:
        jal  scan_keypad           # cho nha phim (doc ve -1)
        li   t0, -1
        bne  a0, t0, gk_release
        mv   a0, s0
        lw   ra, 4(sp)
        lw   s0, 0(sp)
        addi sp, sp, 8
        jalr zero, 0(ra)
# -----------------------------------------------------------------------------
# scan_keypad: quet 4 hang ban phim mot lan.
#   Ra  : a0 = chi so phim 0..15 neu co phim nhan, hoac -1 neu khong
# -----------------------------------------------------------------------------
scan_keypad:
        li   t0, KEY_ROW           # dia chi ghi hang
        li   t1, KEY_COL           # dia chi doc phim
        li   t2, 0                 # hang = 0
sk_loop:
        li   t3, 4
        bge  t2, t3, sk_none       # da quet het 4 hang
        li   t4, 1
        sll  t4, t4, t2            # mat na hang = 1 << hang
        sb   t4, 0(t0)            # chon hang can quet
        lb   t5, 0(t1)           # doc phim (hang|cot)
        andi t5, t5, 0xFF         # giu 8 bit thap (tranh mo rong dau)
        bne  t5, zero, sk_found   # khac 0 -> co phim trong hang nay
        addi t2, t2, 1
        j    sk_loop
sk_none:
        li   a0, -1
        jalr zero, 0(ra)
sk_found:
        # t2 = hang ; t5 = (hang|cot). Tach cot o nibble cao.
        srli t5, t5, 4             # dua nibble cot xuong thap
        andi t5, t5, 0x0F          # t5: 1->cot0, 2->cot1, 4->cot2, 8->cot3
        li   t6, 0                 # cot = 0
sk_col:
        andi a0, t5, 1             # bit thap nhat dang bat?
        bne  a0, zero, sk_calc
        srli t5, t5, 1
        addi t6, t6, 1
        j    sk_col
sk_calc:
        slli a0, t2, 2             # hang * 4
        add  a0, a0, t6            # + cot  => chi so phim
        jalr zero, 0(ra)

# -----------------------------------------------------------------------------
# show_idle / show_on / show_off / show_digit: dieu khien 2 LED 7 doan
# -----------------------------------------------------------------------------
show_idle:                         # hien "--" (chi bat doan g) bao trang thai cho
        li   t0, SEG_LEFT
        li   t1, 0x40	# 0100 0000 
        sb   t1, 0(t0)
        li   t0, SEG_RIGHT
        sb   t1, 0(t0)
        jalr zero, 0(ra)

show_on:                           # hien "On"
        li   t0, SEG_LEFT
        li   t1, 0x3F              # 'O'
        sb   t1, 0(t0)
        li   t0, SEG_RIGHT
        li   t1, 0x54              # 'n'
        sb   t1, 0(t0)
        jalr zero, 0(ra)

show_off:                          # hien "OF"
        li   t0, SEG_LEFT
        li   t1, 0x3F              # 'O'
        sb   t1, 0(t0)
        li   t0, SEG_RIGHT
        li   t1, 0x71              # 'F'
        sb   t1, 0(t0)
        jalr zero, 0(ra)

show_digit:                        # hien chu so a0 (0..9) len LED phai
        la   t0, seg_table
        add  t0, t0, a0
        lb   t1, 0(t0)
        li   t2, SEG_RIGHT
        sb   t1, 0(t2)
        li   t2, SEG_LEFT          # tat LED trai cho de nhin
        sb   zero, 0(t2)
        jalr zero, 0(ra)

# -----------------------------------------------------------------------------
# lockout: treo khoa 60 giay. Trong luc nay khong quet phim nen phim vo tac dung.
# -----------------------------------------------------------------------------
lockout:
        addi sp, sp, -4
        sw   ra, 0(sp)
        la   a0, msg_lock
        jal  puts
        li   t0, SEG_LEFT          # hien "--" suot thoi gian treo
        li   t1, 0x40
        sb   t1, 0(t0)
        li   t0, SEG_RIGHT
        sb   t1, 0(t0)
        li   a0, LOCK_MS           # ngu 60 giay (chuong trinh dung -> phim vo hieu)
        li   a7, 32
        ecall
        la   a0, msg_unlock
        jal  puts
        lw   ra, 0(sp)
        addi sp, sp, 4
        jalr zero, 0(ra)

# -----------------------------------------------------------------------------
# puts: in chuoi ket thuc bang 0.  Vao: a0 = dia chi chuoi
# -----------------------------------------------------------------------------
puts:
        li   a7, 4
        ecall
        jalr zero, 0(ra)
