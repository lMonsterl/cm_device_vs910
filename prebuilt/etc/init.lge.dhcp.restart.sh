#!/system/bin/sh
#DBGFILE="/data/dhcp_restart.log" 
debug() {
	case "$DBGFILE" in
		"")
		;;
	*)
		echo "`date`: $*" >> $DBGFILE
		;;
	esac
}
debug "---->script started<----"

slave=`getprop lge.dhcp.restart.slave`
case "$slave" in
	"" | 0)
		debug "Interface slave is NULL"
		;;
	*)
		debug "Running dhcp restart script for $slave"
		i=0
		indexes="0 1 2 3 4 5 6 7"
		for i in $indexes
		do
			interface="bond$i"
			debug "interface = $interface"
			slaves=`cat /sys/class/net/$interface/bonding/slaves`
			case "$slaves" in
				"" | 0)
					continue
					;;
				*)
					active_slave=`cat /sys/class/net/$interface/bonding/active_slave`
					debug "active_slave = $active_slave"
					case "$active_slave" in
						"$slave")
							MMRIL_CONF_PATH="/data/mmril"
							if ls $MMRIL_CONF_PATH/lge.netmgr.$interface.ipv4_type
							then 
								case "$interface" in
									"bond0")
										;;
									*)
										netcfg $interface resetconn
										ifconfig $interface down
										debug "ifconfig $interface down"
										;;
								esac
								ipv4_type=`cat $MMRIL_CONF_PATH/lge.netmgr.$interface.ipv4_type`
								debug "ipv4_type = $ipv4_type"
								case "$ipv4_type" in
									"auto")
										debug "Run DHCP on $interface"
										netcfg $interface dhcp &
										;;
									"manual")
										debug "Manual configuration of $interface"
										addr=`cat $MMRIL_CONF_PATH/lge.netmgr.$interface.ipv4_addr`
										mask=`cat $MMRIL_CONF_PATH/lge.netmgr.$interface.ipv4_mask`
										gw=`cat $MMRIL_CONF_PATH/lge.netmgr.$interface.ipv4_gw`
										dns=`cat $MMRIL_CONF_PATH/lge.netmgr.$interface.ipv4_dns`
										debug "Manual configuration of $interface: addr=$addr, mask=$mask, gw=$gw, dns=$dns"
										ifconfig $interface $addr $mask
										case "$interface" in
											"bond1")
												route add default gw $gw dev $interface
												;;
										esac
										;;
									"")
										case "$interface" in
											"bond0")
												netcfg $interface resetconn
												ip -6 neigh flush dev bond0
												bond0_oldprefix=`cat $MMRIL_CONF_PATH/lge.dhcp.bond0.old_prefix`
												bond0_iid=`cat $MMRIL_CONF_PATH/lge.dhcp.bond0.iid`
												bond0_newprefix=`cat $MMRIL_CONF_PATH/lge.dhcp.bond0.new_prefix`
												ip -6 addr add $bond0_newprefix":"$bond0_iid/64 dev bond0
												ip -6 addr delete $bond0_oldprefix":"$bond0_iid/64 dev bond0
												ip -6 addr delete fe80::5 dev bond0
												ip -6 addr add fe80::5 dev bond0
												setprop net.ims.bond0_addr $bond0_newprefix":"$bond0_iid
												cat $MMRIL_CONF_PATH/lge.dhcp.bond0.new_prefix > $MMRIL_CONF_PATH/lge.dhcp.bond0.old_prefix
												echo $bond0_newprefix":"$bond0_iid > $MMRIL_CONF_PATH/lge.dhcp.bond0.resync_addr
												;;
											"bond2")
												debug "Bringing interface $interface up"
												ifconfig bond2 up
												ip -6 addr delete fe80::5 dev bond2
												ip -6 addr add fe80::5 dev bond2
												ip -6 ro add ::/0 via fe80::1234:1234:1234 metric 512 dev bond2
												;;
											*)
												debug "Bringing interface $interface up"
												ifconfig $interface up
												ip -6 addr delete fe80::5 dev $interface
												ip -6 addr add fe80::5 dev $interface
												;;
										 esac
										;;
								esac
							else
								debug "Interface" $interface "seems does not started"
							fi
						;;
						esac
					;;
			esac
		done
		;;
esac
setprop lge.dhcp.restart.run 0
debug "Script ended ------>"