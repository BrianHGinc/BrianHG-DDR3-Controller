--------------------------------------
NEW December 3, 2021.
--------------------------------------
BrianHG_DDR3_Controller V1.5
December 3, 2021
--------------------------------------
A maddening over 11K lines of code....
--------------------------------------

See image 'BrianHG_DDR3_v15_Block_Diagram.png' for a simplified block diagram of the BrianHG_DDR3_Controller_v15 controller system.

Note that the original v1.0 source files still exist, still function, and are backwards compatible, but understand that all the source files have been updated.  This includes the new .sdc files in the new demo projects.

In-depth instructions are located in the full v1.0 text release notes as well as all the parameters and ports are well documented within the source code and examples.

These are the new main source file which operate according to the simplified block diagram:


Version 1.5 source files:
--------------------------

BrianHG_DDR3_COMMANDER_v15.sv
- All 16 user multiports are now read and write ports instead of a separate 16 read ports and 16 write ports.
- Radically improved FMAX where a full 16 ports should achieve at least 150Mhz on a -6 Cyclone III/IV and MAX10.
- Sadly, Cyclone V-6 should achieve at least 88MHz where it used to be only 75MHz with just 2 ports.

BrianHG_DDR3_CONTROLLER_v15_top.sv
- Uses the new commander v15.
- Has a 'TAP' port which is a copy of all the writes being send to the DDR3.

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
1. For the 1080p output, remove the DECAs example video sync generator and writ my own proper one which will allow a few real-time video mode selection.
2. Fix a bug with my raster generator which currently only functions properly in 1080p 32bit color, offering proper support for 1/2/4/8/16/32bit color modes.
3. Shrink the video line buffer to the minimal M9K block size allowed with a 128bit memory buss interface.
4. Add a palette support for lower depth video modes.
5. Add a hardware multi-layer-superimposed window system framework.


Next major release v2.0 targets.
---------------------------------
1. Improve FMAX abilities to guarantee 400MHz FMAX half-rate capabilities.
2. Begin Lattice port.
