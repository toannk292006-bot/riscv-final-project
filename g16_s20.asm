.eqv WIDTH        256           
.eqv HEIGHT       256           
.eqv PIXELS       65536         
.eqv FB_BASE      0x10010000    

.eqv RCR          0xffff0000    
.eqv RDR          0xffff0004    
.eqv TCR          0xffff0008    
.eqv TDR          0xffff000c    

.data
.align 2                      
framebuffer: .space 262144    
stackX:      .space 262144    
stackY:      .space 262144    
inputbuf:    .space 1024   
currentColor:.word 0x00ffffff 

cmd_line:      .asciz "line"
cmd_rect:      .asciz "rectangle"
cmd_circle:    .asciz "circle"
cmd_color:     .asciz "color"
cmd_fill:      .asciz "fill"
cmd_clear:     .asciz "clear"

msg_banner: .asciz "Mini CAD RISC-V || Nguyen Khanh Toan \n> "
msg_prompt: .asciz "~> "
msg_ok:     .asciz "[SUCCESS]\n> "
msg_err:    .asciz "[ERROR]\n> "

.text
.globl main


main:
    la a0, msg_banner					# In dòng chữ chào mừng (banner)
    jal print_string          

main_loop:
    la a0, inputbuf           			# Đọc chuỗi lệnh người dùng nhập vào inputbuf
    jal read_line              

    la s0, inputbuf           
    
    lbu t0, 0(s0)      					# Kiểm tra chuỗi nhập vào có rỗng không (ký tự null ở byte đầu tiên)        
    beqz t0, print_prompt_and_loop 

    # phân tích lệnh, nếu khớp với lệnh nào thì nhảy tới hàm xử lý tương ứng
    
    mv a0, s0      		# Kiểm tra lệnh "line"            
    la a1, cmd_line           
    jal match_word            
    bnez a0, handle_line      
    mv a0, s0               # Kiểm tra lệnh "rectangle"
    la a1, cmd_rect
    jal match_word
    bnez a0, handle_rect      
    mv a0, s0               # Kiểm tra lệnh "circle"
    la a1, cmd_circle
    jal match_word
    bnez a0, handle_circle    
    mv a0, s0               # Kiểm tra lệnh "color"
    la a1, cmd_color
    jal match_word
    bnez a0, handle_color     
    mv a0, s0               # Kiểm tra lệnh "fill"
    la a1, cmd_fill
    jal match_word
    bnez a0, handle_fill      
    mv a0, s0               # Kiểm tra lệnh "clear"
    la a1, cmd_clear
    jal match_word
    bnez a0, handle_clear     
    
    # Nếu không khớp từ khóa nào, nhảy tới bộ xử lý lỗi
    j print_err_and_loop      

# --- Bộ xử lý hiển thị dấu nhắc & trạng thái phản hồi ---
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
# CÁC BỘ XỬ LÝ LỆNH (Phân tích số nguyên từ chuỗi văn bản và gọi các hàm vẽ hình học)
# =======================================================================================
handle_clear:
    jal clear_screen          
    j print_ok_and_loop       

handle_line:
    addi s1, s0, 4            	# bỏ qua chữ "line" trong chuỗi
    mv a0, s1                  	# phân tích tham số thứ nhất x1
    jal parse_int                	# gọi hàm phân tích
    beqz a2, print_err_and_loop 	# nếu phân tích thất bại: in lỗi cú pháp
    mv s2, a0                  	# s2 = x1
    mv s1, a1                  	# cập nhật con trỏ chuỗi tới ký tự của số nguyên tiếp theo

    mv a0, s1                  	# phân tích tham số thứ hai y1
    jal parse_int              	
    beqz a2, print_err_and_loop
    mv s3, a0                  	# s3 = y1
    mv s1, a1                  	# cập nhật con trỏ chuỗi

    mv a0, s1                  	# phân tích tham số thứ ba x2
    jal parse_int              
    beqz a2, print_err_and_loop 
    mv s4, a0                  	# s4 = x2
    mv s1, a1                  

    mv a0, s1                  	# phân tích tham số thứ tư y2
    jal parse_int              	
    beqz a2, print_err_and_loop 
    mv s5, a0                  	# s5 = y2

    # gọi hàm draw_line(x1, y1, x2, y2)
    mv a0, s2                  
    mv a1, s3                  
    mv a2, s4                  
    mv a3, s5          
    jal draw_line              
    j print_ok_and_loop       

handle_rect:
    addi s1, s0, 9            	# bỏ qua chuỗi "rectangle" trong lệnh
    mv a0, s1                  	# gọi hàm phân tích để lấy x1
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s2, a0                  	# s2 = x1
    mv s1, a1                  

    mv a0, s1                  	# bắt đầu lấy y1
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s3, a0                  	# s3 = y1
    mv s1, a1                  

    mv a0, s1                  	# bắt đầu lấy x2
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s4, a0                  	# s4 = x2
    mv s1, a1                  

    mv a0, s1                  	# bắt đầu lấy y2
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s5, a0                  	# s5  = y2

    # Gọi hàm draw_rectangle(x1, y1, x2, y2)
    mv a0, s2                  
    mv a1, s3                  
    mv a2, s4                  
    mv a3, s5                  
    jal draw_rectangle        
    j print_ok_and_loop       

handle_circle:
    addi s1, s0, 6            	# bỏ qua chuỗi "circle" trong lệnh
    mv a0, s1                  	# gọi hàm phân tích để lấy xC
    jal parse_int              	
    beqz a2, print_err_and_loop
    mv s2, a0                  	# s2 = xC
    mv s1, a1                  

    mv a0, s1                  	# bắt đầu lấy yC
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s3, a0                  	# s3 = yC
    mv s1, a1                  

    mv a0, s1                  	# bắt đầu lấy bán kính (radius)
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s4, a0                  	# s4 = r
    bltz s4, print_err_and_loop # Kiểm tra hợp lệ: bán kính âm

    # Gọi hàm draw_circle(xc, yc, r)
    mv a0, s2                  
    mv a1, s3                  
    mv a2, s4                  
    jal draw_circle            
    j print_ok_and_loop       

handle_color:
    addi s1, s0, 5            	# bỏ qua chuỗi "color" trong lệnh
    mv a0, s1                  	# phân tích số hex cho mã màu
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s2, a0                  	# s2 = mã màu

    # Lưu trạng thái màu toàn cục
    la t0, currentColor        
    sw s2, 0(t0)              	# nạp mã màu
    j print_ok_and_loop     

handle_fill:
    addi s1, s0, 4            	# bỏ qua chuỗi "fill" trong lệnh
    mv a0, s1                  	# gọi hàm phân tích để lấy seed_x
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s2, a0                  	# s2 = seed_x
    mv s1, a1                  

    mv a0, s1                  	# gọi hàm phân tích để lấy seed_y
    jal parse_int              
    beqz a2, print_err_and_loop
    mv s3, a0                  	# s3 = seed_y

    # Gọi hàm flood_fill(seed_x, seed_y)
    mv a0, s2                  
    mv a1, s3                  
    jal flood_fill            
    j print_ok_and_loop       

# =======================================================================================
# CÁC HÀM ĐỒ HỌA LÕI & VÀO/RA (I/O)
# =======================================================================================

# ---------------------------------------------------------------------------------------
# Hàm:      đọc chuỗi lệnh
# Đầu vào:  a0 = Con trỏ địa chỉ đích để ghi các ký tự chuỗi nhập vào
# ---------------------------------------------------------------------------------------
read_line:
    addi sp, sp, -4          
    sw ra, 0(sp)              
    mv s0, a0                  # sao chép s0 = địa chỉ inputbuf
    li s2, 0             	 	# s2 = số ký tự đã nhập (bắt đầu = 0)
read_line_loop:
    jal get_char              # gọi getchar, kết quả trả về trong a0.
    li t0, 13                  # Kiểm tra a0 = '\r'
    beq a0, t0, read_line_end  
    li t0, 10                  # Kiểm tra a0 = '\n'
    beq a0, t0, read_line_end  

    add t3, s0, s2            # t3 = địa_chỉ_gốc + số ký tự đã đếm
    sb a0, 0(t3)              # Đẩy byte ký tự vào inputbuf
    addi s2, s2, 1            # tăng đếm = đếm + 1

    jal put_char              # In lại ký tự ra màn hình (echo)
    j read_line_loop          
read_line_end:
    li a0, 10                  
    jal put_char              # In ký tự '\n'
    add t3, s0, s2            
    sb zero, 0(t3)            # Chèn byte '\0' bắt buộc
    
    lw ra, 0(sp)
    addi sp, sp, 4           
    ret                        

# ---------------------------------------------------------------------------------------
# Mục đích: Thăm dò thanh ghi nhận (receiver register) của bộ điều khiển Bàn phím để lấy ký tự nhập.
# Đầu ra:   a0 = Mã byte ký tự ASCII lấy được từ phần cứng bàn phím
# ---------------------------------------------------------------------------------------
get_char:
    li t0, RCR                
get_char_wait:
    lw t1, 0(t0)              
    andi t1, t1, 1            # Kiểm tra trạng thái bit Ready (sẵn sàng)
    beqz t1, get_char_wait    # Nếu chưa sẵn sàng thì tiếp tục lặp
    li t0, RDR                
    lbu a0, 0(t0)              # Lấy an toàn giá trị byte từ thanh ghi dữ liệu
    ret                        

# ---------------------------------------------------------------------------------------
# Mục đích: Thăm dò trạng thái sẵn sàng của bộ điều khiển Truyền (Transmitter) và in một ký tự.
# Đầu vào:  a0 = Mã byte ký tự ASCII cần in ra màn hình
# ---------------------------------------------------------------------------------------
put_char:
    li t0, TCR                
put_char_wait:
    lw t1, 0(t0)              
    andi t1, t1, 1            # Kiểm tra cờ trạng thái sẵn sàng (ready)
    beqz t1, put_char_wait    
    li t0, TDR                
    sb a0, 0(t0)              # Ghi byte vào thanh ghi xuất ra terminal
    ret                        

# ---------------------------------------------------------------------------------------
# Mục đích: Duyệt một chuỗi kết thúc bằng null và in từng byte ký tự.
# Đầu vào:  a0 = Địa chỉ của chuỗi cần in
# ---------------------------------------------------------------------------------------
print_string:
    addi sp, sp, -8           
    sw ra, 4(sp)              
    sw s0, 0(sp)              
    mv s0, a0                  
print_string_loop:
    lbu a0, 0(s0)              
    beqz a0, print_string_done # In xong nếu gặp '\0'
    jal put_char              
    addi s0, s0, 1            
    j print_string_loop       
print_string_done:
    lw ra, 4(sp)              
    lw s0, 0(sp)              
    addi sp, sp, 8            
    ret                        

# ---------------------------------------------------------------------------------------
# Mục đích: So sánh chuỗi trong buffer lệnh với chuỗi từ khóa chuẩn để kiểm tra trùng khớp.
# Đầu vào:  a0 = Địa chỉ chuỗi thứ nhất, a1 = Địa chỉ chuỗi thứ hai
# Đầu ra:   a0 = Kết quả (1 nếu khớp, 0 nếu không khớp)
# ---------------------------------------------------------------------------------------
match_word:
    mv t0, a0                 # sao chép t0 = Str1
    mv t1, a1                 # sao chép t1 = Str2
match_loop:
    lbu t2, 0(t1)              # nạp t2 = Str2[i]
    lbu t3, 0(t0)              # nạp t3 = Str1[i]
    beqz t2, match_check_delim # Nếu chuỗi từ khóa kết thúc, kiểm tra ký tự phân cách của chuỗi nhập
    bne t2, t3, match_no      # phát hiện ký tự khác nhau: t2 != t3
    addi t0, t0, 1            # cập nhật t0 = t0 + 1
    addi t1, t1, 1            # cập nhật t1 = t1 + 1
    j match_loop              
match_check_delim:             
    beqz t3, match_yes         # Khớp chính xác nếu gặp byte Null kết thúc
    li t4, ' '                
    beq t3, t4, match_yes     # Điều kiện hợp lệ: ký tự phân cách là dấu cách
    j match_no                
match_yes:
    li a0, 1                  
    ret                        
match_no:
    li a0, 0                  
    ret                        

# ---------------------------------------------------------------------------------------
# Mục đích: Chuyển chuỗi ký tự ASCII chữ-số thành số nguyên có dấu hệ thập phân hoặc thập lục phân.
# Đầu vào:  a0 = Địa chỉ chuỗi
# Đầu ra:   a0 = Giá trị số, a1 = Địa chỉ ký tự cuối sau khi phân tích, a2 = Kết quả (1=Thành công, 0=Thất bại)
# ---------------------------------------------------------------------------------------
parse_int:
    addi sp, sp, -4           
    sw ra, 0(sp)              
    addi a0, a0, 1            # Bỏ qua dấu cách ' ' đầu tiên
    mv t0, a0                 # Sao chép t0 = a0: địa chỉ chuỗi (bắt đầu = 0)
    li t1, 0                  # Giá trị số (bắt đầu = 0)
    li t2, 1                  # Dấu của giá trị (mặc định = 1: dương)
    li t6, 0                  # Bộ đếm số chữ số đã phân tích (bắt đầu = 0)

    lbu t3, 0(t0)             # nạp chữ số đầu tiên vào t3
    li t4, '-'                # Kiểm tra xem có phải số âm không
    bne t3, t4, parse_check_hex # Nếu không âm thì nhảy tới kiểm tra giá trị hex
    li t2, -1                 # Đổi dấu thành âm
    addi t0, t0, 1            # tăng địa chỉ t0

parse_check_hex:
    lbu t3, 0(t0)              
    li t4, '0'                
    bne t3, t4, parse_dec_loop 
    lbu t3, 1(t0)              
    li t4, 'x'                
    beq t3, t4, parse_hex_start # Chuyển hướng sang vòng lặp giải mã thập lục phân nếu bắt được cờ '0x'
    j parse_dec_loop          

parse_hex_start:
    addi t0, t0, 2            
parse_hex_loop:
    lbu t3, 0(t0)              
    li t4, '0'                
    blt t3, t4, parse_hex_done 
    li t4, '9'                
    ble t3, t4, parse_hex_digit_num 
    li t4, 'a'                
    blt t3, t4, parse_hex_done     
    li t4, 'f'                
    ble t3, t4, parse_hex_digit_low 
    j parse_hex_done          
parse_hex_digit_num:
    addi t3, t3, -48          
    j parse_hex_add           
parse_hex_digit_low:
    addi t3, t3, -87          
parse_hex_add:
    slli t1, t1, 4            # Dịch giá trị tích lũy sang trái 4 bit (hệ cơ số 16)
    add t1, t1, t3            
    addi t6, t6, 1            
    addi t0, t0, 1            
    j parse_hex_loop          
parse_hex_done:
    beqz t6, parse_fail       
    mul t1, t1, t2            
    mv a0, t1                 
    mv a1, t0                 
    li a2, 1                  
    lw ra, 0(sp)              
    addi sp, sp, 4            
    ret                        

parse_dec_loop:                
    lbu t3, 0(t0)              
    li t4, '0'                # Dừng phân tích nếu ký tự < '0'
    blt t3, t4, parse_dec_done 
    li t4, '9'                # Dừng phân tích nếu ký tự > '9'
    bgt t3, t4, parse_dec_done 
    addi t3, t3, -48          # Lấy giá trị số = MÃ_ASCII - 48
    li t4, 10                 # Tích lũy giá trị: t1 = t1 * 10 + digit
    mul t1, t1, t4            
    add t1, t1, t3            
    addi t6, t6, 1            # tăng bộ đếm: cnt = cnt + 1
    addi t0, t0, 1            # tăng địa chỉ
    j parse_dec_loop          
parse_dec_done:
    beqz t6, parse_fail       # Nếu bộ đếm chữ số = 0 thì không phân tích được chữ số nào
    mul t1, t1, t2            # nhân với dấu
    mv a0, t1                 # trả về kết quả: giá trị số
    mv a1, t0                 # trả về kết quả: địa chỉ ký tự cuối
    li a2, 1                  # đặt kết quả = 1: phân tích thành công
    lw ra, 0(sp)              
    addi sp, sp, 4            
    ret                        
parse_fail:
    li a0, 0                  # trả về giá trị số = 0
    mv a1, t0                 
    li a2, 0                  # đặt kết quả = 0: phân tích thất bại
    lw ra, 0(sp)              
    addi sp, sp, 4            
    ret                        

clear_screen:
    li t0, FB_BASE            
    li t1, PIXELS             # t1 = số lượng điểm ảnh (pixel)
clear_loop:
    sw zero, 0(t0)            # đặt màu của địa chỉ thành màu đen
    addi t0, t0, 4            # tăng địa chỉ
    addi t1, t1, -1           
    bnez t1, clear_loop       
    ret                        

# ---------------------------------------------------------------------------------------
# Mục đích: Vẽ một điểm ảnh vào frame buffer bằng mã màu đang hoạt động.
# Đầu vào:  a0 = X, a1 = Y
# ---------------------------------------------------------------------------------------
plot_pixel:
    # --- Kiểm tra điểm có nằm ngoài biên không ---
    bltz a0, plot_ret         
    bltz a1, plot_ret         
    li t0, WIDTH              
    bge a0, t0, plot_ret      
    li t0, HEIGHT             
    bge a1, t0, plot_ret      
    
    # --- Tính địa chỉ bộ nhớ của điểm ---
    li t0, WIDTH              
    mul t1, a1, t0            # t1 = Y * WIDTH
    add t1, t1, a0            # t1 = (Y * WIDTH) + X
    slli t1, t1, 2            # t1 = Độ lệch tính theo Byte (t1 * 4 Byte mỗi word)
    li t2, FB_BASE            
    add t2, t2, t1            # t2 = Địa chỉ bộ nhớ tuyệt đối
    la t3, currentColor        
    lw t4, 0(t3)              # Nạp màu hiện tại vào t4
    sw t4, 0(t2)              # Đổi màu của điểm thành currentColor
plot_ret:
    ret                        

# ---------------------------------------------------------------------------------------
# Mục đích: Lấy giá trị màu (word) hiện có của điểm (x,y)
# Đầu vào:  a0 = X, a1 = Y
# Đầu ra:   a0 = Mã màu hex, a1 = cờ kết quả (1=Hợp lệ, 0=Ngoài biên)
# ---------------------------------------------------------------------------------------
get_pixel:
    # --- Kiểm tra điểm có nằm ngoài biên không ---
    bltz a0, get_pixel_fail   
    bltz a1, get_pixel_fail   
    li t0, WIDTH              
    bge a0, t0, get_pixel_fail 
    li t0, HEIGHT             
    bge a1, t0, get_pixel_fail 
    
    # --- Tính địa chỉ bộ nhớ của điểm ---
    li t0, WIDTH              
    mul t1, a1, t0            
    add t1, t1, a0            
    slli t1, t1, 2            
    li t2, FB_BASE            
    add t2, t2, t1            
    lw a0, 0(t2)              # Nạp màu từ địa chỉ bộ nhớ
    li a1, 1                  # Đặt cờ thành công: 1
    ret                        
get_pixel_fail:
    li a0, 0                  
    li a1, 0                  # Đặt cờ thất bại: 0
    ret                        

# ---------------------------------------------------------------------------------------
# Đầu vào hàm:   a0 = x1, a1 = y1, a2 = x2, a3 = y2
# ---------------------------------------------------------------------------------------
draw_line:
    addi sp, sp, -20          
    sw ra, 16(sp)
    sw s0, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)

    mv s0, a0               # khởi tạo x hiện tại: s0 = x1   
    mv s1, a1               # khởi tạo y hiện tại: s1 = y1   
    mv s2, a2               # x cuối: s2 = x2   
    mv s3, a3               # y cuối: s3 = y2   

    sub s4, s2, s0            # tính s4 = dx = x2 - x1
    li s6, 1                  # khởi tạo hướng bước s6 = sx = 1
    bgez s4, dx_ok            # dx = |x2 - x1|
    neg s4, s4                
    li s6, -1                 # sx = 1
dx_ok:
    sub s5, s3, s1            # tính s5 = dy = y2 - y1
    li s7, 1                  # khởi tạo hướng bước s7 = sy = 1
    bgez s5, dy_ok            # kiểm tra dy = |y2 - y1|
    neg s5, s5                
    li s7, -1                 # sy = -1
dy_ok:
    sub s8, s4, s5            # khởi tạo biến sai số s8 = err = dx - dy

line_loop:
    mv a0, s0				# gọi hàm plot_pixel(x,y)
    mv a1, s1                  
    jal plot_pixel            

    beq s0, s2, line_check_y_end 	# kiểm tra nếu x hiện tại = x2 (x cuối)
    j line_not_end            
line_check_y_end:
    beq s1, s3, line_done     # kiểm tra nếu y hiện tại = y2 (y cuối)
line_not_end:
    slli t0, s8, 1            # t0 = 2 * sai số
    neg t1, s5                # t1 = -dy
    blt t0, t1, line_skip_x   # Nhảy nếu 2*sai_số >= -dy
    sub s8, s8, s5            # sai số = sai số - dy
    add s0, s0, s6            # x = x + sx
line_skip_x:
    bgt t0, s4, line_skip_y   # Nhảy nếu 2*sai_số <= dx
    add s8, s8, s4            # sai số = sai số + dx
    add s1, s1, s7            # y = y + sy
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
# Đầu vào hàm:   a0 = x1, a1 = y1, a2 = x2, a3 = y2
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

    mv a0, s0         # gọi hàm vẽ cạnh ngang phía trên         
    mv a1, s1                  
    mv a2, s2                  
    mv a3, s1                  
    jal draw_line
    
    mv a0, s2         # gọi hàm vẽ cạnh dọc bên phải          
    mv a1, s1                  
    mv a2, s2                  
    mv a3, s3                  
    jal draw_line     
             
    mv a0, s2         # gọi hàm vẽ cạnh ngang phía dưới           
    mv a1, s3                  
    mv a2, s0                  
    mv a3, s3                  
    jal draw_line              

    mv a0, s0         # gọi hàm vẽ cạnh dọc bên trái         
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
# Đầu vào hàm:   a0 = xc, a1 = yc, a2 = r
# ---------------------------------------------------------------------------------------
draw_circle:
    addi sp, sp, -12             
    sw ra, 8(sp)              
    sw s0, 4(sp)              
    sw s1, 0(sp)              

    mv s0, a0                 # sao chép s0 = xC  
    mv s1, a1                 # sao chép s1 = yC 
    li s2, 0                  # s2 = x hiện tại (bắt đầu ở 0)
    mv s3, a2                 # s3 = y hiện tại (bắt đầu ở bán kính r)
    slli s4, s3, 1            
    li t0, 3                  
    sub s4, t0, s4            # khởi tạo tham số quyết định s4 = d = 3 - 2r)

circle_loop:
    blt s3, s2, circle_done   # Vẽ xong nếu y < x
    jal circle_plot8          # Vẽ cả 8 điểm đối xứng

    bltz s4, circle_d_negative # Nhánh cập nhật quyết định nếu d < 0
    sub t0, s2, s3            
    slli t0, t0, 2            
    addi t0, t0, 10           
    add s4, s4, t0            # Nếu d >= 0: cập nhật d = d + 4*(x - y) + 10
    addi s3, s3, -1           # Giảm: y = y - 1
    j circle_inc_x            
circle_d_negative:
    slli t0, s2, 2            
    addi t0, t0, 6            
    add s4, s4, t0            # Nếu d < 0: cập nhật d = d + 4*x + 6
circle_inc_x:
    addi s2, s2, 1            # Tăng: x = x + 1
    j circle_loop             # quay lại vòng lặp để vẽ điểm mới

circle_done:             
    lw ra, 8(sp)              
    lw s0, 4(sp)              
    lw s1, 0(sp)              
    addi sp, sp, 12           
    ret                        

# ---------------------------------------------------------------------------------------
# Hàm:      circle_plot8
# Mục đích: Hàm phụ trợ vẽ 8 điểm đối xứng theo gương quanh tâm đường tròn (s0, s1).
# ---------------------------------------------------------------------------------------
circle_plot8:
    addi sp, sp, -4           
    sw ra, 0(sp)              
    
    add a0, s0, s2     # Vẽ (xc + x, yc + y)
    add a1, s1, s3
    jal plot_pixel     

    sub a0, s0, s2     # Vẽ (xc - x, yc + y)
    add a1, s1, s3
    jal plot_pixel     

    add a0, s0, s2     # Vẽ (xc + x, yc - y)
    sub a1, s1, s3
    jal plot_pixel     

    sub a0, s0, s2     # Vẽ (xc - x, yc - y)
    sub a1, s1, s3
    jal plot_pixel     

    add a0, s0, s3     # Vẽ (xc + y, yc + x)
    add a1, s1, s2
    jal plot_pixel     

    sub a0, s0, s3     # Vẽ (xc - y, yc + x)
    add a1, s1, s2
    jal plot_pixel     

    add a0, s0, s3     # Vẽ (xc + y, yc - x)
    sub a1, s1, s2
    jal plot_pixel     

    sub a0, s0, s3     # Vẽ (xc - y, yc - x)
    sub a1, s1, s2
    jal plot_pixel     
    
    lw ra, 0(sp)              
    addi sp, sp, 4            
    ret                

# ---------------------------------------------------------------------------------------
# Đầu vào:   a0 = X, a1 = Y
# ---------------------------------------------------------------------------------------
flood_fill:
    addi sp, sp, -12             
    sw ra, 8(sp)              
    sw s0, 4(sp)              
    sw s1, 0(sp)              

    mv s0, a0                  # khởi tạo x hiện tại: s0 = x
    mv s1, a1                  # khởi tạo y hiện tại: s1 = y
    mv a0, s0                  # Gọi hàm get_pixel(x,y)
    mv a1, s1                  
    jal get_pixel              
    beqz a1, fill_done         # Thoát ngay nếu điểm seed nằm ngoài biên
    mv s2, a0                  # s2 = mã màu hex của điểm (x,y)
    la t0, currentColor        
    lw s3, 0(t0)              # s3 = mã màu hex hiện tại
    beq s2, s3, fill_done     # Dừng tô nếu điểm seed có cùng màu với màu hiện tại

    la s4, stackX             
    la s5, stackY              
    li s6, 0                  # s6 = số phần tử trong stack (khởi tạo = 0)

    mv a0, s0                 # Gọi plot_pixel(x,y)
    mv a1, s1                  
    jal plot_pixel            
    mv a0, s0                  # Gọi hàm để đẩy điểm seed vào stack
    mv a1, s1                  
    jal fill_push              

fill_loop:
    beqz s6, fill_done         # Thoát vòng lặp nếu stack rỗng (s6 == 0)
    addi s6, s6, -1            # Thực hiện thao tác Pop khỏi stack
    slli t0, s6, 2             # Tính địa chỉ bộ nhớ của phần tử cuối trong stack
    add t1, s4, t0            
    lw s0, 0(t1)              #  s0 = x được pop ra
    add t2, s5, t0            
    lw s1, 0(t2)              # s1 = y được pop ra
    
    # Kiểm tra điểm bên Phải: (x + 1, y)
    addi a0, s0, 1
    mv a1, s1
    jal fill_try_neighbor   

    # Kiểm tra điểm bên Trái:  (x - 1, y)
    addi a0, s0, -1
    mv a1, s1
    jal fill_try_neighbor  

    # Kiểm tra điểm bên Dưới: (x, y + 1)
    mv a0, s0
    addi a1, s1, 1
    jal fill_try_neighbor   

    # Kiểm tra điểm bên Trên:    (x, y - 1)
    mv a0, s0
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
# Mục đích: Kiểm tra một điểm ảnh lân cận. Nếu nó trùng với màu nền đích thì tô màu cho nó và đẩy vào stack xử lý.
# Đầu vào:  a0 = X, a1 = Y
# ---------------------------------------------------------------------------------------
fill_try_neighbor:
    addi sp, sp, -12          
    sw ra, 8(sp)              
    sw a0, 4(sp)              
    sw a1, 0(sp)              
    jal get_pixel             # lấy màu của điểm ảnh
    beqz a1, fill_try_done    # Bỏ qua nếu điểm ảnh nằm ngoài biên
    bne a0, s2, fill_try_done # Bỏ qua nếu màu điểm ảnh không trùng với màu nền
    
    # tô màu cho điểm ảnh
    lw a0, 4(sp)              
    lw a1, 0(sp)              
    jal plot_pixel            
    lw a0, 4(sp)              
    lw a1, 0(sp)              
    jal fill_push              # đẩy điểm vào stack
fill_try_done:
    lw ra, 8(sp)             
    addi sp, sp, 12           
    ret                        

# ---------------------------------------------------------------------------------------
# Mục đích: Đẩy một điểm (X, Y) vào các mảng stack.
# Đầu vào:  a0 = X, a1 = Y
# ---------------------------------------------------------------------------------------
fill_push:
    li t0, PIXELS             
    bge s6, t0, fill_push_ret # Ngăn tràn bộ đệm mảng nếu kích thước stack vượt quá số PIXELS tối đa của màn hình
    slli t1, s6, 2            # Nhân chỉ số theo dõi * 4 để tính độ lệch con trỏ theo word
    add t2, s4, t1            
    sw a0, 0(t2)              # Ghi tọa độ vào: stackX[s6] = X
    add t3, s5, t1            
    sw a1, 0(t3)              # Ghi tọa độ vào: stackY[s6] = Y
    addi s6, s6, 1            # Tăng chỉ số con trỏ stack (s6++)
fill_push_ret:
    ret