# =======================================================================================
#  MINI CAD - RISC-V (RV32) - Mo phong ung dung ve hinh hoc don gian
#  Moi truong: RARS
#
#  CAU HINH BAT BUOC TRONG RARS:
#    Tools -> Bitmap Display:
#        Unit Width = 1, Unit Height = 1
#        Display Width = 256, Display Height = 256
#        Base address for display = 0x10010000 (static data)
#    Tools -> Keyboard and Display MMIO Simulator -> Connect to Program
#    => Vung "framebuffer" duoc khai bao DAU TIEN trong .data nen no nam
#       dung tai 0x10010000 (dia chi mac dinh cua .data).
#
#  Cac lenh ho tro (toa do hop le x,y trong [0..255], ngoai vung se bi cat):
#        line x1 y1 x2 y2        ve doan thang
#        rectangle x1 y1 x2 y2   ve hinh chu nhat (vien)
#        circle x y r            ve duong tron
#        color n                 chon mau (chap nhan hex 0x... , thap phan, am)
#        fill x y                to mau (flood fill)
#        clear                   xoa man hinh
#
# =======================================================================================

.eqv WIDTH        256
.eqv HEIGHT       256
.eqv PIXELS       65536
.eqv FB_BASE      0x10010000

.eqv RCR          0xffff0000        # Receiver Control     (bit0 = co ky tu)
.eqv RDR          0xffff0004        # Receiver Data        (du lieu ban phim)
.eqv TCR          0xffff0008        # Transmitter Control  (bit0 = san sang gui)
.eqv TDR          0xffff000c        # Transmitter Data     (ky tu xuat ra man hinh)

.data
.align 2
framebuffer: .space 262144          # Bo dem khung hinh: 256 * 256 * 4 byte
stackX:      .space 262144          # Ngan xep luu toa do X cho flood fill
stackY:      .space 262144          # Ngan xep luu toa do Y cho flood fill
inputbuf:    .space 1024            # Bo dem dong lenh nguoi dung nhap
currentColor:.word 0x00ffffff       # Mau ve hien tai (mac dinh: trang)

# --- Tu khoa lenh ---
cmd_line:      .asciz "line"
cmd_rect:      .asciz "rectangle"
cmd_circle:    .asciz "circle"
cmd_color:     .asciz "color"
cmd_fill:      .asciz "fill"
cmd_clear:     .asciz "clear"

# --- Chuoi thong bao ---
msg_banner: .asciz "=== MINI CAD (RISC-V / RARS) ===\n   Cac lenh:\n  line x1 y1 x2 y2\n  rectangle x1 y1 x2 y2\n  circle x y r\n  color n   \n  fill x y\n  clear\n> "
msg_prompt: .asciz "~> "
msg_ok:     .asciz "[SUCCESS]\n> "
msg_err:    .asciz "[ERROR]\n> "

.text
.globl main

# =======================================================================================
#  CHUONG TRINH CHINH
# =======================================================================================
main:
    la a0, msg_banner               # In banner chao mung
    jal print_string

main_loop:
    la a0, inputbuf                 # Doc 1 dong lenh vao inputbuf
    jal read_line

    la s0, inputbuf

    lbu t0, 0(s0)                   # Neu dong rong (byte dau = '\0') -> nhac lai
    beqz t0, print_prompt_and_loop

    # --- Phan tich lenh: tu khoa nao khop thi nhay toi handler tuong ung ---
    mv a0, s0                       # Kiem tra lenh "line"
    la a1, cmd_line
    jal match_word
    bnez a0, handle_line
    mv a0, s0                       # Kiem tra lenh "rectangle"
    la a1, cmd_rect
    jal match_word
    bnez a0, handle_rect
    mv a0, s0                       # Kiem tra lenh "circle"
    la a1, cmd_circle
    jal match_word
    bnez a0, handle_circle
    mv a0, s0                       # Kiem tra lenh "color"
    la a1, cmd_color
    jal match_word
    bnez a0, handle_color
    mv a0, s0                       # Kiem tra lenh "fill"
    la a1, cmd_fill
    jal match_word
    bnez a0, handle_fill
    mv a0, s0                       # Kiem tra lenh "clear"
    la a1, cmd_clear
    jal match_word
    bnez a0, handle_clear

    j print_err_and_loop            # Khong khop tu khoa nao -> loi cu phap

# --- Cac diem in thong bao roi quay lai vong lap ---
print_prompt_and_loop:
    la a0, msg_prompt
    jal print_string
    j main_loop

print_ok_and_loop:
    la a0, msg_ok
    jal print_string
    j main_loop

print_err_and_loop:
    la a0, msg_err
    jal print_string
    j main_loop

# =======================================================================================
#  CAC HANDLER LENH
#  Quy tac chung: doc den dau parse den do; sau khi parse so CUOI thi goi
#  check_end de bao dam khong con tham so thua.
# =======================================================================================
handle_clear:
    jal clear_screen
    j print_ok_and_loop

# --- line x1 y1 x2 y2 ---
handle_line:
    addi s1, s0, 4                  # Bo qua chu "line"
    mv a0, s1                       # Parse x1
    jal parse_int
    beqz a2, print_err_and_loop     # Parse that bai (thieu so) -> loi
    mv s2, a0                       # s2 = x1
    mv s1, a1                       # Cap nhat con tro sang so tiep theo

    mv a0, s1                       # Parse y1
    jal parse_int
    beqz a2, print_err_and_loop
    mv s3, a0                       # s3 = y1
    mv s1, a1

    mv a0, s1                       # Parse x2
    jal parse_int
    beqz a2, print_err_and_loop
    mv s4, a0                       # s4 = x2
    mv s1, a1

    mv a0, s1                       # Parse y2 (so cuoi)
    jal parse_int
    beqz a2, print_err_and_loop
    mv s5, a0                       # s5 = y2
    mv s1, a1                       # Cap nhat con tro sau so cuoi

    mv a0, s1                       # Kiem tra THUA tham so
    jal check_end
    beqz a0, print_err_and_loop     # Con thua -> loi

    mv a0, s2                       # Goi draw_line(x1, y1, x2, y2)
    mv a1, s3
    mv a2, s4
    mv a3, s5
    jal draw_line
    j print_ok_and_loop

# --- rectangle x1 y1 x2 y2 ---
handle_rect:
    addi s1, s0, 9                  # Bo qua chu "rectangle"
    mv a0, s1                       # Parse x1
    jal parse_int
    beqz a2, print_err_and_loop
    mv s2, a0                       # s2 = x1
    mv s1, a1

    mv a0, s1                       # Parse y1
    jal parse_int
    beqz a2, print_err_and_loop
    mv s3, a0                       # s3 = y1
    mv s1, a1

    mv a0, s1                       # Parse x2
    jal parse_int
    beqz a2, print_err_and_loop
    mv s4, a0                       # s4 = x2
    mv s1, a1

    mv a0, s1                       # Parse y2 (so cuoi)
    jal parse_int
    beqz a2, print_err_and_loop
    mv s5, a0                       # s5 = y2
    mv s1, a1

    mv a0, s1                       # Kiem tra THUA tham so
    jal check_end
    beqz a0, print_err_and_loop

    mv a0, s2                       # Goi draw_rectangle(x1, y1, x2, y2)
    mv a1, s3
    mv a2, s4
    mv a3, s5
    jal draw_rectangle
    j print_ok_and_loop

# --- circle x y r ---
handle_circle:
    addi s1, s0, 6                  # Bo qua chu "circle"
    mv a0, s1                       # Parse xC
    jal parse_int
    beqz a2, print_err_and_loop
    mv s2, a0                       # s2 = xC
    mv s1, a1

    mv a0, s1                       # Parse yC
    jal parse_int
    beqz a2, print_err_and_loop
    mv s3, a0                       # s3 = yC
    mv s1, a1

    mv a0, s1                       # Parse r (so cuoi)
    jal parse_int
    beqz a2, print_err_and_loop
    mv s4, a0                       # s4 = r
    mv s1, a1
    bltz s4, print_err_and_loop     # Ban kinh am -> loi

    mv a0, s1                       # Kiem tra THUA tham so
    jal check_end
    beqz a0, print_err_and_loop

    mv a0, s2                       # Goi draw_circle(xc, yc, r)
    mv a1, s3
    mv a2, s4
    jal draw_circle
    j print_ok_and_loop

# --- color n  (chap nhan hex 0x... , thap phan, am) ---
handle_color:
    addi s1, s0, 5                  # Bo qua chu "color"
    mv a0, s1                       # Parse ma mau (so duy nhat)
    jal parse_int
    beqz a2, print_err_and_loop
    mv s2, a0                       # s2 = ma mau
    mv s1, a1

    mv a0, s1                       # Kiem tra THUA tham so
    jal check_end
    beqz a0, print_err_and_loop

    la t0, currentColor             # Luu ma mau vao bien trang thai
    sw s2, 0(t0)
    j print_ok_and_loop

# --- fill x y ---
handle_fill:
    addi s1, s0, 4                  # Bo qua chu "fill"
    mv a0, s1                       # Parse seed_x
    jal parse_int
    beqz a2, print_err_and_loop
    mv s2, a0                       # s2 = seed_x
    mv s1, a1

    mv a0, s1                       # Parse seed_y (so cuoi)
    jal parse_int
    beqz a2, print_err_and_loop
    mv s3, a0                       # s3 = seed_y
    mv s1, a1

    mv a0, s1                       # Kiem tra THUA tham so
    jal check_end
    beqz a0, print_err_and_loop

    mv a0, s2                       # Goi flood_fill(seed_x, seed_y)
    mv a1, s3
    jal flood_fill
    j print_ok_and_loop

# =======================================================================================
#  CAC HAM I/O & PHAN TICH CHUOI
# =======================================================================================

# ---------------------------------------------------------------------------------------
# check_end: kiem tra phan con lai cua chuoi chi gom space roi '\0'.
# Inputs:  a0 = con tro toi phan con lai (lay tu a1 sau lan parse_int cuoi)
# Outputs: a0 = 1 neu hop le (khong thua tham so), 0 neu con tham so thua
# ---------------------------------------------------------------------------------------
check_end:
    lbu t0, 0(a0)
    li  t1, ' '
    bne t0, t1, check_end_test      # Khong phai space -> di kiem tra ket thuc
    addi a0, a0, 1                  # Bo qua space
    j   check_end
check_end_test:
    beqz t0, check_end_ok           # '\0' -> het chuoi, hop le
    li  a0, 0                       # Con ky tu khac space/null -> thua tham so
    ret
check_end_ok:
    li  a0, 1
    ret

# ---------------------------------------------------------------------------------------
# read_line: doc 1 dong lenh, ket thuc khi gap Enter; co echo ra man hinh.
# Inputs:   a0 = dia chi bo dem dich de ghi chuoi nhap vao
# ---------------------------------------------------------------------------------------
read_line:
    addi sp, sp, -4
    sw ra, 0(sp)
    mv s0, a0                       # s0 = dia chi inputbuf
    li s2, 0                        # s2 = so ky tu da nhap (bat dau = 0)
read_line_loop:
    jal get_char                    # Doc 1 ky tu vao a0
    li t0, 13                       # '\r' -> ket thuc dong
    beq a0, t0, read_line_end
    li t0, 10                       # '\n' -> ket thuc dong
    beq a0, t0, read_line_end

    add t3, s0, s2                  # t3 = dia chi base + so ky tu
    sb a0, 0(t3)                    # Luu ky tu vao bo dem
    addi s2, s2, 1                  # Tang dem ky tu

    jal put_char                    # Echo ky tu vua go ra man hinh
    j read_line_loop
read_line_end:
    li a0, 10
    jal put_char                    # In '\n'
    add t3, s0, s2
    sb zero, 0(t3)                  # Ket chuoi bang '\0'

    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# ---------------------------------------------------------------------------------------
# get_char: cho va doc 1 ky tu tu Keyboard MMIO.
# Outputs:  a0 = ma ASCII ky tu vua nhan
# ---------------------------------------------------------------------------------------
get_char:
    li t0, RCR
get_char_wait:
    lw t1, 0(t0)
    andi t1, t1, 1                  # Kiem tra bit Ready
    beqz t1, get_char_wait          # Chua co ky tu -> tiep tuc cho
    li t0, RDR
    lbu a0, 0(t0)                   # Doc byte du lieu ban phim
    ret

# ---------------------------------------------------------------------------------------
# put_char: cho va in 1 ky tu ra Display MMIO.
# Inputs:   a0 = ma ASCII ky tu can in
# ---------------------------------------------------------------------------------------
put_char:
    li t0, TCR
put_char_wait:
    lw t1, 0(t0)
    andi t1, t1, 1                  # Kiem tra bit Ready
    beqz t1, put_char_wait          # Chua san sang -> tiep tuc cho
    li t0, TDR
    sb a0, 0(t0)                    # Ghi ky tu ra man hinh
    ret

# ---------------------------------------------------------------------------------------
# print_string: in chuoi ket thuc bang '\0'.
# Inputs:   a0 = dia chi chuoi can in
# ---------------------------------------------------------------------------------------
print_string:
    addi sp, sp, -8
    sw ra, 4(sp)
    sw s0, 0(sp)
    mv s0, a0
print_string_loop:
    lbu a0, 0(s0)
    beqz a0, print_string_done      # Gap '\0' -> dung
    jal put_char
    addi s0, s0, 1
    j print_string_loop
print_string_done:
    lw ra, 4(sp)
    lw s0, 0(sp)
    addi sp, sp, 8
    ret

# ---------------------------------------------------------------------------------------
# match_word: so sanh chuoi nhap voi tu khoa. Khop khi tu khoa la tien to cua
#             chuoi nhap, va ky tu ke tiep trong chuoi nhap la space hoac '\0'.
# Inputs:   a0 = chuoi nhap, a1 = tu khoa
# Outputs:  a0 = 1 neu khop, 0 neu khong
# ---------------------------------------------------------------------------------------
match_word:
    mv t0, a0                       # t0 = con tro chuoi nhap
    mv t1, a1                       # t1 = con tro tu khoa
match_loop:
    lbu t2, 0(t1)                   # t2 = ky tu tu khoa
    lbu t3, 0(t0)                   # t3 = ky tu chuoi nhap
    beqz t2, match_check_delim      # Het tu khoa -> kiem tra dau phan cach
    bne t2, t3, match_no            # Khac nhau -> khong khop
    addi t0, t0, 1
    addi t1, t1, 1
    j match_loop
match_check_delim:
    beqz t3, match_yes              # Chuoi nhap cung ket thuc -> khop
    li t4, ' '
    beq t3, t4, match_yes           # Ky tu ke tiep la space -> khop
    j match_no
match_yes:
    li a0, 1
    ret
match_no:
    li a0, 0
    ret

# ---------------------------------------------------------------------------------------
# parse_int: chuyen chuoi ASCII thanh so nguyen co dau. Ho tro hex (0x...),
#            thap phan, va dau am '-'.
# Inputs:   a0 = dia chi chuoi
# Outputs:  a0 = gia tri so
#           a1 = dia chi ky tu ngay sau so vua doc
#           a2 = 1 neu thanh cong, 0 neu that bai
# ---------------------------------------------------------------------------------------
parse_int:
    addi sp, sp, -4
    sw ra, 0(sp)
    addi a0, a0, 1                  # Bo qua 1 space dau
    mv t0, a0                       # t0 = con tro chuoi
    li t1, 0                        # t1 = gia tri tich luy
    li t2, 1                        # t2 = dau (mac dinh duong)
    li t6, 0                        # t6 = so chu so da doc

    lbu t3, 0(t0)                   # Kiem tra dau am
    li t4, '-'
    bne t3, t4, parse_check_hex
    li t2, -1                       # Doi dau thanh am
    addi t0, t0, 1

parse_check_hex:
    lbu t3, 0(t0)
    li t4, '0'
    bne t3, t4, parse_dec_loop      # Khong bat dau bang '0' -> thap phan
    lbu t3, 1(t0)
    li t4, 'x'
    beq t3, t4, parse_hex_start     # Co tien to '0x' -> hex
    j parse_dec_loop

parse_hex_start:
    addi t0, t0, 2                  # Bo qua '0x'
parse_hex_loop:
    lbu t3, 0(t0)
    li t4, '0'
    blt t3, t4, parse_hex_done
    li t4, '9'
    ble t3, t4, parse_hex_digit_num # '0'..'9'
    li t4, 'A'
    blt t3, t4, parse_hex_done      # khoang ':' .. '@' -> dung
    li t4, 'F'
    ble t3, t4, parse_hex_digit_up  # 'A'..'F' (chu HOA)
    li t4, 'a'
    blt t3, t4, parse_hex_done      # khoang 'G' .. '`' -> dung
    li t4, 'f'
    ble t3, t4, parse_hex_digit_low # 'a'..'f' (chu thuong)
    j parse_hex_done
parse_hex_digit_num:
    addi t3, t3, -48                # '0'..'9' -> 0..9
    j parse_hex_add
parse_hex_digit_up:
    addi t3, t3, -55                # 'A'(65)..'F' -> 10..15
    j parse_hex_add
parse_hex_digit_low:
    addi t3, t3, -87                # 'a'(97)..'f' -> 10..15
parse_hex_add:
    slli t1, t1, 4                  # value = value*16 + digit
    add t1, t1, t3
    addi t6, t6, 1
    addi t0, t0, 1
    j parse_hex_loop
parse_hex_done:
    beqz t6, parse_fail             # Khong doc duoc chu so nao -> that bai
    mul t1, t1, t2                  # Nhan voi dau
    mv a0, t1
    mv a1, t0
    li a2, 1
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

parse_dec_loop:
    lbu t3, 0(t0)
    li t4, '0'
    blt t3, t4, parse_dec_done      # < '0' -> dung
    li t4, '9'
    bgt t3, t4, parse_dec_done      # > '9' -> dung
    addi t3, t3, -48                # ASCII -> gia tri
    li t4, 10
    mul t1, t1, t4                  # value = value*10 + digit
    add t1, t1, t3
    addi t6, t6, 1
    addi t0, t0, 1
    j parse_dec_loop
parse_dec_done:
    beqz t6, parse_fail             # Khong co chu so -> that bai
    mul t1, t1, t2                  # Nhan voi dau
    mv a0, t1
    mv a1, t0
    li a2, 1
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
parse_fail:
    li a0, 0
    mv a1, t0
    li a2, 0
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# =======================================================================================
#  CAC HAM VE HINH
# =======================================================================================

# ---------------------------------------------------------------------------------------
# clear_screen: xoa toan bo man hinh ve mau den (0).
# ---------------------------------------------------------------------------------------
clear_screen:
    li t0, FB_BASE
    li t1, PIXELS                   # t1 = so diem anh
clear_loop:
    sw zero, 0(t0)                  # To diem anh thanh mau den
    addi t0, t0, 4
    addi t1, t1, -1
    bnez t1, clear_loop
    ret

# ---------------------------------------------------------------------------------------
# plot_pixel: to 1 diem anh bang currentColor. Tu dong cat neu ngoai vung.
# Inputs:   a0 = X, a1 = Y
# ---------------------------------------------------------------------------------------
plot_pixel:
    bltz a0, plot_ret               # Cat clip neu ngoai vung
    bltz a1, plot_ret
    li t0, WIDTH
    bge a0, t0, plot_ret
    li t0, HEIGHT
    bge a1, t0, plot_ret

    li t0, WIDTH                    # Tinh dia chi: offset = (Y*WIDTH + X) * 4
    mul t1, a1, t0
    add t1, t1, a0
    slli t1, t1, 2
    li t2, FB_BASE
    add t2, t2, t1
    la t3, currentColor
    lw t4, 0(t3)                    # Lay mau hien tai
    sw t4, 0(t2)                    # Ghi mau vao framebuffer
plot_ret:
    ret

# ---------------------------------------------------------------------------------------
# get_pixel: lay mau cua diem (X, Y).
# Inputs:   a0 = X, a1 = Y
# Outputs:  a0 = ma mau, a1 = 1 neu hop le, 0 neu ngoai vung
# ---------------------------------------------------------------------------------------
get_pixel:
    bltz a0, get_pixel_fail
    bltz a1, get_pixel_fail
    li t0, WIDTH
    bge a0, t0, get_pixel_fail
    li t0, HEIGHT
    bge a1, t0, get_pixel_fail

    li t0, WIDTH
    mul t1, a1, t0
    add t1, t1, a0
    slli t1, t1, 2
    li t2, FB_BASE
    add t2, t2, t1
    lw a0, 0(t2)                    # Doc mau tu framebuffer
    li a1, 1
    ret
get_pixel_fail:
    li a0, 0
    li a1, 0
    ret

# ---------------------------------------------------------------------------------------
# draw_line: ve doan thang bang thuat toan Bresenham.
# Inputs:   a0 = x1, a1 = y1, a2 = x2, a3 = y2
# ---------------------------------------------------------------------------------------
draw_line:
    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)

    mv s0, a0                       # s0 = x hien tai = x1
    mv s1, a1                       # s1 = y hien tai = y1
    mv s2, a2                       # s2 = x2 (dich)
    mv s3, a3                       # s3 = y2 (dich)

    sub s4, s2, s0                  # s4 = dx = x2 - x1
    li s6, 1                        # s6 = sx = 1 (huong tang x)
    bgez s4, dx_ok
    neg s4, s4                      # dx = |dx|
    li s6, -1                       # sx = -1
dx_ok:
    sub s5, s3, s1                  # s5 = dy = y2 - y1
    li s7, 1                        # s7 = sy = 1 (huong tang y)
    bgez s5, dy_ok
    neg s5, s5                      # dy = |dy|
    li s7, -1                       # sy = -1
dy_ok:
    sub s8, s4, s5                  # s8 = err = dx - dy

line_loop:
    mv a0, s0                       # Ve diem (x, y) hien tai
    mv a1, s1
    jal plot_pixel

    beq s0, s2, line_check_y_end    # x == x2 ?
    j line_not_end
line_check_y_end:
    beq s1, s3, line_done           # va y == y2 -> xong
line_not_end:
    slli t0, s8, 1                  # t0 = 2*err
    neg t1, s5                      # t1 = -dy
    blt t0, t1, line_skip_x         # neu 2*err < -dy thi bo qua buoc x
    sub s8, s8, s5                  # err -= dy
    add s0, s0, s6                  # x += sx
line_skip_x:
    bgt t0, s4, line_skip_y         # neu 2*err > dx thi bo qua buoc y
    add s8, s8, s4                  # err += dx
    add s1, s1, s7                  # y += sy
line_skip_y:
    j line_loop

line_done:
    lw ra, 16(sp)
    lw s0, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 20
    ret

# ---------------------------------------------------------------------------------------
# draw_rectangle: ve vien hinh chu nhat bang 4 doan thang.
# Inputs:   a0 = x1, a1 = y1, a2 = x2, a3 = y2
# ---------------------------------------------------------------------------------------
draw_rectangle:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3

    mv a0, s0                       # Canh tren: (x1,y1)-(x2,y1)
    mv a1, s1
    mv a2, s2
    mv a3, s1
    jal draw_line

    mv a0, s2                       # Canh phai: (x2,y1)-(x2,y2)
    mv a1, s1
    mv a2, s2
    mv a3, s3
    jal draw_line

    mv a0, s2                       # Canh duoi: (x2,y2)-(x1,y2)
    mv a1, s3
    mv a2, s0
    mv a3, s3
    jal draw_line

    mv a0, s0                       # Canh trai: (x1,y2)-(x1,y1)
    mv a1, s3
    mv a2, s0
    mv a3, s1
    jal draw_line

    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    addi sp, sp, 16
    ret

# ---------------------------------------------------------------------------------------
# draw_circle: ve duong tron bang thuat toan midpoint (Bresenham).
# Inputs:   a0 = xc, a1 = yc, a2 = r
# ---------------------------------------------------------------------------------------
draw_circle:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)

    mv s0, a0                       # s0 = xC
    mv s1, a1                       # s1 = yC
    li s2, 0                        # s2 = x (bat dau = 0)
    mv s3, a2                       # s3 = y (bat dau = r)
    slli s4, s3, 1
    li t0, 3
    sub s4, t0, s4                  # s4 = d = 3 - 2r

circle_loop:
    blt s3, s2, circle_done         # Dung khi y < x
    jal circle_plot8                # Ve 8 diem doi xung

    bltz s4, circle_d_negative
    sub t0, s2, s3                  # d >= 0: d += 4*(x - y) + 10 ; y--
    slli t0, t0, 2
    addi t0, t0, 10
    add s4, s4, t0
    addi s3, s3, -1
    j circle_inc_x
circle_d_negative:
    slli t0, s2, 2                  # d < 0: d += 4*x + 6
    addi t0, t0, 6
    add s4, s4, t0
circle_inc_x:
    addi s2, s2, 1                  # x++
    j circle_loop

circle_done:
    lw ra, 8(sp)
    lw s0, 4(sp)
    lw s1, 0(sp)
    addi sp, sp, 12
    ret

# ---------------------------------------------------------------------------------------
# circle_plot8: ve 8 diem doi xung quanh tam (s0, s1) voi offset (s2, s3).
# ---------------------------------------------------------------------------------------
circle_plot8:
    addi sp, sp, -4
    sw ra, 0(sp)

    add a0, s0, s2                  # (xc+x, yc+y)
    add a1, s1, s3
    jal plot_pixel

    sub a0, s0, s2                  # (xc-x, yc+y)
    add a1, s1, s3
    jal plot_pixel

    add a0, s0, s2                  # (xc+x, yc-y)
    sub a1, s1, s3
    jal plot_pixel

    sub a0, s0, s2                  # (xc-x, yc-y)
    sub a1, s1, s3
    jal plot_pixel

    add a0, s0, s3                  # (xc+y, yc+x)
    add a1, s1, s2
    jal plot_pixel

    sub a0, s0, s3                  # (xc-y, yc+x)
    add a1, s1, s2
    jal plot_pixel

    add a0, s0, s3                  # (xc+y, yc-x)
    sub a1, s1, s2
    jal plot_pixel

    sub a0, s0, s3                  # (xc-y, yc-x)
    sub a1, s1, s2
    jal plot_pixel

    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# ---------------------------------------------------------------------------------------
# flood_fill: to mau lan 4 huong tu (x, y), thay vung dang co cung mau voi
#             diem seed. Dung 2 ngan xep tuong minh stackX / stackY.
# Inputs:   a0 = X, a1 = Y
# ---------------------------------------------------------------------------------------
flood_fill:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s0, 4(sp)
    sw s1, 0(sp)

    mv s0, a0                       # s0 = x
    mv s1, a1                       # s1 = y
    mv a0, s0                       # Lay mau diem seed
    mv a1, s1
    jal get_pixel
    beqz a1, fill_done              # Seed ngoai vung -> thoat
    mv s2, a0                       # s2 = mau dich (target) can thay the
    la t0, currentColor
    lw s3, 0(t0)                    # s3 = mau to
    beq s2, s3, fill_done           # Mau to trung mau dich -> khong lam gi

    la s4, stackX
    la s5, stackY
    li s6, 0                        # s6 = so phan tu trong ngan xep

    mv a0, s0                       # To diem seed va day vao ngan xep
    mv a1, s1
    jal plot_pixel
    mv a0, s0
    mv a1, s1
    jal fill_push

fill_loop:
    beqz s6, fill_done              # Ngan xep rong -> xong
    addi s6, s6, -1                 # Pop: lay phan tu dinh ngan xep
    slli t0, s6, 2
    add t1, s4, t0
    lw s0, 0(t1)                    # s0 = x vua pop
    add t2, s5, t0
    lw s1, 0(t2)                    # s1 = y vua pop

    addi a0, s0, 1                  # Lan can phai (x+1, y)
    mv a1, s1
    jal fill_try_neighbor

    addi a0, s0, -1                 # Lan can trai (x-1, y)
    mv a1, s1
    jal fill_try_neighbor

    mv a0, s0                       # Lan can duoi (x, y+1)
    addi a1, s1, 1
    jal fill_try_neighbor

    mv a0, s0                       # Lan can tren (x, y-1)
    addi a1, s1, -1
    jal fill_try_neighbor

    j fill_loop

fill_done:
    lw ra, 8(sp)
    lw s0, 4(sp)
    lw s1, 0(sp)
    addi sp, sp, 12
    ret

# ---------------------------------------------------------------------------------------
# fill_try_neighbor: neu diem (X, Y) co mau bang mau dich (s2) thi to no va
#                    day vao ngan xep.
# Inputs:   a0 = X, a1 = Y
# ---------------------------------------------------------------------------------------
fill_try_neighbor:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw a0, 4(sp)
    sw a1, 0(sp)
    jal get_pixel                   # Lay mau diem lan can
    beqz a1, fill_try_done          # Ngoai vung -> bo qua
    bne a0, s2, fill_try_done       # Khong phai mau dich -> bo qua

    lw a0, 4(sp)                    # To diem
    lw a1, 0(sp)
    jal plot_pixel
    lw a0, 4(sp)                    # Day diem vao ngan xep
    lw a1, 0(sp)
    jal fill_push
fill_try_done:
    lw ra, 8(sp)
    addi sp, sp, 12
    ret

# ---------------------------------------------------------------------------------------
# fill_push: day diem (X, Y) vao 2 ngan xep stackX / stackY.
# Inputs:   a0 = X, a1 = Y
# ---------------------------------------------------------------------------------------
fill_push:
    li t0, PIXELS
    bge s6, t0, fill_push_ret       # Chong tran ngan xep
    slli t1, s6, 2
    add t2, s4, t1
    sw a0, 0(t2)                    # stackX[s6] = X
    add t3, s5, t1
    sw a1, 0(t3)                    # stackY[s6] = Y
    addi s6, s6, 1                  # s6++
fill_push_ret:
    ret
