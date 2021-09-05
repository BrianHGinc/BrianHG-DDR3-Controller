BrianHD_DDR3 V1.00 system FPGA utilization reports:

300MHz_PHY_only.png - DDR3 controller with 1 read & write port to an 8 bit device build.

300MHz-8_ellipse.png - DDR3 controller random ellipse project with 4 ports, 128 bit access, 300MHz Max10-8.
300MHz_ellipse.png - DDR3 controller random ellipse project with 4 ports, 128 bit access, 300MHz Max10-6.
400MHz_ellipse.png - DDR3 controller random ellipse project with 4 ports, 128 bit access, 400MHz Max10-6.
450MHz_ellipse.png - DDR3 controller random ellipse project with 4 ports, 128 bit access, 450MHz Max10-6.
500MHz_ellipse.png - DDR3 controller random ellipse project with 4 ports, 128 bit access, 500MHz Max10-6.

I've included a few builds.  You will notice that the LC/LUT increases with frequency.  This is most likely the compiler adding duplicate parallel logic cells to improve FMAX timing.


I highlighted the 'BrianHG_PHY_SEQ' module which tells you the full LC/LUT count is you were to build a stand-alone 1 read/write port DDR3 controller.

The COMMANDER module is the multiport handler configured with 2 read and 2 write ports in the ellipse demo.
