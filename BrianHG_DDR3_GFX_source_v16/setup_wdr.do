transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_GFX_Sync_Gen.sv}
vlog -sv -work work {BrianHG_GFX_Window_DDR3_Reader.sv}
vlog -sv -work work {BrianHG_GFX_Window_DDR3_Reader_tb.sv}
vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc" BrianHG_GFX_Window_DDR3_Reader_tb

restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

# add wave /BrianHG_GFX_Window_DDR3_Reader_tb/*


add wave -divider     "Settings"
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_h_res 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_h_total 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_hs_front_porch 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_hs_size 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_hs_polarity 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_v_res 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_v_total 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_vs_front_porch 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_vs_size 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VID_vs_polarity 

add wave -divider     "CLK/RST"
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/reset
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/CLK_DIVIDE_IN
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/CLK_IN

add wave -divider     "SG Output"
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/CLK_PHASE_OUT
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/h_count_out
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/H_ena
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/V_ena
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/Video_ena
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/HS_out
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/VS_out
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_SG/v_count_out

add wave -divider     "Win GFX Setup"
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_bpp          
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_base_addr    
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_bitmap_width 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_bitmap_x_pos 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_bitmap_y_pos 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_x_offset     
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_y_offset     
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_x_size       
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_y_size       
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_scale_width  
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_scale_height 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_scale_h_begin
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_scale_v_begin

add wave -divider     "Win Tile Setup"
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_tile_enable
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_tile_base
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_tile_bpp
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_tile_height
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_win_tile_width

add wave -divider     "Line Buffer Stat"
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/lb_stat_vena 
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/lb_stat_hrst 
add wave -hexadecimal {BrianHG_GFX_Window_DDR3_Reader_tb/lb_stat_qinc[0]}

add wave -divider     "Win DDR3 CMD"
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_busy 
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_ena 
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_addr 
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_read_vector_tx 

add wave -divider     "Win Geometry"
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/rast_vpos
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_y_begin
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_y_end
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_height_cnt
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_ena
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_y_pos 
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_v_scale
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_t_y_pos
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_read_addr 

add wave -divider     "Win DDR3 Internals"
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/MAX_BURST 
add wave -decimal     BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/lb_free_space
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/lb_x_offset
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/CMD_vid_tile_x_begin
add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_read_len 

add wave -unsigned    BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/SEQ
add wave -decimal     BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/win_read_remain
add wave -hexadecimal BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/lb_write_pos_WIN
add wave -decimal     BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/burst_limiter
add wave -decimal     BrianHG_GFX_Window_DDR3_Reader_tb/DUT_WDR/SEQb 


do run_wdr.do
