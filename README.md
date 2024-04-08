# BrianHG-DDR3-Controller
-----------------------------------------------------
BrianHG_DDR3_Controller V1.65 Release, April 8, 2024.
-----------------------------------------------------
New: Added PLL support for Arria V GX, GT, SX, ST, GZ.

Also added a $stop & $error message if the FPGA_FAMILY is Unknown.

Also added Arria V and Cyclone V PLL frequencies to 1Ghz / 2gtps.

-----------------------------------------------------
BrianHG_DDR3_Controller V1.6 Release, June 11, 2022.
Includes new BrianHG_GFX_VGA_Window_System.
-----------------------------------------------------

Folder BrianHG_DDR3 now contains the new v1.6 controller.
Main source files:

 - BrianHG_DDR3_v15_and_v16_Block_Diagram.png -> Illustration of module connections.

 - Includes these following sub-modules :
   - BrianHG_DDR3_CONTROLLER_v16_top.sv     -> v1.6 TOP entry to the complete project which wires the DDR3_COMMANDER_v16 to the DDR3_PHY_SEQ giving you access to all the read/write ports + access to the DDR3 IO pins.
   - BrianHG_DDR3_COMMANDER_v16.sv          -> v1.6 High FMAX speed multi-port read and write requests and cache, commands the BrianHG_DDR3_PHY_SEQ.sv sequencer.
   - BrianHG_DDR3_CMD_SEQUENCER_v16.sv      -> v1.6 Takes in the read and write requests, generates a stream of DDR3 commands to execute the read and writes.
   - BrianHG_DDR3_PHY_SEQ_v16.sv            -> v1.6 DDR3 PHY sequencer.          (If you want just a compact DDR3 controller, skip the DDR3_CONTROLLER_top & DDR3_COMMANDER and just use this module alone.)
   - BrianHG_DDR3_PLL.sv                    -> Generates the system clocks. (*** Currently Altera/Intel only ***)
   - BrianHG_DDR3_GEN_tCK.sv                -> Generates all the tCK count clock cycles for the DDR3_PHY_SEQ so that the DDR3 clock cycle requirements are met.
   - BrianHG_DDR3_FIFOs.sv                  -> Serial shifting logic FIFOs.

 - Includes the following test-benches :
   - BrianHG_DDR3_CONTROLLER_v16_top_tb.sv  -> Test the entire 'BrianHG_DDR3_CONTROLLER_v16_top.sv' system with Mircon's DDR3 Verilog model.
   - BrianHG_DDR3_COMMANDER_v16_tb.sv       -> Test just the commander_v16.  The 'DDR3_PHY_SEQ' is dummy simulated.  (*** This one will simulate on any vendor's ModelSim ***)
   - BrianHG_DDR3_CMD_SEQUENCER_v16_tb.sv   -> Test just the DDR3 command sequencer.                                 (*** This one will simulate on any vendor's ModelSim ***)
   - BrianHG_DDR3_PHY_SEQ_v16_tb.sv         -> Test just the DDR3 PHY sequencer with Mircon's DDR3 Verilog model providing logged DDR3 command results with any access violations listed.
   - BrianHG_DDR3_PLL_tb.sv                 -> Test just the PLL module.

 - IO port vendor specific modules :
   - BrianHG_DDR3_IO_PORT_ALTERA.sv         -> Physical DDR IO pin driver specifically for Altera/Intel Cyclone III/IV/V and MAX10.

 - Modelsim 'do' script files.
   - All setup_xxx.do files setup their associated Modelsim simulation.
   - All run_xxx.do   files quick re-compile and run their associated Modelsim simulation.


Folder 'BrianHG_DDR3_GFX_source_v16' contains my new BrianHG_GFX_VGA_Window_System multi-window system.
Main source files:

 - BrianHG_GFX_VGA_Window_System.pdf          -> Visual block diagram for the graphics system and layer-swapping illustration.
 - BrianHG_GFX_VGA_Window_System.txt          -> Full documentation for the VGA window system.

 - Includes these top hierarchy files:
   - BrianHG_GFX_VGA_Window_System.sv           -> Full window system where you drive the CMD_win_xxx controls via input ports.
   - BrianHG_GFX_VGA_Window_System_DDR3_REGS.sv -> Full window system where you drive the CMD_win_xxx controls via writing to DDR3 memory addresses through any multiport.

 - Modelsim 'do' script files.
   - All setup_xxx.do files setup their associated Modelsim simulation.
   - All run_xxx.do   files quick re-compile and run their associated Modelsim simulation.


New Arrow DECA board demo complete projects running the v1.6 BrianHG_DDR3_Controller conected to
the BrianHG_GFX_VGA_Window_System, all at 400MHz, all 100% timing requirements met.
Source folders:

 - BrianHG_DDR3_DECA_GFX_DEMO_v16_1_LAYER     -> Replaces the original ellipse demo, but now uses my new BrianHG_GFX_VGA_Window_System.
 - BrianHG_DDR3_DECA_GFX_DEMO_v16_2_LAYERS    -> Improved ellipse demo using 2 translucent windows scrolling at different speeds.
 - BrianHG_DDR3_DECA_GFX_HWREGS_v16_16_LAYERS -> Example 16 window layer system where writes to the DDR3 controls the window's regs.
 - BrianHG_DDR3_DECA_RS232_DEBUG_TEST_v16     -> Single port DDR3 controller example connected to my RS232 debugger.
 - BrianHG_DDR3_DECA_PHY_SEQ_only_v16         -> (No multiport controller.) Bare minimum DDR3 PHY_SEQ controller connected to my RS232 debugger.

Test hypothetical builds for Cyclone III,IV,V to see if we can meet FMAX.
 - BrianHG_DDR3_CIII_GFX_TEST_v16_1_LAYER_Q13.0sp1  -> Cyclone III example using Quartus 13.0 sp1.
 - BrianHG_DDR3_CIV_GFX_TEST_v16_1_LAYER            -> Cyclone IV example using Quartus 20.1.
 - BrianHG_DDR3_CV_GFX_TEST_v16_1_LAYER_350MHz      -> Cyclone V example running only at 350MHz using Quartus 20.1.


- Get new 2 window layer ellipse demo here:
https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/msg4230856/#msg4230856
or here: https://github.com/BrianHGinc/BrianHG-DDR3-Controller/blob/main/BrianHG_DDR3_DECA_GFX_DEMOS_v16.zip

- Get new VGA video system demo configured for up to 16 window layers driven by my RS232_Debugger here:
https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/msg4233016/#msg4233016
or here: https://github.com/BrianHGinc/BrianHG-DDR3-Controller/blob/main/BrianHG_DDR3_DECA_GFX_HWREGS_v16_16_LAYERS_test.zip
source here: https://github.com/BrianHGinc/BrianHG-DDR3-Controller/tree/main/BrianHG_DDR3_DECA_GFX_HWREGS_v16_16_LAYERS

- User 'davemuscle' created an Avalon interface wrapper comparing my DDR3 PHY_SEQ_only free controller to Altera's expensive UniPHY IP, see here:
https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/msg4108963/#msg4108963
(Note that both controllers should have achieve double the bandwidth and my 'BrianHG_DDR3_DECA_GFX_DEMO_v16_2_LAYERS' demo already runs at double the efficiency.)

- User 'Nockieboy' has been working on integrating my controller with his Z80 8-bit GPU project, see his first multi-layer-window test here:
https://www.eevblog.com/forum/fpga/fpga-vga-controller-for-8-bit-computer/msg3980567/#msg3980567
and color font/tile mode test:
https://www.eevblog.com/forum/fpga/fpga-vga-controller-for-8-bit-computer/msg4029019/#msg4029019

- You can find all my older versions of my DDR3 Controller system and demos in a new branch called 'pre_v16'.

Enjoy the absurd number of lines of code to make all of this possible in a user configurable way!

--------------------------------------
BrianHG_DDR3_Controller V1.6 Preview
January 28, 2022
--------------------------------------
Here is a preview of my new 64 window layer DDR3 VGA graphics system See the 2 page block diagram:

https://github.com/BrianHGinc/BrianHG-DDR3-Controller/blob/main/BrianHG_DDR3_GFX_source_v16/BrianHG_GFX_VGA_Window_System.pdf block diagram and:

https://github.com/BrianHGinc/BrianHG-DDR3-Controller/blob/main/BrianHG_DDR3_GFX_source_v16/BrianHG_GFX_VGA_Window_System.txt documentation for developers.


Features:
- Up to 64 window layers, with alpha blend transparency from layer-to-layer.
- In system real-time video mode switching support.
- A huge set of configurable parameters able to address up to 4gb of DDR3 ram with bitmap sizes of up to 65536x65536 pixels.
- Supports 32/16a/16b/8/4/2/1 bpp windows.
- Supports accelerated Fonts/Tiles stored in dedicated M9K blockram with resolutions of 4/8/16/32 X 4/8/16/32 pixels.
- Supports up to 1k addressable tiles/characters with 32/16a/16b/8/4/2/1 bpp, with mirror and flip.
- Each window has a base address, X&Y screen position & H&V sizes up to 65kx65k pixels.
- Independent bpp depth for each window.
- Optional independent or shared 256 color 32 bit RGBA palettes for each window.
- In tile mode, each tile/character's output with 8 bpp and below can be individually assigned to different portions of the palette.
- Multilayer 8 bit alpha stencil translucency between layers with programmable global override.
- Quick layer swap-able registers.
- Hardware individual integer X&Y scaling where each window output can be scaled 1x through 16x.

A full demo of my new BrianHG_DDR3_CONTROLLER_v16 containing the multi-window VGA system demo should be uploaded in a few days.


# BrianHG-DDR3-Controller
--------------------------------------
BrianHG_DDR3_Controller V1.5
December 3, 2021
--------------------------------------
A maddening over 11K lines of code....
--------------------------------------

See image: [https://github.com/BrianHGinc/BrianHG-DDR3-Controller/blob/main/BrianHG_DDR3_v15_Block_Diagram.png](https://github.com/BrianHGinc/BrianHG-DDR3-Controller/blob/main/BrianHG_DDR3_v15_and_v16_Block_Diagram.png) for a simplified block diagram of the BrianHG_DDR3_Controller_v15 controller system.

Note that the original v1.0 source files still exist, still function, and are backwards compatible, but understand that all the source files have been updated.  This includes the new .sdc files in the new demo projects.

In-depth instructions are located in the full v1.0 text release notes as well as all the parameters and ports are well documented within the source code and examples.

Written by Brian Guralnick. For public use. Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/

-------------------------------------------------------------------------------------------
These are the new main source file which operate according to the simplified block diagram:

New Version 1.5 source files:
--------------------------

BrianHG_DDR3_COMMANDER_v15.sv
- All 16 user multiports are now read and write ports instead of a separate 16 read ports and 16 write ports.
- Radically improved FMAX where a full 16 ports should achieve at least 150Mhz on a -6 Cyclone III/IV and MAX10.
- Sadly, Cyclone V-6 should achieve at least ~92MHz where it used to be only 75MHz with just 2 ports.

BrianHG_DDR3_CONTROLLER_v15_top.sv
- Uses the new commander v15.
- Has a 'TAP' port which is a copy of all the writes being sent to the DDR3.


New Version 1.5 example/demo projects (Arrow DECA board compatible):
--------------------------
BrianHG_DDR3_DECA_RS232_DEBUG_TEST_v15_300MHz_QR
- Functional on Arrow DECA board, an entry level example 300MHz DDR3, 1/4 rate multiport with RS232 debugger interface.
- Improved .sdc file for better DDR3 timing margins.

BrianHG_DDR3_DECA_Show_1080p_v15_375Mhz_HR
- Functional on Arrow DECA board 375MHz DDR3, 1/2 rate multiport example 1080p HDMI video out with RS232 debugger interface.
- Improved .sdc file for better DDR3 timing margins.

BrianHG_DDR3_DECA_Show_1080p_v15_400MHz_QR
- Functional on Arrow DECA board 400MHz DDR3, 1/4 rate multiport example 1080p HDMI video out with RS232 debugger interface.
- Improved .sdc file for better DDR3 timing margins.

BrianHG_DDR3_DECA_GFX_DEMO_v15_300MHz_HR
- Functional on Arrow DECA board 300MHz DDR3, 1/2 rate multiport example 1080p HDMI video out with RS232 debugger interface.
- Geometry random ellipse & noise generator demo, see: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/msg3785711/#msg3785711  for instructions.
- Improved .sdc file for better DDR3 timing margins.

BrianHG_DDR3_DECA_GFX_DEMO_v15_400MHz_QR
- Functional on Arrow DECA board 400MHz DDR3, 1/4 rate multiport example 1080p HDMI video out with RS232 debugger interface.
- Geometry random ellipse & noise generator demo, see: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/msg3785711/#msg3785711  for instructions.
- Improved .sdc file for better DDR3 timing margins.

BrianHG_DDR3_CV_GFX_FMAX_Test_v15_350MHz_QR
- Hypothetical Cyclone V FMAX compile test of the random ellipse & noise generator demo.  Note that in v1.0, Cyclone V could barely achieve 300MHz 1/4 rate multiport with 3 ports running the geometry random ellipse & noise generator demo.  v1.5 can now achieve 350MHz with more ports and some head-room to spare.
- Improved .sdc file for better DDR3 timing margins.


Note that Cyclone III/IV FMAX tests were not done since in v1.0, they actually perform slightly better than the MAX10 demos.

New Version 1.5 Modelsim Testbench source files and setup script files:
--------------------------
Version 1.5 test-bench, multiport commander:
- BrianHG_DDR3_COMMANDER_v15_tb.sv
- setup_com_v15.do   -Modelsim setup sim script file.
- run_com_v15.do     -Modelsim re-compile & run script file

Version 1.5 test-bench, complete ram controller system:
- BrianHG_DDR3_CONTROLLER_v15_top_tb.sv
- setup_top_v15.do   -Modelsim setup sim script file.
- run_top_v15.do     -Modelsim re-compile & run script file


Minor issues to fix / things to do for upcoming releases.
---------------------------------------------------------
1. For the 1080p output, remove the DECAs example video sync generator and write my own proper one which will allow a few real-time video mode selection.
2. Fix a bug with my raster generator which currently only functions properly in 1080p 32bit color, offering proper support for 1/2/4/8/16/32bit color modes.
3. Shrink the video line buffer to the minimal M9K block size allowed with a 128bit memory buss interface.
4. Add a palette support for lower depth video modes.
5. Add a hardware multi-layer-superimposed window system framework.


Next major release v2.0 targets.
---------------------------------
1. Improve FMAX abilities to guarantee 400MHz FMAX half-rate capabilities.
2. Begin Lattice port.

---------------------------------
Nov 1, 20201

Demo preview v1.5 DECA eval board .sof programming file:
---------------------------------

- Multiport interface can now officially reach 200 MHz in half rate mode and potentially be overclocked to 250MHz.
See my Arrow DECA BrianHG_DDR3_Controller V1.5 overclocked to 500MHz in Half-rate mode.

Download file: BrianHG_DDR3_DECA_DDR3_v1.5_GFX_DEMO.zip  -  Don't forget to read the readme file...

Here : https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/msg3785711/#msg3785711

---------------------------------
August 27, 2021

# V1.0
A SystemVerilog DDR3 Controller, 16 read, 16 write ports, configurable widths, priority, auto-burst size & smart cache for each port. Fully documented source code. TestBenches included running with Micron's DDR3 Verilog model to prove error free command functionality. 

Fully functional hardware tested on Arrow's DECA 37$ MAX10 developement board with a 512mb DDR3 ram chip generating a 1080p 32bit color HDMI video output with a random 2D ellipse geometry drawing graphics engine.

True 400MHz/800MTPS support for Altera/Intel Cyclone/Max speed grade -6, 300MHz for -8. -8 can be overclockded to 400MHz. (-6 can run at 500MHz/1GTPS is unofficial but functional on Arrow's DECA board using 1x 16bit DDR3 ram chip)

BrianHG_DDR3_README_V1.00.txt Status/Revision Log, Instructions.
August 27, 2021.

Written by Brian Guralnick.
For public use.
Leave questions in the https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/

Designed for Altera/Intel Quartus Cyclone III/IV/V/10/MAX10 and others.
 - Lattice ECP5/LFE5U series.  (Coming soon)
 - Xilinx Artix 7 series.      (Coming soon)

 - DECA projects eval board here: https://www.arrow.com/en/products/deca/arrow-development-tools
 - EEVBlog DECA guide here: https://www.eevblog.com/forum/fpga/arrow-deca-max-10-board-for-$37/
 - EEVBlog DECA 1080p out demo .sof file here: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/msg3630084/#msg3630084

*************************************************************
*** Release V1.00, August 27, 2021 **************************
*** Tested on Quartus Prime 20.1   **************************
*************************************************************

------------------------------------------
Featured full Quartus Prime 20.1 projects:  (Except for 'BrianHG_DDR3_CIII_GFX_FMAX_Test_Q13.0sp1')
------------------------------------------

 - BrianHG_DDR3_DECA_GFX_DEMO                 400MHz, functional DDR3 System scrolling ellipse with optional RS232 debug port demo for Arrow DECA eval board.
 - BrianHG_DDR3_DECA_Show_1080p               400MHz, functional DDR3 System 1080p 32bit display with optional RS232 debug port demo for Arrow DECA eval board.
 - BrianHG_DDR3_DECA_RS232_DEBUG_TEST         400MHz, functional DDR3 System RS232 debug port demo for Arrow DECA eval board.
 - BrianHG_DDR3_DECA_only_PHY_SEQ             400MHz, functional DDR3 PHY Only controller with RS232 debug port demo for Arrow DECA eval board.
 - BrianHG_DDR3_CIV_GFX_FMAX_Test             400MHz, Hypothetical Cyclone IV DDR3 System scrolling ellipse build to verify FMAX.
 - BrianHG_DDR3_CIII_GFX_FMAX_Test_Q13.0sp1   400MHz, Hypothetical Cyclone III DDR3 System scrolling ellipse build to verify FMAX.  (Uses Quartus 13.0sp1)
 - BrianHG_DDR3_CV_GFX_FMAX_Fail              400MHz, Hypothetical Cyclone V-6 DDR3 System scrolling ellipse build to verify FMAX.  (FMAX FAILED)
 - BrianHG_DDR3_CV_GFX_FMAX_Test              300MHz, Hypothetical Cyclone V-6 DDR3 System scrolling ellipse build to verify FMAX.  (PASSED, but with features disabled)
 - BrianHG_DDR3_CV_PHY_ONLY_FMAX_Test         375MHz, Hypothetical Cyclone V-6 DDR3 PHY Only controller with RS232 debug port build to verify FMAX. (375MHz only, no multiport)


------------------------------------------
Source Folders:
------------------------------------------
 - BrianHG_DDR3                               Source code for BrianHG_DDR3 controller.
 - BrianHG_DDR3_GFX_source                    Source code for rendering random ellipses with a scrolling screen.


------------------------------------------
Screenshots folder:
------------------------------------------
 - LC-LUT_screenshots/                        Contains tables of the compiled LC&LUT usage for various clock frequency and feature builds.
 - FMAX_screenshots/                          Contains FMAX timing analyzer results screenshots of various FPGA builds.


Check here for compiled FMAX & LC/LUT usage stats:

https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/msg3649318/#msg3649318



As a reference, use the ***PHY_ONLY*** projects to see how to wire the stand alone DDR3 controller with a single read-write port.
All the other project folders contain the full configurable multi-port controller examples.

Note that currently, the full multi-port 'COMMANDER' controller has a FMAX limit of around 125MHz on -6 Cyclones.  This means for those who want to use the full multiport, you will be running the 'INTERFACE_SPEED' in 'Quarter' speed mode.

Parameter 'INTERFACE_SPEED'
Quarter  Means that the system interface CMD_CLK, will be tied to DDR3_CLK_25 and will be running at 25% the DDR3_CLK.  So with a 400MHz DDR3 clock, the CMD_CLK will be running at 100MHz.
Half     Means that the system interface CMD_CLK, will be tied to DDR3_CLK_50 and will be running at 50% the DDR3_CLK.  So with a 400MHz DDR3 clock, the CMD_CLK will be running at 200MHz.


Additional notes when using the ***PHY_ONLY*** projects:
The interface speed of the 'BrianHG_DDR3_PHY_SEQ.sv' is locked onto 'DDR3_CLK_50' regardless of the 'INTERFACE_SPEED' parameter's setting.
The 'BrianHG_DDR3_PHY_SEQ.sv' has 2 methods of interfacing.

a) Parameter 'USE_TOGGLE_CONTROLS = 1'.  With this setting, the 'SEQ_CMD_ENA_t' input, and 'SEQ_BUSY_t' / 'SEQ_RDATA_RDY_t' outputs are toggles.  This the module will accept a command each time you toggle the 'SEQ_CMD_ENA_t' input.  This means you can clock your logic at the Full/Half/or/Quarter speed.  Read the source code for directions.

b) Parameter 'USE_TOGGLE_CONTROLS = 0'.  With this setting, the 'SEQ_CMD_ENA_t' input, and 'SEQ_BUSY_t' / 'SEQ_RDATA_RDY_t' outputs are changed to active high signals running on the 'DDR3_CLK_50' clock.  This means the module will accept a command every 'DDR3_CLK_50' clock cycle while the 'SEQ_CMD_ENA_t' is high/true.


---------------------------------------------------------
Changes since v0.95:
(See full revision history at the end of this document)
---------------------------------------------------------

400MHz FMAX consistency has improved.

Added these new system parameters to allow you to shrink LC/LUT count for simpler or slower designs:

parameter bit        BHG_OPTIMIZE_SPEED      = 1,                // Use '1' for better FMAX performance, this will increase logic cell usage in the BrianHG_DDR3_PHY_SEQ module.
                                                                 // It is recommended that you use '1' when running slowest -8 Altera fabric FPGA above 300MHz or Altera -6 fabric above 350MHz.
                                                                 
parameter bit        BHG_EXTRA_SPEED         = 1,                // Use '1' for even better FMAX performance or when overclocking the core.  This will increase logic cell usage.


Changes 'DDR3_WDQ_PHASE' parameter from 90 degree to 270 degree which helps improve FMAX:

parameter int        DDR3_WDQ_PHASE          = 270,              // 270, Select the write and write DQS output clock phase relative to the DDR3_CLK/CK#



BrianHG_DDR3_PLL.sv Version 1.2, August 26, 2021:
     Added support for Cyclone V / Arria V / Stratix V style PLL support.


------------------------------------
How to achieve the full 400MHz FMAX
------------------------------------
Note that the Cyclone devices are a fairly slow fabric.  If the fitter makes 1 crucial mistake, the 400MHz can be severly crippled.

Looking at example screenshot:
FMAX_screenshots/Example_400MHz_lemmon_333MHz_timing.png

You can see that only 1 red signal on the WDQ clock has miserably failed with a slack of -0.497ns (333MHz) compared to the next route which is well withing the clear.
What happened here is the fitter began with a lemon starting position.  For this type of issue where only 1-5 routes are unable to clear the required slack, adjust this compiler setting:

Compiler Settings / Advanced Settings (Fitter) / Fitter Initial Placement Seed

Choose an integer of 1 and up.

For more severe timing issues, on the compiler settings page, choose between:
Area
Balanced
Performance (High Effort...)

Do not choose 'Performance (Aggressive...)' as this setting rarely improves things with the BrianHG_DDR3_Controller and just wastes gates.

Additional setting which will affect FMAX are:

Compiler Settings / Advanced Settings (Synthesis) / Pre-Mapping Resynthesis Optimization
Turning this feature on really helps with complex designs.


Compiler Settings / Advanced Settings (Fitter) / Perform Physical Synthesis for Combinational Logic For Performance
Compiler Settings / Advanced Settings (Fitter) / Perform Register Retiming For Performance

Turning these 2 on helps.

Compiler Settings / Advanced Settings (Fitter) / Placement Effort Multiplier
Compiler Settings / Advanced Settings (Fitter) / Router Timing Optimization Level

Increasing these 2 helps.



******************************************
Source Files:
******************************************
- Includes these following sub-modules :
  - BrianHG_DDR3_CONTROLLER_top.sv    -> The TOP entry to the complete project which wires the DDR3_COMMANDER to the DDR3_PHY_SEQ giving you access to all the read and write ports + access to the DDR3 IO pins.
  - BrianHG_DDR3_COMMANDER.sv         -> Handles the multi-port read and write requests and cache, commands the BrianHG_DDR3_PHY_SEQ.sv sequencer.
  - BrianHG_DDR3_CMD_SEQUENCER.sv     -> Takes in the read and write requests, generates a stream of DDR3 commands to execute the read and writes.
  - BrianHG_DDR3_PHY_SEQ.sv           -> DDR3 PHY sequencer.          (If you want just a compact DDR3 controller, skip the DDR3_CONTROLLER_top & DDR3_COMMANDER and just use this module alone.)
  - BrianHG_DDR3_PLL.sv               -> Generates the system clocks. (*** Currently Altera/Intel only ***)
  - BrianHG_DDR3_GEN_tCK.sv           -> Generates all the tCK count clock cycles for the DDR3_PHY_SEQ so that the DDR3 clock cycle requirements are met.
  - BrianHG_DDR3_FIFOs.sv             -> Serial shifting logic FIFOs.

- Includes the following test-benches:
  - BrianHG_DDR3_CONTROLLER_top_tb.sv -> Test the entire 'BrianHG_DDR3_CONTROLLER_top.sv' system with Mircon's DDR3 Verilog model.
  - BrianHG_DDR3_COMMANDER_tb.sv      -> Test just the commander.  The 'DDR3_PHY_SEQ' is dummy simulated.  (*** This one will simulate on any vendor's ModelSim ***)
  - BrianHG_DDR3_CMD_SEQUENCER_tb.sv  -> Test just the DDR3 command sequencer.                             (*** This one will simulate on any vendor's ModelSim ***)
  - BrianHG_DDR3_PHY_SEQ_tb.sv        -> Test just the DDR3 PHY sequencer with Mircon's DDR3 Verilog model providing logged DDR3 command results with any access violations listed.
  - BrianHG_DDR3_PLL_tb.sv            -> Test just the PLL module.

- IO port vendor specific modules
  - BrianHG_DDR3_IO_PORT_ALTERA.sv    -> Physical DDR IO pin driver specifically for Altera/Intel Cyclone III/IV/V and MAX10.
  - BrianHG_DDR3_IO_PORT_LATTICE.sv   -> Physical DDR IO pin driver specifically for Lattice ECP5/LFE5U series. (*** Coming soon ***)
  - BrianHG_DDR3_IO_PORT_XILINX.sv    -> Physical DDR IO pin driver specifically for Xilinx Artix 7 series.     (*** Coming soon ***)

- Optional RS232 Debugger
  - rs232_DEBUGGER.v                  -> RS232 debugger source & .exe, see: https://www.eevblog.com/forum/fpga/verilog-rs232-uart-and-rs232-debugger-source-code-and-educational-tutorial/
  - sync_rs232_uart.v

- Example SDC file
  - BrianHG_DDR3_DECA.sdc             -> Example .sdc file used with the Arrow Deca FPGA development board.  It specifies timing constraints for the DDR3 IO pins
                                         and the multicycle constraints between the different DDR3_CK PLL clock phases and potential slower CMD_CLK domains.

- Extended demo source files in folder 'BrianHG_DDR3_GFX_source'
  - BrianHG_display_rmem.sv           -> From coordinates and a base memory address, this module generates a read address and line buffer pointer to render a display.
  - BrianHG_draw_test_patterns.sv     -> This modules draws graphics into the DDR3 ram.
  - BrianHG_scroll_screen.sv          -> A screen scroll which bounces off the borders with random speed trajectory.
  - ellipse_generator.sv              -> A geometry unit which draws ellipses.
  - BrianHG_draw_test_patterns_tb.sv  -> Test bench for the 'BrianHG_draw_test_patterns.sv'.


*********************************************************
Example Quartus Prime Projects, Clocks and timing specs.
*********************************************************

  Though the following projects have been setup for Arrow's DECA board, they should give you an idea of how to initiate and interface with the BrianHG_DDR3 controller system.  All deep documentation is written in the source code.  Modelsim simulations are covered in the next section.


  When engineering your code, to improve FMAX, it is sometimes beneficial to change this setting in the menu:
 - Assignments / Settings / Compiler Settings / Advanced Settings (Synthesis) / Pre-Mapping Resynthesis Optimization = ON.
 - Note that in the main compiler settings page, 'Performance High Effort' or 'Balanced' usually reach a good FMAX while 'Performance Aggressive' can sometimes lead to a worse FMAX.  This problem should be improved upon as it is on the list of * Known Issues with release v0.9v *.


 - RS232 Debugger and blue status leds:
******************************************
    The Blue LEDs will match the 'In3[7:0]' (Green box at the bottom left hand corner) in the RS232 debugger hex editor.
    0 = Stuck failed to power up.   
    1 = Stuck during read calibration trying to seek for the lowest invalid tuning position. 
    2 = Stuck during read calibration trying to seek to the lowest valid tuning position.
    3 = Stuck during read calibration trying to seek to the highest invalid tuning position.
    
    *** Note that Blue LED[7] is also tied to the RS232 RXD/TXD activity.
        So it may be blinking when the debugger is connected and running.
        
    *** Note that the RS232 debugger RXD input connected to GPIO0_D[3] and the TXD output is connected to GPIO0_D[1].
    
    Successful setup and tuning of the DDR3 will show:
    8'bxxxxxxx0'  The width of the 'x' shows the number of valid tuning positions where the read data passed the read test.
                  The code tuned the PLL to the center-left position before beginning function and setting DDR3_READY flag.
                  
    RS232 Debugger 'In2[7:0] & In1[7:0]' = A 16 bit read data counter.  When refreshing the display, the counter in the MSB
    8 bits, 'In2[7:0]' should increment.  'In1[7:0]' will only change from 0 if there are read errors or read requests are lost.
    
    RS232 Debugger 'In0[7:0] :  Bit 2 = PLL Locked, Bit 3 = SEQ_CAL_PASS, Bit 4 = DDR3_READY.
    
    RS232 Debugger  [CTRL-R] = Reset everything, including PLL.  Should be similar to a power-up except for Memory Initialization Files.
    
    RS232 Debugger 'Out3[7:0]' (Red box bottom right corner, click on a bit to swap it's value)
                    Out3[7]  = Reset the DDR3_PHY_SEQ DDR3 controller.
                    Out3[6]  = Reset the DDR3_COMMANDER, multiport commander only.
    
    For the GFX Demo:
                    Out2[7]  = Swap the scroll screen enable.
                    Out2[6]  = Swap the ellipse draw enable.
                    Out2[1]  = Draw binary counter color pattern.
                    Out2[0]  = Draw random noise.
******************************************

Folders:

 - BrianHG_DDR3                               -> Only contains all the .v & .sv source code which the next project folders read from.
 - BrianHG_DDR3_DECA_GFX_DEMO                 400MHz, functional DDR3 System scrolling ellipse with optional RS232 debug port demo for Arrow DECA eval board.
 - BrianHG_DDR3_DECA_Show_1080p               400MHz, functional DDR3 System 1080p 32bit display with optional RS232 debug port demo for Arrow DECA eval board.
 - BrianHG_DDR3_DECA_RS232_DEBUG_TEST         400MHz, functional DDR3 System RS232 debug port demo for Arrow DECA eval board.
 - BrianHG_DDR3_DECA_only_PHY_SEQ             400MHz, functional DDR3 PHY Only controller with RS232 debug port demo for Arrow DECA eval board.
 - BrianHG_DDR3_CIV_GFX_FMAX_Test             400MHz, Hypothetical Cyclone IV DDR3 System scrolling ellipse build to verify FMAX.
 - BrianHG_DDR3_CIII_GFX_FMAX_Test_Q13.0sp1   400MHz, Hypothetical Cyclone III DDR3 System scrolling ellipse build to verify FMAX.  (Uses Quartus 13.0sp1)
 - BrianHG_DDR3_CV_GFX_FMAX_Fail              400MHz, Hypothetical Cyclone V-6 DDR3 System scrolling ellipse build to verify FMAX.  (FMAX FAILED)
 - BrianHG_DDR3_CV_GFX_FMAX_Test              300MHz, Hypothetical Cyclone V-6 DDR3 System scrolling ellipse build to verify FMAX.  (PASSED, but with features disabled)
 - BrianHG_DDR3_CV_PHY_ONLY_FMAX_Test         375MHz, Hypothetical Cyclone V-6 DDR3 PHY Only controller with RS232 debug port build to verify FMAX. (375MHz only, no  multiport)
 - BrianHG_DDR3_GFX_source                    -> Only contains source code for rendering the random ellipses demo.

-----------------------
- For the pll clocks:

  - MAX10_CLK1_50     -> CLK_IN,      This is the source oscillator clock at 50MHz.
  - *DDR3_PLL5*clk[0] -> DDR_CLK,     DDR3 clock and runs at the 300-400MHz.
  - *DDR3_PLL5*clk[1] -> DDR_CLK_WDQ, DDR3 write data clock, set to 90 degrees out of phase compared to BHG_*|pll1[0].
  - *DDR3_PLL5*clk[2] -> DDR_CLK_RDQ, DDR3 read data clock, at power-up, this clock is automatically tuned to the best phase to capture the read data coming back from the DDR3 ram chips.
  - *DDR3_PLL5*clk[3] -> DDR_CLK_50,  This is the interface clock for the DDR3_PHY controller and it runs at 50% speed of the DDR_CLK clock.
  - *DDR3_PLL5*clk[4] -> DDR_CLK_25,  This is the reset and power-up logic clock for the DDR3_PHY controller and it runs at 25% speed of the DDR_CLK clock.

  -  CMD_CLK                          This clock is tied to either DDR_CLK, DDR_CLK_50, or DDR_CLK_25 depending on parameter 'INTERFACE_SPEED' being Full, Half, or Quarter.  This clock drives the multiport COMMANDER module and sets it's interface clock speed.
-----------------------

Note that the set_input_delays in the 'BrianHG_DDR3_DECA.sdc' are mandatory, otherwise the DDR will not initialize or read data properly.  The set_multicycle_path are optional, but recommended as they relax the timing constraints between the CLK_IN domain and the rest of the design allowing the compiler to concentrate on the 300MHz section for raw speed.


*********************************************************
Modelsim Test Benches and how to use:
 - DDR3 Verilog model from Micron Required for this test-bench.
 - The required DDR3 SDRAM Verilog Model V1.74 available at:
 - https://media-www.micron.com/-/media/client/global/documents/products/sim-model/dram/ddr3/ddr3-sdram-verilog-model.zip?rev=925a8a05204e4b5c9c1364302de60126
 - From the 'DDR3 SDRAM Verilog Model.zip', only these 2 files are required in the main simulation test-bench source folder:
  - ddr3.v
  - 4096Mb_ddr3_parameters.vh
 - They must be placed inside the 'BrianHG_DDR3' folder, otherwise the 'BrianHG_DDR3_PHY_SEQ_tb.sv' and 'BrianHG_DDR3_CONTROLLER_top_tb.sv' will not work.
*********************************************************

For all of these simulations, just open Modelsim all on it's own.
Select 'File - Change Directory'
Then navigate to the 'BrianHG_DDR3' folder.

In the transcript, type 'do setup_xxx.do' to setup or change to a chosen simulation.
If you edit a source file and want to re-compile / re-run the sim, in the transcript you will type 'do run_xxx.do'.
All deep documentation is written in the source code.


*********************************************************
- BrianHG_DDR3_CMD_SEQUENCER_tb.sv  -> Test just the DDR3 command sequencer.
  (*** This testbench will simulate on any vendor's ModelSim ***)
*********************************************************

    This module is the sequencing brain of the BrianHG_DDR3_CONTROLLER.  It takes in read, write
and refresh commands, and spits out a sequence of DDR3 commands which will read/write data into
a DDR3 ram chip.  It will keep track of which banks are open with which rows and only open/close
banks as necessary.

To setup, type       -> do setup_seq.do
To run, type         -> do run_seq.do
Stimulus script file -> DDR3_CMD_SEQ_script.txt


*********************************************************
- BrianHG_DDR3_COMMANDER_tb.sv      -> Test just the commander.  The 'DDR3_PHY_SEQ' is dummy simulated.
  (*** This testbench will simulate on any vendor's ModelSim ***)
*********************************************************

    This module contains the 16 read and 16 write ports.  It intelligently selects which port
gets access to the BrianHG_DDR3_PHY_SEQ for the best possible continuous burst stream.

To setup, type       -> do setup_com.do
To run, type         -> do run_com.do
Stimulus script file -> DDR3_COMMAND_script.txt


*********************************************************
- BrianHG_DDR3_PLL_tb.sv            -> Test just the PLL module.
  (*** This testbench requires Altera/Intel's ModelSim ***)
*********************************************************

    Simple PLL test.  There is room for additional PLLs to be intitated based on the parameters 'FPGA_VENDOR' and
'FPGA_FAMILY'.

To setup, type       -> do setup_pll.do
To run, type         -> do run_pll.do


*********************************************************
- BrianHG_DDR3_PHY_SEQ_tb.sv        -> Test just the DDR3 PHY sequencer with Mircon's DDR3 Verilog model
                                       providing logged DDR3 command results with any access violations listed.
  (*** This testbench requires Altera/Intel's ModelSim ***)
*********************************************************

    This tests the basic DDR3 ram controller utilizing the BrianHG_DDR3_CMD_SEQUENCER.  It sets
a number of timers at reception of each command so it will know at the next command when it
is permitted.  It uses the BrianHG_DDR3_IO_PORT_ALTERA, BrianHG_DDR3_PLL and BrianHG_DDR3_FIFO
modules to orchestrate it's actions.  It uses Micron's DDR3 Verilog model to simulate a DDR3
ram chip and verify that no sent commands are errors.

To setup, type       -> do setup_phy.do
To run, type         -> do run_phy.do
Stimulus script file -> DDR3_PHY_script.txt


*********************************************************
- BrianHG_DDR3_CONTROLLER_top_tb.sv -> Test the entire 'BrianHG_DDR3_CONTROLLER_top.sv' system with Mircon's DDR3 Verilog model.
  (*** This testbench requires Altera/Intel's ModelSim ***)
*********************************************************

    This tests the entire 16 read & write port BrianHG_DDR3_CONTROLLER_top system driving
Micron's DDR3 ram model.

To setup, type       -> do setup_top.do
To run, type         -> do run_top.do
Stimulus script file -> DDR3_CONTROLLER_top_script.txt








************************************************************************************************************
************************************************************************************************************
********** REVISION HISTORY ********************************************************************************
************************************************************************************************************
************************************************************************************************************

Get the history archive at https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/


**********************************
Beta Release V0.95, August 4, 2021.
Tested on Quartus Prime 20.1
**********************************

Changes: BrianHG_DDR3_PLL.sv: Version 1.1, July 22, 2021

    The PLL now has 5 clock outputs plus the original parameter configurable CMD_CLK.

The new clock outputs are as follows:
   DDR3_CLK,              // DDR3 CK clock running at 1/2 the DQ rate.
   DDR3_CLK_WDQ,          // DDR3 write data clock 90 degree out of phase running at 1/2 the DQ rate.
   DDR3_CLK_RDQ,          // DDR3 phase adjustable read data input clock running at 1/2 the DQ rate.
   DDR3_CLK_50,           // DDR3 clock running at 1/4 the DQ rate.
   DDR3_CLK_25,           // DDR3 clock running at 1/8 the DQ rate.
   CMD_CLK,               // Ram controller interface clock running at DDR3_CLK, or 1/2 DDR3_CLK, or 1/4 DDR3_CLK

This will allow you access to additional clock divisions for you project use.


Changes: BrianHG_DDR3_PHY_SEQ.sv: Version 0.95, August 1, 2021.

1) Improved FMAX timing to at least achieve 300MHz under normal compile options.
   There still is room for improvement on the cross clock domain timing.

2) When using the DDR3_PHY_SEQ by itself as a DDR3 stand-alone controller with the parameter feature:
   USE_TOGGLE_CONTROLS = 0,
   The interface IO controls exclusively run at the 'DDR3_CLK_50' speed, in other words, half-rate.


BrianHG_DDR3_COMMANDER.sv: Version 0.95, August 4, 2021.

1) When running the complete controller with the BrianHG_DDR3_COMMANDER set at Quarter speed, a bug with consecutive sequential burst having empty gaps withing the burst has been eliminated.
2) FMAX still needs improvement.
3) Original 'DDR3_CMD_FIFO_Rs_inst' parameter bug still needs to be set to 1 to function properly.


BrianHG_DDR3_CMD_SEQUENCER.sv: Version 0.95, August 1, 2021.

    All known issues fixed.


**********************************
Beta Release V0.9, July 13, 2021.
Tested on Quartus Prime 20.1
**********************************

********** Known Issues with release v0.9v **********

BrianHG_DDR3_PLL.sv: Version 1.0, March 10, 2021
    With a source clock of 50MHz, a DDR3 frequency of 250,300,350,400,450 MHz works with every build,
however when selecting odd frequencies like 310 or 320 MHz with some builds, it will fail to boot, initialize and
calibrate the DDR3.  This appears to be an issue with the MAX 10 PLL or internal FPGA timing and not a coding error.
    Also, in Modelsim, 16 PLL tuning steps appear to move the clock by 180 degrees but in the FPGA, 16 steps
seem to move the clock by 360 degrees.  However, this doe not effect the functionality of the code and
still needs absolute proof.  ***Note that the Modelsim simulations are functional, not gate level.


BrianHG_DDR3_PHY_SEQ.sv: Version 0.9, July 12, 2021.
1)  When the system parameter 'INTERFACE_SPEED' is set to 'FULL', running the BrianHG_DDR3_PHY_SEQ_tb.sv
in Modelsim yields occasional dropped/skipped commands coming from the BrianHG_DDR3_CMD_SEQUENCER.sv
revealing an error from Micron's DDR3 model.  The issue is potentially tied to a middle fifo 'BHG_FIFO'
being overflowed.
2)  FMAX is being cut just below 300MHz due to the command allowance timers generating the 'DDR3_TX_BUSY'
flag for said fifo in issue (1).  Since this is connected to the overflow flag, these 2 issues need to
be solved together.

BrianHG_DDR3_IO_PORT_ALTERA.sv: Version 0.9, July 12, 2021
    May need a bit of cleaning to aid in generation of Lattice and Xilinx IO DDR buffer versions.

BrianHG_DDR3_GEN_tCK.sv: Version 1.0, March 10, 2021.
    Everything appears OK.

BrianHG_DDR3_CONTROLLER_top.sv: Version 1.0, June 01, 2021.
    Everything appears OK.

BrianHG_DDR3_COMMANDER.sv: Version 0.9, May 21, 2021.
1)  Currently, the command request input FIFOs have been set to 3 commands with the 'full' flag set to
trigger when only 2 full.  Changing the 'full' flag to go active once the last word has been filled
causes the module to loose/skip commands.  Also, lowering the FIFO's total size to down to 2 also causes
the module to skip/loose commands.  So far, this issue is ok with it's current settings.  Note that any
of the above setting will simulate without loosing commands, however, the command loss is only a few after
thousands of requests making it difficult to trace in simulation.
2)  For now, the parameter 'PORT_R_CMD_STACK' must be set to 1.  Currently, the intermediate read
stack FIFO 'DDR3_CMD_FIFO_Rs_inst' needs to be set to a size of at least 16 to prevent the loss of
read requests during heavy traffic or long sequential bursts.  Even though the module is coded to
monitor that FIFO's full flag and halt further read requests eventually setting the 'CMD_R_busy'
within the command chain, for some reason, the busy is either not set in time or commands are allowed
through and dropped leaving gaps in the read request.
3)  FMAX needs to be improved when using a large number of simultaneous read and write ports.

BrianHG_DDR3_CMD_SEQUENCER.sv: Version 0.9, June 20, 2021.
    Connected to BrianHG_DDR3_PHY_SEQ.sv problem when the system parameter 'INTERFACE_SPEED' is set to
'FULL', this module may continue to output a command even though the FIFO it's talking to may be full.
Once again, this module appears to simulate properly on it's own.

