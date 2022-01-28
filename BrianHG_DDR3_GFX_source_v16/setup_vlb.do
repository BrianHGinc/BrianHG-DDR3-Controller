transcript on
if {[file exists work]} {
	vdel -lib work -all
}
vlib work
vmap work work
vlog -sv -work work {BrianHG_GFX_Sync_Gen.sv}
vlog -sv -work work {BrianHG_GFX_Video_Line_Buffer.sv}
vlog -sv -work work {BrianHG_GFX_Video_Line_Buffer_tb.sv}
vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L work -voptargs="+acc" BrianHG_GFX_Video_Line_Buffer_tb

restart -force -nowave
# This line shows only the varible name instead of the full path and which module it was in
config wave -signalnamewidth 1

# add wave /BrianHG_GFX_Video_Line_Buffer_tb/*


add wave -divider     "Settings"
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_h_res 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_h_total 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_hs_front_porch 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_hs_size 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_hs_polarity 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_v_res 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_v_total 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_vs_front_porch 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_vs_size 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VID_vs_polarity 

add wave -divider     "CLK/RST"
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/reset
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/CLK_DIVIDE_IN
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/CLK_IN

add wave -divider     "SyncGen Output"
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/CLK_PHASE_OUT
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/h_count_out
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/H_ena
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/V_ena
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/HS_out
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/VS_out
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_SG/v_count_out

add wave -divider     "LineBuf W-Pal/Tile"
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_pal_wena 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_pal_waddr 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_pal_wdata 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_pal_wmask 

add wave -divider     "LineBuf W-Line"
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_LBID 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_lbuf_wena 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_lbuf_waddr 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_lbuf_wdata 

add wave -divider     "LineBuf Tile"
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_tile_base 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_tile_bpp 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_tile_height 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_tile_width 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_tile_y_begin 

add wave -divider     "LineBuf Window"
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_bpp 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_h_offset 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_h_width 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_pixel_width 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_width_begin 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/CMD_vid_x_buf_begin 

add wave -divider     "LineBuf SyncIn"
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/VID_RST 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/VID_CLK 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/VCLK_PHASE_IN 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/hc_in 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/H_ena_in 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/V_ena_in 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/VID_RST_logic 

add wave -divider     "LineBuf out"
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.t_base   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.t_ena   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.bpp    
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.phase  
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.vena   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.hc     
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.hena   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.lena   
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.data   
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.c_add  
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.c_bgc  
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.c_index
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.x_index
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/genblk2/lbo_dly.y_index

add wave -divider     "Tile out"
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_base   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_tena   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_bpp    
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_phase  
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_vena   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_hc     
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_hena   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_lena   
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_data   
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_c_add  
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_c_bgc  
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_c_index
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_x_index
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/tile_out_y_index

add wave -divider     "Palette out"
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/pal_out_bpp 
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/pal_out_phase
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/pal_out_vena
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/pal_out_hc  
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/pal_out_hena
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/pal_out_lena
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/pal_out_data

add wave -divider     "LineBuf SyncThru"
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/VENA
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/WLENA
add wave -unsigned    BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/RGBA
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/HS_in 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/HS_out 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/VS_in 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/VS_out 

add wave -divider     "LineBuf Stat"
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/lb_stat_vena 
add wave -hexadecimal BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/lb_stat_hrst 
add wave -hexadecimal {BrianHG_GFX_Video_Line_Buffer_tb/DUT_LB/lb_stat_qinc[0]} 

do run_vlb.do

