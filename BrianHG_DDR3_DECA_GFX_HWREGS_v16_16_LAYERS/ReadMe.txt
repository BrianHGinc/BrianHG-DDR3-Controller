//****************************************************************************************************************
//
// Demo documentation.
//
// BrianHG_DDR3_DECA_GFX_HWREGS_v16_16_LAYERS which test runs the BrianHG_DDR3_CONTROLLER_top_v16
// DDR3 controller with the BrianHG_GFX_VGA_Window_System_DDR3_REGS.
// 
// Version 1.60, June 9, 2022.
//
// Written by Brian Guralnick.
// For public use.
// Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
//****************************************************************************************************************

A pre-built DECA compatible programming .sof file : BrianHG_DDR3_DECA_GFX_HWREGS_v16_16_LAYERS.sof should be used for this demo.

This demo requires a PC with a RS232 <-> 3.3v LVTTL converter and the use of my RS232 debugger to live edit window controls.
All necessary files are found in this project's sub-folder 'RS232_debugger'.

Wiring: On DECA PCB, connector P8.  (Assigned at lines 759-761 in BrianHG_DDR3_DECA_top.sv)
    P8-Pin 2 - GND            <-> PC GND
    P8-Pin 4 - GPIO0_D[1] out --> PC LVTTL RXD
    P8-Pin 6 - GPIO0_D[3] in  <-- PC LVTTL TXD

* Optional RS232 debugger project github page: https://github.com/BrianHGinc/Verilog-RS232-Synch-UART-RS232-Debugger-and-PC-host-RS232-Hex-editor


After JTAG programming/running one of the BrianHG_DDR3_DECA_GFX_DEMO_v16_1/2_LAYER/2_500MHzQR.sof ellipse demos, generating a bunch of
ellipses to fill the DDR3 memory with something to show, JTAG program the DECA board with this file:
'BrianHG_DDR3_DECA_GFX_HWREGS_v16_16_LAYERS.sof' found in this directory.

A static 1080p image with interleaved ellipses should now be showing.

Now run the 'RS232_debugger/RS232_Debugger.exe'.
Once in the Debugger editor, press 'CTRL-o' on your keyboard and enter the COM # of your RS232<->TTL converter.

If successfully wired and connected, the COM should recognize the DECA board and open a software limited 1 megabyte buffer.

Next, press 'l' to load a binary file and type:
3layer1080p.bin
Then press [Y].

Immediately the ellipses should de-lace, and slowly the words 'Hello, Hello...' should load in at the top of the display
with a 'slanted ghost' throughout the image.

After load binary file '3layer1080p.bin',
you should see this: (images in the 'RS232_debugger')
'BrianHG_DDR3_DECA_GFX_HWREGS_1.png'

Press 'PageDown' and you should then see this:
'BrianHG_DDR3_DECA_GFX_HWREGS_2.png'

Since parameters 'HWREG_BASE_ADDRESS = 32'h00000100', 'PDI_LAYERS = 4' &
'SDI_LAYERS = 4', the control address count goes like this:

Layer 00 = PDI0, SDI0, = address 0x100 - 0x11F.
Layer 01 = PDI0, SDI1, = address 0x120 - 0x13F.
Layer 02 = PDI0, SDI2, = address 0x140 - 0x15F.
Layer 03 = PDI0, SDI3, = address 0x160 - 0x17F.
Layer 04 = PDI1, SDI0, = address 0x180 - 0x19F.
Layer 05 = PDI1, SDI1, = address 0x1A0 - 0x1BF.
Layer 06 = PDI1, SDI2, = address 0x1C0 - 0x1DF.
Layer 07 = PDI1, SDI3, = address 0x1E0 - 0x1FF.
Layer 08 = PDI2, SDI0, = address 0x200 - 0x21F.
Layer 09 = PDI2, SDI1, = address 0x220 - 0x23F.
Layer 10 = PDI2, SDI2, = address 0x240 - 0x25F.
Layer 11 = PDI2, SDI3, = address 0x260 - 0x27F.
Layer 12 = PDI3, SDI0, = address 0x280 - 0x29F.
Layer 13 = PDI3, SDI1, = address 0x2A0 - 0x2BF.
Layer 14 = PDI3, SDI2, = address 0x2C0 - 0x2DF.
Layer 15 = PDI3, SDI3, = address 0x2E0 - 0x2FF.

See 'BrianHG_GFX_VGA_Window_System.txt', lines 332-384: 'CMD_win_**** connection to HW_REGS'
for which addresses are connected to which CMD_win_xxx controls.

* Note that the SDI layers above 0 are only accessible when the pixel clock divider is above 1.
* See 'BrianHG_GFX_VGA_Window_System.txt', lines 127-197:
* 'Understanding Preset Video modes and what how SDI_LAYERs works.'


Example, to get rid of the 'slanted ghost' image on the screen, Layer 01 has the wrong
'CMD_win_bitmap_width' setting at address 0x186.  Scrolling your mouse over the address
should reveal 4095 on the '16bit Decimal' display below the memory display.

Click on the byte at address 0x186 and use the keypad '+' key to do a 16bit increment
to 4096 correcting the 'slanted ghost' image.  Y9ou may use the keyboard keys or mouse-wheel
to play with the register viewing the results in real-time.  Use a right-click to stop
editing bytes an you may now use the wheel-mouse of keyboard to move the display address.

Read the 'BrianHG_GFX_VGA_Window_System.txt' for all the register controls and you may
also load binary the following demo files for some 32bit graphics with window layer
alpha-blending:

3layer1080p.bin     > current demo.
4layer1080p.bin     > multiple windows of a 32 bit alpha-blended color graphic.
8layer720p.bin      > multiple windows of a 32 bit alpha-blended color graphic.
14layer480p.bin     > multiple windows of a 32 bit alpha-blended color graphic.
