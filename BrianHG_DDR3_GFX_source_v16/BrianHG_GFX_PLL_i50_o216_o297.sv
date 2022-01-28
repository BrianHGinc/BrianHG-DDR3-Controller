// *****************************************************************************************************
// Demo BrianHG_GFX_PLL_i50_o216_o297.sv.
// IE: Take in 50MHz, and output a switchable 216/297MHz.
//
// Version 1.6, December 27, 2021.
//
// Written by Brian Guralnick.
// For public use.
//
// See: https://www.eevblog.com/forum/fpga/brianhg_ddr3_controller-open-source-ddr3-controller/
//
// *****************************************************************************************************
module BrianHG_GFX_PLL_i50_o216_o297 (
input   CLK_IN_50          ,
input   RESET              ,
input   SEL_297            ,         // For the switched output, low = 216MHz or high = 297MHz.

output  CLK_SWITCH         ,         // 216.0/297.0 MHz out.
output  CLK_SWITCH_50      ,         // 108.0/148.5 MHz out.

output  CLK_54             ,         // 54 MHz out. - Used to generate an exact 48KHz I2S audio clock
output  CLK_7425           ,         // 74.25 MHz out.

output  LOCKED
);

wire PLL1_LOCKED;
wire PLL2_LOCKED;
wire PLL3_LOCKED;

assign LOCKED = PLL1_LOCKED && PLL2_LOCKED && PLL3_LOCKED ;

// **********************************************************************************
// 50MHz to 54MHz.
// **********************************************************************************
logic [4:0]  PLL_50_54;    // PLL has 5 outputs.
assign       CLK_54 = PLL_50_54[0];
 altpll #(

  .bandwidth_type ("AUTO"),           .inclk0_input_frequency (20000),      .compensate_clock ("CLK0"),         .lpm_hint ("CBX_MODULE_PREFIX=BrianHG_GFX_PLL_i50_o216_o297"),
  .clk0_divide_by (25),               .clk0_duty_cycle (50),                .clk0_multiply_by (27),             .clk0_phase_shift ("0"),
  //.clk1_divide_by (50),               .clk1_duty_cycle (50),                .clk1_multiply_by (27),             .clk1_phase_shift ("0"),
  //.clk2_divide_by (100),              .clk2_duty_cycle (50),                .clk2_multiply_by (27),             .clk2_phase_shift ("0"),
  //.clk3_divide_by (CLK_IN_DIV),       .clk3_duty_cycle (50),                .clk3_multiply_by (27),             .clk3_phase_shift ("0"),
  //.clk4_divide_by (CLK_IN_DIV),       .clk4_duty_cycle (50),                .clk4_multiply_by (27),             .clk4_phase_shift ("0"),

  .lpm_type         ("altpll"),       .operation_mode    ("NORMAL"),        .pll_type         ("AUTO"),         .port_activeclock        ("PORT_UNUSED"),
  .port_areset      ("PORT_USED"),    .port_clkbad0      ("PORT_UNUSED"),   .port_clkbad1     ("PORT_UNUSED"),  .port_clkloss            ("PORT_UNUSED"),
  .port_clkswitch   ("PORT_UNUSED"),  .port_configupdate ("PORT_UNUSED"),   .port_fbin        ("PORT_UNUSED"),  .port_inclk0             ("PORT_USED"),
  .port_inclk1      ("PORT_UNUSED"),  .port_locked       ("PORT_USED"),     .port_pfdena      ("PORT_UNUSED"),  .port_phasecounterselect ("PORT_UNUSED"),
  .port_phasedone   ("PORT_UNUSED"),  .port_phasestep    ("PORT_UNUSED"),   .port_phaseupdown ("PORT_UNUSED"),  .port_pllena             ("PORT_UNUSED"),
  .port_scanaclr    ("PORT_UNUSED"),  .port_scanclk      ("PORT_UNUSED"),   .port_scanclkena  ("PORT_UNUSED"),  .port_scandata           ("PORT_UNUSED"),
  .port_scandataout ("PORT_UNUSED"),  .port_scandone     ("PORT_UNUSED"),   .port_scanread    ("PORT_UNUSED"),  .port_scanwrite          ("PORT_UNUSED"),
  .port_clk0        ("PORT_USED"),    .port_clk1         ("PORT_UNUSED"),   .port_clk2        ("PORT_UNUSED"),  .port_clk3               ("PORT_UNUSED"),
  .port_clk4        ("PORT_UNUSED"),  .port_clk5         ("PORT_UNUSED"),   .port_clkena0     ("PORT_UNUSED"),  .port_clkena1            ("PORT_UNUSED"),
  .port_clkena2     ("PORT_UNUSED"),  .port_clkena3      ("PORT_UNUSED"),   .port_clkena4     ("PORT_UNUSED"),  .port_clkena5            ("PORT_UNUSED"),
  .port_extclk0     ("PORT_UNUSED"),  .port_extclk1      ("PORT_UNUSED"),   .port_extclk2     ("PORT_UNUSED"),  .port_extclk3            ("PORT_UNUSED"),
  .width_clock      (5),              .self_reset_on_loss_lock ("OFF"),     .intended_device_family  ("MAX 10")

 ) VGA_50_54 (
                .inclk ({1'b0, CLK_IN_50}),.clk (PLL_50_54),
                .activeclock (),           .areset (RESET),        .clkbad (),          .clkena ({6{1'b1}}),     .clkloss (),
                .clkswitch (1'b0),         .configupdate (1'b0),   .enable0 (),         .enable1 (),             .extclk (),
                .extclkena ({4{1'b1}}),    .fbin (1'b1),           .fbmimicbidir (),    .fbout (),               .fref (),
                .icdrclk (),               .locked (PLL1_LOCKED),  .pfdena (1'b1),      .phasedone (),           .phasestep (1'b1),
                .phaseupdown (1'b0),       .pllena (1'b1),         .scanaclr (1'b0),    .scanclk (1'b0),         .scanclkena (1'b1),
                .scandata (1'b0),          .scandataout (),        .scandone (),        .scanread (1'b0),        .scanwrite (1'b0),
                .sclkout0 (),              .sclkout1 (),           .vcooverrange (),    .vcounderrange (),       .phasecounterselect ({4{1'b1}}));


// **********************************************************************************
// 54MHz to 74.25MHz.
// **********************************************************************************
logic [4:0]  PLL_54_74;    // PLL has 5 outputs.
assign       CLK_7425 = PLL_54_74[0];
 altpll #(

  .bandwidth_type ("AUTO"),           .inclk0_input_frequency (18518),      .compensate_clock ("CLK0"),         .lpm_hint ("CBX_MODULE_PREFIX=BrianHG_GFX_PLL_i50_o216_o297"),
  .clk0_divide_by (8),                .clk0_duty_cycle (50),                .clk0_multiply_by (11),             .clk0_phase_shift ("0"),
  //.clk1_divide_by (50),               .clk1_duty_cycle (50),                .clk1_multiply_by (11),             .clk1_phase_shift ("0"),
  //.clk2_divide_by (100),              .clk2_duty_cycle (50),                .clk2_multiply_by (11),             .clk2_phase_shift ("0"),
  //.clk3_divide_by (CLK_IN_DIV),       .clk3_duty_cycle (50),                .clk3_multiply_by (11),             .clk3_phase_shift ("0"),
  //.clk4_divide_by (CLK_IN_DIV),       .clk4_duty_cycle (50),                .clk4_multiply_by (11),             .clk4_phase_shift ("0"),

  .lpm_type         ("altpll"),       .operation_mode    ("NORMAL"),        .pll_type         ("AUTO"),         .port_activeclock        ("PORT_UNUSED"),
  .port_areset      ("PORT_USED"),    .port_clkbad0      ("PORT_UNUSED"),   .port_clkbad1     ("PORT_UNUSED"),  .port_clkloss            ("PORT_UNUSED"),
  .port_clkswitch   ("PORT_UNUSED"),  .port_configupdate ("PORT_UNUSED"),   .port_fbin        ("PORT_UNUSED"),  .port_inclk0             ("PORT_USED"),
  .port_inclk1      ("PORT_UNUSED"),  .port_locked       ("PORT_USED"),     .port_pfdena      ("PORT_UNUSED"),  .port_phasecounterselect ("PORT_UNUSED"),
  .port_phasedone   ("PORT_UNUSED"),  .port_phasestep    ("PORT_UNUSED"),   .port_phaseupdown ("PORT_UNUSED"),  .port_pllena             ("PORT_UNUSED"),
  .port_scanaclr    ("PORT_UNUSED"),  .port_scanclk      ("PORT_UNUSED"),   .port_scanclkena  ("PORT_UNUSED"),  .port_scandata           ("PORT_UNUSED"),
  .port_scandataout ("PORT_UNUSED"),  .port_scandone     ("PORT_UNUSED"),   .port_scanread    ("PORT_UNUSED"),  .port_scanwrite          ("PORT_UNUSED"),
  .port_clk0        ("PORT_USED"),    .port_clk1         ("PORT_UNUSED"),   .port_clk2        ("PORT_UNUSED"),  .port_clk3               ("PORT_UNUSED"),
  .port_clk4        ("PORT_UNUSED"),  .port_clk5         ("PORT_UNUSED"),   .port_clkena0     ("PORT_UNUSED"),  .port_clkena1            ("PORT_UNUSED"),
  .port_clkena2     ("PORT_UNUSED"),  .port_clkena3      ("PORT_UNUSED"),   .port_clkena4     ("PORT_UNUSED"),  .port_clkena5            ("PORT_UNUSED"),
  .port_extclk0     ("PORT_UNUSED"),  .port_extclk1      ("PORT_UNUSED"),   .port_extclk2     ("PORT_UNUSED"),  .port_extclk3            ("PORT_UNUSED"),
  .width_clock      (5),              .self_reset_on_loss_lock ("OFF"),     .intended_device_family  ("MAX 10")

 ) VGA_54_74 (
                .inclk ({1'b0, CLK_54}),   .clk (PLL_54_74),
                .activeclock (),           .areset (RESET),        .clkbad (),          .clkena ({6{1'b1}}),     .clkloss (),
                .clkswitch (1'b0),         .configupdate (1'b0),   .enable0 (),         .enable1 (),             .extclk (),
                .extclkena ({4{1'b1}}),    .fbin (1'b1),           .fbmimicbidir (),    .fbout (),               .fref (),
                .icdrclk (),               .locked (PLL2_LOCKED),  .pfdena (1'b1),      .phasedone (),           .phasestep (1'b1),
                .phaseupdown (1'b0),       .pllena (1'b1),         .scanaclr (1'b0),    .scanclk (1'b0),         .scanclkena (1'b1),
                .scandata (1'b0),          .scandataout (),        .scandone (),        .scanread (1'b0),        .scanwrite (1'b0),
                .sclkout0 (),              .sclkout1 (),           .vcooverrange (),    .vcounderrange (),       .phasecounterselect ({4{1'b1}}));

/*
// **********************************************************************************
// 54MHz or 74.25MHz to X4 and X2 outputs
// **********************************************************************************

logic [4:0]  PLL_SW_216_297;    // PLL has 5 outputs.
assign       CLK_SWITCH    = PLL_SW_216_297[0];
assign       CLK_SWITCH_50 = PLL_SW_216_297[1];

 altpll #(

  .bandwidth_type ("AUTO"),           .inclk0_input_frequency (15625),      .compensate_clock ("CLK0"),         .lpm_hint ("CBX_MODULE_PREFIX=BrianHG_GFX_PLL_i50_o216_o297"),
  .clk0_divide_by (1),                .clk0_duty_cycle (50),                .clk0_multiply_by (4),              .clk0_phase_shift ("0"),
  .clk1_divide_by (1),                .clk1_duty_cycle (50),                .clk1_multiply_by (2),              .clk1_phase_shift ("0"),
  //.clk2_divide_by (100),              .clk2_duty_cycle (50),                .clk2_multiply_by (11),             .clk2_phase_shift ("0"),
  //.clk3_divide_by (CLK_IN_DIV),       .clk3_duty_cycle (50),                .clk3_multiply_by (11),             .clk3_phase_shift ("0"),
  //.clk4_divide_by (CLK_IN_DIV),       .clk4_duty_cycle (50),                .clk4_multiply_by (11),             .clk4_phase_shift ("0"),
                                      .inclk1_input_frequency (15625),      .switch_over_type ("MANUAL"),

  .lpm_type         ("altpll"),       .operation_mode    ("NORMAL"),        .pll_type         ("AUTO"),         .port_activeclock        ("PORT_UNUSED"),
  .port_areset      ("PORT_USED"),    .port_clkbad0      ("PORT_UNUSED"),   .port_clkbad1     ("PORT_UNUSED"),  .port_clkloss            ("PORT_UNUSED"),
  .port_clkswitch   ("PORT_USED"),    .port_configupdate ("PORT_UNUSED"),   .port_fbin        ("PORT_UNUSED"),  .port_inclk0             ("PORT_USED"),
  .port_inclk1      ("PORT_USED"),    .port_locked       ("PORT_USED"),     .port_pfdena      ("PORT_UNUSED"),  .port_phasecounterselect ("PORT_UNUSED"),
  .port_phasedone   ("PORT_UNUSED"),  .port_phasestep    ("PORT_UNUSED"),   .port_phaseupdown ("PORT_UNUSED"),  .port_pllena             ("PORT_UNUSED"),
  .port_scanaclr    ("PORT_UNUSED"),  .port_scanclk      ("PORT_UNUSED"),   .port_scanclkena  ("PORT_UNUSED"),  .port_scandata           ("PORT_UNUSED"),
  .port_scandataout ("PORT_UNUSED"),  .port_scandone     ("PORT_UNUSED"),   .port_scanread    ("PORT_UNUSED"),  .port_scanwrite          ("PORT_UNUSED"),
  .port_clk0        ("PORT_USED"),    .port_clk1         ("PORT_USED"),     .port_clk2        ("PORT_UNUSED"),  .port_clk3               ("PORT_UNUSED"),
  .port_clk4        ("PORT_UNUSED"),  .port_clk5         ("PORT_UNUSED"),   .port_clkena0     ("PORT_UNUSED"),  .port_clkena1            ("PORT_UNUSED"),
  .port_clkena2     ("PORT_UNUSED"),  .port_clkena3      ("PORT_UNUSED"),   .port_clkena4     ("PORT_UNUSED"),  .port_clkena5            ("PORT_UNUSED"),
  .port_extclk0     ("PORT_UNUSED"),  .port_extclk1      ("PORT_UNUSED"),   .port_extclk2     ("PORT_UNUSED"),  .port_extclk3            ("PORT_UNUSED"),
  .width_clock      (5),              .self_reset_on_loss_lock ("OFF"),     .intended_device_family  ("MAX 10")

 ) VGA_SW_216_297 (
                .inclk ({CLK_7425, CLK_54}),   .clk (PLL_SW_216_297),
                .activeclock (),           .areset (RESET),        .clkbad (),          .clkena ({6{1'b1}}),     .clkloss (),
                .clkswitch (SEL_297),      .configupdate (1'b0),   .enable0 (),         .enable1 (),             .extclk (),
                .extclkena ({4{1'b1}}),    .fbin (1'b1),           .fbmimicbidir (),    .fbout (),               .fref (),
                .icdrclk (),               .locked (PLL3_LOCKED),  .pfdena (1'b1),      .phasedone (),           .phasestep (1'b1),
                .phaseupdown (1'b0),       .pllena (1'b1),         .scanaclr (1'b0),    .scanclk (1'b0),         .scanclkena (1'b1),
                .scandata (1'b0),          .scandataout (),        .scandone (),        .scanread (1'b0),        .scanwrite (1'b0),
                .sclkout0 (),              .sclkout1 (),           .vcooverrange (),    .vcounderrange (),       .phasecounterselect ({4{1'b1}}));
*/
// **********************************************************************************
// 54MHz or 74.25MHz to X4 and X2 outputs
// **********************************************************************************

logic [4:0]  PLL_SW_216_297;    // PLL has 5 outputs.
assign       CLK_SWITCH    = PLL_SW_216_297[0];
assign       CLK_SWITCH_50 = PLL_SW_216_297[1];

 altpll #(

  .bandwidth_type ("AUTO"),           .inclk0_input_frequency (13468),      .compensate_clock ("CLK0"),         .lpm_hint ("CBX_MODULE_PREFIX=BrianHG_GFX_PLL_i50_o216_o297"),
  .clk0_divide_by (1),                .clk0_duty_cycle (50),                .clk0_multiply_by (4),              .clk0_phase_shift ("0"),
  .clk1_divide_by (1),                .clk1_duty_cycle (50),                .clk1_multiply_by (2),              .clk1_phase_shift ("0"),
  //.clk2_divide_by (100),              .clk2_duty_cycle (50),                .clk2_multiply_by (11),             .clk2_phase_shift ("0"),
  //.clk3_divide_by (CLK_IN_DIV),       .clk3_duty_cycle (50),                .clk3_multiply_by (11),             .clk3_phase_shift ("0"),
  //.clk4_divide_by (CLK_IN_DIV),       .clk4_duty_cycle (50),                .clk4_multiply_by (11),             .clk4_phase_shift ("0"),
                                      //.inclk1_input_frequency (15625),      .switch_over_type ("MANUAL"),

  .lpm_type         ("altpll"),       .operation_mode    ("NORMAL"),        .pll_type         ("AUTO"),         .port_activeclock        ("PORT_UNUSED"),
  .port_areset      ("PORT_USED"),    .port_clkbad0      ("PORT_UNUSED"),   .port_clkbad1     ("PORT_UNUSED"),  .port_clkloss            ("PORT_UNUSED"),
  .port_clkswitch   ("PORT_USED"),    .port_configupdate ("PORT_UNUSED"),   .port_fbin        ("PORT_UNUSED"),  .port_inclk0             ("PORT_USED"),
  .port_inclk1      ("PORT_UNUSED"),  .port_locked       ("PORT_USED"),     .port_pfdena      ("PORT_UNUSED"),  .port_phasecounterselect ("PORT_UNUSED"),
  .port_phasedone   ("PORT_UNUSED"),  .port_phasestep    ("PORT_UNUSED"),   .port_phaseupdown ("PORT_UNUSED"),  .port_pllena             ("PORT_UNUSED"),
  .port_scanaclr    ("PORT_UNUSED"),  .port_scanclk      ("PORT_UNUSED"),   .port_scanclkena  ("PORT_UNUSED"),  .port_scandata           ("PORT_UNUSED"),
  .port_scandataout ("PORT_UNUSED"),  .port_scandone     ("PORT_UNUSED"),   .port_scanread    ("PORT_UNUSED"),  .port_scanwrite          ("PORT_UNUSED"),
  .port_clk0        ("PORT_USED"),    .port_clk1         ("PORT_USED"),     .port_clk2        ("PORT_UNUSED"),  .port_clk3               ("PORT_UNUSED"),
  .port_clk4        ("PORT_UNUSED"),  .port_clk5         ("PORT_UNUSED"),   .port_clkena0     ("PORT_UNUSED"),  .port_clkena1            ("PORT_UNUSED"),
  .port_clkena2     ("PORT_UNUSED"),  .port_clkena3      ("PORT_UNUSED"),   .port_clkena4     ("PORT_UNUSED"),  .port_clkena5            ("PORT_UNUSED"),
  .port_extclk0     ("PORT_UNUSED"),  .port_extclk1      ("PORT_UNUSED"),   .port_extclk2     ("PORT_UNUSED"),  .port_extclk3            ("PORT_UNUSED"),
  .width_clock      (5),              .self_reset_on_loss_lock ("OFF"),     .intended_device_family  ("MAX 10")

 ) VGA_SW_216_297 (
                .inclk ({1'b0, CLK_7425}),   .clk (PLL_SW_216_297),
                .activeclock (),           .areset (RESET),        .clkbad (),          .clkena ({6{1'b1}}),     .clkloss (),
                .clkswitch (1'b0),         .configupdate (1'b0),   .enable0 (),         .enable1 (),             .extclk (),
                .extclkena ({4{1'b1}}),    .fbin (1'b1),           .fbmimicbidir (),    .fbout (),               .fref (),
                .icdrclk (),               .locked (PLL3_LOCKED),  .pfdena (1'b1),      .phasedone (),           .phasestep (1'b1),
                .phaseupdown (1'b0),       .pllena (1'b1),         .scanaclr (1'b0),    .scanclk (1'b0),         .scanclkena (1'b1),
                .scandata (1'b0),          .scandataout (),        .scandone (),        .scanread (1'b0),        .scanwrite (1'b0),
                .sclkout0 (),              .sclkout1 (),           .vcooverrange (),    .vcounderrange (),       .phasecounterselect ({4{1'b1}}));


endmodule
