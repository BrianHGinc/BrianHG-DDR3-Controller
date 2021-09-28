Ok, I though some may want to know about DDR pin planning in Quartus.

I've attached 2 screenshots of Quartus' pin planner, 1 for Cyclone_IV and 1 for Max_10.

You will see that I have chosen x8 devices even though we are suing an x16 DDR3 ram chip.  I have done this since the x16 DDR3 actually has 2 groups of DQS basically making it 2 x8 devices.

See 'Max10_pinplanner.png' for the Max_10 device.


As for the Cyclone_IV (included Cyclone III), you will notice that there exists the DQS, but not a DQS_n.  My DDR3 ram controller will still work, however, it requires you connect the DDR3's DQS_n to the adjacent DQS IO within the same x8 bank.  Preferably a emulated differential pair as long as it is within the same IO bank, even if it isn't highlighted as being part of the same x8 group.  (Quartus' reported polarity of this differential pair doesn't matter.  So long as the DQS pin is connected to the DQS on the DDR3 and the differential pair gets connected to DQS# on the DDR3 even if Quartus' pin planner says that the x8 DQS pin is the negative part of the differential pair.)

See 'Cyclone_IV_pinplanner.png' for Cyclone IV/III device.

The data mask pins also need to be placed inside the same associated x8 group.

Remember to check the data sheets as some older Cyclones have higher IO performance on the top and bottom rows compared to the left and right sides.  You want to use the higher speed performance IOs.

The CK and CK_n pins should be a differential pair close to the center of everything if you are using more than 1 DDR3 ram chip, otherwise, either end or center will do.

Note that the MAX_10 devices as well as Cyclone_V do have a dedicated CK and CK_n pin for DDR3.  You will need to use these for your DDR3 CK/CK_n if you want full compatibility with Altera's DDR3 controller.

Download Arrow DECA's schematics to get a complete example of the DDR3 wiring. 
