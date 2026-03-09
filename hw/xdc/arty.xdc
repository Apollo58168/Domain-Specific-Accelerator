## This file is a general .xdc for the ARTY Rev. A
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project


# Clock signal

set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports sys_clk_i]
#create_clock -name sys_clk_i -period 10.000 -waveform {0.000 5.000} [get_ports sys_clk_i];
#derive_pll_clocks
#derive_clock_uncertainty
#create_generated_clock -period 24.000 -waveform {0.000 12.000} -name clk -source [get_pins clk_wiz_0/clk_in1] [get_nets clk]
#create_generated_clock -period  6.000 -waveform {0.000  3.000} -name clk_166M -source [get_pins clk_wiz_0/clk_in1] [get_nets clk_166M]
#create_generated_clock -period  5.000 -waveform {0.000  2.500} -name clk_200M -source [get_pins clk_wiz_0/clk_in1] [get_nets clk_200M]

set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports resetn_i]

#Switches

#set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports { usr_sw[0] }]; #IO_L12N_T1_MRCC_16 Sch=sw[0]
#set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports { usr_sw[1] }]; #IO_L13P_T2_MRCC_16 Sch=sw[1]
#set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports { usr_sw[2] }]; #IO_L13N_T2_MRCC_16 Sch=sw[2]
#set_property -dict { PACKAGE_PIN A10 IOSTANDARD LVCMOS33 } [get_ports { usr_sw[3] }]; #IO_L14P_T2_SRCC_16 Sch=sw[3]


# LEDs

set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {usr_led[0]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {usr_led[1]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {usr_led[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {usr_led[3]}]
#set_property -dict { PACKAGE_PIN E1  IOSTANDARD LVCMOS33 } [get_ports { rgb_led[0] }]; #IO_L18N_T2_35 Sch=led0_b
#set_property -dict { PACKAGE_PIN F6  IOSTANDARD LVCMOS33 } [get_ports { rgb_led[1] }]; #IO_L19N_T3_VREF_35 Sch=led0_g
#set_property -dict { PACKAGE_PIN G6  IOSTANDARD LVCMOS33 } [get_ports { rgb_led[2] }]; #IO_L19P_T3_35 Sch=led0_r
#set_property -dict { PACKAGE_PIN G4  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_b[1] }]; #IO_L20P_T3_35 Sch=led1_b
#set_property -dict { PACKAGE_PIN J4  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_g[1] }]; #IO_L21P_T3_DQS_35 Sch=led1_g
#set_property -dict { PACKAGE_PIN G3  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_r[1] }]; #IO_L20N_T3_35 Sch=led1_r
#set_property -dict { PACKAGE_PIN H4  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_b[2] }]; #IO_L21N_T3_DQS_35 Sch=led2_b
#set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_g[2] }]; #IO_L22N_T3_35 Sch=led2_g
#set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_r[2] }]; #IO_L22P_T3_35 Sch=led2_r
#set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_b[3] }]; #IO_L23P_T3_35 Sch=led3_b
#set_property -dict { PACKAGE_PIN H6  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_g[3] }]; #IO_L24P_T3_35 Sch=led3_g
#set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports { rgb_led_r[3] }]; #IO_L23N_T3_35 Sch=led3_r


#Buttons

set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {usr_btn[0]}]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports {usr_btn[1]}]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports {usr_btn[2]}]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports {usr_btn[3]}]

#UART
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports uart_rx]

##ChipKit Digital I/O Low

#set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { ck_io[0] }]; #IO_L16P_T2_CSI_B_14 Sch=ck_io[0]
#set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { ck_io[1] }]; #IO_L18P_T2_A12_D28_14 Sch=ck_io[1]
#set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { ck_io[2] }]; #IO_L8N_T1_D12_14 Sch=ck_io[2]
#set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { ck_io[3] }]; #IO_L19P_T3_A10_D26_14 Sch=ck_io[3]
#set_property -dict { PACKAGE_PIN R12 IOSTANDARD LVCMOS33 } [get_ports { ck_io[4] }]; #IO_L5P_T0_D06_14 Sch=ck_io[4]
#set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { ck_io[5] }]; #IO_L14P_T2_SRCC_14 Sch=ck_io[5]
#set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports { ck_io[6] }]; #IO_L14N_T2_SRCC_14 Sch=ck_io[6]
#set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { LCD_E }]; #IO_L15N_T2_DQS_DOUT_CSO_B_14 Sch=ck_io[7]
#set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports { LCD_RW }]; #IO_L11P_T1_SRCC_14 Sch=ck_io[8]
#set_property -dict { PACKAGE_PIN M16 IOSTANDARD LVCMOS33 } [get_ports { LCD_RS }]; #IO_L10P_T1_D14_14 Sch=ck_io[9]
#set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { LCD_D[3] }]; #IO_L18N_T2_A11_D27_14 Sch=ck_io[10]
#set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { LCD_D[2] }]; #IO_L17N_T2_A13_D29_14 Sch=ck_io[11]
#set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { LCD_D[1] }]; #IO_L12N_T1_MRCC_14 Sch=ck_io[12]
#set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports { LCD_D[0] }]; #IO_L12P_T1_MRCC_14 Sch=ck_io[13]

##ChipKit Digital I/O High

#set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports { ck_io[26] }]; #IO_L19N_T3_A09_D25_VREF_14 Sch=ck_io[26]
#set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { ck_io[27] }]; #IO_L16N_T2_A15_D31_14 Sch=ck_io[27]
#set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { VGA_HSYNC }]; #IO_L6N_T0_D08_VREF_14 Sch=ck_io[28]
#set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports { VGA_VSYNC }]; #IO_25_14 Sch=ck_io[29]
#set_property -dict { PACKAGE_PIN R11 IOSTANDARD LVCMOS33 } [get_ports { VGA_GREEN[0] }]; #IO_0_14 Sch=ck_io[30]
#set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports { VGA_GREEN[1] }]; #IO_L5N_T0_D07_14 Sch=ck_io[31]
#set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports { VGA_GREEN[2] }]; #IO_L13N_T2_MRCC_14 Sch=ck_io[32]
#set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { VGA_GREEN[3] }]; #IO_L13P_T2_MRCC_14 Sch=ck_io[33]
#set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports { VGA_BLUE[0] }]; #IO_L15P_T2_DQS_RDWR_B_14 Sch=ck_io[34]
#set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { VGA_BLUE[1] }]; #IO_L11N_T1_SRCC_14 Sch=ck_io[35]
#set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { VGA_BLUE[2] }]; #IO_L8P_T1_D11_14 Sch=ck_io[36]
#set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { VGA_BLUE[3] }]; #IO_L17P_T2_A14_D30_14 Sch=ck_io[37]
#set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { VGA_RED[0] }]; #IO_L7N_T1_D10_14 Sch=ck_io[38]
#set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { VGA_RED[1] }]; #IO_L7P_T1_D09_14 Sch=ck_io[39]
#set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { VGA_RED[2] }]; #IO_L9N_T1_DQS_D13_14 Sch=ck_io[40]
#set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { VGA_RED[3] }]; #IO_L9P_T1_DQS_14 Sch=ck_io[41]

##Misc. ChipKit signals

#set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { ck_ioa }]; #IO_L10N_T1_D15_14 Sch=ck_ioa
#set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { ck_rst }]; #IO_L16P_T2_35 Sch=ck_rst

## ChipKit SPI

set_property -dict {PACKAGE_PIN F4 IOSTANDARD LVCMOS33} [get_ports spi_miso]
set_property -dict {PACKAGE_PIN D3 IOSTANDARD LVCMOS33} [get_ports spi_mosi]
set_property -dict {PACKAGE_PIN F3 IOSTANDARD LVCMOS33} [get_ports spi_sck]
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports spi_ss]


## ChipKit I2C

#set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }]; #IO_L4P_T0_D04_14 Sch=ck_scl
#set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }]; #IO_L4N_T0_D05_14 Sch=ck_sda
#set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports { scl_pup }]; #IO_L9N_T1_DQS_AD3N_15 Sch=scl_pup
#set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS33 } [get_ports { sda_pup }]; #IO_L9P_T1_DQS_AD3P_15 Sch=sda_pup


##SMSC Ethernet PHY

#set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { eth_col }]; #IO_L16N_T2_A27_15 Sch=eth_col
#set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { eth_crs }]; #IO_L15N_T2_DQS_ADV_B_15 Sch=eth_crs
#set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { eth_mdc }]; #IO_L14N_T2_SRCC_15 Sch=eth_mdc
#set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { eth_mdio }]; #IO_L17P_T2_A26_15 Sch=eth_mdio
#set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { eth_ref_clk }]; #IO_L22P_T3_A17_15 Sch=eth_ref_clk
#set_property -dict { PACKAGE_PIN C16   IOSTANDARD LVCMOS33 } [get_ports { eth_rstn }]; #IO_L20P_T3_A20_15 Sch=eth_rstn
#set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { eth_rx_clk }]; #IO_L14P_T2_SRCC_15 Sch=eth_rx_clk
#set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { eth_rx_dv }]; #IO_L13N_T2_MRCC_15 Sch=eth_rx_dv
#set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[0] }]; #IO_L21N_T3_DQS_A18_15 Sch=eth_rxd[0]
#set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[1] }]; #IO_L16P_T2_A28_15 Sch=eth_rxd[1]
#set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[2] }]; #IO_L21P_T3_DQS_15 Sch=eth_rxd[2]
#set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxd[3] }]; #IO_L18N_T2_A23_15 Sch=eth_rxd[3]
#set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { eth_rxerr }]; #IO_L20N_T3_A19_15 Sch=eth_rxerr
#set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { eth_tx_clk }]; #IO_L13P_T2_MRCC_15 Sch=eth_tx_clk
#set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { eth_tx_en }]; #IO_L19N_T3_A21_VREF_15 Sch=eth_tx_en
#set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[0] }]; #IO_L15P_T2_DQS_15 Sch=eth_txd[0]
#set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[1] }]; #IO_L19P_T3_A22_15 Sch=eth_txd[1]
#set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[2] }]; #IO_L17N_T2_A25_15 Sch=eth_txd[2]
#set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[3] }]; #IO_L18P_T2_A24_15 Sch=eth_txd[3]


##Quad SPI Flash

#set_property -dict { PACKAGE_PIN L13   IOSTANDARD LVCMOS33 } [get_ports { qspi_cs }]; #IO_L6P_T0_FCS_B_14 Sch=qspi_cs
#set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[0] }]; #IO_L1P_T0_D00_MOSI_14 Sch=qspi_dq[0]
#set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[1] }]; #IO_L1N_T0_D01_DIN_14 Sch=qspi_dq[1]
#set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[2] }]; #IO_L2P_T0_D02_14 Sch=qspi_dq[2]
#set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { qspi_dq[3] }]; #IO_L2N_T0_D03_14 Sch=qspi_dq[3]


##ChipKit Analog I/O (in Digital I/O mode)

#set_property -dict { PACKAGE_PIN F5 IOSTANDARD LVCMOS33 } [get_ports { ck_A[0] }]; # Sch=ck_A0
#set_property -dict { PACKAGE_PIN D8 IOSTANDARD LVCMOS33 } [get_ports { ck_A[1] }]; # Sch=ck_A1
#set_property -dict { PACKAGE_PIN C7 IOSTANDARD LVCMOS33 } [get_ports { ck_A[2] }]; # Sch=ck_A2
#set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 } [get_ports { ck_A[3] }]; # Sch=ck_A3
#set_property -dict { PACKAGE_PIN D7 IOSTANDARD LVCMOS33 } [get_ports { ck_A[4] }]; # Sch=ck_A4
#set_property -dict { PACKAGE_PIN D5 IOSTANDARD LVCMOS33 } [get_ports { ck_A[5] }]; # Sch=ck_A5
#set_property -dict { PACKAGE_PIN B7 IOSTANDARD LVCMOS33 } [get_ports { ck_A[6] }]; # Sch=ck_A6
#set_property -dict { PACKAGE_PIN B6 IOSTANDARD LVCMOS33 } [get_ports { ck_A[7] }]; # Sch=ck_A7
#set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS33 } [get_ports { ck_A[8] }]; # Sch=ck_A8
#set_property -dict { PACKAGE_PIN E5 IOSTANDARD LVCMOS33 } [get_ports { ck_A[9] }]; # Sch=ck_A9
#set_property -dict { PACKAGE_PIN A4 IOSTANDARD LVCMOS33 } [get_ports { ck_A[10] }]; # Sch=ck_A10
#set_property -dict { PACKAGE_PIN A3 IOSTANDARD LVCMOS33 } [get_ports { ck_A[11] }]; # Sch=ck_A11


##Power Analysis

#set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33 } [get_ports { sns0v_n[95] }]; #IO_L8N_T1_AD10N_15 Sch=sns0v_n[95]
#set_property -dict { PACKAGE_PIN A15   IOSTANDARD LVCMOS33 } [get_ports { sns0v_p[95] }]; #IO_L8P_T1_AD10P_15 Sch=sns0v_p[95]
#set_property -dict { PACKAGE_PIN F14   IOSTANDARD LVCMOS33 } [get_ports { sns5v_n[0] }]; #IO_L5N_T0_AD9N_15 Sch=sns5v_n[0]
#set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33 } [get_ports { sns5v_p[0] }]; #IO_L5P_T0_AD9P_15 Sch=sns5v_p[0]
#set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { vsns5v[0] }]; #IO_L3P_T0_DQS_AD1P_15 Sch=vsns5v[0]
#set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports { vsnsvu }]; #IO_L7P_T1_AD2P_15 Sch=vsnsvu

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]






















connect_debug_port u_ila_0/probe2 [get_nets [list {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[0]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[1]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[2]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[3]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[4]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[5]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[6]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[7]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[8]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[9]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[10]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[11]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[12]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[13]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[14]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[15]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[16]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[17]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[18]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[19]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[20]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[21]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[22]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[23]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[24]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[25]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[26]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[27]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[28]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[29]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[30]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataA[31]}]]
connect_debug_port u_ila_0/probe3 [get_nets [list {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[0]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[1]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[2]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[3]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[4]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[5]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[6]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[7]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[8]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[9]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[10]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[11]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[12]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[13]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[14]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[15]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[16]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[17]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[18]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[19]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[20]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[21]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[22]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[23]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[24]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[25]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[26]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[27]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[28]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[29]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[30]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataB[31]}]]
connect_debug_port u_ila_0/probe4 [get_nets [list {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[0]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[1]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[2]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[3]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[4]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[5]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[6]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[7]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[8]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[9]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[10]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[11]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[12]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[13]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[14]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[15]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[16]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[17]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[18]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[19]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[20]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[21]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[22]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[23]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[24]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[25]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[26]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[27]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[28]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[29]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[30]} {Conv3D_Accelerator_Simple/conv_fma_feed_dataC[31]}]]
connect_debug_port u_ila_0/probe8 [get_nets [list {Conv3D_Accelerator_Simple/conv_fma_result_reg[0]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[1]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[2]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[3]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[4]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[5]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[6]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[7]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[8]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[9]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[10]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[11]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[12]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[13]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[14]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[15]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[16]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[17]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[18]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[19]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[20]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[21]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[22]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[23]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[24]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[25]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[26]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[27]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[28]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[29]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[30]} {Conv3D_Accelerator_Simple/conv_fma_result_reg[31]}]]
connect_debug_port u_ila_0/probe13 [get_nets [list Conv3D_Accelerator_Simple/conv_fma_data_valid]]



connect_debug_port u_ila_0/probe2 [get_nets [list {Conv3D_Accelerator_Simple/S[0]} {Conv3D_Accelerator_Simple/S[1]} {Conv3D_Accelerator_Simple/S[2]}]]
connect_debug_port u_ila_0/probe3 [get_nets [list {Conv3D_Accelerator_Simple/S_NEXT[0]} {Conv3D_Accelerator_Simple/S_NEXT[1]} {Conv3D_Accelerator_Simple/S_NEXT[2]}]]
connect_debug_port u_ila_0/probe4 [get_nets [list {Conv3D_Accelerator_Simple/conv_dot_result_data[0]} {Conv3D_Accelerator_Simple/conv_dot_result_data[1]} {Conv3D_Accelerator_Simple/conv_dot_result_data[2]} {Conv3D_Accelerator_Simple/conv_dot_result_data[3]} {Conv3D_Accelerator_Simple/conv_dot_result_data[4]} {Conv3D_Accelerator_Simple/conv_dot_result_data[5]} {Conv3D_Accelerator_Simple/conv_dot_result_data[6]} {Conv3D_Accelerator_Simple/conv_dot_result_data[7]} {Conv3D_Accelerator_Simple/conv_dot_result_data[8]} {Conv3D_Accelerator_Simple/conv_dot_result_data[9]} {Conv3D_Accelerator_Simple/conv_dot_result_data[10]} {Conv3D_Accelerator_Simple/conv_dot_result_data[11]} {Conv3D_Accelerator_Simple/conv_dot_result_data[12]} {Conv3D_Accelerator_Simple/conv_dot_result_data[13]} {Conv3D_Accelerator_Simple/conv_dot_result_data[14]} {Conv3D_Accelerator_Simple/conv_dot_result_data[15]} {Conv3D_Accelerator_Simple/conv_dot_result_data[16]} {Conv3D_Accelerator_Simple/conv_dot_result_data[17]} {Conv3D_Accelerator_Simple/conv_dot_result_data[18]} {Conv3D_Accelerator_Simple/conv_dot_result_data[19]} {Conv3D_Accelerator_Simple/conv_dot_result_data[20]} {Conv3D_Accelerator_Simple/conv_dot_result_data[21]} {Conv3D_Accelerator_Simple/conv_dot_result_data[22]} {Conv3D_Accelerator_Simple/conv_dot_result_data[23]} {Conv3D_Accelerator_Simple/conv_dot_result_data[24]} {Conv3D_Accelerator_Simple/conv_dot_result_data[25]} {Conv3D_Accelerator_Simple/conv_dot_result_data[26]} {Conv3D_Accelerator_Simple/conv_dot_result_data[27]} {Conv3D_Accelerator_Simple/conv_dot_result_data[28]} {Conv3D_Accelerator_Simple/conv_dot_result_data[29]} {Conv3D_Accelerator_Simple/conv_dot_result_data[30]} {Conv3D_Accelerator_Simple/conv_dot_result_data[31]}]]
connect_debug_port u_ila_0/probe5 [get_nets [list {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[0]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[1]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[2]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[3]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[4]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[5]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[6]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[7]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[8]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[9]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[10]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[11]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[12]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[13]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[14]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[15]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[16]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[17]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[18]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[19]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[20]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[21]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[22]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[23]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[24]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[25]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[26]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[27]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[28]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[29]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[30]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataB[31]}]]
connect_debug_port u_ila_0/probe6 [get_nets [list {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[0]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[1]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[2]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[3]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[4]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[5]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[6]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[7]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[8]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[9]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[10]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[11]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[12]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[13]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[14]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[15]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[16]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[17]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[18]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[19]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[20]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[21]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[22]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[23]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[24]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[25]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[26]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[27]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[28]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[29]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[30]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataA[31]}]]
connect_debug_port u_ila_0/probe7 [get_nets [list {Conv3D_Accelerator_Simple/conv_compute_cycles[0]} {Conv3D_Accelerator_Simple/conv_compute_cycles[1]} {Conv3D_Accelerator_Simple/conv_compute_cycles[2]} {Conv3D_Accelerator_Simple/conv_compute_cycles[3]} {Conv3D_Accelerator_Simple/conv_compute_cycles[4]} {Conv3D_Accelerator_Simple/conv_compute_cycles[5]} {Conv3D_Accelerator_Simple/conv_compute_cycles[6]} {Conv3D_Accelerator_Simple/conv_compute_cycles[7]} {Conv3D_Accelerator_Simple/conv_compute_cycles[8]} {Conv3D_Accelerator_Simple/conv_compute_cycles[9]} {Conv3D_Accelerator_Simple/conv_compute_cycles[10]} {Conv3D_Accelerator_Simple/conv_compute_cycles[11]} {Conv3D_Accelerator_Simple/conv_compute_cycles[12]} {Conv3D_Accelerator_Simple/conv_compute_cycles[13]} {Conv3D_Accelerator_Simple/conv_compute_cycles[14]} {Conv3D_Accelerator_Simple/conv_compute_cycles[15]} {Conv3D_Accelerator_Simple/conv_compute_cycles[16]} {Conv3D_Accelerator_Simple/conv_compute_cycles[17]} {Conv3D_Accelerator_Simple/conv_compute_cycles[18]} {Conv3D_Accelerator_Simple/conv_compute_cycles[19]} {Conv3D_Accelerator_Simple/conv_compute_cycles[20]} {Conv3D_Accelerator_Simple/conv_compute_cycles[21]} {Conv3D_Accelerator_Simple/conv_compute_cycles[22]} {Conv3D_Accelerator_Simple/conv_compute_cycles[23]} {Conv3D_Accelerator_Simple/conv_compute_cycles[24]} {Conv3D_Accelerator_Simple/conv_compute_cycles[25]} {Conv3D_Accelerator_Simple/conv_compute_cycles[26]} {Conv3D_Accelerator_Simple/conv_compute_cycles[27]} {Conv3D_Accelerator_Simple/conv_compute_cycles[28]} {Conv3D_Accelerator_Simple/conv_compute_cycles[29]} {Conv3D_Accelerator_Simple/conv_compute_cycles[30]} {Conv3D_Accelerator_Simple/conv_compute_cycles[31]}]]
connect_debug_port u_ila_0/probe8 [get_nets [list {Conv3D_Accelerator_Simple/data_o[0]} {Conv3D_Accelerator_Simple/data_o[1]} {Conv3D_Accelerator_Simple/data_o[2]} {Conv3D_Accelerator_Simple/data_o[3]} {Conv3D_Accelerator_Simple/data_o[4]} {Conv3D_Accelerator_Simple/data_o[5]} {Conv3D_Accelerator_Simple/data_o[6]} {Conv3D_Accelerator_Simple/data_o[7]} {Conv3D_Accelerator_Simple/data_o[8]} {Conv3D_Accelerator_Simple/data_o[9]} {Conv3D_Accelerator_Simple/data_o[10]} {Conv3D_Accelerator_Simple/data_o[11]} {Conv3D_Accelerator_Simple/data_o[12]} {Conv3D_Accelerator_Simple/data_o[13]} {Conv3D_Accelerator_Simple/data_o[14]} {Conv3D_Accelerator_Simple/data_o[15]} {Conv3D_Accelerator_Simple/data_o[16]} {Conv3D_Accelerator_Simple/data_o[17]} {Conv3D_Accelerator_Simple/data_o[18]} {Conv3D_Accelerator_Simple/data_o[19]} {Conv3D_Accelerator_Simple/data_o[20]} {Conv3D_Accelerator_Simple/data_o[21]} {Conv3D_Accelerator_Simple/data_o[22]} {Conv3D_Accelerator_Simple/data_o[23]} {Conv3D_Accelerator_Simple/data_o[24]} {Conv3D_Accelerator_Simple/data_o[25]} {Conv3D_Accelerator_Simple/data_o[26]} {Conv3D_Accelerator_Simple/data_o[27]} {Conv3D_Accelerator_Simple/data_o[28]} {Conv3D_Accelerator_Simple/data_o[29]} {Conv3D_Accelerator_Simple/data_o[30]} {Conv3D_Accelerator_Simple/data_o[31]}]]
connect_debug_port u_ila_0/probe9 [get_nets [list {Conv3D_Accelerator_Simple/fc_layer_cycles[0]} {Conv3D_Accelerator_Simple/fc_layer_cycles[1]} {Conv3D_Accelerator_Simple/fc_layer_cycles[2]} {Conv3D_Accelerator_Simple/fc_layer_cycles[3]} {Conv3D_Accelerator_Simple/fc_layer_cycles[4]} {Conv3D_Accelerator_Simple/fc_layer_cycles[5]} {Conv3D_Accelerator_Simple/fc_layer_cycles[6]} {Conv3D_Accelerator_Simple/fc_layer_cycles[7]} {Conv3D_Accelerator_Simple/fc_layer_cycles[8]} {Conv3D_Accelerator_Simple/fc_layer_cycles[9]} {Conv3D_Accelerator_Simple/fc_layer_cycles[10]} {Conv3D_Accelerator_Simple/fc_layer_cycles[11]} {Conv3D_Accelerator_Simple/fc_layer_cycles[12]} {Conv3D_Accelerator_Simple/fc_layer_cycles[13]} {Conv3D_Accelerator_Simple/fc_layer_cycles[14]} {Conv3D_Accelerator_Simple/fc_layer_cycles[15]} {Conv3D_Accelerator_Simple/fc_layer_cycles[16]} {Conv3D_Accelerator_Simple/fc_layer_cycles[17]} {Conv3D_Accelerator_Simple/fc_layer_cycles[18]} {Conv3D_Accelerator_Simple/fc_layer_cycles[19]} {Conv3D_Accelerator_Simple/fc_layer_cycles[20]} {Conv3D_Accelerator_Simple/fc_layer_cycles[21]} {Conv3D_Accelerator_Simple/fc_layer_cycles[22]} {Conv3D_Accelerator_Simple/fc_layer_cycles[23]} {Conv3D_Accelerator_Simple/fc_layer_cycles[24]} {Conv3D_Accelerator_Simple/fc_layer_cycles[25]} {Conv3D_Accelerator_Simple/fc_layer_cycles[26]} {Conv3D_Accelerator_Simple/fc_layer_cycles[27]} {Conv3D_Accelerator_Simple/fc_layer_cycles[28]} {Conv3D_Accelerator_Simple/fc_layer_cycles[29]} {Conv3D_Accelerator_Simple/fc_layer_cycles[30]} {Conv3D_Accelerator_Simple/fc_layer_cycles[31]}]]
connect_debug_port u_ila_0/probe10 [get_nets [list {Conv3D_Accelerator_Simple/pool_layer_cycles[0]} {Conv3D_Accelerator_Simple/pool_layer_cycles[1]} {Conv3D_Accelerator_Simple/pool_layer_cycles[2]} {Conv3D_Accelerator_Simple/pool_layer_cycles[3]} {Conv3D_Accelerator_Simple/pool_layer_cycles[4]} {Conv3D_Accelerator_Simple/pool_layer_cycles[5]} {Conv3D_Accelerator_Simple/pool_layer_cycles[6]} {Conv3D_Accelerator_Simple/pool_layer_cycles[7]} {Conv3D_Accelerator_Simple/pool_layer_cycles[8]} {Conv3D_Accelerator_Simple/pool_layer_cycles[9]} {Conv3D_Accelerator_Simple/pool_layer_cycles[10]} {Conv3D_Accelerator_Simple/pool_layer_cycles[11]} {Conv3D_Accelerator_Simple/pool_layer_cycles[12]} {Conv3D_Accelerator_Simple/pool_layer_cycles[13]} {Conv3D_Accelerator_Simple/pool_layer_cycles[14]} {Conv3D_Accelerator_Simple/pool_layer_cycles[15]} {Conv3D_Accelerator_Simple/pool_layer_cycles[16]} {Conv3D_Accelerator_Simple/pool_layer_cycles[17]} {Conv3D_Accelerator_Simple/pool_layer_cycles[18]} {Conv3D_Accelerator_Simple/pool_layer_cycles[19]} {Conv3D_Accelerator_Simple/pool_layer_cycles[20]} {Conv3D_Accelerator_Simple/pool_layer_cycles[21]} {Conv3D_Accelerator_Simple/pool_layer_cycles[22]} {Conv3D_Accelerator_Simple/pool_layer_cycles[23]} {Conv3D_Accelerator_Simple/pool_layer_cycles[24]} {Conv3D_Accelerator_Simple/pool_layer_cycles[25]} {Conv3D_Accelerator_Simple/pool_layer_cycles[26]} {Conv3D_Accelerator_Simple/pool_layer_cycles[27]} {Conv3D_Accelerator_Simple/pool_layer_cycles[28]} {Conv3D_Accelerator_Simple/pool_layer_cycles[29]} {Conv3D_Accelerator_Simple/pool_layer_cycles[30]} {Conv3D_Accelerator_Simple/pool_layer_cycles[31]}]]
connect_debug_port u_ila_0/probe11 [get_nets [list {Conv3D_Accelerator_Simple/conv_copypad_cycles[0]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[1]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[2]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[3]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[4]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[5]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[6]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[7]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[8]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[9]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[10]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[11]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[12]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[13]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[14]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[15]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[16]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[17]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[18]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[19]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[20]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[21]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[22]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[23]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[24]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[25]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[26]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[27]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[28]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[29]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[30]} {Conv3D_Accelerator_Simple/conv_copypad_cycles[31]}]]
connect_debug_port u_ila_0/probe12 [get_nets [list {Conv3D_Accelerator_Simple/conv_layer_cycles[0]} {Conv3D_Accelerator_Simple/conv_layer_cycles[1]} {Conv3D_Accelerator_Simple/conv_layer_cycles[2]} {Conv3D_Accelerator_Simple/conv_layer_cycles[3]} {Conv3D_Accelerator_Simple/conv_layer_cycles[4]} {Conv3D_Accelerator_Simple/conv_layer_cycles[5]} {Conv3D_Accelerator_Simple/conv_layer_cycles[6]} {Conv3D_Accelerator_Simple/conv_layer_cycles[7]} {Conv3D_Accelerator_Simple/conv_layer_cycles[8]} {Conv3D_Accelerator_Simple/conv_layer_cycles[9]} {Conv3D_Accelerator_Simple/conv_layer_cycles[10]} {Conv3D_Accelerator_Simple/conv_layer_cycles[11]} {Conv3D_Accelerator_Simple/conv_layer_cycles[12]} {Conv3D_Accelerator_Simple/conv_layer_cycles[13]} {Conv3D_Accelerator_Simple/conv_layer_cycles[14]} {Conv3D_Accelerator_Simple/conv_layer_cycles[15]} {Conv3D_Accelerator_Simple/conv_layer_cycles[16]} {Conv3D_Accelerator_Simple/conv_layer_cycles[17]} {Conv3D_Accelerator_Simple/conv_layer_cycles[18]} {Conv3D_Accelerator_Simple/conv_layer_cycles[19]} {Conv3D_Accelerator_Simple/conv_layer_cycles[20]} {Conv3D_Accelerator_Simple/conv_layer_cycles[21]} {Conv3D_Accelerator_Simple/conv_layer_cycles[22]} {Conv3D_Accelerator_Simple/conv_layer_cycles[23]} {Conv3D_Accelerator_Simple/conv_layer_cycles[24]} {Conv3D_Accelerator_Simple/conv_layer_cycles[25]} {Conv3D_Accelerator_Simple/conv_layer_cycles[26]} {Conv3D_Accelerator_Simple/conv_layer_cycles[27]} {Conv3D_Accelerator_Simple/conv_layer_cycles[28]} {Conv3D_Accelerator_Simple/conv_layer_cycles[29]} {Conv3D_Accelerator_Simple/conv_layer_cycles[30]} {Conv3D_Accelerator_Simple/conv_layer_cycles[31]}]]
connect_debug_port u_ila_0/probe13 [get_nets [list {Conv3D_Accelerator_Simple/data_i[0]} {Conv3D_Accelerator_Simple/data_i[1]} {Conv3D_Accelerator_Simple/data_i[2]} {Conv3D_Accelerator_Simple/data_i[3]} {Conv3D_Accelerator_Simple/data_i[4]} {Conv3D_Accelerator_Simple/data_i[5]} {Conv3D_Accelerator_Simple/data_i[6]} {Conv3D_Accelerator_Simple/data_i[7]} {Conv3D_Accelerator_Simple/data_i[8]} {Conv3D_Accelerator_Simple/data_i[9]} {Conv3D_Accelerator_Simple/data_i[10]} {Conv3D_Accelerator_Simple/data_i[11]} {Conv3D_Accelerator_Simple/data_i[12]} {Conv3D_Accelerator_Simple/data_i[13]} {Conv3D_Accelerator_Simple/data_i[14]} {Conv3D_Accelerator_Simple/data_i[15]} {Conv3D_Accelerator_Simple/data_i[16]} {Conv3D_Accelerator_Simple/data_i[17]} {Conv3D_Accelerator_Simple/data_i[18]} {Conv3D_Accelerator_Simple/data_i[19]} {Conv3D_Accelerator_Simple/data_i[20]} {Conv3D_Accelerator_Simple/data_i[21]} {Conv3D_Accelerator_Simple/data_i[22]} {Conv3D_Accelerator_Simple/data_i[23]} {Conv3D_Accelerator_Simple/data_i[24]} {Conv3D_Accelerator_Simple/data_i[25]} {Conv3D_Accelerator_Simple/data_i[26]} {Conv3D_Accelerator_Simple/data_i[27]} {Conv3D_Accelerator_Simple/data_i[28]} {Conv3D_Accelerator_Simple/data_i[29]} {Conv3D_Accelerator_Simple/data_i[30]} {Conv3D_Accelerator_Simple/data_i[31]}]]
connect_debug_port u_ila_0/probe14 [get_nets [list {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[0]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[1]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[2]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[3]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[4]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[5]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[6]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[7]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[8]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[9]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[10]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[11]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[12]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[13]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[14]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[15]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[16]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[17]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[18]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[19]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[20]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[21]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[22]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[23]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[24]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[25]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[26]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[27]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[28]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[29]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[30]} {Conv3D_Accelerator_Simple/conv_dot_feed_dataC[31]}]]
connect_debug_port u_ila_0/probe15 [get_nets [list Conv3D_Accelerator_Simple/conv_compute_active]]
connect_debug_port u_ila_0/probe16 [get_nets [list Conv3D_Accelerator_Simple/conv_copypad_active]]
connect_debug_port u_ila_0/probe17 [get_nets [list Conv3D_Accelerator_Simple/conv_dot_data_valid]]
connect_debug_port u_ila_0/probe18 [get_nets [list Conv3D_Accelerator_Simple/conv_dot_result_valid]]
connect_debug_port u_ila_0/probe19 [get_nets [list Conv3D_Accelerator_Simple/conv_fma_busy]]
connect_debug_port u_ila_0/probe20 [get_nets [list Conv3D_Accelerator_Simple/conv_layer_active]]
connect_debug_port u_ila_0/probe21 [get_nets [list Conv3D_Accelerator_Simple/fc_fma_busy]]
connect_debug_port u_ila_0/probe22 [get_nets [list Conv3D_Accelerator_Simple/fc_layer_active]]
connect_debug_port u_ila_0/probe23 [get_nets [list Conv3D_Accelerator_Simple/pool_add_busy]]
connect_debug_port u_ila_0/probe24 [get_nets [list Conv3D_Accelerator_Simple/pool_layer_active]]
connect_debug_port u_ila_0/probe25 [get_nets [list Conv3D_Accelerator_Simple/pool_mul_busy]]




create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list Clock_Generator/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {Aquila_SoC/RISCV_CORE0/exe2mem_pc[0]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[1]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[2]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[3]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[4]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[5]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[6]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[7]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[8]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[9]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[10]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[11]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[12]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[13]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[14]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[15]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[16]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[17]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[18]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[19]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[20]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[21]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[22]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[23]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[24]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[25]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[26]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[27]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[28]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[29]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[30]} {Aquila_SoC/RISCV_CORE0/exe2mem_pc[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 2 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {Aquila_SoC/data_sel_r[0]} {Aquila_SoC/data_sel_r[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 32 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {DSA/conv_compute_cycles[0]} {DSA/conv_compute_cycles[1]} {DSA/conv_compute_cycles[2]} {DSA/conv_compute_cycles[3]} {DSA/conv_compute_cycles[4]} {DSA/conv_compute_cycles[5]} {DSA/conv_compute_cycles[6]} {DSA/conv_compute_cycles[7]} {DSA/conv_compute_cycles[8]} {DSA/conv_compute_cycles[9]} {DSA/conv_compute_cycles[10]} {DSA/conv_compute_cycles[11]} {DSA/conv_compute_cycles[12]} {DSA/conv_compute_cycles[13]} {DSA/conv_compute_cycles[14]} {DSA/conv_compute_cycles[15]} {DSA/conv_compute_cycles[16]} {DSA/conv_compute_cycles[17]} {DSA/conv_compute_cycles[18]} {DSA/conv_compute_cycles[19]} {DSA/conv_compute_cycles[20]} {DSA/conv_compute_cycles[21]} {DSA/conv_compute_cycles[22]} {DSA/conv_compute_cycles[23]} {DSA/conv_compute_cycles[24]} {DSA/conv_compute_cycles[25]} {DSA/conv_compute_cycles[26]} {DSA/conv_compute_cycles[27]} {DSA/conv_compute_cycles[28]} {DSA/conv_compute_cycles[29]} {DSA/conv_compute_cycles[30]} {DSA/conv_compute_cycles[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {DSA/conv_copypad_cycles[0]} {DSA/conv_copypad_cycles[1]} {DSA/conv_copypad_cycles[2]} {DSA/conv_copypad_cycles[3]} {DSA/conv_copypad_cycles[4]} {DSA/conv_copypad_cycles[5]} {DSA/conv_copypad_cycles[6]} {DSA/conv_copypad_cycles[7]} {DSA/conv_copypad_cycles[8]} {DSA/conv_copypad_cycles[9]} {DSA/conv_copypad_cycles[10]} {DSA/conv_copypad_cycles[11]} {DSA/conv_copypad_cycles[12]} {DSA/conv_copypad_cycles[13]} {DSA/conv_copypad_cycles[14]} {DSA/conv_copypad_cycles[15]} {DSA/conv_copypad_cycles[16]} {DSA/conv_copypad_cycles[17]} {DSA/conv_copypad_cycles[18]} {DSA/conv_copypad_cycles[19]} {DSA/conv_copypad_cycles[20]} {DSA/conv_copypad_cycles[21]} {DSA/conv_copypad_cycles[22]} {DSA/conv_copypad_cycles[23]} {DSA/conv_copypad_cycles[24]} {DSA/conv_copypad_cycles[25]} {DSA/conv_copypad_cycles[26]} {DSA/conv_copypad_cycles[27]} {DSA/conv_copypad_cycles[28]} {DSA/conv_copypad_cycles[29]} {DSA/conv_copypad_cycles[30]} {DSA/conv_copypad_cycles[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {DSA/conv_layer_cycles[0]} {DSA/conv_layer_cycles[1]} {DSA/conv_layer_cycles[2]} {DSA/conv_layer_cycles[3]} {DSA/conv_layer_cycles[4]} {DSA/conv_layer_cycles[5]} {DSA/conv_layer_cycles[6]} {DSA/conv_layer_cycles[7]} {DSA/conv_layer_cycles[8]} {DSA/conv_layer_cycles[9]} {DSA/conv_layer_cycles[10]} {DSA/conv_layer_cycles[11]} {DSA/conv_layer_cycles[12]} {DSA/conv_layer_cycles[13]} {DSA/conv_layer_cycles[14]} {DSA/conv_layer_cycles[15]} {DSA/conv_layer_cycles[16]} {DSA/conv_layer_cycles[17]} {DSA/conv_layer_cycles[18]} {DSA/conv_layer_cycles[19]} {DSA/conv_layer_cycles[20]} {DSA/conv_layer_cycles[21]} {DSA/conv_layer_cycles[22]} {DSA/conv_layer_cycles[23]} {DSA/conv_layer_cycles[24]} {DSA/conv_layer_cycles[25]} {DSA/conv_layer_cycles[26]} {DSA/conv_layer_cycles[27]} {DSA/conv_layer_cycles[28]} {DSA/conv_layer_cycles[29]} {DSA/conv_layer_cycles[30]} {DSA/conv_layer_cycles[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 32 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {DSA/fc_layer_cycles[0]} {DSA/fc_layer_cycles[1]} {DSA/fc_layer_cycles[2]} {DSA/fc_layer_cycles[3]} {DSA/fc_layer_cycles[4]} {DSA/fc_layer_cycles[5]} {DSA/fc_layer_cycles[6]} {DSA/fc_layer_cycles[7]} {DSA/fc_layer_cycles[8]} {DSA/fc_layer_cycles[9]} {DSA/fc_layer_cycles[10]} {DSA/fc_layer_cycles[11]} {DSA/fc_layer_cycles[12]} {DSA/fc_layer_cycles[13]} {DSA/fc_layer_cycles[14]} {DSA/fc_layer_cycles[15]} {DSA/fc_layer_cycles[16]} {DSA/fc_layer_cycles[17]} {DSA/fc_layer_cycles[18]} {DSA/fc_layer_cycles[19]} {DSA/fc_layer_cycles[20]} {DSA/fc_layer_cycles[21]} {DSA/fc_layer_cycles[22]} {DSA/fc_layer_cycles[23]} {DSA/fc_layer_cycles[24]} {DSA/fc_layer_cycles[25]} {DSA/fc_layer_cycles[26]} {DSA/fc_layer_cycles[27]} {DSA/fc_layer_cycles[28]} {DSA/fc_layer_cycles[29]} {DSA/fc_layer_cycles[30]} {DSA/fc_layer_cycles[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {DSA/pool_layer_cycles[0]} {DSA/pool_layer_cycles[1]} {DSA/pool_layer_cycles[2]} {DSA/pool_layer_cycles[3]} {DSA/pool_layer_cycles[4]} {DSA/pool_layer_cycles[5]} {DSA/pool_layer_cycles[6]} {DSA/pool_layer_cycles[7]} {DSA/pool_layer_cycles[8]} {DSA/pool_layer_cycles[9]} {DSA/pool_layer_cycles[10]} {DSA/pool_layer_cycles[11]} {DSA/pool_layer_cycles[12]} {DSA/pool_layer_cycles[13]} {DSA/pool_layer_cycles[14]} {DSA/pool_layer_cycles[15]} {DSA/pool_layer_cycles[16]} {DSA/pool_layer_cycles[17]} {DSA/pool_layer_cycles[18]} {DSA/pool_layer_cycles[19]} {DSA/pool_layer_cycles[20]} {DSA/pool_layer_cycles[21]} {DSA/pool_layer_cycles[22]} {DSA/pool_layer_cycles[23]} {DSA/pool_layer_cycles[24]} {DSA/pool_layer_cycles[25]} {DSA/pool_layer_cycles[26]} {DSA/pool_layer_cycles[27]} {DSA/pool_layer_cycles[28]} {DSA/pool_layer_cycles[29]} {DSA/pool_layer_cycles[30]} {DSA/pool_layer_cycles[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list DSA/conv_compute_active]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list DSA/conv_copypad_active]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list DSA/conv_layer_active]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list DSA/fc_layer_active]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list DSA/pool_layer_active]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list Aquila_SoC/RISCV_CORE0/rst_i]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
