V1.00 FMAX results:

Files,  Description:

300MHz, Hypothetical Cyclone III-8 DDR3 System scrolling ellipse build to verify FMAX.
(Uses Quartus 13.0sp1)
Cyclone III-8_300MHz_EP3C40F484C8_GFX.png

400MHz, Hypothetical Cyclone III-6 DDR3 System scrolling ellipse build to verify FMAX.
(Uses Quartus 13.0sp1)
Cyclone III-6_400MHz_EP3C40F484C6_GFX.png


300MHz, Hypothetical Cyclone IV-8 DDR3 System scrolling ellipse build to verify FMAX.
Cyclone IV-E-8_300MHz_EP4CE30F23C8_GFX.png

400MHz, Hypothetical Cyclone IV-6 DDR3 System scrolling ellipse build to verify FMAX.
Cyclone IV-E-6_400MHz_EP4CE30F23C6_GFX.png


300MHz, functional DDR3 System scrolling ellipse with optional RS232 debug port demo for Arrow DECA eval board, but compiled for a -8.
Max 10-8_300MHz_10M50DAF484C8GES_GFX_DECA.png

400MHz, functional DDR3 System scrolling ellipse with optional RS232 debug port demo for Arrow DECA eval board.
Max 10-6_400MHz_10M50DAF484C6GES_GFX_DECA.png



400MHz, Hypothetical Cyclone V-6 DDR3 System scrolling ellipse build to verify FMAX.
( :-- FMAX FAILED  :-- )  Take a look at the multiport clock.
Cyclone V-E-6_400MHz_5CEFA4F23C6_GFX_FAIL.png

300MHz, Hypothetical Cyclone V-6 DDR3 System scrolling ellipse build to verify FMAX.
(PASSED, but with I had to disable some smart multiport features and this is a CV-6 :--)
Cyclone V-E-6_300MHz_5CEFA4F23C6_GFX.png

300MHz, Hypothetical Cyclone V-7 DDR3 PHY Only controller with RS232 debug port build to verify FMAX.
(300MHz only, no multiport )  A CV-7  :--, not even a -8.  Compiling for a -8 leaves 4 clock domain crossing nets in the red even though the rest of the design including IO ports easily pass.
Cyclone V-E-7_300MHz_5CEFA4F23C7_PHY_ONLY.png

375MHz, Hypothetical Cyclone V-6 DDR3 PHY Only controller with RS232 debug port build to verify FMAX.
(375MHz only, no multiport  :-- ) Compiling for 400MHz reveals ~8 clock domain crossing nets in the red even though the rest of the design including IO ports easily pass.  In fact, this FPGA should have reached 500MHz.
Cyclone V-E-6_375MHz_5CEFA4F23C6_PHY_ONLY.png


I will be sending my code to Intel to see why their Cyclone V only gets 60% speed on my multiport module.  Maybe there is something in the compiler setting to help as the FPGA fabric of Cyclone V is radically different compared to all other Cyclone & MAX FPGAs.


Clocks [ 0 ],[ 1 ],[ 2 ] and the DDR_CK, Write clock, read clock.
Clock  [ 3 ] is the DDR_CLK_50 half speed clock, the interface speed of the Brian_DDR3_PHY_SEQ.
Clock  [ 4 ] is the DDR_CLK_25 quarter speed clock, current set for the MULTIPORT module.
