# Settings relating to configuration memory, referring to schematic of CmodA7
# Pin "CFGBVS_0" is tied to VCC3V3 (pin V11). Configuration supply voltage is 3.3V.
# Comment re Nexys4 DDR board: "CFGBVS_0" is tied to VCC3V3 (pin P8).

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
