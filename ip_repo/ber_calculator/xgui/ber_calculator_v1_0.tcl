# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BE_CNT_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "BYTE_NUM" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DATA_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to update ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ADDR_WIDTH { PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to validate ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.BE_CNT_WIDTH { PARAM_VALUE.BE_CNT_WIDTH } {
	# Procedure called to update BE_CNT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BE_CNT_WIDTH { PARAM_VALUE.BE_CNT_WIDTH } {
	# Procedure called to validate BE_CNT_WIDTH
	return true
}

proc update_PARAM_VALUE.BYTE_NUM { PARAM_VALUE.BYTE_NUM } {
	# Procedure called to update BYTE_NUM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BYTE_NUM { PARAM_VALUE.BYTE_NUM } {
	# Procedure called to validate BYTE_NUM
	return true
}

proc update_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to update DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_WIDTH { PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to validate DATA_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.BYTE_NUM { MODELPARAM_VALUE.BYTE_NUM PARAM_VALUE.BYTE_NUM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BYTE_NUM}] ${MODELPARAM_VALUE.BYTE_NUM}
}

proc update_MODELPARAM_VALUE.DATA_WIDTH { MODELPARAM_VALUE.DATA_WIDTH PARAM_VALUE.DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_WIDTH}] ${MODELPARAM_VALUE.DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.ADDR_WIDTH { MODELPARAM_VALUE.ADDR_WIDTH PARAM_VALUE.ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ADDR_WIDTH}] ${MODELPARAM_VALUE.ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.BE_CNT_WIDTH { MODELPARAM_VALUE.BE_CNT_WIDTH PARAM_VALUE.BE_CNT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BE_CNT_WIDTH}] ${MODELPARAM_VALUE.BE_CNT_WIDTH}
}

