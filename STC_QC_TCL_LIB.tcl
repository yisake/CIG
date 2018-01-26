#package require stc
package require registry
set stcVersion 3.70
set stcDir [registry get [subst {HKEY_LOCAL_MACHINE\\SOFTWARE\\Spirent Communications\\Spirent TestCenter\\$stcVersion}] TARGETDIR]
set Title [registry get [subst {HKEY_LOCAL_MACHINE\\SOFTWARE\\Spirent Communications\\Spirent TestCenter\\$stcVersion\\Components\\Spirent TestCenter Application}] Title]

source $stcDir/$Title/SpirentTestCenter.tcl


#######add by hanxu start#########################
proc ReservePort {args} {
	set project [stc::create Project]
	set index [lsearch $args -stcPortList] 
	if {$index != -1} {
		set stcPortList [lindex $args [expr $index + 1]]
	} else  {
	}	
	
	for {set i 0} {$i < [llength $stcPortList]} {incr i} {
		set stcPort [lindex $stcPortList $i]
		set portH [stc::create Port -under $project -location //$stcPort]
		stc::perform attachPorts -portList [list $portH] -autoConnect TRUE 
		after 3000
		
		set analyzer [stc::get $portH -children-Analyzer]
		
		set txstreaminfo [stc::subscribe -parent $project \
										-configType StreamBlock \
										-resultType TxStreamResults
						]
		
		set txstreaminfo [stc::subscribe -parent $project \
										-configType StreamBlock \
										-resultType RxStreamBlockResults
						 ]
						
		set txstreaminfo [stc::subscribe -parent $project \
										-configType StreamBlock \
										-resultType RxStreamSummaryResults
						]
		
		set txstreaminfo [stc::subscribe -parent $project \
										-configType Analyzer \
										-resultType AnalyzerPortResults
						]
		
		set txstreaminfo [stc::subscribe -parent $project \
										-configType Generator \
										-resultType GeneratorPortResults
						]
						
		stc::perform AnalyzerStart -AnalyzerList $analyzer
		stc::apply
	}
}

proc ReleasePort {args} {
	set project [stc::create Project]
	set index [lsearch $args -stcPortList] 
	if {$index != -1} {
		set stcPortList [lindex $args [expr $index + 1]]
	} else  {
	}	
	
	for {set i 0} {$i < [llength $stcPortList]} {incr i} {
		set stcPort [lindex $stcPortList $i]
		set portH [stc::create Port -under $project -location //$stcPort]
		stc::perform attachPorts -portList [list $portH] -autoConnect FALSE
		after 3000
		
		stc::apply
	}
}
#######add by hanxu end#########################

proc LoadXmlFile {stcVersion xmlFile stcPorts} {
    if [catch {
        package require registry
        set stcDir [registry get [subst {HKEY_LOCAL_MACHINE\\SOFTWARE\\Spirent Communications\\Spirent TestCenter\\$stcVersion}] TARGETDIR]
        set Title [registry get [subst {HKEY_LOCAL_MACHINE\\SOFTWARE\\Spirent Communications\\Spirent TestCenter\\$stcVersion\\Components\\Spirent TestCenter Application}] Title]
        source $stcDir/$Title/SpirentTestCenter.tcl
    } errMsg ] {
            puts "���� SpirentTestCenter�ײ��ʧ��?: $errMsg\n��ȷ�������Ѱ�װSpirentTestCenter$stcVersion"
            return -1
    }
    stc::perform  loadfromxml -filename $xmlFile
    if {$stcPorts != "default"} {
        set hPortList [stc::get project1 -children-port]
        if {[llength $hPortList] != [llength $stcPorts]} {
            error "�����STC Port��Ŀ��XML�е�STC Port��Ŀ�����?����!"
        }
        set index -1
        foreach port $stcPorts {
            stc::config [lindex $hPortList [incr index]] -location $port
        }
    }
    stc::perform attachPorts -autoConnect true -portList [ stc::get project1 -children-Port ]
    SubscribeStcStats
    puts "LoadXmlFile completed!"
}
#######################
# Add by Aleon 1011/09/19
#######################
proc SaveAsXml {filename} {
	if {$filename != "none"} {
		set dir [file dirname $filename]
		if {[file isdirectory $dir] == 1} {
			stc::perform SaveAsXml -Config project1 -filename $filename 
			#wait 3
			puts "Save xml configuration file to $filename!"
		} else {
			error "This directory of file is not correct, please check it again!"
		}
	} else {
		stc::perform -Config project1 -SaveDefault true
		puts "Save xml configuration file to default."
	}
}

proc StartCapture {port} {
    set CaptureProxyId ""
    set hPortList [stc::get project1 -children-port]
    foreach ele $port {
        catch {
            lappend CaptureProxyId [lindex $hPortList [expr $ele - 1]]
        }
    }
    stc::perform CaptureStartCommand -CaptureProxyId $CaptureProxyId    
    puts "stc::perform CaptureStartCommand -CaptureProxyId $CaptureProxyId  "
}

proc StopCapture {port} {
    set CaptureProxyId ""
    set hPortList [stc::get project1 -children-port]
    foreach ele $port {
        catch {
            lappend CaptureProxyId [lindex $hPortList [expr $ele - 1]]
        }
    }
    stc::perform CaptureStopCommand -CaptureProxyId $CaptureProxyId  
    puts "stc::perform CaptureStopCommand -CaptureProxyId $CaptureProxyId  "
}


proc StartStcStream {streamNames} {
	if {$streamNames == "all"} { 
		 foreach hPort [stc::get project1 -children-port] {
			
			set generator [stc::get $hPort -children-Generator]
			set errorCode 1
			if {[catch {
				set state [stc::get $generator -state]
				if {$state == "STOPPED" } {
					set errorCode [stc::perform GeneratorStart -GeneratorList $generator  -ExecuteSynchronous TRUE  ]    
				} elseif {$state == "RUNNING"} {
                   #Stop first, then start again
                   puts "The generator of port: $hPort in running state, take actions to re-start it"
                   set errorCode [stc::perform GeneratorStop -GeneratorList $generator  -ExecuteSynchronous TRUE ]
                   after 1000 
                   set errorCode [stc::perform GeneratorStart -GeneratorList $generator  -ExecuteSynchronous TRUE ]
				}
             
				puts "Finish starting the traffic generator on $hPort ..."
			} err]} {
				puts "ERROR: $err"
			}
		}
		
	} else {
		foreach streamName $streamNames {
			set flag 0
			set streamName [string tolower $streamName]
			if {1} {
				foreach hPort [stc::get project1 -children-port] {
					foreach stream [stc::get $hPort -children-streamblock] {
						set name [stc::get $stream -name]
						set name [string tolower $name]
                    
						if {$name != $streamName} {
							continue
							puts =============
							puts streamName=$streamName
							set RunningState [stc::get $stream -RunningState]         
							puts $RunningState="stc::get $stream -RunningState"
							if {([string tolower $RunningState] == "stopped") || ([string tolower $RunningState] == "pending_stop")} {
								stc::config $stream -active false   
								puts "stc::config $stream -active false "
							}
                        
						}
                    
						stc::config $stream -active true     
						set flag 1
						set RunningState [stc::get $stream -RunningState]                    
						if {([string tolower $RunningState] == "stopped") || ([string tolower $RunningState] == "pending_stop")} {
							stc::perform StreamBlockStartCommand -StreamBlockList $stream 
							puts "stc::perform StreamBlockStartCommand -StreamBlockList $stream "  
						}
					}
				}
			}
			if {$flag == 0} {
				puts "error:$streamName not found!"
			}
		}
	}
}

proc StopStcStream {streamNames} {
	if {$streamNames == "all"} { 
		 foreach hPort [stc::get project1 -children-port] {
			
			set generator [stc::get $hPort -children-Generator]
			set errorCode 1
			if {[catch {
				set state [stc::get $generator -state]
				if {$state == "STOPPED" } {
					continue    
				} elseif {$state == "RUNNING"} {
                   #Stop first, then start again
                   set errorCode [stc::perform GeneratorStop -GeneratorList $generator  -ExecuteSynchronous TRUE ]
				}
             
				puts "Finish stopping the traffic generator on $hPort..."
			} err]} {
				puts "ERROR: $err"
			}
		}
		
	} else {
		foreach streamName $streamNames {
			set flag 0
			set streamName [string tolower $streamName]
			if {1} {
				foreach hPort [stc::get project1 -children-port] {
					foreach stream [stc::get $hPort -children-streamblock] {
						set name [stc::get $stream -name]
						set name [string tolower $name]
						if {$name != $streamName} {continue}
						set flag 1
						set RunningState [stc::get $stream -RunningState]
						if {([string tolower $RunningState] == "stopped") || ([string tolower $RunningState] == "pending_stop")} { continue}
						stc::perform StreamBlockStopCommand -StreamBlockList $stream 
						puts "stc::perform StreamBlockStopCommand -StreamBlockList $stream"                                           
						stc::config $stream -active false
					}
				}
			}
			if {$flag == 0} {
				puts "error:$streamName not found!"
			}
		}	
    }
}
proc ConfigStcStream {args} {
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }

    #����stream����
    set streamConfig ""
    if {[info exist arr(-load)]} {
        
        set list [split $arr(-load) %]
        if {[llength $list]>=2} {
            set load [lindex $list 0]
            set loadUnit "PERCENT_LINE_RATE"
        }

        set list [split $arr(-load) m]
        if {[llength $list]>=2} {
            set load [lindex $list 0]
            set loadUnit "MEGABITS_PER_SECOND"
        }

        set list [split $arr(-load) pps]
        if {[llength $list]>=2} {
            set load [lindex $list 0]
            set loadUnit "FRAMES_PER_SECOND"
        }
        
        lappend streamConfig -load
        lappend streamConfig $load
        lappend streamConfig -loadUnit
        lappend streamConfig $loadUnit
    }    

    if {[info exist arr(-framesize)]} {
        set list [split $arr(-framesize) -]
        if {[llength $list] == 3} {
            lappend streamConfig -MinFrameLength
            lappend streamConfig [lindex $list 0]                
            lappend streamConfig -StepFrameLength
            lappend streamConfig [lindex $list 1]            
            lappend streamConfig -MaxFrameLength
            lappend streamConfig [lindex $list 2]
            lappend streamConfig -FrameLengthMode
            lappend streamConfig "incr"        
        } elseif {[llength $list] == 2} {
            lappend streamConfig -MinFrameLength
            lappend streamConfig [lindex $list 0]        
            lappend streamConfig -MaxFrameLength
            lappend streamConfig [lindex $list 1]
            lappend streamConfig -FrameLengthMode
            lappend streamConfig "random"        
        } elseif {[llength $list] == 1} {
            lappend streamConfig -FixedFrameLength
            lappend streamConfig $arr(-framesize)
            lappend streamConfig -FrameLengthMode
            lappend streamConfig "fixed"
        }
    }     

    eval stc::config $hStream $streamConfig
    puts "stc::config $hStream $streamConfig"

    set port [stc::get $hStream -parent]
    set generator [stc::get $port -children-generator]
    set generatorConfig [stc::get $generator -children-generatorConfig]
    
    if {$arr(-txnum) <= 0} {
        stc::config $generatorConfig -SchedulingMode "rate_based" -DurationMode "CONTINUOUS"  
    } else {
		puts "aaaaaa"
        stc::config $generatorConfig -SchedulingMode "rate_based" -DurationMode "BURSTS"  -Duration $arr(-txnum) 
    }
    
}
proc CreateStcStream {args} {
    set tempArgs $args
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-stcport)]} {
        error "please specify stcPort for Creating Stream!"
    }          

    set ports [stc::get project1 -children-port] 
    if {($arr(-stcport) < 1)||($arr(-stcport) > [llength $ports])} {
         error "wrong stcPort ($arr(-stcport)).   1<= stcPort <= [llength $ports] "
    }

    set hPort [lindex $ports [incr arr(-stcport) -1]]

    #����stream����
    set streamConfig ""
    if {[info exist arr(-load)]} {
        
        set list [split $arr(-load) %]
        if {[llength $list]>=2} {
            set load [lindex $list 0]
            set loadUnit "PERCENT_LINE_RATE"
        }

        set list [split $arr(-load) m]
        if {[llength $list]>=2} {
            set load [lindex $list 0]
            set loadUnit "MEGABITS_PER_SECOND"
        }

        set list [split $arr(-load) pps]
        if {[llength $list]>=2} {
            set load [lindex $list 0]
            set loadUnit "FRAMES_PER_SECOND"
        }
        
        lappend streamConfig -load
        lappend streamConfig $load
        lappend streamConfig -loadUnit
        lappend streamConfig $loadUnit
    }    

    if {[info exist arr(-framesize)]} {
        set list [split $arr(-framesize) -]
        if {[llength $list] == 3} {
            lappend streamConfig -MinFrameLength
            lappend streamConfig [lindex $list 0]                
            lappend streamConfig -StepFrameLength
            lappend streamConfig [lindex $list 1]            
            lappend streamConfig -MaxFrameLength
            lappend streamConfig [lindex $list 2]
            lappend streamConfig -FrameLengthMode
            lappend streamConfig "incr"        
        } elseif {[llength $list] == 2} {
            lappend streamConfig -MinFrameLength
            lappend streamConfig [lindex $list 0]        
            lappend streamConfig -MaxFrameLength
            lappend streamConfig [lindex $list 1]
            lappend streamConfig -FrameLengthMode
            lappend streamConfig "random"        
        } else {
            lappend streamConfig -FixedFrameLength
            lappend streamConfig $arr(-framesize)
            lappend streamConfig -FrameLengthMode
            lappend streamConfig "fixed"
        }
		
	
    } 
    
	
    set hStream [stc::create streamblock -under $hPort -name $arr(-streamname) -frameconfig ""]
    puts "stc::create streamblock -under $hPort -name $arr(-streamname)"
    eval stc::config $hStream $streamConfig
	
	#add by hanxu start
	set index [lsearch $tempArgs -fcsInsert]
	if {$index != -1} {
		set fcsInsert [lindex $tempArgs [expr $index + 1]]
		if {$fcsInsert == "TRUE"} {
			stc::config $hStream -EnableFcsErrorInsertion TRUE
		} else {
			stc::config $hStream -EnableFcsErrorInsertion FALSE
		}
		
	} else  {
	}
	#add by hanxu end
	
    puts "stc::config $hStream $streamConfig"

    set port [stc::get $hStream -parent]
    set generator [stc::get $port -children-generator]
    set generatorConfig [stc::get $generator -children-generatorConfig] 

    if {$arr(-txnum) <= 0} {
        stc::config $generatorConfig -SchedulingMode "rate_based" -DurationMode "CONTINUOUS"  
    } else {
		puts "aaaaaa"
        stc::config $generatorConfig -SchedulingMode "rate_based" -DurationMode "BURSTS"  -Duration $arr(-txnum) 
    }	
	
	
}

proc AddEthHdr {args} {
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
    set Ether1 [stc::create ethernet:EthernetII -under $hStream -dstMac $arr(-dstmac) -srcMac $arr(-srcmac)  -name ethHdr]    
    puts "stc::create ethernet:EthernetII -under $hStream -dstMac $arr(-dstmac) -srcMac $arr(-srcmac)  -name ethHdr"
    if {$arr(-ethertype) != "auto"} {
       stc::config $Ether1 -etherType $arr(-ethertype)
    }

    if {$arr(-srcmaccnt) > 1} {
    set ethModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-srcmac) \
            -Mask "00:00:FF:FF:FF:FF" -OffsetReference ethHdr.srcMac -EnableStream False \
            -Offset 0 -ModifierMode incr -RecycleCount $arr(-srcmaccnt) -StepValue $arr(-srcmacstep) -RepeatCount $arr(-srcmacrepeat)]
    }

    if {$arr(-dstmaccnt) > 1} {
    set ethModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-dstmac) \
            -Mask "00:00:FF:FF:FF:FF" -OffsetReference ethHdr.dstMac -EnableStream False \
            -Offset 0 -ModifierMode incr -RecycleCount $arr(-dstmaccnt) -StepValue $arr(-dstmacstep) -RepeatCount $arr(-dstmacrepeat)]
    }    
    if {$arr(-ethertypecnt) > 1} {
    set ethModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-ethertype) \
            -OffsetReference ethHdr.etherType  -Mask {FFFF} -EnableStream False \
            -Offset 0 -ModifierMode incr -RecycleCount $arr(-ethertypecnt) -StepValue $arr(-ethertypestep) -RepeatCount $arr(-ethertyperepeat)]          
    }    
}

proc ConfigEthHdr {args} {
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
    #set ethernetII [stc::get $hStream -EthernetII]
	stc::config $hStream -ethernet:EthernetII.dstMac $arr(-dstmac) -ethernet:EthernetII.srcMac $arr(-srcmac)  
    puts "stc::config ethernet:EthernetII -under $hStream -dstMac $arr(-dstmac) -srcMac $arr(-srcmac)  -name ethHdr"
  
}

proc AddCustomHdr {args} {
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }

      stc::config $hStream -AllowInvalidHeaders "TRUE"  
      #����/����custom pkt   
      set custom1 [stc::create custom:Custom -under $hStream -pattern $arr(-hexstring) ]   
      puts "stc::create custom:Custom -under $hStream -pattern $arr(-hexstring)"
}

proc AddVlanHdr {args} {
    catch {array unset arr}
	
	set index [lsearch $args -enableStream] 
	if { $index != -1} {
		set enableStream [lindex $args [expr $index + 1]]
	}
   
    set args [string tolower $args]
    array set  arr $args

	
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

	# Modify by Aleon ; 
	# date: 2011.08.29
	set pri $arr(-pri)
	set binaryList {};
	while {1} {
		set tempRes [expr int($pri/2)]
		set tempQuota [expr int($pri%2)]
		lappend binaryList $tempQuota
		set pri $tempRes
		if {$pri == 0} {
			break;
		}
	}

	for {set k [llength $binaryList]} { $k > 0} {incr k -1} {
		append binary [lindex $binaryList [expr $k-1]]
	}

	set priValue [format "%03s" $binary]
	#puts $priValue
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    

	
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
    set pdus [stc::get $hStream -children]
    
        foreach pdu $pdus {
            if {[string first "ethernet" $pdu]!= -1} {
                set hEth $pdu
                set vlans1 ""
                foreach child [stc::get $pdu -children] {
                    if {[string first "vlans" $child]!= -1} {
                         set vlans1 $child   
                         break
                    }     
                }
				set eth_h1 [stc::get $hEth -Name]
            		
                if {$vlans1 == ""} {
                    set vlans1 [stc::create vlans -under $hEth]  
                }
                set vlan1 [stc::create vlan -under $vlans1]
                puts "stc::create vlan -under $vlans1 -name vlanHdr"
                stc::config $vlan1 -id $arr(-vlanid) -cfi $arr(-cfi) -pri $priValue 
                if {$arr(-tpid) != "auto"} {
                   stc::config $vlan1 -type $arr(-tpid)
                }
				set vlan_1  [stc::get $vlan1 -Name] 
                if {$arr(-vlanidcnt)>1} {
                    set VlanModifier1 [stc::create RangeModifier -under $hStream  -Data [stc::get $vlan1 -id] \
                       -Mask 4095 -OffsetReference ${eth_h1}.vlans.${vlan_1}.id -EnableStream False \
                       -Offset 0 -ModifierMode INCR -RecycleCount $arr(-vlanidcnt) -StepValue $arr(-vlanidstep) -RepeatCount $arr(-vlanidrepeat)]
						puts "in!!!!!!!!!"
                }    
			
            }
        }
}

proc dec2bin {dec change} {

	set bin ""
	set a 1
	while {$a>0} {
		set a [expr $dec/$change]
		set b [expr $dec%$change]
		set dec $a
		set bin $b$bin
	}
	set len [string length $bin]
	if {$len < 8 } {
		for {set i 0} {$i<[expr 8-$len]} {incr i} {
		set bin 0$bin
	    }
	}
	return $bin
}


proc AddIpv4Hdr {args} {
	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
    
    set  ipv4 [stc::create ipv4:IPv4 -under $hStream -name ipv4Hdr -destAddr $arr(-dstip) -gateway $arr(-gw) -sourceAddr  $arr(-srcip)]    
    puts "stc::create ipv4:IPv4 -under $hStream -name ipv4Hdr -destAddr $arr(-dstip) -gateway $arr(-gw) -sourceAddr  $arr(-srcip)"

    if {$arr(-srcipcnt) > 1} {
        set IPModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-srcip) \
            -Mask "255.255.255.255" -OffsetReference ipv4Hdr.sourceAddr -StepValue $arr(-srcipstep) -EnableStream False \
            -Offset 0 -ModifierMode INCR -RecycleCount $arr(-srcipcnt) -RepeatCount $arr(-srciprepeat)]   
    }

    if {$arr(-dstipcnt) > 1} {
        set IPModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-dstip) \
            -Mask "255.255.255.255" -OffsetReference ipv4Hdr.destAddr -StepValue $arr(-dstipstep) -EnableStream False \
            -Offset 0 -ModifierMode INCR -RecycleCount $arr(-dstipcnt) -RepeatCount $arr(-dstiprepeat)]   
    }
    if {0} {
		set tos_precedence [expr ($arr(-tos_dscp) & 0xff) >> 5]
		set dBit [expr ($arr(-tos_dscp) & 16) >> 4]
		puts $dBit
		set tBit [expr ($arr(-tos_dscp) & 8) >> 3]
		puts $tBit
		set rBit [expr ($arr(-tos_dscp) & 4) >> 2]
		puts $rBit
		set mBit [expr ($arr(-tos_dscp) & 2) >> 1]
    }

	# Modify by Aleon ; 
	# date: 2011.08.25
	set dBit 0
	set tBit 0
	set rBit 0
	set mBit 0
    if {1} {
		set tos_precedence [expr ($arr(-tos_dscp)/8)]
		#puts $tos_precedence
		set decQuota [expr ($arr(-tos_dscp)%8)]
		#puts $decQuota
		set binaryList {};
		while {1} {
			set tempRes [expr int($decQuota/2)]
			set tempQuota [expr int($decQuota%2)]
			lappend binaryList $tempQuota
			set decQuota $tempRes
			if {$decQuota == 0} {
				break;
			}
		}
		set dBit [lindex $binaryList 0]
		set tBit [lindex $binaryList 1]
		set rBit [lindex $binaryList 2]
	}
	set tosDiffserv1 [stc::create tosDiffserv -under $ipv4]
    set tos1 [stc::create tos -under $tosDiffserv1]
    stc::config $tos1 -dBit $dBit -tBit $tBit -rBit $rBit -mBit $mBit -precedence $tos_precedence
	
	
	
	###############add by hanxu################################################################
	
	set index [lsearch $tempArgs -dscpEnable] 
	if {$index != -1} {
		
		set dscpEnable [lindex $tempArgs [expr $index + 1]]
	} else  {

		set dscpEnable false
		
	}	
	if {$dscpEnable == "true"} {
	
		set index [lsearch $tempArgs -dscp] 
		if {$index != -1} {
			set dscp [lindex $tempArgs [expr $index + 1]]
		} else  {
			set dscp 0
		}		
		set dscpTemp [dec2bin $dscp 2]
		
		set dscpHigh [string range $dscpTemp 2 4]
		set dscpHigh [expr [string index $dscpHigh 2] * 1 + [string index $dscpHigh 1] * 2 + [string index $dscpHigh 0] * 4]
		
		set dscpLow [string range $dscpTemp 5 7]
		set dscpLow [expr [string index $dscpLow 2] * 1 + [string index $dscpLow 1] * 2 + [string index $dscpLow 0] * 4]
		
		
		set tosDiffserv1 [stc::create tosDiffserv -under $ipv4]
		set dscpH [stc::create diffServ -under $tosDiffserv1]
		stc::config $dscpH -dscpHigh $dscpHigh -dscpLow $dscpLow -Name DSCP
		
		set index [lsearch $tempArgs -dscpstep] 
		if {$index != -1} {
			set dscpstep [lindex $tempArgs [expr $index + 1]]
		} else  {
			set dscpstep 4
		}
		
		set index [lsearch $tempArgs -dscprepeat] 
		if {$index != -1} {
			set dscprepeat [lindex $tempArgs [expr $index + 1]]
		} else  {
			set dscprepeat 0
		}		
		
		set index [lsearch $tempArgs -dscpcount] 
		if {$index != -1} {
			set dscpcount [lindex $tempArgs [expr $index + 1]]
			puts "$dscpcount"
			set DSCPLowModifier [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $dscp \
						-Mask "FF" -OffsetReference ipv4Hdr.tosDiffserv.diffServ -StepValue $dscpstep -EnableStream False \
						-Offset 0 -ModifierMode INCR -RecycleCount $dscpcount -RepeatCount $dscprepeat]
		} else  {
		}
		
		stc::apply
    }		
	
}

#----------------------
# Create cfm ccm header.
#------------------------
proc AddCfmCcmHdr {args} {
	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
	#create and configure ccm header.
	set ccm [stc::create serviceoam:CCM -under $hStream -CCMIntervalField 4 \
											-Reserved 0000 \
											-FirstTLVOffset 46 \
											-MAEPI 0 \
											-Name ccm \
											-OpCode 1 \
											-RDIbit 0 \
											-Reserved 0000 \
											-SequenceNumber 0]  
	set cfmheader [stc::create cfmHeader -under $ccm -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
	set theccmtlvs [stc::create theCCMTLVS -under $ccm -Name theccmtlvs]
	set ccmtlvlist [stc::create CCMTLVList -under $theccmtlvs -Name ccmtlvlist]
	set endtlv [stc::create EndTLV -under $ccmtlvlist -Name endtlv \
												-Type 00 ]
	set portstatus [stc::create PortStatusTLV -under $ccmtlvlist \
										-Length 0000 \
										-Name portstatus \
										-PortStatusValues 02 \
										-Type 02 ]
	set senderidtlv [stc::create SenderIDTLV -under $ccmtlvlist \
										-ChassisIDLen 00 \
										-Length 0000 \
										-Name senderidtlv \
										-Type 01 ]											
	puts "stc::create $ccm -under $hStream -name eoamccm."
	
	stc::apply  	
	
}
#-------------------------
# Create cfm lbm header.
#--------------------------
proc AddCfmLbmHdr {args} {

	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
 	#create and configure lbm header.
		set lbm [stc::create serviceoam:LBM -under $hStream \
										-Name eoamlbm \
										-FirstTLVOffset 04 \
										-Flags 00000000 \
										-OpCode 3 \
										-LBtID 0]
		set cfmheader [stc::create cfmHeader -under $lbm -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
		set thelbmtlvs [stc::create theLBMTLVs -under $lbm -name lbmtlvs]
		set lbmtlvlist [stc::create LBMTLVList -under $thelbmtlvs -name lbmtlvlist]
		set endtlv [stc::create EndTLV -under $lbmtlvlist \
										-name endtlv \
										-type 01]
		puts "stc::create $lbm -under $hStream -name eoamlbm "
	
	stc::apply   			
}
#----------------------
# Create cfm lbr header.
#------------------------
proc AddCfmLbrHdr {args} {
	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
 	#create and configure lbr header.
		set lbr [stc::create serviceoam:LBR -under $hStream \
										-Name eoamlbm \
										-FirstTLVOffset 04 \
										-Flags 00000000 \
										-OpCode 2 \
										-LBtID 0]
		set cfmheader [stc::create cfmHeader -under $lbr -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
		set thelbrtlvs [stc::create theLBRTLVs -under $lbr -name lbrtlvs]
		set lbrtlvlist [stc::create LBMTLVList -under $thelbrtlvs -name lbrtlvlist]
		set endtlv [stc::create EndTLV -under $lbrtlvlist \
										-name endtlv \
										-type 00]
		puts "stc::create $lbr -under $hStream -name eoamlbr "
	
	stc::apply  	
	
}
#----------------------
# Create  ltm header.
#------------------------
proc AddCfmLtmHdr {args} {
	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 

    set index [lsearch $args -ltmttl] 
    if {$index != -1} {
        set ltmTtl [lindex $args [expr $index + 1]]
    } 

    set index [lsearch $args -origmac] 
    if {$index != -1} {
        set origMAC [lindex $args [expr $index + 1]]
    } 

    set index [lsearch $args -targetmac] 
    if {$index != -1} {
        set targetMAC [lindex $args [expr $index + 1]]
    } 
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
	#create and configure ltm header.
	set ltm [stc::create serviceoam:LTM -under $hStream \
											-FirstTLVOffset 11 \
											-Flags 80 \
											-Name ltm \
											-OpCode 5 \
											-LTMTransID 00000000 \
											-LTMTTL $ltmTtl \
											-OrigMAC $origMAC \
											-TargetMAC $targetMAC]  
	set cfmheader [stc::create cfmHeader -under $ltm -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
	set theltmtlvs [stc::create theLTMTLVs -under $ltm -name ltmtlvs]
	set ltmtlvlist [stc::create LTMTLVList -under $theltmtlvs -name ltmtlvlist]
	set endtlv [stc::create EndTLV -under $ltmtlvlist \
										-name endtlv \
										-type 00]											
	puts "stc::create $ltm -under $hStream -name eoamltm."
	
	stc::apply  	
	
}
#----------------------
# Create  ltr header.
#------------------------
proc AddCfmLtrHdr {args} {
	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
	
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }
    set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
	#create and configure ltr header.
	set ltr [stc::create serviceoam:LTR -under $hStream \
											-FirstTLVOffset 06 \
											-FwdYes 1 \
											-LTRRelayAction 01 \
											-LTRTransID 00000000 \
											-Name ltr \
											-OpCode 4 \
											-ReplyTTL 00 \
											-Reserved 00000 \
											-TermMEP 1 \
											-UseFDBonly 0]  
	set cfmheader [stc::create cfmHeader -under $ltr -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
	set theltrtlvs [stc::create theLTRTLVs -under $ltr -name ltrtlvs]
	set ltrtlvlist [stc::create LTRTLVList -under $theltrtlvs -name ltrtlvlist]
	set orgspectlv [stc::create OrgSpecTLV -under $ltrtlvlist \
											-Length 0000 \
											-Name orgspectlv \
											-OUI 000000 \
											-SubType 00 \
											-Type 1F]
	set ltregressidenttlv [stc::create LTREgressIdentTLV -under $ltrtlvlist \
													-Length 0000 \
													-Name ltregressidenttlv \
													-Type 08]
	set replyegresstlvformattlv [stc::create ReplyEgressTLVFormatTLV -under $ltrtlvlist \
													-EgressAction 01 \
													-EgressMac 00:00:01:00:00:01 \
													-Length 0000 \
													-Type 06 ]
	set replyingresstlvformattlv [stc::create ReplyIngressTLVFormatTLV -under $ltrtlvlist \
													-IngressAction 01 \
													-IngressMac 00:00:01:00:00:01 \
													-Length 0000 \
													-Type 05 ]													
	set endtlv [stc::create EndTLV -under $ltrtlvlist \
										-name endtlv \
										-type 00]											
	puts "stc::create $ltr -under $hStream -name eoamltr."
	
	stc::apply  	
	
}
#----------------------
# Create lmm header.
#------------------------
proc AddCfmLmmHdr {args} {
	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 

	set index [lsearch $args -opcode] 
    if {$index != -1} {
        set opCode [lindex $args [expr $index + 1]]
    } 
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
	#create and configure lmm header.
	set lmm [stc::create serviceoam:LMM -under $hStream \
											-FirstTLVOffset 0C \
											-Flags 00000000 \
											-Name lmm \
											-OpCode $opCode \
											-RxFCf 00000000 \
											-TxFCb 00000000 ]  
	set cfmheader [stc::create cfmHeader -under $lmm -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
	set endtlv [stc::create EndTLV -under $lmm \
										-name endtlv \
										-type 00]											
	puts "stc::create $lmm -under $hStream -name eoamlmm."
	
	stc::apply  	
	
}
#----------------------
# Create lmr header.
#------------------------
proc AddCfmLmrHdr {args} {
	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
	#create and configure lmr header.
	set lmr [stc::create serviceoam:LMR -under $hStream \
											-FirstTLVOffset 0C \
											-Flags 00000000 \
											-Name lmr \
											-OpCode 2A \
											-RxFCf 00000000 \
											-TxFCb 00000000 ]  
	set cfmheader [stc::create cfmHeader -under $lmr -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
	set endtlv [stc::create EndTLV -under $lmr \
										-name endtlv \
										-type 00]											
	puts "stc::create $lmr -under $hStream -name eoamlmr."
	
	stc::apply  	
	
}
#----------------------
# Create cfm dmm header.
#------------------------
proc AddCfmDmmHdr {args} {

	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

	set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
 	#create and configure dmm header.
	set dmm [stc::create serviceoam:DMM -under $hStream -name eoamdmm \
										-FirstTLVOffset 20 \
										-Flags 00000000 \
										-OpCode 2F \
										-RxTimeStampb 0000000000000000 \
										-RxTimeStampf 0000000000000000 \
										-TxTimeStampb 0000000000000000 \
										-TxTimeStampf 0000000000000000]   
	set cfmheader [stc::create cfmHeader -under $dmm -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
	set endtlv [stc::create EndTLV -under $dmm \
										-name endtlv \
										-type 00]											
	puts "stc::create $dmm -under $hStream -name eoamdmm."
	
	stc::apply   			
}
#----------------------
# Create cfm dmr header.
#------------------------
proc AddCfmDmrHdr {args} {

	set tempArgs $args 
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }
	
    set index [lsearch $args -mdlevel] 
    if {$index != -1} {
        set mdLevel [lindex $args [expr $index + 1]]
    } 
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }
 	#create and configure dmr header.
	set dmr [stc::create serviceoam:DMR -under $hStream -name eoamdmm \
										-FirstTLVOffset 20 \
										-Flags 00000000 \
										-OpCode 2E \
										-RxTimeStampb 0000000000000000 \
										-RxTimeStampf 0000000000000000 \
										-TxTimeStampb 0000000000000000 \
										-TxTimeStampf 0000000000000000]   
	set cfmheader [stc::create cfmHeader -under $dmr -MDlevel $mdLevel \
											-Name cfmHeader \
											-Version 00000]
	set endtlv [stc::create EndTLV -under $dmr \
										-name endtlv \
										-type 00]											
	puts "stc::create $dmr -under $hStream -name eoamdmr."
	
	stc::apply   			
}

proc AddIpv6Hdr {args} {
    set tempArgs $args
	catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }

    set  ipv6 [stc::create ipv6:IPv6 -under $hStream -name ipv6Hdr -destAddr $arr(-dstip) -gateway $arr(-gw) -sourceAddr  $arr(-srcip) -flowLabel $arr(-flowlabel) -trafficClass $arr(-trafficclass)]    
    puts "stc::create ipv6:IPv6 -under $hStream -name ipv6Hdr -destAddr $arr(-dstip) -gateway $arr(-gw) -sourceAddr  $arr(-srcip) -flowLabel $arr(-flowlabel) -trafficClass $arr(-trafficclass)"

    if {$arr(-srcipcnt) > 1} {
        set IPModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-srcip) \
            -Mask "::FFFF:FFFF" -OffsetReference ipv6Hdr.sourceAddr -StepValue $arr(-srcipstep)  -EnableStream False \
            -Offset 0 -ModifierMode INCR -RecycleCount $arr(-srcipcnt) -RepeatCount $arr(-srciprepeat)]   
    }

    if {$arr(-dstipcnt) > 1} {
        set IPModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-dstip) \
            -Mask "::FFFF:FFFF" -OffsetReference ipv6Hdr.destAddr -StepValue $arr(-dstipstep)  -EnableStream False \
            -Offset 0 -ModifierMode INCR -RecycleCount $arr(-dstipcnt) -RepeatCount $arr(-dstiprepeat)]   
    }
	
		
	#Add by Huangfu chunfeng 2014/3/27,This is another way to set the argument
	#set tempArgs $arr(-trafficclassEnable)
	#set tempArgs [string towoler $tempArgs]
	#if { $tempArgs!="true" } {
	#	set tempArgs false
	#}
	set index [lsearch $tempArgs -trafficclassEnable]
	if {$index != -1} {
		set trafficclassEnable [lindex $tempArgs [expr $index+1]]
		set trafficclassEnable [string tolower $trafficclassEnable]
	} else {
		set trafficclassEnable false
	}
	
	if {$trafficclassEnable == "true"} {
	
		set index [lsearch $tempArgs -trafficclass] 
		if {$index != -1} {
			set trafficclass [lindex $tempArgs [expr $index + 1]]
		} else  {
			set trafficclass 0
		}		
		
		set index [lsearch $tempArgs -trafficclassstep] 
		if {$index != -1} {
			set trafficclassstep [lindex $tempArgs [expr $index + 1]]
		} else  {
			set trafficclassstep 4
		}
		
		set index [lsearch $tempArgs -trafficclassrepeat] 
		if {$index != -1} {
			set trafficclassrepeat [lindex $tempArgs [expr $index + 1]]
		} else  {
			set trafficclassrepeat 0
		}		
		
		set index [lsearch $tempArgs -trafficclasscount] 
		if {$index != -1} {
			set trafficclasscount [lindex $tempArgs [expr $index + 1]]
			puts "$trafficclasscount"
			set TrafficClassModifier [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $trafficclass \
						-Mask "255" -OffsetReference ipv6Hdr.trafficClass -StepValue $trafficclassstep -EnableStream False \
						-Offset 0 -ModifierMode INCR -RecycleCount $trafficclasscount -RepeatCount $trafficclassrepeat]
			puts "stc::create RangeModifier -Data $trafficclass -StepValue $trafficclassstep -ModifierMode INCR -RecycleCount $trafficclasscount -RepeatCount $trafficclassrepeat"
		} else  {
		}
		
		stc::apply
    }	

}

proc AddUdpHdr {args} {
    catch {array unset arr}
    set args [string tolower $args]
    array set  arr $args
    if {![info exist arr(-streamname)]} {
        error "please specify streamName!"
    }

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $arr(-streamname) $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($arr(-streamname)) can not be found, please correct!" 
    }

    set  udp [stc::create udp:Udp -under $hStream -name udpHdr -sourcePort $arr(-srcport) -destPort $arr(-dstport) ]    
    puts "stc::create udp:Udp -under $hStream -name udpHdr -sourcePort $arr(-srcport) -destPort $arr(-dstport) "

    if {$arr(-srcportcnt) > 1} {
        set IPModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-srcport) \
            -Mask 0xFFFF -OffsetReference udpHdr.sourcePort -StepValue $arr(-srcportstep) -EnableStream False \
            -Offset 0 -ModifierMode INCR -RecycleCount $arr(-srcportcnt) -RepeatCount $arr(-srcportrepeat)]   
    }

    if {$arr(-dstportcnt) > 1} {
        set IPModifier1 [stc::create RangeModifier -under $hStream -EnableStream TRUE -Data $arr(-dstport) \
            -Mask 0xFFFF -OffsetReference udpHdr.destPort -StepValue $arr(-dstportstep) -EnableStream False \
            -Offset 0 -ModifierMode INCR -RecycleCount $arr(-dstportcnt) -RepeatCount $arr(-dstportrepeat)]   
    }
}
proc Num2Ip {num} {
    set byte0 [expr $num & 0xff]
    set byte1 [expr ($num >> 8) & 0xff]
    set byte2 [expr ($num >> 16) & 0xff]
    set byte3 [expr ($num >> 24) & 0xff]
    return $byte3.$byte2.$byte1.$byte0
}
#Add by Hualin ; 2011.10/10
proc AddIgmpHdr {args} { 
  
	#Parse stream name parameters.
	set index [lsearch $args -streamName] 
    if {$index != -1} {
        set streamName [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }    
	
	set pduName igmp
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }

    #Parse IgmpType parameter    
    set index [lsearch $args -IgmpType] 
    if {$index != -1} {
        set IgmpType [lindex $args [expr $index + 1]]
    } 
        
    #Parse GroupAddr parameter    
    set index [lsearch $args -GroupAddr] 
    if {$index != -1} {
        set GroupAddr [lindex $args [expr $index + 1]]
    }

    #Parse GroupCount parameter    
    set index [lsearch $args -GroupCount] 
    if {$index != -1} {
        set GroupCount [lindex $args [expr $index + 1]]
    } else {
		set GroupCount 1
	}

    #Parse IncreaseStep parameter    
    set index [lsearch $args -IncreaseStep] 
    if {$index != -1} {
        set IncreaseStep [lindex $args [expr $index + 1]]
    } else {
		set IncreaseStep 1
	}
    
    #Parse MaxReponseTime parameter    
    set index [lsearch $args -MaxReponseTime] 
    if {$index != -1} {
        set MaxReponseTime [lindex $args [expr $index + 1]]
    }    
     
    #Parse Checksum parameter    
    set index [lsearch $args -Checksum] 
    if {$index != -1} {
        set Checksum [lindex $args [expr $index + 1]]
    }

     #Parse SuppressFlag parameter    
    set index [lsearch $args -SuppressFlag] 
    if {$index != -1} {
        set SuppressFlag [lindex $args [expr $index + 1]]
    }   

    #Parse QRV parameter    
    set index [lsearch $args -QRV] 
    if {$index != -1} {
        set QRV [lindex $args [expr $index + 1]]
    } else {
	
	}

    #Parse QQIC parameter    
    set index [lsearch $args -QQIC] 
    if {$index != -1} {
        set QQIC [lindex $args [expr $index + 1]]
    }
    
    #Parse SourceNum parameter    
    set index [lsearch $args -SourceNum] 
    if {$index != -1} {
        set SourceNum [lindex $args [expr $index + 1]]
    } else {
		set SourceNum 0
	}
	
     #Parse SrcIpList parameter    
    set index [lsearch $args -SrcIpList] 
    if {$index != -1} {
        set SrcIpList [lindex $args [expr $index + 1]]
    } else {
		set SrcIpList ""
	}   

     #Parse Reserved parameter    
    set index [lsearch $args -Reserved] 
    if {$index != -1} {
        set Reserved [lindex $args [expr $index + 1]]
    } else {
		set Reserved 0
	} 
    
     #Parse GroupRecords parameter    
    set index [lsearch $args -GroupRecords] 
    if {$index != -1} {
        set GroupRecords [lindex $args [expr $index + 1]]
    }   

    #Parse GroupNum parameter    
    set index [lsearch $args -GroupNum] 
    if {$index != -1} {
        set GroupNum [lindex $args [expr $index + 1]]
    } else {
		set GroupNum $GroupCount
	}

     #Parse RecordType parameter    
    set index [lsearch $args -RecordType] 
    if {$index != -1} {
        set RecordType [lindex $args [expr $index + 1]]
    }   

     #Parse AuxiliaryDataLen parameter    
    set index [lsearch $args -AuxiliaryDataLen] 
    if {$index != -1} {
        set AuxiliaryDataLen [lindex $args [expr $index + 1]]
    } else {
		set AuxiliaryDataLen 0
	}

     #Parse MulticastAddr parameter    
    set index [lsearch $args -MulticastAddr] 
    if {$index != -1} {
        set MulticastAddr [lindex $args [expr $index + 1]]
    } else {
		set MulticastAddr $GroupAddr
	}    
      
    #Create IGMP packet object
    switch $IgmpType {
        igmpv1report {
            set hIgmp [stc::create igmp:Igmpv1 -under $hStream]
            #Store the packet header
            lappend m_PduNameList $pduName
            set m_PduHandleList($pduName) $hIgmp

            stc::config $hIgmp -type 2 -groupAddress $GroupAddr 
 
            if {$Checksum != "0" } {
                 stc::config $hIgmp -checksum $Checksum
            }
                           
        }
        igmpv1query {
            set hIgmp [stc::create igmp:Igmpv1 -under $hStream]
            #Store the packet header
            lappend m_PduNameList $pduName
            set m_PduHandleList($pduName) $hIgmp

            stc::config $hIgmp -type 1 -groupAddress $GroupAddr 
             if {$Checksum != "0" } {
                 stc::config $hIgmp -checksum $Checksum
            }
        }
        igmpv2report {
            set hIgmp [stc::create igmp:Igmpv2 -under $hStream]
             #Store the packet header
            lappend m_PduNameList $pduName
            set m_PduHandleList($pduName) $hIgmp

            stc::config $hIgmp -type 16 -maxRespTime $MaxReponseTime -groupAddress $GroupAddr 

             if {$Checksum != "0" } {
                 stc::config $hIgmp -checksum $Checksum
            }
        }
        igmpv2leave {
            set hIgmp [stc::create igmp:Igmpv2 -under $hStream]
            #Store the packet header
            lappend m_PduNameList $pduName
            set m_PduHandleList($pduName) $hIgmp

            stc::config $hIgmp -type 17 -maxRespTime $MaxReponseTime -groupAddress $GroupAddr 
             if {$Checksum != "0" } {
                 stc::config $hIgmp -checksum $Checksum
            }
        }
        igmpv2query {
            set hIgmp [stc::create igmp:Igmpv2 -under $hStream]
            #Store the packet header
            lappend m_PduNameList $pduName
            set m_PduHandleList($pduName) $hIgmp

            stc::config $hIgmp -type 11 -maxRespTime $MaxReponseTime -groupAddress $GroupAddr 
             if {$Checksum != "0" } {
                 stc::config $hIgmp -checksum $Checksum
            }
        }
        igmpv3query {
            set hIgmp [stc::create igmp:Igmpv3Query -under $hStream]
            #Store the packet header
            lappend m_PduNameList $pduName
            set m_PduHandleList($pduName) $hIgmp
            
            stc::config $hIgmp \
                -type 11 \
                -maxRespTime $MaxReponseTime \
                -groupAddress $GroupAddr \
                -sFlag $SuppressFlag \
                -qrv $QRV \
                -qqic $QQIC \
                -numSource $SourceNum 
            set hAddrList [stc::create addrList -under $hIgmp]
            foreach SrcIp $SrcIpList {
                set hIpv4Addr [stc::create ipv4Addr -under $hAddrList]
                stc::config $hIpv4Addr -value $SrcIp
            } 

             if {$Checksum != "0" } {
                 stc::config $hIgmp -checksum $Checksum
            }
        }
        igmpv3report {
            set hIgmp [stc::create igmp:Igmpv3Report -under $hStream]
            #Store the packet header
            lappend m_PduNameList $pduName
            set m_PduHandleList($pduName) $hIgmp

            stc::config $hIgmp \
                -type 22 \
                -reserved $Reserved \
                -reserved2 $Reserved  -numGrpRecords $GroupNum


            set hgrpRecords [stc::create grpRecords -under $hIgmp]
			#Modify by Aleon; 2011.10.15
			for {set k 0} {$k < $GroupNum} {incr k} {
				
				set tmpValue [expr [lindex [split $MulticastAddr "."] 3 ] + $k]
				set startMulticastAddr [join [lreplace [split $MulticastAddr "."] 3 3 $tmpValue] "."]
			    set hGrpRecord [stc::create GroupRecord -under $hgrpRecords]
				stc::config $hGrpRecord -auxDataLen $AuxiliaryDataLen \
                 -mcastAddr $startMulticastAddr \
                 -recordType $RecordType  -numSource $SourceNum
			}
            #Configure Addr List
            set hAddrList [stc::create addrList -under $hGrpRecord]
            foreach SrcIp $SrcIpList {
                set hIpv4Addr [stc::create ipv4Addr -under $hAddrList]
                stc::config $hIpv4Addr -value $SrcIp
            }  

            if {$Checksum != "0" } {
                 stc::config $hIgmp -checksum $Checksum
            }                                         
        }
        default {
            error "The specified Type of CreateIGMPPkt is invalid"
        }
    }   

    if {$GroupCount != "1" && $IgmpType != "igmpv3report" } {
        set igmp1 [stc::get $hIgmp -Name]
        set IgmpStep [Num2Ip $IncreaseStep ]

        stc::create "RangeModifier" \
                -under $hStream -EnableStream TRUE \
                -ModifierMode "INCR" \
                -Mask "255.255.255.255" \
                -StepValue $IgmpStep \
                -RecycleCount $GroupCount \
                -RepeatCount "0" \
                -Data $GroupAddr \
                -Offset "0" \
                -OffsetReference "$igmp1.groupAddress" \
                -Active "TRUE" \
                -Name "IGMP Modifier"
     } 
}

##############################add by hanxu start##################

proc AddDhcpClientMsg {args} {

	set index [lsearch $args -streamName] 
    if {$index != -1} {
        set streamName [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }    
	
	set index [lsearch $args -bootFileName] 
    if {$index != -1} {
        set bootFileName [lindex $args [expr $index + 1]]
    } else {
    }    
	
	set index [lsearch $args -bootpFlags] 
    if {$index != -1} {
        set bootpFlags [lindex $args [expr $index + 1]]
    } else {
    }    
	
	set index [lsearch $args -clientAddr] 
    if {$index != -1} {
        set clientAddr [lindex $args [expr $index + 1]]
    } else {
    }    
	
	set index [lsearch $args -clientHWPad] 
    if {$index != -1} {
        set clientHWPad [lindex $args [expr $index + 1]]
    } else {
    }    
	
	set index [lsearch $args -clientMac] 
    if {$index != -1} {
        set clientMac [lindex $args [expr $index + 1]]
    } else {
    }    
	
	set index [lsearch $args -elapsed] 
    if {$index != -1} {
        set elapsed [lindex $args [expr $index + 1]]
    } else {
    }    
	
	set index [lsearch $args -haddrLen] 
    if {$index != -1} {
        set haddrLen [lindex $args [expr $index + 1]]
    } else {
    }    
	
	set index [lsearch $args -hardwareType] 
    if {$index != -1} {
        set hardwareType [lindex $args [expr $index + 1]]
    } else {
    }  

	set index [lsearch $args -hops] 
    if {$index != -1} {
        set hops [lindex $args [expr $index + 1]]
    } else {
    }  
	
	#####common######
	set index [lsearch $args -yourAddr] 
    if {$index != -1} {
        set yourAddress [lindex $args [expr $index + 1]]
    } else {
    }  
	
	set index [lsearch $args -clientAddr] 
    if {$index != -1} {
        set clientAddress [lindex $args [expr $index + 1]]
    } else {
    }  
	
	set index [lsearch $args -messageType] 
    if {$index != -1} {
        set messageTypeCode [lindex $args [expr $index + 1]]
    } else {
    }  
		
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
	set dhcpClientMsg [stc::create dhcp:Dhcpclientmsg -under $hStream -yourAddr $yourAddress -clientAddr $clientAddress]

	set options [stc::create options -under $dhcpClientMsg]

	set DHCPOption [stc::create DHCPOption -under $options]

	set messageType [stc::create MessageType -under $DHCPOption -code $messageTypeCode]

	
	stc::apply
	
	
	
}


proc AddPPPoeDiscovery {args} {

	set index [lsearch $args -streamName] 
    if {$index != -1} {
        set streamName [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }    
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
	
	set pppoeDis [stc::create pppoe:PPPoEDiscovery -under $hStream ]
	stc::apply
    
    
}


proc AddPPPoeSession {args} {

	set index [lsearch $args -streamName] 
    if {$index != -1} {
        set streamName [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }    
	
	set index [lsearch $args -sessionId] 
    if {$index != -1} {
        set sessionId [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }  
	
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
	
	set pppoeSession [stc::create pppoe:PPPoESession -under $hStream ]
	
	stc::config $pppoeSession -sessionId $sessionId
	
	stc::apply
    
    
}

proc AddPPPHdr {args} {

	set index [lsearch $args -streamName] 
    if {$index != -1} {
        set streamName [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }   

	set index [lsearch $args -protocolType] 
    if {$index != -1} {
        set protocolType [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }    
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
	
	set ppp [stc::create ppp:PPP -under $hStream ]
	
	stc::config $ppp -protocolType $protocolType
	
	stc::apply
    
    
}


proc AddArpHdr {args} {

	set index [lsearch $args -streamName] 
    if {$index != -1} {
        set streamName [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }    
	
	set index [lsearch $args -operation] 
    if {$index != -1} {
        set operation [lindex $args [expr $index + 1]]
    } else {
        error "please specify option!"
    }    
	
	set index [lsearch $args -senderHwAddr] 
    if {$index != -1} {
        set senderHwAddr [lindex $args [expr $index + 1]]
    } else {
        error "please specify option!"
    }    
	
	set index [lsearch $args -senderPAddr] 
    if {$index != -1} {
        set senderPAddr [lindex $args [expr $index + 1]]
    } else {
        error "please specify option!"
    }    
	
	set index [lsearch $args -targetPAddr] 
    if {$index != -1} {
        set targetPAddr [lindex $args [expr $index + 1]]
    } else {
        error "please specify option!"
    }    
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
	
	set arp [stc::create arp:ARP -under $hStream -operation $operation -senderHwAddr $senderHwAddr -senderPAddr $senderPAddr -targetPAddr $targetPAddr]
	stc::apply
    
    
}


proc AddRarpHdr {args} {

	set index [lsearch $args -streamName] 
    if {$index != -1} {
        set streamName [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }    
	
	set index [lsearch $args -operation] 
    if {$index != -1} {
        set operation [lindex $args [expr $index + 1]]
    } else {
        error "please specify option!"
    }    
	
	set index [lsearch $args -senderHwAddr] 
    if {$index != -1} {
        set senderHwAddr [lindex $args [expr $index + 1]]
    } else {
        error "please specify option!"
    }    
	
	set index [lsearch $args -senderPAddr] 
    if {$index != -1} {
        set senderPAddr [lindex $args [expr $index + 1]]
    } else {
        error "please specify option!"
    }    
	
	set index [lsearch $args -targetPAddr] 
    if {$index != -1} {
        set targetPAddr [lindex $args [expr $index + 1]]
    } else {
        error "please specify option!"
    }    
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
	
	set rarp [stc::create arp:RARP -under $hStream -operation $operation -senderHwAddr $senderHwAddr -senderPAddr $senderPAddr -targetPAddr $targetPAddr]
	stc::apply
    
    
}


proc AddLacpHdr {args} {

	set index [lsearch $args -streamName] 
    if {$index != -1} {
        set streamName [lindex $args [expr $index + 1]]
    } else {
        error "please specify streamName!"
    }    
	
	
    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
	set lacp [stc::create lacp:LACP -under $hStream]
	stc::apply
    
    
}





##############################add by hanxu end##################
###########################

# Add by Hualin ; 2011.09/19
proc CreateHost {args} {

    set args [string tolower $args]
    puts "Enter the proc of CreateHost..."
        
    #Parse HostName parameter
    set index [lsearch $args -hostname] 
    if {$index != -1} {
        set hostName [lindex $args [expr $index + 1]]
    } else  {
        puts " Please specify HostName parameter \nexit the proc of CreateHost..."
    }

	#Parse stc port parameter
    set index [lsearch $args -stcport] 
    if {$index != -1} {
        set stcPort [lindex $args [expr $index + 1]]
    } else  {
        set stcPort 1
    } 	
	#Parse MacAddr parameter
    set index [lsearch $args -macaddr] 
    if {$index != -1} {
        set macAddr [lindex $args [expr $index + 1]]
    } else {
        set macAddr "00:01:20:00:00:01"
    } 
    #Parse IpVersion parameter
    set index [lsearch $args -ipversion] 
    if {$index != -1} {
        set ipVersion [lindex $args [expr $index + 1]]
    } else {
        set ipVersion ipv4
    }
    set ipVersion [string tolower $ipVersion]

    #Parse HostType parameter
    set index [lsearch $args -hosttype] 
    if {$index != -1} {
        set hostType [lindex $args [expr $index + 1]]
    } else  {
        set hostType "ETHERNET"
    }
    set hostType [string tolower $hostType]
    
    #Parse Ipv4Addr parameter
    set index [lsearch $args -ipv4addr] 
    if {$index != -1} {
        set ipv4Addr [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else  {
        set ipv4Addr "192.168.1.2"
    }
    
    #Parse Ipv4SutAddr parameter
    set index [lsearch $args -ipv4gateway] 
    if {$index != -1} {
        set ipv4AddrGateway [lindex $args [expr $index + 1]]
        if {$ipv4AddrGateway == "default"} {
			set ipv4AddrGateway [join [lreplace [split $ipv4Addr "."] 3 3 1] "."]
        }
    }
	
     #Parse RouterId parameter
    set index [lsearch $args -routerid] 
    if {$index != -1} {
        set routerId [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else  {
        set routerId $ipv4Addr
    }
	
    #Parse Ipv4Mask parameter
    set index [lsearch $args -ipv4mask] 
    if {$index != -1} {
        set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else {
        set index [lsearch $args -ipv4addrprefixlen] 
        if {$index != -1} {
            set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
            set ipVersion ipv4
        } else  {
            set ipv4AddrPrefixLen 24
        }
    }
    #Parse vlanId parameter
    set index [lsearch $args -vlanid] 
    if {$index != -1} {
        set vlanId [lindex $args [expr $index + 1]]
    } else {
		set vlanId 100
	}
	
	#Parse priority of vlan parameter
	set index [lsearch $args -vlanpriority] 
    if {$index != -1} {
        set vlanPriority [lindex $args [expr $index + 1]]
    } else {
		set vlanPriority 7
	}
	
	#Parser vlan type parameter
	set index [lsearch $args -vlantype] 
    if {$index != -1} {
        set vlanType [lindex $args [expr $index + 1]]
    } else {
		set vlanType 33024
	}
	
	#Parser vlan type parameter
	set index [lsearch $args -qinqlist] 
    if {$index != -1} {
        set QinQList [lindex $args [expr $index + 1]]
    }
    set hHost ""
	set portList {};
    foreach port [stc::get project1 -children-port] {
		lappend portList $port
        foreach host [stc::get $port -children-host] {
            set name [stc::get $host -name]
            set name [string tolower $name]
            if { $name != $hostName} {
                set hHost $host
				#puts "aaa: $hHost"
                break
            }
        }
    }
    #puts [lindex $portList 1]
    if {$hHost == ""} {
        error "HostName ($hostName) can not be found, please correct!" 
    }
	
	#---------------------------------------------------
	# Create the host.
	#------------------------------------------
	set hHost [stc::create Host -under project1 \
									-DeviceCount 1 \
									-RouterId 1.1.1.1 \
									-EnablePingResponse TRUE \
									-Name $hostName]
	puts "stc::create host $hostName completed."

    #---------------------------------------------------
	# Create or Configure the ethernet II interface for the host.
	#------------------------------------------
	set EtherIIF [stc::create EthIIIf -under $hHost -Active TRUE -SourceMac $macAddr]
	puts "Host EthIIIf creation/configuration has completed."
	
	#---------------------------------------------------
	# Creating/configuring the host's IPv4 interface...
	#------------------------------------------
    if {$ipVersion == "ipv4"} {
		set hIpv4If [stc::create Ipv4If \
							-under $hHost \
							-Address $ipv4Addr \
							-PrefixLength $ipv4AddrPrefixLen \
							-UsePortDefaultIpv4Gateway "FALSE" \
							-Gateway $ipv4AddrGateway \
							-ResolveGatewayMac "TRUE" \
							-Name "Ipv4If 2"]
		puts "Host IPv4 interface creation/configuration has completed."
									
		stc::config $hHost -AffiliationPort-targets [lindex $portList [expr $stcPort -1]] 
		stc::config $hHost -TopLevelIf-targets $hIpv4If
		stc::config $hHost -PrimaryIf-targets $hIpv4If
		stc::config $hIpv4If -StackedOn $EtherIIF		
	
	}	
	#---------------------------------------------------
	# Adding vlan ID on ethII interface...
	#------------------------------------------	
	if {[lsearch $args -vlanid] != -1} {
		if {[lsearch $args -qinqlist] == -1} {
            set hVlanIf [stc::create VlanIf -under $hHost -VlanId $vlanId -Priority $vlanPriority -TpId $vlanType] 
            stc::config $hIpv4If -StackedOnEndpoint-targets $hVlanIf
            stc::config $hVlanIf -StackedOnEndpoint-targets $EtherIIF      
        } else {
 
			set i 0               
            foreach QinQ $QinQList {
				set i [expr $i + 1]
				set vlanType [lindex $QinQ 0]
				set hexFlag [string range $vlanType 0 1]
				if {[string tolower $hexFlag] != "0x" } {
					set vlanType 0x$vlanType
				} 
				set vlanType [format %d $vlanType]
            
				set vlanId [lindex $QinQ 1]
				set vlanPriority [lindex $QinQ 2]
				set m_vlanIfList($i) [stc::create VlanIf -under $hHost -IdList "" -vlanId $vlanId -Priority $vlanPriority -TpId $vlanType]   

				if {$i == 1} {
					stc::config $m_vlanIfList($i) -StackedOnEndpoint-targets $EtherIIF  
				} else {
					stc::config $m_vlanIfList($i) -StackedOnEndpoint-targets $m_vlanIfList([expr $i - 1])
				}             
			} 

			if {$i != 0} {
                stc::config $hIpv4If -StackedOnEndpoint-targets $m_vlanIfList($i)
			}
        }
		puts "Adding vlan ID on ethII interface has completed."
	}
	
	stc::apply
    puts "Exit the proc of CreateHost..."
}

# add by peng
# date: 2012.01.16
proc CreatePPPoEServer {args} {
     
    #Parse HostName parameter
    set index [lsearch $args -hostName] 
    if {$index != -1} {
        set hostName [lindex $args [expr $index + 1]]
    } else  {
        puts " Please specify HostName parameter \nexit the proc of CreateHost..."
    }

    #Parse pppoeServerName parameter
    set index [lsearch $args -pppoeServerName] 
    if {$index != -1} {
        set pppoeServerName [lindex $args [expr $index + 1]]
    } 
	#Parse stc port parameter
    set index [lsearch $args -stcPort] 
    if {$index != -1} {
        set stcPort [lindex $args [expr $index + 1]]
    } 
	#Parse MacAddr parameter
    set index [lsearch $args -macAddr] 
    if {$index != -1} {
        set macAddr [lindex $args [expr $index + 1]]
    } 
    #Parse IpVersion parameter
    set index [lsearch $args -ipVersion] 
    if {$index != -1} {
        set ipVersion [lindex $args [expr $index + 1]]
    } 
    set ipVersion [string tolower $ipVersion]
  
    #Parse Ipv4Addr parameter
    set index [lsearch $args -ipv4Addr] 
    if {$index != -1} {
        set ipv4Addr [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } 
	
    #Parse Ipv4SutAddr parameter
    set index [lsearch $args -ipv4Gateway] 
    if {$index != -1} {
        set ipv4AddrGateway [lindex $args [expr $index + 1]]
        if {$ipv4AddrGateway == "default"} {
			set ipv4AddrGateway [join [lreplace [split $ipv4Addr "."] 3 3 1] "."]
        }
    }
     #Parse RouterId parameter
    set index [lsearch $args -routerId] 
    if {$index != -1} {
        set routerId [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } 
	
	#ipv4PeerPoolAddr
	set index [lsearch $args -ipv4PeerPoolAddr] 
    if {$index != -1} {
        set ipv4PeerPoolAddr [lindex $args [expr $index + 1]]
        
    } 
	
	#networkCount
	set index [lsearch $args -networkCount] 
    if {$index != -1} {
        set networkCount [lindex $args [expr $index + 1]]
        
    } 
	
    #Parse Ipv4Mask parameter
    set index [lsearch $args -ipv4Mask] 
    if {$index != -1} {
        set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else {
        set index [lsearch $args -ipv4AddrprefixLen] 
        if {$index != -1} {
            set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
            set ipVersion ipv4
        } else  {
            set ipv4AddrPrefixLen 24
        }
    }
    #Parse vlanId parameter
    set index [lsearch $args -vlanTag] 
    if {$index != -1} {
        set vlanTag [lindex $args [expr $index + 1]]
		set vlanId [lindex [split $vlanTag ","] 0]
		set vlanPriority [lindex [split $vlanTag ","] 1]
    } 
	
	#Parser vlan type parameter
	set index [lsearch $args -qinqList] 
    if {$index != -1} {
        set QinQList [lindex $args [expr $index + 1]]
    }
    set hHost ""
	set portList {};
    foreach port [stc::get project1 -children-port] {
		lappend portList $port
        foreach host [stc::get $port -children-host] {
            set name [stc::get $host -name]
            set name [string tolower $name]
            if { $name != $hostName} {
                set hHost $host
				#puts "aaa: $hHost"
                break
            }
        }
    }
	
	#Parser authentication
	set index [lsearch $args -authentication] 
    if {$index != -1} {
        set authentication [lindex $args [expr $index + 1]]
    } 
	
	#Parser authenUsername
	set index [lsearch $args -authenUsr] 
    if {$index != -1} {
        set authenUsr [lindex $args [expr $index + 1]]
    } 
	
	#Parser authenPwd
	set index [lsearch $args -authenPwd] 
    if {$index != -1} {
        set authenPwd [lindex $args [expr $index + 1]]
    } 
	
    #puts [lindex $portList 1]
    if {$hHost == ""} {
        error "HostName ($hostName) can not be found, please correct!" 
    }
	
	#---------------------------------------------------
	# Create the host.
	#------------------------------------------
	#set hHost [stc::create Host -under project1 -DeviceCount $stcPort -RouterId $routerId -Name $hostName]
	set hHost [stc::create Host -under project1 \
									-DeviceCount 1 \
									-RouterId 1.1.1.1 \
									-EnablePingResponse TRUE \
									-Name $hostName]
	puts "stc::create host $hostName completed."

    #---------------------------------------------------
	# Create or Configure the ethernet II interface for the host.
	#------------------------------------------
	set hEthIIIf [stc::create EthIIIf -under $hHost -Active TRUE -SourceMac $macAddr]
	puts "Host EthIIIf creation/configuration has completed."

    #Create PPP & PPPoE interface
	set hPppoeIf [stc::create "PppoeIf" -under $hHost ]
    set hPppIf [stc::create "PppIf" -under $hHost ]

	#Create PPPoE Server��Peer Pool
	set pppoxPortCfg [lindex [stc::get [lindex $portList [expr $stcPort -1]] -children-PppoxPortConfig] 0]
    stc::config $pppoxPortCfg -EmulationType "SERVER" -ConnectRate 100 -DisconnectRate 1000

    set m_hPppoeSrvCfg [stc::create "PppoeServerBlockConfig" -under $hHost -Name $hostName ]	
    stc::config $m_hPppoeSrvCfg \
                    -MruSize 1492 \
                    -EnableEchoRequest "TRUE" \
                    -EchoRequestGenFreq 10 \
                    -LcpConfigRequestMaxAttempts 10 \
                    -NcpConfigRequestMaxAttempts 10 \
                    -LcpConfigRequestTimeout 3 \
                    -LcpTermRequestTimeout 3 \
                    -NcpConfigRequestTimeout 3 \
                    -LcpTermRequestMaxAttempts 10 \
                    -MaxNaks 5 \
                    -Authentication $authentication \
                    -Username $authenUsr \
                    -Password $authenPwd \
                    -Active True \
                    -ChapReplyTimeout 3  \
                    -PapPeerRequestTimeout 3 \
                    -LcpConfigRequestTimeout 3 \
                    -LcpTermRequestTimeout 10 \
                    -NcpConfigRequestTimeout 3 

    set m_hPppoeSrvPeerPool [lindex [stc::get $m_hPppoeSrvCfg -children-PppoeServerIpv4PeerPool] 0] 
	stc::config $m_hPppoeSrvPeerPool -AddrIncrement 1 \
									-Ipv4PeerPoolAddr $ipv4PeerPoolAddr \
									-NetworkCount $networkCount \
									-StartIpList $ipv4PeerPoolAddr \
									-PrefixLength 24 
											
	#---------------------------------------------------
	# Creating/configuring the host's IPv4 interface...
	#------------------------------------------
    if {$ipVersion == "ipv4"} {
		set hIpv4If [stc::create Ipv4If \
							-under $hHost \
							-Address $ipv4Addr \
							-PrefixLength $ipv4AddrPrefixLen \
							-UsePortDefaultIpv4Gateway "FALSE" \
							-Gateway $ipv4AddrGateway \
							-ResolveGatewayMac "TRUE" \
							-Name "Ipv4If 2"]
		
		puts "Host IPv4 interface creation/configuration has completed."
		
		stc::config $hHost -AffiliationPort-targets [lindex $portList [expr $stcPort -1]] 
		stc::config $hHost -TopLevelIf-targets $hIpv4If
		stc::config $hHost -PrimaryIf-targets $hIpv4If
		stc::config $hIpv4If -StackedOn $hEthIIIf		
	}
	    
    stc::config $hIpv4If -StackedOnEndpoint-targets " $hPppIf "
    stc::config $hPppIf -StackedOnEndpoint-targets " $hPppoeIf "

	#---------------------------------------------------
	# Adding vlan ID on ethII interface...
	#------------------------------------------	
	if {$vlanTag != -1} {
			set hVlanIf [stc::create VlanIf -under $hHost -VlanId $vlanId -Priority $vlanPriority]
			stc::config $hVlanIf -StackedOnEndpoint-targets $hEthIIIf
            stc::config $hPppoeIf -StackedOnEndpoint-targets $hVlanIf
			puts "Host VLAN interface creation/configuration has completed."
    } elseif {[lsearch $QinQList "-1"] == -1} {
			set k 0
			foreach QinQ $QinQList {
			
				set vlanTag $QinQ
				set vlanId [lindex [split $vlanTag ","] 0]
				set vlanPrio [lindex [split $vlanTag ","] 1]
				
				set m_vlanIfList($k) [stc::create VlanIf -under $hHost -IdList "" -vlanId $vlanId -Priority $vlanPrio]
				
				if {$k == 0} {
					stc::config $m_vlanIfList($k) -StackedOnEndpoint-targets $hEthIIIf 	
				} else {
					stc::config $m_vlanIfList($k) -StackedOnEndpoint-targets $m_vlanIfList([expr $k - 1])	
				}
				incr k
			}
			if {$k != 0} {
                stc::config $hPppoeIf -StackedOnEndpoint-targets $m_vlanIfList([expr $k -1])			
			} 
        	puts "Host QinQ interface creation/configuration has completed."
	} else {
		stc::config $hPppoeIf -StackedOnEndpoint-targets " $hEthIIIf "
	}		
	stc::config $m_hPppoeSrvCfg -UsesIf-targets " $hIpv4If $hPppoeIf "		
    stc::apply

    puts "Exit the proc of CreatePPPoEServer..."
}

proc CreatePPPoEClient {args} {
     
    #Parse HostName parameter
    set index [lsearch $args -hostName] 
    if {$index != -1} {
        set hostName [lindex $args [expr $index + 1]]
    } else  {
        puts " Please specify HostName parameter \nexit the proc of CreateHost..."
    } 
	#Parse stc port parameter
    set index [lsearch $args -stcPort] 
    if {$index != -1} {
        set stcPort [lindex $args [expr $index + 1]]
    } 
	#Parse pppoe server name parameter
    set index [lsearch $args -pppoeServerName] 
    if {$index != -1} {
        set pppoeServerName [lindex $args [expr $index + 1]]
    } 
	#Parse MacAddr parameter
    set index [lsearch $args -macAddr] 
    if {$index != -1} {
        set macAddr [lindex $args [expr $index + 1]]
    } 
    #Parse IpVersion parameter
    set index [lsearch $args -ipVersion] 
    if {$index != -1} {
        set ipVersion [lindex $args [expr $index + 1]]
    } 
    set ipVersion [string tolower $ipVersion]
  
    #Parse Ipv4Addr parameter
    set index [lsearch $args -ipv4Addr] 
    if {$index != -1} {
        set ipv4Addr [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } 
	
     #Parse RouterId parameter
    set index [lsearch $args -routerId] 
    if {$index != -1} {
        set routerId [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } 
	
    #Parse Ipv4Mask parameter
    set index [lsearch $args -ipv4Mask] 
    if {$index != -1} {
        set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else {
        set index [lsearch $args -ipv4AddrprefixLen] 
        if {$index != -1} {
            set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
            set ipVersion ipv4
        } else  {
            set ipv4AddrPrefixLen 24
        }
    }
    #Parse vlanId parameter
    set index [lsearch $args -vlanTag] 
    if {$index != -1} {
        set vlanTag [lindex $args [expr $index + 1]]
		set vlanId [lindex [split $vlanTag ","] 0]
		set vlanPriority [lindex [split $vlanTag ","] 1]
    } 
	
	#Parser vlan type parameter
	set index [lsearch $args -qinqList] 
    if {$index != -1} {
        set QinQList [lindex $args [expr $index + 1]]
    }
    set hHost ""
	set portList {};
    foreach port [stc::get project1 -children-port] {
		lappend portList $port
        foreach host [stc::get $port -children-host] {
            set name [stc::get $host -name]
            set name [string tolower $name]
            if { $name != $hostName} {
                set hHost $host
				#puts "aaa: $hHost"
                break
            }
        }
    }
	
	#Parser authentication
	set index [lsearch $args -authentication] 
    if {$index != -1} {
        set authentication [lindex $args [expr $index + 1]]
    } 
	
	#Parser authenUsername
	set index [lsearch $args -authenUsr] 
    if {$index != -1} {
        set authenUsr [lindex $args [expr $index + 1]]
    } 
	
	#Parser authenPwd
	set index [lsearch $args -authenPwd] 
    if {$index != -1} {
        set authenPwd [lindex $args [expr $index + 1]]
    } 
	
    #puts [lindex $portList 1]
    if {$hHost == ""} {
        error "HostName ($hostName) can not be found, please correct!" 
    }
	
	#---------------------------------------------------
	# Create the host.
	#------------------------------------------
	#set hHost [stc::create Host -under project1 -DeviceCount $stcPort -RouterId $routerId -Name $hostName]
	set hHost [stc::create Host -under project1 -DeviceCount 1 -RouterId 1.1.1.1 -Name $hostName]
	puts "stc::create host $hostName completed."

    #---------------------------------------------------
	# Create or Configure the ethernet II interface for the host.
	#------------------------------------------
	set hEthIIIf [stc::create EthIIIf -under $hHost -Active TRUE -SourceMac $macAddr]
	puts "Host EthIIIf creation/configuration has completed."

    set m_hPppoeClientCfg [stc::create "PppoeClientBlockConfig" -under $hHost]

	set pppoxPortCfg [lindex [stc::get [lindex $portList [expr $stcPort -1]] -children-PppoxPortConfig] 0]
    stc::config $pppoxPortCfg -EmulationType "CLIENT" -ConnectRate 100 -DisconnectRate 1000
    
	#Create PPP & PPPoE interface
	set hPppoeIf [stc::create "PppoeIf" -under $hHost ]
    set hPppIf [stc::create "PppIf" -under $hHost ]
    stc::config $m_hPppoeClientCfg -PapRequestTimeout 3 \
                    -MruSize 1492 \
					-AutoRetryCount 65535 \
                    -EnableEchoRequest "TRUE" \
                    -EchoRequestGenFreq 10 \
                    -LcpConfigRequestMaxAttempts 10 \
                    -NcpConfigRequestMaxAttempts 10 \
                    -LcpTermRequestMaxAttempts 10 \
                    -MaxNaks 5 \
                    -Authentication $authentication \
                    -Username $authenUsr \
                    -Password $authenPwd \
                    -Active TRUE \
                     -EnableMruNegotiation TRUE \
                    -ChapAckTimeout 3 \
                    -ChapChalRequestTimeout 3 \
                    -PadiTimeout 3 \
                    -PadiMaxAttempts 10 \
                    -PadrTimeout 3 \
                    -PadrMaxAttempts 10
					       
	#---------------------------------------------------
	# Creating/configuring the host's IPv4 interface...
	#------------------------------------------
    if {$ipVersion == "ipv4"} {
		set hIpv4If [stc::create Ipv4If \
							-under $hHost \
							-Address $ipv4Addr \
							-PrefixLength $ipv4AddrPrefixLen \
							-UsePortDefaultIpv4Gateway "FALSE" \
							-ResolveGatewayMac "TRUE" \
							-Name "Ipv4If 2"]
		
		puts "Host IPv4 interface creation/configuration has completed."
		
		stc::config $hHost -AffiliationPort-targets [lindex $portList [expr $stcPort -1]] 
		stc::config $hHost -TopLevelIf-targets $hIpv4If
		stc::config $hHost -PrimaryIf-targets $hIpv4If
		stc::config $hIpv4If -StackedOn $hEthIIIf		
	}
	    
    stc::config $hIpv4If -StackedOnEndpoint-targets " $hPppIf "
    stc::config $hPppIf -StackedOnEndpoint-targets " $hPppoeIf "

	#---------------------------------------------------
	# Adding vlan ID on ethII interface...
	#------------------------------------------	
	if {$vlanTag != -1} {
			set hVlanIf [stc::create VlanIf -under $hHost -VlanId $vlanId -Priority $vlanPriority]
			stc::config $hVlanIf -StackedOnEndpoint-targets $hEthIIIf
            stc::config $hPppoeIf -StackedOnEndpoint-targets $hVlanIf
			puts "Host VLAN interface creation/configuration has completed."
    } elseif {[lsearch $QinQList "-1"] == -1} {
			set k 0
			foreach QinQ $QinQList {
			
				set vlanTag $QinQ
				set vlanId [lindex [split $vlanTag ","] 0]
				set vlanPrio [lindex [split $vlanTag ","] 1]				
				set m_vlanIfList($k) [stc::create VlanIf -under $hHost -IdList "" -vlanId $vlanId -Priority $vlanPrio]
				
				if {$k == 0} {
					stc::config $m_vlanIfList($k) -StackedOnEndpoint-targets $hEthIIIf 	
				} else {
					stc::config $m_vlanIfList($k) -StackedOnEndpoint-targets $m_vlanIfList([expr $k - 1])	
				}
				incr k
			}
			if {$k != 0} {
                stc::config $hPppoeIf -StackedOnEndpoint-targets $m_vlanIfList([expr $k -1])			
			} 
        puts "Host QinQ interface creation/configuration has completed."	
	} else {
		stc::config $hPppoeIf -StackedOnEndpoint-targets " $hEthIIIf "
	}		
	stc::config $m_hPppoeClientCfg -UsesIf-targets " $hIpv4If $hPppoeIf "		
    stc::apply

    puts "Exit the proc of CreatePPPoEClient..."
}

proc CreateDhcpServer {args} {
     
    #Parse HostName parameter
    set index [lsearch $args -hostName] 
    if {$index != -1} {
        set hostName [lindex $args [expr $index + 1]]
    } else  {
        puts " Please specify HostName parameter \nexit the proc of CreateHost..."
    } 
	#Parse stc port parameter
    set index [lsearch $args -stcPort] 
    if {$index != -1} {
        set stcPort [lindex $args [expr $index + 1]]
    } 
	#Parse pppoe server name parameter
    set index [lsearch $args -dhcpServerName] 
    if {$index != -1} {
        set dhcpServerName [lindex $args [expr $index + 1]]
    } 
	#Parse MacAddr parameter
    set index [lsearch $args -macAddr] 
    if {$index != -1} {
        set macAddr [lindex $args [expr $index + 1]]
    } 
    #Parse IpVersion parameter
    set index [lsearch $args -ipVersion] 
    if {$index != -1} {
        set ipVersion [lindex $args [expr $index + 1]]
    } 
    set ipVersion [string tolower $ipVersion]
  
    #Parse Ipv4Addr parameter
    set index [lsearch $args -ipv4Addr] 
    if {$index != -1} {
        set ipv4Addr [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } 
	
    #Parse Ipv4SutAddr parameter
    set index [lsearch $args -ipv4AddrGateway] 
    if {$index != -1} {
        set ipv4AddrGateway [lindex $args [expr $index + 1]]
		puts $ipv4AddrGateway
        if {$ipv4AddrGateway == "default"} {
			set ipv4AddrGateway [join [lreplace [split $ipv4Addr "."] 3 3 1] "."]
			puts $ipv4AddrGateway
        }
    }

     #Parse RouterId parameter
    set index [lsearch $args -routerId] 
    if {$index != -1} {
        set routerId [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } 
	
    #Parse Ipv4Mask parameter
    set index [lsearch $args -ipv4Mask] 
    if {$index != -1} {
        set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else {
        set index [lsearch $args -ipv4AddrprefixLen] 
        if {$index != -1} {
            set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
            set ipVersion ipv4
        } else  {
            set ipv4AddrPrefixLen 24
        }
    }
    #Parse vlanId parameter
    set index [lsearch $args -vlanTag] 
    if {$index != -1} {
        set vlanTag [lindex $args [expr $index + 1]]
		set vlanId [lindex [split $vlanTag ","] 0]
		set vlanPriority [lindex [split $vlanTag ","] 1]
    } 
	
	#Parser vlan type parameter
	set index [lsearch $args -qinqList] 
    if {$index != -1} {
        set QinQList [lindex $args [expr $index + 1]]
    }
    set hHost ""
	set portList {};
    foreach port [stc::get project1 -children-port] {
		lappend portList $port
        foreach host [stc::get $port -children-host] {
            set name [stc::get $host -name]
            set name [string tolower $name]
            if { $name != $hostName} {
                set hHost $host
                break
            }
        }
    }
	set poolName cig
	#Parser leaseTime
	set index [lsearch $args -leaseTime] 
    if {$index != -1} {
        set leaseTime [lindex $args [expr $index + 1]]
    } 
	
	#Parser poolStart
	set index [lsearch $args -poolStart] 
    if {$index != -1} {
        set poolStart [lindex $args [expr $index + 1]]
    } 
	
	#Parser prefixLen
	set index [lsearch $args -prefixLen] 
    if {$index != -1} {
        set prefixLen [lindex $args [expr $index + 1]]
    } 
	#Parser poolNum
	set index [lsearch $args -poolNum] 
    if {$index != -1} {
        set poolNum [lindex $args [expr $index + 1]]
    } 	
    #puts [lindex $portList 1]
    if {$hHost == ""} {
        error "HostName ($hostName) can not be found, please correct!" 
    }
	
	#---------------------------------------------------
	# Create the Dhcp host.
	#------------------------------------------
	#set hHost [stc::create Host -under project1 -DeviceCount $stcPort -RouterId $routerId -Name $hostName]
	set hHost [stc::create Host -under project1 -DeviceCount 1 -RouterId 1.1.1.1 -Name $hostName]
	puts "stc::create host $hostName completed."

    #---------------------------------------------------
	# Create or Configure the ethernet II interface for the host.
	#------------------------------------------
	set hEthIIIf [stc::create EthIIIf -under $hHost -Active TRUE -SourceMac $macAddr]
	puts "Host EthIIIf creation/configuration has completed."

    #set m_hdhcpv4ServerCfg [stc::create "Dhcpv4BlockConfig" -under $hHost]
	set dhcpv4PortCfg [lindex [stc::get [lindex $portList [expr $stcPort -1]] -children-Dhcpv4PortConfig] 0]
    stc::config $dhcpv4PortCfg -RequestRate 100.0 -ReleaseRate 100.0 -RetryCount 4 -Active True

    #Create DHCPv4 Server,block,defaultPool
	set hDhcpSrvCfg [stc::create "Dhcpv4ServerConfig" -under $hHost -Name $dhcpServerName ]
	stc::config $hDhcpSrvCfg -LeaseTime $leaseTime
	#public variable m_hDhcpSrvRelayAgentPoolCfg														
    #Configure server pool address and Relay Agent pool. If ipv4Addr and poolStart in the same
    #network, then use server pool address; otherwise will use Relay Agent pool
    set m_hDhcpSrvPoolCfg [lindex [stc::get $hDhcpSrvCfg -children-Dhcpv4ServerDefaultPoolConfig] 0] 
    set serverIpNetmask [ipnetmask $ipv4Addr $prefixLen]
    set poolIpNetmask [ipnetmask $poolStart $prefixLen]
    if {$serverIpNetmask == $poolIpNetmask} { 
        puts "Config server default address pool ..."
        set hDhcpSrvPoolCfg $m_hDhcpSrvPoolCfg 
        stc::config $hDhcpSrvPoolCfg -StartIpList $poolStart \
									-PrefixLength $prefixLen \
									-HostAddrStep 0.0.0.1 \
									-LimitHostAddrCount "TRUE" \
									-HostAddrCount $poolNum

        if {[info exists poolName]} {
            stc::config $hDhcpSrvPoolCfg -Name $poolName
        }    
    } else {
		if {$poolName != ""} {
            #puts "Config relay agent address pool, pool name is:$m_poolName ..."
            if {[info exists m_hDhcpSrvRelayAgentPoolCfg($poolName)]} { 
                set hDhcpSrvPoolCfg $m_hDhcpSrvRelayAgentPoolCfg($poolName)
                stc::config $hDhcpSrvPoolCfg -StartIpList $poolStart -PrefixLength $prefixLen \
                       -HostAddrStep 0.0.0.1 -LimitHostAddrCount "TRUE" \
                       -HostAddrCount $poolNum
            } else {
                stc::config $m_hDhcpSrvPoolCfg \
                     -RouterList "" \
					 -DomainNameServerList "" \
                     -StartIpList $poolStart \
					 -PrefixLength $prefixLen \
                     -HostAddrStep 0.0.0.1 \
					 -LimitHostAddrCount "TRUE" \
                     -HostAddrCount $poolNum \
					 -Name $poolName]
                set m_hDhcpSrvRelayAgentPoolCfg($poolName) $m_hDhcpSrvPoolCfg
            }
        } 

        set defaultPoolStart [stc::get $m_hDhcpSrvPoolCfg -StartIpList]
        set defaultPoolIpNetmask [ipnetmask $defaultPoolStart $prefixLen]
        if {$defaultPoolIpNetmask != $serverIpNetmask} {
            set testIpAddrDec [ipaddr2dec $ipv4Addr]
            set testIpAddrDec [expr $testIpAddrDec + 1]
            set poolStartIpAddr [dec2ipaddr $testIpAddrDec]
            stc::config $m_hDhcpSrvPoolCfg -StartIpList $poolStartIpAddr
        }
    }       

        #Create Dhcpv4ServerMsgOption handle
        set m_hDhcpSrvOfferOption [stc::create "Dhcpv4ServerMsgOption" -under $hDhcpSrvCfg -MsgType OFFER ]       
        #Create Dhcpv4ServerMsgOption handle
        set m_hDhcpSrvAckOption [stc::create "Dhcpv4ServerMsgOption" -under $hDhcpSrvCfg -MsgType ACK]
					       
	#---------------------------------------------------
	# Creating/configuring the host's IPv4 interface...
	#------------------------------------------
    if {$ipVersion == "ipv4"} {
		set hIpv4If [stc::create Ipv4If \
							-under $hHost \
							-Address $ipv4Addr \
							-PrefixLength $prefixLen \
							-UsePortDefaultIpv4Gateway "FALSE" \
							-Gateway $ipv4AddrGateway \
							-ResolveGatewayMac "TRUE" \
							-Name "Ipv4If 2"]
		
		puts "Host IPv4 interface creation/configuration has completed."
		
		stc::config $hHost -AffiliationPort-targets [lindex $portList [expr $stcPort -1]] 
		stc::config $hHost -TopLevelIf-targets $hIpv4If
		stc::config $hHost -PrimaryIf-targets $hIpv4If
		stc::config $hIpv4If -StackedOn $hEthIIIf		
	}
	#Build the relationships between objects
    stc::config $hDhcpSrvCfg -UsesIf-targets $hIpv4If      

	#---------------------------------------------------
	# Adding vlan ID on ethII interface...
	#------------------------------------------	
	if {$vlanTag != -1} {
			set hVlanIf [stc::create VlanIf -under $hHost -VlanId $vlanId -Priority $vlanPriority]
			stc::config $hVlanIf -StackedOnEndpoint-targets $hEthIIIf
			stc::config $hIpv4If -StackedOnEndpoint-targets $hVlanIf
            puts "Host VLAN interface creation/configuration has completed."
    } elseif {[lsearch $QinQList "-1"] == -1} {
		set k 0
		foreach QinQ $QinQList {		
			set vlanTag $QinQ
			set vlanId [lindex [split $vlanTag ","] 0]
			set vlanPrio [lindex [split $vlanTag ","] 1]				
			set m_vlanIfList($k) [stc::create VlanIf -under $hHost -IdList "" -vlanId $vlanId -Priority $vlanPrio]
				
			if {$k == 0} {
				stc::config $m_vlanIfList($k) -StackedOnEndpoint-targets $hEthIIIf 	
			} else {
					stc::config $m_vlanIfList($k) -StackedOnEndpoint-targets $m_vlanIfList([expr $k - 1])	
			}
				incr k
		}
			if {$k != 0} {
                stc::config $hIpv4If -StackedOnEndpoint-targets $m_vlanIfList([expr $k -1])			
			} 
        puts "Host QinQ interface creation/configuration has completed."	
	} else {
		stc::config $hIpv4If -StackedOnEndpoint-targets " $hEthIIIf "
	}		
	#stc::config $dhcpv4PortCfg -UsesIf-targets " $hIpv4If"		
    stc::apply

    puts "Exit the proc of CreateDHCPServer..."
}

proc CreateDhcpClient {args} {
     
    #Parse HostName parameter
    set index [lsearch $args -hostName] 
    if {$index != -1} {
        set hostName [lindex $args [expr $index + 1]]
    } else  {
        puts " Please specify HostName parameter \nexit the proc of CreateHost..."
    } 
	#Parse stc port parameter
    set index [lsearch $args -stcPort] 
    if {$index != -1} {
        set stcPort [lindex $args [expr $index + 1]]
    } 
	#Parse pppoe server name parameter
    set index [lsearch $args -dhcpServerName] 
    if {$index != -1} {
        set dhcpServerName [lindex $args [expr $index + 1]]
    } 
	#Parse MacAddr parameter
    set index [lsearch $args -macAddr] 
    if {$index != -1} {
        set macAddr [lindex $args [expr $index + 1]]
    } 
	
    #Parse Ipv4SutAddr parameter
    set index [lsearch $args -ipv4Gateway] 
    if {$index != -1} {
        set ipv4Gateway [lindex $args [expr $index + 1]]
    } 
     #Parse RouterId parameter
    set index [lsearch $args -routerId] 
    if {$index != -1} {
        set routerId [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } 
	
    #Parse vlanId parameter
    set index [lsearch $args -vlanTag] 
    if {$index != -1} {
        set vlanTag [lindex $args [expr $index + 1]]
		set vlanId [lindex [split $vlanTag ","] 0]
		set vlanPriority [lindex [split $vlanTag ","] 1]
    } 
	
	#Parser vlan type parameter
	set index [lsearch $args -qinqList] 
    if {$index != -1} {
        set QinQList [lindex $args [expr $index + 1]]
    }
    set hHost ""
	set portList {};
    foreach port [stc::get project1 -children-port] {
		lappend portList $port
        foreach host [stc::get $port -children-host] {
            set name [stc::get $host -name]
            set name [string tolower $name]
            if { $name != $hostName} {
                set hHost $host
				#puts "aaa: $hHost"
                break
            }
        }
    }
	set poolName cig
	#Parser clientType
	set index [lsearch $args -clientType] 
    if {$index != -1} {
        set clientType [lindex $args [expr $index + 1]]
    } 
	
	#Parser relayAgentIpAddr
	set index [lsearch $args -relayAgentIpAddr] 
    if {$index != -1} {
        set relayAgentIpAddr [lindex $args [expr $index + 1]]
    } 
	
	#Parser serverIpAddr
	set index [lsearch $args -serverIpAddr] 
    if {$index != -1} {
        set serverIpAddr [lindex $args [expr $index + 1]]
    } 
	#Parser payLoad
	set index [lsearch $args -payLoad] 
    if {$index != -1} {
        set payLoad [lindex $args [expr $index + 1]]
		if {$payLoad == "None" } {
			set payLoad ""
		} 
    } 
	#Parser MsgType
	set index [lsearch $args -msgType] 
    if {$index != -1} {
        set msgType [lindex $args [expr $index + 1]]
    } 

	#Parser OptionType
	set index [lsearch $args -optionType] 
    if {$index != -1} {
        set OptionType [lindex $args [expr $index + 1]]
    } 	
    #puts [lindex $portList 1]
    if {$hHost == ""} {
        error "HostName ($hostName) can not be found, please correct!" 
    }
	
	#---------------------------------------------------
	# Create the Dhcp host.
	#------------------------------------------
	set hHost [stc::create Host -under project1 -DeviceCount 1 -RouterId 1.1.1.1 -Name $hostName]
	puts "stc::create host $hostName completed."

    #---------------------------------------------------
	# Create or Configure the ethernet II interface for the host.
	#------------------------------------------
	set hEthIIIf [stc::create EthIIIf -under $hHost -Active TRUE -SourceMac $macAddr]
	puts "Host EthIIIf creation/configuration has completed."
		       
	#---------------------------------------------------
	# Creating/configuring the host's IPv4 interface...
	#------------------------------------------
	set hIpv4If [stc::create Ipv4If \
							-under $hHost \
							-UsePortDefaultIpv4Gateway "FALSE" \
							-ResolveGatewayMac "TRUE" \
							-Name "Ipv4If 2"]	
	puts "Host IPv4 interface creation/configuration has completed."
 
	stc::config $hHost -AffiliationPort-targets [lindex $portList [expr $stcPort -1]] 
	stc::config $hHost -TopLevelIf-targets $hIpv4If
	stc::config $hHost -PrimaryIf-targets $hIpv4If
	stc::config $hIpv4If -StackedOn $hEthIIIf		
	
    #set m_hdhcpv4ServerCfg [stc::create "Dhcpv4BlockConfig" -under $hHost]
	set dhcpv4PortCfg [lindex [stc::get [lindex $portList [expr $stcPort -1]] -children-Dhcpv4PortConfig] 0]
    stc::config $dhcpv4PortCfg -RequestRate 100.0 -ReleaseRate 100.0 -RetryCount 4 -Active True

	set hDhcpBlkCfg [stc::create "Dhcpv4BlockConfig"  -under $hHost \
						-Name $hostName \
						-UseBroadcastFlag FALSE \
						-EnableAutoRetry "TRUE" \
						-RetryAttempts 4 \
						-EnableCircuitId FALSE \
						-EnableRemoteId FALSE \
						-EnableRouterOption TRUE \
						-OptionList "1 3 6 15 33 44 51" \
						-Active True]
    
	
	
    if {$clientType == "dhcprelay"} {
        stc::config $hDhcpBlkCfg -EnableRelayAgent TRUE
        if {$relayAgentIpAddr != "-1"} {
            stc::config $hDhcpBlkCfg -RelayAgentIpv4Addr $relayAgentIpAddr
        }
        if {$serverIpAddr != "-1"} {
            stc::config $hDhcpBlkCfg -RelayServerIpv4Addr $serverIpAddr
        }
        stc::config $hDhcpBlkCfg -RelayClientMacAddrStart $macAddr -RelayClientMacAddrStep 00-00-00-00-00-01
    }

    if {$ipv4Gateway != -1} {
         stc::config $hIpv4If -Gateway $ipv4Gateway
    }
    
	set counter 0
   # if {$payLoad != ""} {
        switch $OptionType {
                    "submask" {
                        set m_hDiscoveryOptionArr($counter) [stc::create "Dhcpv4MsgOption" -under $hDhcpBlkCfg -MsgType $msgType -OptionType 1 -Payload $payLoad -HexValue FALSE]                        
                    }
                    "dns" {
                        set m_hDiscoveryOptionArr($counter) [stc::create "Dhcpv4MsgOption" -under $hDhcpBlkCfg -MsgType $msgType -OptionType 6 -Payload $payLoad -HexValue FALSE]                        
                    }
                    "relayagent" {
                        set m_hDiscoveryOptionArr($counter) [stc::create "Dhcpv4MsgOption" -under $hDhcpBlkCfg -MsgType $msgType -OptionType 82 -Payload $payLoad -HexValue FALSE]                        
                    }
                    "gateway" {
                        set m_hDiscoveryOptionArr($counter) [stc::create "Dhcpv4MsgOption" -under $hDhcpBlkCfg -MsgType $msgType -OptionType 3 -Payload $payLoad -HexValue FALSE]                        
                    }
                    "classidentifier" {
                        set m_hDiscoveryOptionArr($counter) [stc::create "Dhcpv4MsgOption" -under $hDhcpBlkCfg -MsgType $msgType -OptionType 60 -Payload $payLoad -HexValue FALSE]
                    }                                  
        }        
   # }

	#Build the relationships between objects
    stc::config $hDhcpBlkCfg -UsesIf-targets $hIpv4If 
	#---------------------------------------------------
	# Adding vlan ID on ethII interface...
	#------------------------------------------	
	if {$vlanTag != -1} {
			set hVlanIf [stc::create VlanIf -under $hHost -VlanId $vlanId -Priority $vlanPriority]
			stc::config $hVlanIf -StackedOnEndpoint-targets $hEthIIIf
			stc::config $hIpv4If -StackedOnEndpoint-targets $hVlanIf
            puts "Host VLAN interface creation/configuration has completed."
    } elseif {[lsearch $QinQList "-1"] == -1} {
		set k 0
		foreach QinQ $QinQList {		
			set vlanTag $QinQ
			set vlanId [lindex [split $vlanTag ","] 0]
			set vlanPrio [lindex [split $vlanTag ","] 1]				
			set m_vlanIfList($k) [stc::create VlanIf -under $hHost -IdList "" -vlanId $vlanId -Priority $vlanPrio]
				
			if {$k == 0} {
				stc::config $m_vlanIfList($k) -StackedOnEndpoint-targets $hEthIIIf 	
			} else {
					stc::config $m_vlanIfList($k) -StackedOnEndpoint-targets $m_vlanIfList([expr $k - 1])	
			}
				incr k
		}
			if {$k != 0} {
                stc::config $hIpv4If -StackedOnEndpoint-targets $m_vlanIfList([expr $k -1])			
			} 
        puts "Host QinQ interface creation/configuration has completed."	
	} else {
		stc::config $hIpv4If -StackedOnEndpoint-targets " $hEthIIIf "
	}		
	
    stc::apply

    puts "Exit the proc of CreateDHCPClient..."
}

proc DeleteStcStream {streamNames} {
    foreach streamName $streamNames {
        set streamName [string tolower $streamName]
        if {1} {
            foreach hPort [stc::get project1 -children-port] {
                foreach stream [stc::get $hPort -children-streamblock] {
                    set name [stc::get $stream -name]
                    set name [string tolower $name]
                    if {$name != $streamName} {continue}
                    stc::delete $stream 
                    puts "stc::delete $stream  "
                    break
                }
            }
        }    
    }
}

proc GetStreamStats {streamNames} {
    after 3000
    puts ""  
    foreach streamName $streamNames {
    set streamName [string tolower $streamName]

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($streamName) can not be found, please correct!" 
    }

           set txFrameCnt 0
           set txL1BitRate 0
           set txL2BitRate 0
           set txFrameRate 0

           set rxL1BitRate 0
           set rxL2BitRate 0
           set rxFrameRate 0
           set rxFrameCnt 0   
           set droppedFrameCountRealTime 0
                
       foreach hTxResult [stc::get $hStream -children-txstreamresults] {
           set txFrameCnt [stc::get $hTxResult -FrameCount]
           set txL1BitRate [stc::get $hTxResult -L1bitRate]
           set txL2BitRate [stc::get $hTxResult -BitRate]
           set txFrameRate [stc::get $hTxResult -FrameRate]           
       }
       foreach hRxResult [stc::get $hStream -children-RxStreamsummaryResults] {
                set rxL1BitRate [stc::get $hRxResult -l1bitrate]
                set rxL2BitRate [stc::get $hRxResult -bitrate]
                set rxFrameRate [stc::get $hRxResult -sigframerate]
                set rxFrameCnt [stc::get $hRxResult -SigFrameCount]   
                set droppedFrameCountRealTime [stc::get $hRxResult -DroppedFrameCount]
				#set droppedFramePercent [stc::get $hRxResult -DroppedFramePercent]
       }

       if {$txFrameCnt > 0} {
           set frameLossCnt [expr $txFrameCnt - $rxFrameCnt]
           set frameLossPct [expr $frameLossCnt * 100.0 / $txFrameCnt]
       } else {
           set frameLossCnt NA
           set frameLossPct NA
       }
       after 2000
       puts ---------------------------
       puts streamName=$streamName
       puts txFrameCnt=$txFrameCnt
       puts txL1BitRate=$txL1BitRate
       puts txL2BitRate=$txL2BitRate
       puts txFrameRate=$txFrameRate
       puts rxFrameCnt=$rxFrameCnt
       puts rxL1BitRate=$rxL1BitRate
       puts rxL2BitRate=$rxL2BitRate
       puts rxFrameRate=$rxFrameRate
       puts frameLossCnt=$frameLossCnt
       puts frameLossPct="$frameLossPct %"   
       puts droppedFrameCountRealTime=$droppedFrameCountRealTime
	   #puts droppedFramePercent=$droppedFramePercent
       after 2000
   }
}




proc GetStcStreamStats {streamNames {rxPortName "all"}} {
    set allPortName ""
    if {$rxPortName =="all"} {
        foreach port [stc::get project1 -children-port] {
            lappend allPortName [string tolower [stc::get $port -name]]
        }
        set rxPortName $allPortName
    }
    set rxPortName [string tolower $rxPortName]
    set streamNames [string tolower $streamNames]
    
    foreach streamName $streamNames {
        set hStream ""
        set streamName [string tolower $streamName]        
       
            foreach hPort [stc::get project1 -children-port] {
               set portName [stc::get $port -name]
                foreach stream [stc::get $hPort -children-streamblock] {
                    set name [stc::get $stream -name]
                    set name [string tolower $name]
                    if {[string first $streamName $name] == -1} {continue}
                    set hStream $stream
                }
            }
     
        if {$hStream == ""} {
            puts "error:$streamName not found!"
        } else {
            foreach result [stc::get $hStream -resultchild-targets] {
                if {[string first txstreamresults $result] != -1} {
                    puts ==================================
                    puts streamName=$streamName                    
                    puts txPort=$portName
                    puts txCnt=[stc::get $result -frameCount]
                    puts txRate=[stc::get $result -frameRate]
                } elseif {[string first rxstreamsummaryresults $result] != -1} {
                    set rxPort ""
                    set rxCnt ""
                    set rxRate ""
                    foreach subResult [stc::get $result -resultchild-targets] {
                        set analyzer [stc::get $subResult -parent]
                        set hRxPort [stc::get $analyzer -parent]
                        set portName [string tolower [stc::get $hRxPort -name]]
                        if {[string first $portName $rxPortName] == -1} {continue}
                        lappend rxPort [stc::get $hRxPort -name]
                        lappend rxCnt [stc::get $subResult -sigFrameCount]
                        lappend rxRate [stc::get $subResult -sigFrameRate]
                    }
                    puts rxPort=$rxPort
                    puts rxCnt=$rxCnt
                    puts rxRate=$rxRate
                }
            }
        }
    }
}
proc GetPortIgmpStats {{portName all}} {
    set hPortList ""
    set portName [string tolower $portName]
    
    foreach port [stc::get project1 -children-port] {
        if {$portName == "all"} {
             lappend hPortList $port
             continue
        }
        set name [string tolower [stc::get $port -name]]
        if {[string first $name $portName] != -1} {
            lappend hPortList $port
        }
    } 

    if {$hPortList == ""} {
        puts "error: port ($portName) not found !"
        return
    }
    foreach port $hPortList {
           set name [stc::get $port -name]
           foreach igmpportconfig [stc::get $port -children-igmpportconfig] {
               foreach igmpportresults [stc::get $igmpportconfig -resultchild-Targets] {
                   puts ====================
                   puts portName=$name
                   catch {array unset arr}
                   array set arr [stc::get $igmpportresults]
                   catch {unset arr(-Active)}
                   catch {unset arr(-Name)}
                   catch {unset arr(-parent)}
                   catch {unset arr(-resultchild-Sources)}
                   foreach name [array names arr] {
                      set name1 [string map {- ""} $name]
                       puts $name1=$arr($name)
                   }
               }
           }
    }    
}


proc GetFilteredStats {} {
#��ȡ����ͳ�����?
after 3000
puts ""  
catch {array unset txArr}
foreach port [stc::get project1 -children-port] {
    set location [stc::get $port -location]
    foreach stream [stc::get $port -children-streamblock] {
       set streamName [stc::get $stream -name]
       foreach hTxResult [stc::get $stream -children-txstreamresults] {
           set streamId [stc::get $hTxResult -StreamId]
           set txCnt [stc::get $hTxResult -FrameCount]
           set txArr($streamId) $txCnt
           set txPort($streamId) $location
           set streamNameArr($streamId) $streamName

          set txRate(L1BitRate,$streamId) [stc::get $hTxResult -L1bitRate]
          set txRate(L2BitRate,$streamId) [stc::get $hTxResult -BitRate]
          set txRate(FrameRate,$streamId) [stc::get $hTxResult -FrameRate]           
       }
    }    
}
#��ȡ����ͳ�����?
set resultDataSetList [stc::get project1 -children-resultdataset]
set filteredResultHandleList ""
set resultDataSetListToBeDelete ""
set resultDataSetList [stc::get project1 -children-resultdataset]
set flag 0

foreach resultDataSet $resultDataSetList {
    set ResultHandleList [stc::get $resultDataSet -ResultHandleList] 
    foreach ResultHandle $ResultHandleList {
        set index [string first "filteredstream" $ResultHandle]
        if {$index != -1} {
            lappend filteredResultHandleList  $ResultHandle
            set flag 1
        }
    }
    if {$flag} {
        lappend resultDataSetListToBeDelete $resultDataSet
    }
}

catch {array unset statsArr}
catch {array unset rxRate}
set streamIdList ""
foreach filteredResultHandle $filteredResultHandleList {
    catch {array unset arr}
    array set arr [stc::get $filteredResultHandle]   
    catch {unset filterStatsList}
    set analyzer $arr(-parent)
    set port [stc::get $analyzer -parent]
    
    
    for {set i 1} {$i<=10} {incr i} {
        if {$arr(-FilteredName_$i) != "" } {
            lappend filterStatsList $arr(-FilteredName_$i)
            lappend filterStatsList $arr(-FilteredValue_$i)

            set name1 [string tolower $arr(-FilteredName_$i)]
            set index1 [string first "rx" $name1]
            set index2 [string first "stream" $name1]
            set index3 [string first "id" $name1]
            if {($index1!=-1)&&($index2!=-1)&&($index3!=-1)} {
                set streamId $arr(-FilteredValue_$i)

                if {[lsearch $streamIdList $streamId] == -1} {
                    lappend streamIdList $streamId
                }                
                
                set statsArr(txFrameCount,$streamId) $txArr($streamId)
                set statsArr(txPort,$streamId) $txPort($streamId)
                set statsArr(streamName,$streamId) $streamNameArr($streamId)

               set statsArr(rxFrameCount,$streamId) $arr(-SigFrameCount)
               set statsArr(minFrameSize,$streamId) $arr(-MinFrameLength)
               set statsArr(maxFrameSize,$streamId) $arr(-MaxFrameLength)   
               set statsArr(rxPort,$streamId) [stc::get $port -location]  

               set rxRate(L1BitRate,$streamId) $arr(-L1BitRate) 
               set rxRate(L2BitRate,$streamId) $arr(-BitRate)
               set rxRate(FrameRate,$streamId) $arr(-SigFrameRate)
                
               
                if {$statsArr(txFrameCount,$streamId) <= 0} {
                    set statsArr(frameLoss,$streamId) "NA"
                } else {
                    set statsArr(frameLoss,$streamId) [expr ($statsArr(txFrameCount,$streamId) - $statsArr(rxFrameCount,$streamId)) * 100.0 / $statsArr(txFrameCount,$streamId) ]%
                }                
            }            
        }
    }
    set statsArr(filterstats,$streamId) $filterStatsList
}

foreach streamId $streamIdList {
    puts ------------------------------------
    puts streamName=>$statsArr(streamName,$streamId) 
    puts txPort=>$statsArr(txPort,$streamId)
    puts rxPort=>$statsArr(rxPort,$streamId)
    puts txFrameCnt=>$statsArr(txFrameCount,$streamId)
    puts rxFrameCnt=>$statsArr(rxFrameCount,$streamId)
    puts frameLoss=>$statsArr(frameLoss,$streamId)
    puts txL1BitRate=>$txRate(L1BitRate,$streamId)
    puts txL2BitRate=>$txRate(L2BitRate,$streamId)
    puts txFrameRate=>$txRate(FrameRate,$streamId)
    puts rxL1BitRate=>$rxRate(L1BitRate,$streamId)
    puts rxL2BitRate=>$rxRate(L2BitRate,$streamId)
    puts rxFrameRate=>$rxRate(FrameRate,$streamId)
    #puts minFrameSize=>$statsArr(minFrameSize,$streamId)
    #puts maxFrameSize=>$statsArr(maxFrameSize,$streamId)
    catch {array unset temp}
    array set temp $statsArr(filterstats,$streamId)
    foreach name [array names temp] {
        puts $name=>$temp($name)
    }
} 
}

proc SubscribeStcStats {} {
    set statsType "portstats"
    set statsType [string tolower $statsType]
    if {[string first  "portstats" $statsType] !=  -1} { 
        set handle(generatorResultView) [stc::subscribe -parent project1  \
            -resultParent project1 \
            -configType generator \
            -resultType generatorportresults \
            -filterList ""  ]
    
        set handle(analyzerResultView) [stc::subscribe -parent project1 \
            -resultParent project1  \
            -configType analyzer \
            -resultType analyzerportresults \
            -filterList ""  ]
        }

    set statsType "streamstats"
    if {[string first  "streamstats" $statsType] !=  -1} {         

        set handle(rxStreamResultView) [stc::subscribe -parent project1 \
                -resultParent project1 \
                -configType streamblock \
                -resultType RxStreamsummaryResults -Interval  1]
    
            
        set handle(txStreamResultView) [stc::subscribe -parent [lindex [stc::get system1 -children-Project] 0] \
            -resultParent project1 \
            -configType streamblock \
            -resultType txstreamresults \
            -filterList ""  -Interval  1]
        }
    if {[string first  "filterstats" $statsType] !=  -1} {        
       foreach port [stc::get system1.Project(1) -children-Port]  {
           stc::subscribe -parent [lindex [stc::get system1 -children-Project] 0] \
               -resultParent $port \
               -configType analyzer \
               -resultType filteredstreamresults \
               -filterList "" \
               -viewAttributeList "streamindex framecount sigframecount fcserrorframecount minlatency maxlatency seqrunlength droppedframecount droppedframepercent inorderframecount reorderedframecount duplicateframecount lateframecount prbsbiterrorcount prbsfilloctetcount ipv4checksumerrorcount tcpudpchecksumerrorcount framerate sigframerate fcserrorframerate droppedframerate droppedframepercentrate inorderframerate reorderedframerate duplicateframerate lateframerate prbsbiterrorrate ipv4checksumerrorrate tcpudpchecksumerrorrate filteredvalue_1 filteredvalue_2 filteredvalue_3 filteredvalue_4 filteredvalue_5 filteredvalue_6 filteredvalue_7 filteredvalue_8 filteredvalue_9 filteredvalue_10 bitrate shorttermavglatency avglatency prbsbiterrorratio bitcount l1bitcount l1bitrate shorttermavgjitter avgjitter rfc4689absoluteavgjitter minjitter maxjitter shorttermavginterarrivaltime avginterarrivaltime mininterarrivaltime maxinterarrivaltime lastseqnum inseqframecount outseqframecount inseqframerate outseqframerate histbin1count histbin2count histbin3count histbin4count histbin5count histbin6count histbin7count histbin8count histbin9count histbin10count histbin11count histbin12count histbin13count histbin14count histbin15count histbin16count minframelength maxframelength " \
               -interval 1                
       } 

        set handle(txStreamResultView) [stc::subscribe -parent [lindex [stc::get system1 -children-Project] 0] \
            -resultParent project1 \
            -configType streamblock \
            -resultType txstreamresults \
            -filterList ""  -Interval  1]       
    }  
    SubscribeDhcpStats
}
proc GetPortStats {ports1} {
    after 3000 
    puts ""  
    foreach port $ports1 {
        set ports [stc::get project1 -children-port] 
        if {($port < 1)||($port > [llength $ports])} {
             error "wrong stcPort ($port).   1<= port <= [llength $ports] "
        }
    
        set hPort [lindex $ports [incr port -1]]    
        set generator [lindex [stc::get $hPort -children-generator] 0]
        set GeneratorPortResults [lindex [stc::get $generator -children-GeneratorPortResults] 0]
        catch {array unset arr}
        array set arr [stc::get $GeneratorPortResults]
        
        puts -------------------------
        puts port=[expr $port + 1]
        puts txFrameCnt=$arr(-GeneratorSigFrameCount)
        puts txFrameRate=$arr(-GeneratorSigFrameRate)
        puts txL1BitRate=$arr(-L1BitRate)
        after 1000
        
        set analyzer [lindex [stc::get $hPort -children-analyzer] 0]
       
        set AnalyzerPortResults [lindex [stc::get $analyzer -children-AnalyzerPortResults] 0]
        
        catch {array unset arr}
        array set arr [stc::get $AnalyzerPortResults]
        puts rxFrameCnt=$arr(-SigFrameCount)
        puts rxFrameRate=$arr(-SigFrameRate)
        puts rxL1BitRate=$arr(-L1BitRate)
        after 1000
        
    }
}
proc GetCapturedPktCnt {port} {
    after 3000
    set ports [stc::get project1 -children-port] 
    if {($port < 1)||($port > [llength $ports])} {
         error "wrong stcPort ($port).   1<= port <= [llength $ports] "
    }
    set hPort [lindex $ports [incr port -1]]    
    set capture [lindex [stc::get $hPort -children-capture] 0]   
    after 1000    
    set pktCnt [stc::get $capture -PktCount]
    puts $pktCnt
    after 1000
    puts "CapturePktCnt=$pktCnt"
    after 1000
    
}
proc GetStreamInfo {streamNames} {
    after 3000
    puts ""  
    foreach streamName $streamNames {
    set streamName [string tolower $streamName]

    set hStream ""
    foreach port [stc::get project1 -children-port] {
        foreach stream [stc::get $port -children-streamblock] {
            set name [stc::get $stream -name]
            set name [string tolower $name]
            if {[string first $streamName $name] != -1} {
                set hStream $stream
                break
            }
        }
    }
    
    if {$hStream == ""} {
        error "streamName ($streamName) can not be found, please correct!" 
    }

    set pdus [stc::get $hStream -children]
    set vlanInfo ""
    
        foreach pdu $pdus {
            if {[string first "ethernet" $pdu]!= -1} {
                foreach child [stc::get $pdu -children] {
                    if {[string first "vlans" $child]!= -1} {
                         set vlans1 $child   
                         set vlan [lindex [stc::get $vlans1 -children-vlan] 0]
                         lappend vlanInfo -vlanId
                         lappend vlanInfo [stc::get $vlan -id]
                         lappend vlanInfo -pri
                         lappend vlanInfo [stc::get $vlan -pri]
                    }     
                }                  
            }
        }
        if {$vlanInfo == ""} {
             set vlanInfo NA
        }

        
       catch {array unset arr}
       array set arr [stc::get $hStream]
       puts ---------------------------
       puts streamName=$streamName
       puts txPort=$arr(-parent)
       puts BurstSize=$arr(-BurstSize)
       puts FrameLengthMode=$arr(-FrameLengthMode)
       puts FixedFrameLength=$arr(-FixedFrameLength)
       puts MinFrameLength=$arr(-MinFrameLength)
       puts MaxFrameLength=$arr(-MaxFrameLength)
       puts StepFrameLength=$arr(-StepFrameLength)
       puts Load=$arr(-Load)
       puts LoadUnit=$arr(-LoadUnit)
       puts InterFrameGap=$arr(-InterFrameGap)
       puts vlanInfo=$vlanInfo
       puts RunningState=$arr(-RunningState)             
   }
}
proc ClearCapture {ports1} {
    puts ""  
    foreach port $ports1 {
        set ports [stc::get project1 -children-port] 
        if {($port < 1)||($port > [llength $ports])} {
             error "wrong stcPort ($port).   1<= port <= [llength $ports] "
        }
    
        set hPort [lindex $ports [incr port -1]]    
        set capture [lindex [stc::get $hPort -children-capture] 0]
        stc::perform CaptureStartCommand -CaptureProxyId $hPort
        puts "stc::perform CaptureStartCommand -CaptureProxyId $hPort"
        after 3000
        stc::perform CaptureStopCommand -CaptureProxyId $hPort   
        puts "stc::perform CaptureStopCommand -CaptureProxyId $hPort  "
    }
}
proc ShowCapRawPkt {port pktIndex} {
    puts ""  
        set ports [stc::get project1 -children-port] 
        if {($port < 1)||($port > [llength $ports])} {
             error "wrong stcPort ($port).   1<= port <= [llength $ports] "
        }
    
        set hPort [lindex $ports [incr port -1]]    
        catch {array unset arr}
        set list [split $pktIndex -]
        set start [lindex $list 0]
        if {[llength $list ]<2} {
            set end [lindex $list 0] 
        } else {
            set end [lindex $list 1]
        }
        puts [format "%5s%7s   %s" Index Length Data]
        for {set index $start} {$index <= $end} {incr index} {
        catch {array unset arr}
        array set arr [stc::perform CaptureGetFrameCommand -CaptureProxyId $hPort -frameIndex [expr $index - 1]]
        set arr(-PacketData) [string tolower $arr(-PacketData)]
        set index1 [string first "555555d5" $arr(-PacketData)] 
        if {$index1 != -1} {            
            set newString [string range "$arr(-PacketData)" [expr $index1 + 8] end ]
            set stringLen [string length $newString]
            set stringLen [expr $stringLen / 2]
            puts [format "%5s%7s   %s" $index $stringLen $newString]
        } else {
            set  stringLen [string length $arr(-PacketData)]
            set stringLen [expr $stringLen / 2]
            puts [format "%5s%7s   %s" $index  $stringLen $arr(-PacketData) ]
            
        }   
     }
}
proc ShowCapRawPkt2 {port pktIndex} {
    puts ""  
        set ports [stc::get project1 -children-port] 
        if {($port < 1)||($port > [llength $ports])} {
             error "wrong stcPort ($port).   1<= port <= [llength $ports] "
        }
    
        set hPort [lindex $ports [incr port -1]]    
        catch {array unset arr}
        set list [split $pktIndex -]
        set start [lindex $list 0]
        if {[llength $list ]<2} {
            set end [lindex $list 0] 
        } else {
            set end [lindex $list 1]
        }
        for {set index $start} {$index <= $end} {incr index} {
        puts ---------------------------------------------
        puts pktIndex=$index
        array set arr [stc::perform CaptureGetFrameCommand -CaptureProxyId $hPort -frameIndex [expr $index - 1]]
         set arr(-PacketData) [string tolower $arr(-PacketData)]
        set index1 [string first "555555d5" $arr(-PacketData)] 
        if {$index1 != -1} {            
            set newString [string range "$arr(-PacketData)" [expr $index1 + 8] end ]
            set stringLen [string length $newString]
            puts DataLength=[expr $stringLen /2]
            puts Timestamp=$arr(-Timestamp)
            puts PacketData:            
            for {set offset 0} {$offset < $stringLen} {} {         
                catch {
                    puts -nonewline [string range $newString  $offset   [incr offset 3]]
                    incr offset
                    puts -nonewline " "
                }
                if {[expr $offset % 32]==0} {
                    puts -nonewline \n
                }            
            }
            puts -nonewline \n
        }   
     }
}
proc ClearStats {} {
     stc::perform ResultClearAllTrafficCommand -PortList  [stc::get project1 -children-port]
     after 3000
     puts "stc::perform ResultClearAllTrafficCommand -PortList  [stc::get project1 -children-port]"
}
proc WaitKeyboardInput1 {{platform "cmcc"}} {
      if {1} {
        if {$platform == "cmcc"} {
            puts "please press  'a' to continue..."
            flush stdout
            set ::input [gets stdin]
            while {$::input != "a"} {        

                puts input=$::input 
                puts -------------------------------------------------            
                
                if {[catch {    
                uplevel 1 {
                set ret [eval [subst $::input]]
                puts ret=$ret
                }
                puts -------------------------------------------------
                } output]} {puts err=$output}                
                puts  "please press  'a' to continue..."                
                set ::input [gets stdin]
            }
        } else {
            puts "waiting 3 seconds..."
            after 3000
        }   
    }
}
#################################################
#DHCP
proc SubscribeDhcpStats {} {
    foreach emulateddevice [stc::get project1 -children-emulateddevice] {
         set children [stc::get $emulateddevice -children ]
         set children [string tolower $children]
         set index [string first dhcp $children]
         if {$index != -1} {
            stc::subscribe -parent [lindex [stc::get system1 -children-Project] 0] \
                -resultParent " [lindex [stc::get system1 -children-Project] 0] " \
                -configType dhcpv4blockconfig \
                -resultType dhcpv4blockresults 
        
            stc::subscribe -parent [lindex [stc::get system1 -children-Project] 0] \
                -resultParent " [lindex [stc::get system1 -children-Project] 0] " \
                -configType dhcpv4blockconfig \
                -resultType Dhcpv4SessionResults                
         }
    }
}
proc StartDhcpServer {{serverNames all}} {
     set serverNames [string tolower $serverNames]
     set hServer "" 
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach serverName $serverNames {
             if {$name == $serverName} {
                 lappend hServer $emulateddevice
             } elseif {$serverName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first dhcpv4serverconfig $children]
               if {$index != -1} {
                   lappend hServer $emulateddevice
               }         
             }
         }        
     }
     if {$hServer != ""} {
         stc::perform DeviceStartCommand -DeviceList $hServer
         puts "stc::perform DeviceStartCommand -DeviceList $hServer"
         after 3000
     }     
}

proc RequestIpAddr {{clientNames all}} {
     set clientNames [string tolower $clientNames]
     set hClient "" 
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach clientName $clientNames {
             if {$name == $clientName} {
                 lappend hClient $emulateddevice
             } elseif {$clientName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first dhcpv4blockconfig $children]
               if {$index != -1} {
                   lappend hClient $emulateddevice
               }         
             }
         }        
     }
     if {$hClient != ""} {
         stc::perform Dhcpv4BindCommand -BlockList $hClient
         puts "stc::perform Dhcpv4BindCommand -BlockList $hClient"
         #after 3000
     }     
}

proc ReleaseIpAddr {{clientNames all}} {
     set clientNames [string tolower $clientNames]
     set hClient "" 
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach clientName $clientNames {
             if {$name == $clientName} {
                 lappend hClient $emulateddevice
             } elseif {$clientName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first dhcpv4blockconfig $children]
               if {$index != -1} {
                   lappend hClient $emulateddevice
               }         
             }
         }        
     }
     if {$hClient != ""} {
         stc::perform Dhcpv4ReleaseCommand -BlockList $hClient
         puts "stc::perform Dhcpv4ReleaseCommand -BlockList $hClient"
         #after 3000
     }     
}

proc RenewIpAddr {{clientNames all}} {
     set clientNames [string tolower $clientNames]
     set hClient "" 
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach clientName $clientNames {
             if {$name == $clientName} {
                 lappend hClient $emulateddevice
             } elseif {$clientName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first dhcpv4blockconfig $children]
               #puts emulateddevice=$emulateddevice
               #puts children=$children
               if {$index != -1} {
                   lappend hClient $emulateddevice
               }         
             }
         }        
     }
     if {$hClient != ""} {
         foreach ele $hClient {
         catch {stc::perform Dhcpv4RenewCommand -BlockList $ele}
         puts "stc::perform Dhcpv4RenewCommand -BlockList $ele"
         }
         #after 3000
     }     
}
proc GetDhcpAggStats {{clientNames all}} {
     puts [format "%12s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s" HostName CurrentAttemptCount CurrentIdleCount CurrentBoundCount TotalAttemptCount TotalBoundCount TotalFailedCount TotalRenewedCount TotalRetriedCount BindRate AttemptRate TxDiscoverCount TxRequestCount TxRenewCount TxRebindCount TxReleaseCount RxAckCount RxNakCount RxOfferCount RxForceRenewCount]
     puts ===========================================================================================================================================================================================================================================================================================================================================================================================================================
     set clientNames [string tolower $clientNames]        


     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {         
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]      
         set hClient ""
         if {$clientNames == "all"} {    
            set children [stc::get $emulateddevice -children ]
            set children [string tolower $children]
            set index [string first dhcpv4blockconfig $children]
            if {$index != -1} {
                set hClient [lindex [stc::get $emulateddevice -children-dhcpv4blockconfig ] 0]
            }         
         } else {
              set index [lsearch $clientNames $name] 
              if {$index == -1} {continue}
              set clientNames [lreplace $clientNames $index $index]
              set hClient [lindex [stc::get $emulateddevice -children-dhcpv4blockconfig ] 0]
         } 
         if {$hClient != ""} {
             foreach result [stc::get $hClient -children-dhcpv4blockresults] {
                  catch {array unset arr}
                  array set arr [stc::get $result]
                  puts [format "%12s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s%22s" $name $arr(-CurrentAttemptCount) $arr(-CurrentIdleCount) $arr(-CurrentBoundCount) $arr(-TotalAttemptCount) $arr(-TotalBoundCount) $arr(-TotalFailedCount) $arr(-TotalRenewedCount) $arr(-TotalRetriedCount) $arr(-BindRate) $arr(-AttemptRate) $arr(-TxDiscoverCount) $arr(-TxRequestCount) $arr(-TxRenewCount) $arr(-TxRebindCount) $arr(-TxReleaseCount) $arr(-RxAckCount) $arr(-RxNakCount) $arr(-RxOfferCount) $arr(-RxForceRenewCount)]
                  break
              }
          }                 
      }
}          

proc GetDhcpStats {{clientNames all}} {
     puts [format "%12s%8s%13s%24s%20s%7s%13s%18s%21s%17s%29s%28s%6s%6s" "HostName" "Index" "State"	"ErrorStatus"	"MAC" "VLAN"	"InnerVLAN"	"IP"	"LeaseReceived(s)" "LeaseLeft(s)" "DiscoverResponseTime(s)"	"RequestResponseTime(s)" "VPI" "VCI"]
     puts ==============================================================================================================================================================================================================================
     set clientNames [string tolower $clientNames]    
     set hClient "" 
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {         
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach clientName $clientNames {
             if {$name == $clientName} {
                 lappend hClient [stc::get $emulateddevice -children-dhcpv4blockconfig ]
             } elseif {$clientName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first dhcpv4blockconfig $children]
               if {$index != -1} {
                   lappend hClient [stc::get $emulateddevice -children-dhcpv4blockconfig ]
               }         
             }
         }           
     } 

     if {$hClient != ""} {    
            set dir [pwd]
            set filename [file join $dir dhcpSession.csv]
            catch {file delete -force $filename}
            stc::perform dhcpv4sessioninfo -blockList $hClient -filename $filename

            set line ""
            set number 0
            set fileId [open $filename r]
            while {[gets $fileId line] >= 0} {    
             
                incr number
                if {$number == 1} {continue}
                set list [split $line ,]
                             
                set HostName [string map {" " _} [lindex $list 2]]
                set Index [string map {" " _} [lindex $list 0]]
                set State [string map {" " _} [lindex $list 3]]
                set ErrorStatus [string map {" " _} [lindex $list 4]]
                set MAC [string map {" " _} [lindex $list 5]]
                set VLAN [string map {" " _} [lindex $list 6]]
                set InnerVLAN [string map {" " _} [lindex $list 7]]
                set IP [string map {" " _} [lindex $list 8]]
                set LeaseReceived [string map {" " _} [lindex $list 9]]
                set LeaseLeft [string map {" " _} [lindex $list 10]]
                set DiscoverResponseTime [string map {" " _} [lindex $list 11]]
                set RequestResponseTime [string map {" " _} [lindex $list 12]]
                set VPI [string map {" " _} [lindex $list 13]]
                set VCI [string map {" " _} [lindex $list 14]]
                
                puts [format "%12s%8s%13s%24s%20s%7s%13s%18s%21s%17s%29s%28s%6s%6s" "$HostName" "$Index" "$State"	"$ErrorStatus"	"$MAC" "$VLAN"	"$InnerVLAN"	"$IP"	"$LeaseReceived" "$LeaseLeft" "$DiscoverResponseTime"	"$RequestResponseTime" "$VPI" "$VCI"]
     
            }
            close $fileId
            catch {file delete -force $filename}
     }      
}

proc GetDhcpServerStats {{serverNames all}} {

     set serverNames [string tolower $serverNames]    
	 set DhcpSessionStats ""
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {         
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]
		puts "aaaa"
         foreach serverNames $serverNames {
             if {$name == $serverNames} {
                 set dhcpv4BlockConfig [stc::get $emulateddevice -children-Dhcpv4BlockConfig ]
				 puts "bbbb"
				 #set hDhcpSessionStats [stc::get $dhcpv4BlockConfig -Dhcpv4SessionResults]
				 
					lappend DhcpSessionStats -ErrorStatus 
					lappend DhcpSessionStats [stc::get $dhcpv4BlockConfig -ErrorStatus]
					puts "cccc"
					lappend DhcpSessionStats -InnerVlanId 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -InnerVlanId]
					lappend DhcpSessionStats -Ipv4Addr 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -Ipv4Addr]    
					lappend DhcpSessionStats -LeaseLeft 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -LeaseLeft]
					lappend DhcpSessionStats -LeaseRx 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -LeaseRx]
					lappend DhcpSessionStats -MacAddr 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -MacAddr]
					lappend DhcpSessionStats -RequestRespTime 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -RequestRespTime]
					lappend DhcpSessionStats -SessionState 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -SessionState]
					lappend DhcpSessionStats -Vci 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -Vci]
					lappend DhcpSessionStats -Vpi 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -Vpi]
             } elseif {$clientName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first dhcpv4blockconfig $children]
               if {$index != -1} {
                   set dhcpv4BlockConfig [stc::get $emulateddevice -children-Dhcpv4BlockConfig ]
				   set hDhcpSessionStats [stc::get $dhcpv4BlockConfig -children-Dhcpv4SessionResults]
					lappend DhcpSessionStats -ErrorStatus 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -ErrorStatus]
					lappend DhcpSessionStats -InnerVlanId 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -InnerVlanId]
					lappend DhcpSessionStats -Ipv4Addr 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -Ipv4Addr]    
					lappend DhcpSessionStats -LeaseLeft 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -LeaseLeft]
					lappend DhcpSessionStats -LeaseRx 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -LeaseRx]
					lappend DhcpSessionStats -MacAddr 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -MacAddr]
					lappend DhcpSessionStats -RequestRespTime 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -RequestRespTime]
					lappend DhcpSessionStats -SessionState 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -SessionState]
					lappend DhcpSessionStats -Vci 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -Vci]
					lappend DhcpSessionStats -Vpi 
					lappend DhcpSessionStats [stc::get $hDhcpSessionStats -Vpi]
               }         
             }
         }           
     } 
	
	return $DhcpSessionStats
}
proc SaveCaptureFile {port captureFile} {
    set CaptureProxyId ""
    set hPortList [stc::get project1 -children-port]
    foreach ele $port {
        catch {
            lappend CaptureProxyId [lindex $hPortList [expr $ele - 1]]
        }
    }
    stc::perform CaptureDataSaveCommand -CaptureProxyId $CaptureProxyId  -filename   $captureFile
    puts "stc::perform CaptureDataSaveCommand -CaptureProxyId $CaptureProxyId  -filename   $captureFile"
}
proc Ping {srcDeviceName dstIpAddr frameCount} {
    set deviceList ""
    foreach device [stc::get project1 -children-emulateddevice] {
        set name [stc::get $device -name]
        set name [string tolower $name]
        if {$name == $srcDeviceName} {
            set deviceList $device
            break
        }
    }
    if {$deviceList == ""} {
       puts "device ($deviceList) does not exist, please check!"
       return
    }
    stc::perform pingstart -deviceList $deviceList -framecount $frameCount -waitforpingtofinish true -pingipv4dstaddr $dstIpAddr
    after 2000
    set hPort [stc::get $deviceList -affiliationport-Targets]
    set pingReport [lindex [stc::get $hPort -children-pingReport] 0]
    catch {array unset arr}
    array set arr [stc::get $pingReport]
    puts   "FailedPingCount:$arr(-FailedPingCount)   SuccessfulPingCount:$arr(-SuccessfulPingCount)   AttemptedPingCount:$arr(-AttemptedPingCount) "    
}
proc SetCaptureFilter {port {srcMac N/A} {dstMac N/A} {srcIp N/A} {dstIp N/A} {vlanHdrNum 0} {vlanId N/A}} {
    set Port(2) [lindex [stc::get project1 -children-port] [expr $port - 1]]    
    set Capture(2) [lindex [stc::get $Port(2) -children-Capture] 0]
    puts "$srcMac $dstMac $srcIp $dstIp $vlanId"
    
    set CaptureFilter(2) [lindex [stc::get $Capture(2) -children-CaptureFilter] 0]
    foreach CaptureAnalyzerFilter [stc::get $CaptureFilter(2) -children-CaptureAnalyzerFilter] {
        stc::delete $CaptureAnalyzerFilter
    }

    if {($srcMac == "N/A")&&($dstMac == "N/A")&&($srcIp == "N/A")&&($dstIp == "N/A")&&($vlanId == "N/A")} {
        return
    }    
    
    if {($srcMac != "N/A")} {
        set FrameConfig "<frame ><config><pdus><pdu name=\"eth2\" pdu=\"ethernet:EthernetII\"><srcMac>$srcMac</srcMac></pdu></pdus></config></frame>"
        set CaptureAnalyzerFilter [stc::create "CaptureAnalyzerFilter" \
                -under $CaptureFilter(2) \
                -IsSelected "TRUE" \
                -ValueToBeMatched $srcMac \
                -FilterDescription srcMac \
                -FrameConfig $FrameConfig]   
                stc::apply
   }  
    if {($dstMac != "N/A")} {
        set FrameConfig "<frame ><config><pdus><pdu name=\"eth2\" pdu=\"ethernet:EthernetII\"><dstMac>$dstMac</dstMac></pdu></pdus></config></frame>"
        set CaptureAnalyzerFilter [stc::create "CaptureAnalyzerFilter" \
                -under $CaptureFilter(2) \
                -IsSelected "TRUE" \
                -ValueToBeMatched $dstMac \
                -FilterDescription dstMac \
                -FrameConfig $FrameConfig]        
                stc::apply
   }
   if {($srcIp != "N/A")} {
        if {$vlanHdrNum == 2} {
            set FrameConfig "<frame ><config><pdus><pdu name=\"eth1\" pdu=\"ethernet:EthernetII\"><vlans name=\"vlans\"><Vlan name=\"Vlan\"></Vlan><Vlan name=\"Vlan_1\"></Vlan></vlans></pdu><pdu name=\"ip_1\" pdu=\"ipv4:IPv4\"><sourceAddr>$srcIp</sourceAddr></pdu></pdus></config></frame>"
        } elseif {$vlanHdrNum == 1} {
            set FrameConfig "<frame ><config><pdus><pdu name=\"eth1\" pdu=\"ethernet:EthernetII\"><vlans name=\"vlans\"><Vlan name=\"Vlan\"></Vlan></vlans></pdu><pdu name=\"ip_1\" pdu=\"ipv4:IPv4\"><sourceAddr>$srcIp</sourceAddr></pdu></pdus></config></frame>"
        } else {
            set FrameConfig "<frame ><config><pdus><pdu name=\"eth1\" pdu=\"ethernet:EthernetII\"></pdu><pdu name=\"ip_1\" pdu=\"ipv4:IPv4\"><sourceAddr>$srcIp</sourceAddr></pdu></pdus></config></frame>"
        }
        set CaptureAnalyzerFilter [stc::create "CaptureAnalyzerFilter" \
                -under $CaptureFilter(2) \
                -IsSelected "TRUE" \
                -ValueToBeMatched $srcIp \
                -FilterDescription srcIp \
                -FrameConfig $FrameConfig]    
                stc::apply
   }

   if {($dstIp != "N/A")} {
        if {$vlanHdrNum == 2} {
            set FrameConfig "<frame ><config><pdus><pdu name=\"eth1\" pdu=\"ethernet:EthernetII\"><vlans name=\"vlans\"><Vlan name=\"Vlan\"></Vlan><Vlan name=\"Vlan_1\"></Vlan></vlans></pdu><pdu name=\"ip_1\" pdu=\"ipv4:IPv4\"><destAddr>$dstIp</destAddr></pdu></pdus></config></frame>"
        } elseif {$vlanHdrNum == 1} {
            set FrameConfig "<frame ><config><pdus><pdu name=\"eth1\" pdu=\"ethernet:EthernetII\"><vlans name=\"vlans\"><Vlan name=\"Vlan\"></Vlan></vlans></pdu><pdu name=\"ip_1\" pdu=\"ipv4:IPv4\"><destAddr>$dstIp</destAddr></pdu></pdus></config></frame>"
        } else {
            set FrameConfig "<frame ><config><pdus><pdu name=\"eth1\" pdu=\"ethernet:EthernetII\"></pdu><pdu name=\"ip_1\" pdu=\"ipv4:IPv4\"><destAddr>$dstIp</destAddr></pdu></pdus></config></frame>"
        }
        set CaptureAnalyzerFilter [stc::create "CaptureAnalyzerFilter" \
                -under $CaptureFilter(2) \
                -IsSelected "TRUE" \
                -ValueToBeMatched $dstIp \
                -FilterDescription dstIp \
                -FrameConfig $FrameConfig]     
                stc::apply
   }  
   
   if {($vlanId != "N/A")} {
		if {$vlanHdrNum == 2} {
			set vlanId1 [lindex $vlanId 0]
			set vlanId2 [lindex $vlanId 1]
			set FrameConfig "<frame ><config><pdus><pdu name=\"eth2\" pdu=\"ethernet:EthernetII\"><vlans name=\"vlans\"><Vlan name=\"vlan1\"><id>$vlanId1</id></Vlan><Vlan name=\"vlan2\"><id>$vlanId2</id></Vlan></vlans></pdu></pdus></config></frame>"
		} elseif {$vlanHdrNum == 1} {
			set vlanId [lindex $vlanId 0]
			set FrameConfig "<frame ><config><pdus><pdu name=\"eth2\" pdu=\"ethernet:EthernetII\"><vlans name=\"vlans\"><Vlan name=\"vlan1\"><id>$vlanId</id></Vlan></vlans></pdu></pdus></config></frame>"
		}
        set CaptureAnalyzerFilter [stc::create "CaptureAnalyzerFilter" \
                -under $CaptureFilter(2) \
                -IsSelected "TRUE" \
                -ValueToBeMatched $vlanId \
                -FilterDescription vlanId \
                -FrameConfig $FrameConfig]        
                stc::apply
   }
   
   
    stc::apply
   catch {stc::perform captureStop -CaptureProxyId $Port(2)}
   catch {stc::perform captureStart -CaptureProxyId $Port(2)}
   catch {stc::perform captureStop -CaptureProxyId $Port(2)}
}
#################################################
#################################################
#IGMP
proc SubscribeIgmpStats {} {
    stc::subscribe -parent [lindex [stc::get system1 -children-Project] 0] \
        -resultParent " [lindex [stc::get system1 -children-Project] 0] " \
        -configType igmpportconfig \
        -resultType igmpportresults \
        -filterList "" \
        -viewAttributeList "txframecount txv1reportcount txv2reportcount txv3reportcount txv3modeisincludecount txv3modeisexcludecount txv3changetoincludemodecount txv3changetoexcludemodecount txv3allownewsourcescount txv3blockoldsourcescount txleavegroupcount txv1querycount txv2querycount txv3querycount txgeneralquerycount txgroupspecificquerycount txgroupandsourcespecificquerycount rxframecount rxv1reportcount rxv2reportcount rxv3reportcount rxv1querycount rxv2querycount rxv3querycount rxgeneralquerycount rxgroupspecificquerycount rxgroupandsourcespecificquerycount rxunknowntypecount rxigmpchecksumerrorcount rxigmplengtherrorcount " \
        -interval 1 
    foreach device [stc::get project1 -children-emulateddevice] {
        foreach igmphostconfig [stc::get $device -children-igmphostconfig] {
            foreach igmpgroupmembership [stc::get $igmphostconfig -children-igmpgroupmembership] {
                stc::config $igmpgroupmembership -active false
            }
        }
    }        
}


proc IgmpJoin {clientName groupName} {
puts "IgmpJoin..."
    set clientName [string tolower $clientName]
    set groupName [string tolower $groupName]
    foreach device [stc::get project1 -children-emulateddevice] {
        set name [string tolower [stc::get $device -name]]
        if {[string first $clientName $name] == -1} {continue}
        foreach igmphostconfig [stc::get $device -children-igmphostconfig] {
            foreach igmpgroupmembership [stc::get $igmphostconfig -children-igmpgroupmembership] {
                set flag 0
                foreach group [stc::get $igmpgroupmembership -subscribedgroups-Targets] {
                     set name [string tolower [stc::get $group -name]]
                     if {[string first $groupName $name] != -1} {
                         stc::config $group -active true
                         set flag 1
                     } else {
                     }
                }
                if {$flag} {
                    stc::config $igmpgroupmembership -active true
                    stc::perform IgmpMldJoinGroups -BlockList $igmpgroupmembership
                }
            }
        }
    } 
puts "IgmpJoin Completed!"    
}

proc IgmpLeave {clientName groupName} {
puts "IgmpLeave..."
    set clientName [string tolower $clientName]
    set groupName [string tolower $groupName]
    
    foreach device [stc::get project1 -children-emulateddevice] {
        set name [string tolower [stc::get $device -name]]
        if {[string first $clientName $name] == -1} {continue}
        foreach igmphostconfig [stc::get $device -children-igmphostconfig] {
            foreach igmpgroupmembership [stc::get $igmphostconfig -children-igmpgroupmembership] {
                set flag 0
                foreach group [stc::get $igmpgroupmembership -subscribedgroups-Targets] {
                     set name [string tolower [stc::get $group -name] ]
                     if {[string first $groupName $name] != -1} {
                         stc::config $group -active true
                         set flag 1
                     } else {
                     }
                }
                if {$flag} {
                    stc::config $igmpgroupmembership -active true
                    stc::perform IgmpMldLeaveGroups -BlockList $igmpgroupmembership
                    stc::config $igmpgroupmembership -active false
                }
            }
        }
    }  
puts "IgmpLeave Completed!"    
}


#################################################
#PPP
proc StartPppServer {{serverNames all}} {
     set serverNames [string tolower $serverNames]
     set hServer "" 
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach serverName $serverNames {
             if {$name == $serverName} {
                 lappend hServer $emulateddevice
             } elseif {$serverName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first pppoeserver $children]
               if {$index != -1} {
                   lappend hServer $emulateddevice
               }         
             }
         }        
     }
     if {$hServer != ""} {
         stc::perform DeviceStartCommand -DeviceList $hServer
         puts "stc::perform DeviceStartCommand -DeviceList $hServer"
         after 3000
     }     
}
proc PppRequestIpAddr {{deviceNames all}} {
     set deviceNames [string tolower $deviceNames]
     set hClient "" 
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach serverName $deviceNames {
             if {$name == $serverName} {
                 lappend hClient $emulateddevice
             } elseif {$serverName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first pppoeserver $children]
               if {$index != -1} {
                   lappend hClient $emulateddevice
               }         
             }
         }        
     }
     if {$hClient != ""} {
         stc::perform DeviceStartCommand -DeviceList $hClient
         puts "stc::perform DeviceStartCommand -DeviceList $hClient"
         
     } 
     after 5000
     foreach hPort [stc::get project1 -children-port] {
         stc::perform generatorStop -generatorList [stc::get $hPort -children-generator]
         after 1000
         stc::perform generatorStart -generatorList [stc::get $hPort -children-generator]
     }
}
proc PppReleaseIpAddr {{deviceNames all}} {
     set deviceNames [string tolower $deviceNames]
     set hClient "" 
     foreach emulateddevice [stc::get project1 -children-emulateddevice]  {
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach serverName $deviceNames {
             if {$name == $serverName} {
                 lappend hClient $emulateddevice
             } elseif {$serverName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first pppoeserver $children]
               if {$index != -1} {
                   lappend hClient $emulateddevice
               }         
             }
         }        
     }
     if {$hClient != ""} {
         stc::perform DeviceStopCommand -DeviceList $hClient
         puts "stc::perform DeviceStopCommand -DeviceList $hClient"
         after 3000
     }     
}

proc GetPppClientStats {{clientNames all}} {
  
	set Mac ""
	set IpAddr ""
    set SessionId ""
    set RemoteIp ""
    set AgentCircuitId ""
    set AgentRemoteId ""
    set NumOfAttempt ""
    set EstablishmentPhase ""
    set State "IDLE"
    set DiscoveryState ""
    set FailureReason ""
    set StateAttempted ""
    set StateEstablished ""
    set StateClosed ""
    set StateFailed ""
    set SessionLifeTime ""
    set EstablishmentTime ""
	
    set clientNames [string tolower $clientNames]    
    set hClient "" 
    foreach emulateddevice [stc::get project1 -children-emulateddevice]  {         
         set name [stc::get $emulateddevice -name]
         set name [string tolower $name]

         foreach clientName $clientNames {
            if {$name == $clientName} {
                 lappend hClient [stc::get $emulateddevice -children-pppoeclientblockconfig ]
            } elseif {$clientName == "all"} {

               set children [stc::get $emulateddevice -children ]
               set children [string tolower $children]
               set index [string first pppoeclientblockconfig $children]
               if {$index != -1} {
                   lappend hClient [stc::get $emulateddevice -children-pppoeclientblockconfig ]
               }         
            }
         }           
    }    

    if {$hClient != ""} {    

        set hostState ""
        stc::perform PppoxSessionInfo -BlockList $hClient -FileName "C:/sessions.csv"
        set fid [open "C:/sessions.csv" r]
        set i 0
        while {[gets $fid line]} {
            if {$i != 0} {
                set listLine [split $line ,]
                set temp [lindex $listLine 10]
                if {$temp == ""} {
                    break
                }
                set temp [regsub -all : $temp ""]
                set temp [regsub -all -- - $temp ""]
                set temp [regsub -all \\. $temp ""]

                if {$temp != ""} {
                    lappend hostState -Mac 
                    lappend hostState [lindex $listLine 10] 
                    lappend hostState -IpAddr 
                    lappend hostState [lindex $listLine 6] 
                    lappend hostState -SessionId   
                    lappend hostState [lindex $listLine 3] 
                    lappend hostState -RemoteIp  
                    lappend hostState [lindex $listLine 7] 
                    lappend hostState -NumOfAttempt  
                    lappend hostState [lindex $listLine 14] 
                    lappend hostState -FailureReason  
                    lappend hostState [lindex $listLine 5]
                    lappend hostState -StateAttempted   
                    lappend hostState [lindex $listLine 14]
                    lappend hostState -StateEstablished    
                    lappend hostState [lindex $listLine 15]
                    lappend hostState -StateClosed     
                    lappend hostState [lindex $listLine 18]
                    lappend hostState -StateFailed      
                    lappend hostState [lindex $listLine 16]
                    lappend hostState -EstablishmentTime        
                    lappend hostState [lindex $listLine 20]
                
                    set IpAddr [lindex $listLine 6] 
                    set SessionId [lindex $listLine 3] 
                    set RemoteIp [lindex $listLine 7] 
                    set NumOfAttempt [lindex $listLine 14] 
                    set State [lindex $listLine 4]
                    lappend hostState -State
                    lappend hostState $State
                    if {[string tolower $State] == "connected"} {
                        set EstablishmentPhase "Established"
                    } elseif {[string tolower $State] == "connecting" } { 
                        set IPCPConfigRequest [lindex $listLine 37]
                        set PAPConfigRequest [lindex $listLine 41]
                        set LcpConfigRequest [lindex $listLine 22]

                        if {$IPCPConfigRequest != "0" } {
                            set EstablishmentPhase "NCPOpening"   
                        } elseif {$PAPConfigRequest != "0" } {
                            set EstablishmentPhase "Authenticating"  
                        } elseif {$LcpConfigRequest != "0" } {
                            set EstablishmentPhase "LCPOpening"
                        } else {
                            set EstablishmentPhase "Discovery"
                        } 
                    } elseif {[string tolower $State] == "idle" } {
                        set EstablishmentPhase "StartWait"
                    } else {
                        set EstablishmentPhase "Inactive"
                    }
                 
                    lappend hostState -EstablishmentPhase 
                    lappend hostState $EstablishmentPhase
               
                    set TxPADI [lindex $listLine 45]
                    set RxPADI [lindex $listLine 46]
                    set TxPADR [lindex $listLine 47]
                    set RxPADS [lindex $listLine 48]
                    if {$RxPADS != "0"} {
                        set DiscoveryState "RxPADS"
                    } elseif {$TxPADR != "0"} {
                        set DiscoveryState "TxPADR"
                    } elseif {$RxPADI != "0"} {
                        set DiscoveryState "RxPADI"
                    } else {
                        set DiscoveryState "TxPADI"
                    }       
               
                    lappend hostState -DiscoveryState 
                    lappend hostState $DiscoveryState
 
                    set FailureReason [lindex $listLine 5]
                    set StateAttempted [lindex $listLine 14]
                    set StateEstablished [lindex $listLine 15]
                    set StateClosed [lindex $listLine 18]
                    set StateFailed [lindex $listLine 16]
                    set EstablishmentTime [lindex $listLine 20]
                    break
                }
            }
            incr i
        }
        close $fid
        catch { file delete "C:/sessions.csv" } 
        return $hostState
    }      
}


#===================================add by hanxu================================================
proc CreatePPPoEBoundStream {args} {
		

	  set index [lsearch $args -serverDeviceName] 
	  if {$index != -1} {
			set serverDeviceName [lindex $args [expr $index + 1]]
			set serverDeviceName [string tolower $serverDeviceName]
	  } 
	  
	  set index [lsearch $args -clientDeviceName] 
	  if {$index != -1} {
			set clientDeviceName [lindex $args [expr $index + 1]]
			set clientDeviceName [string tolower $clientDeviceName]
	  } 
	  
	  set index [lsearch $args -clientPort] 
	  if {$index != -1} {
			set clientPort [lindex $args [expr $index + 1]]
	  } 
	  
	   set index [lsearch $args -wanStreamName] 
	  if {$index != -1} {
			set wanStreamName [lindex $args [expr $index + 1]]
	  } 
	  
	   set index [lsearch $args -lanStreamName] 
	  if {$index != -1} {
			set lanStreamName [lindex $args [expr $index + 1]]
	  } 
	  
	  set clientPortList [stc::get project1 -children-port] 
	  set clientPort [lindex $clientPortList [expr $clientPort - 1]]
	  set serverPort [lindex $clientPortList 0]
	  
	  
	foreach emulateddevice [stc::get project1 -children-emulateddevice]  {         
        set name [stc::get $emulateddevice -name]
        set name [string tolower $name]

		if {$name == $clientDeviceName} {
	
			set hClientIpv4If [stc::get $emulateddevice -children-Ipv4If ]
		} 
		
		if {$name == $serverDeviceName} {
	
			set hServerIpv4If [stc::get $emulateddevice -children-Ipv4If ]
		}
		
    }    
	
	set lanStream [stc::create streamblock -under $clientPort -name $lanStreamName]
	set wanStream [stc::create streamblock -under $serverPort -name $wanStreamName]
	
	stc::create pppoe:PPPoESession -under $lanStream
	
	#create lanstream
	stc::config $lanStream -SrcBinding $hClientIpv4If
	stc::config $lanStream -DstBinding $hServerIpv4If
	
	#create wanstream
	stc::config $wanStream -SrcBinding $hServerIpv4If
	stc::config $wanStream -DstBinding $hClientIpv4If
	
}




proc CreateDhcpBoundStream {args} {
		

	  set index [lsearch $args -serverDeviceName] 
	  if {$index != -1} {
			set serverDeviceName [lindex $args [expr $index + 1]]
			set serverDeviceName [string tolower $serverDeviceName]
	  } 
	  
	  set index [lsearch $args -clientDeviceName] 
	  if {$index != -1} {
			set clientDeviceName [lindex $args [expr $index + 1]]
			set clientDeviceName [string tolower $clientDeviceName]
	  } 
	  
	  set index [lsearch $args -clientPort] 
	  if {$index != -1} {
			set clientPort [lindex $args [expr $index + 1]]
	  } 
	  
	   set index [lsearch $args -wanStreamName] 
	  if {$index != -1} {
			set wanStreamName [lindex $args [expr $index + 1]]
	  } 
	  
	   set index [lsearch $args -lanStreamName] 
	  if {$index != -1} {
			set lanStreamName [lindex $args [expr $index + 1]]
	  } 
	  
	  set clientPortList [stc::get project1 -children-port] 
	  set clientPort [lindex $clientPortList [expr $clientPort - 1]]
	  set serverPort [lindex $clientPortList 0]
	  
	  
	foreach emulateddevice [stc::get project1 -children-emulateddevice]  {         
        set name [stc::get $emulateddevice -name]
        set name [string tolower $name]

		if {$name == $clientDeviceName} {
	
			set hClientIpv4If [stc::get $emulateddevice -children-Ipv4If ]
		} 
		
		if {$name == $serverDeviceName} {
	
			set hServerIpv4If [stc::get $emulateddevice -children-Ipv4If ]
		}
		
    }    
	
	set lanStream [stc::create streamblock -under $clientPort -name $lanStreamName]
	set wanStream [stc::create streamblock -under $serverPort -name $wanStreamName]
	
	#stc::create pppoe:PPPoESession -under $lanStream
	
	#create lanstream
	stc::config $lanStream -SrcBinding $hClientIpv4If
	stc::config $lanStream -DstBinding $hServerIpv4If
	
	#create wanstream
	stc::config $wanStream -SrcBinding $hServerIpv4If
	stc::config $wanStream -DstBinding $hClientIpv4If
	
}

proc ArpNdStartOnAllStreamBlocks {} {
	 set portList [stc::get project1 -children-port] 
	 stc::perform ArpNdStartOnAllStreamBlocks -PortList $portList
}

proc ArpNdStart {args} {
	  set index [lsearch $args -streamName] 
	  if {$index != -1} {
			set streamName [lindex $args [expr $index + 1]]
	  }  
	  foreach port [stc::get project1 -children-port] {
			foreach stream [stc::get $port -children-streamblock] {
				set hStreamName [stc::get $stream -name]
				if {$streamName ==  $hStreamName} {
					stc::perform ArpNdStart -HandleList $stream
				}
			}
	  }
	
}

proc ArpNdVerifyResolved {streamName} {
     
	foreach streamName $streamName {
		set streamName [string tolower $streamName]

		set hStream ""
		foreach port [stc::get project1 -children-port] {
			foreach stream [stc::get $port -children-streamblock] {
				set name [stc::get $stream -name]
				set name [string tolower $name]
				
				if {[string first $streamName $name] != -1} {
					set hStream $stream
					break
				}
			}
		}
	
	}
	puts [stc::perform ArpNdVerifyResolved -HandleList $hStream]
	
	
	
}


proc GetArpCache {stcPort} {
	set stcPortList [stc::get project1 -children-port]
	set hStcPort [lindex $stcPortList [expr $stcPort - 1]]
	stc::perform ArpNdUpdateArpCache -HandleList $hStcPort
	puts [stc::get [stc::get $hStcPort -children-arpcache] -ArpCacheData]
	
}

proc ConfigPortCopper {port args} {
	set portCopper ""
	set AutoNegotiation TRUE
	set AutoMdix FALSE
	set AutoNegotiationMasterSlave MASTER
	set LineSpeed SPEED_1G
	set Duplex FULL
    set hPortList [stc::get project1 -children-port]
    foreach ele $port {
		set portCopper [lindex $hPortList [expr $ele - 1]]
		set portCopper [stc::get $portCopper -children-EthernetCopper]
		stc::config $portCopper -PortSetupMode PORTCONFIG_ONLY
		stc::apply
		set index [lsearch $args -autoNegotiation] 
		if {$index != -1} {
			set AutoNegotiation [lindex $args [expr $index + 1]]
			set AutoNegotiation [string toupper $AutoNegotiation]
		} else  {
			puts "argument error"
		}
        
		if {$AutoNegotiation == TRUE} {
			set index [lsearch $args -autoMdix] 
			if {$index != -1} {
				set AutoMdix [lindex $args [expr $index + 1]]
				set AutoMdix [string toupper $AutoMdix]
			} else  {
				set AutoMdix FALSE
			}		
			
			set index [lsearch $args -autoNegotiationMasterSlave] 
			if {$index != -1} {
				set AutoNegotiationMasterSlave [lindex $args [expr $index + 1]]
				set AutoNegotiationMasterSlave [string toupper $AutoNegotiationMasterSlave]
			} else  {
				set AutoNegotiationMasterSlave MASTER
			}		
		}
		
		if {$AutoNegotiation == FALSE} {
			set index [lsearch $args -duplex] 
			if {$index != -1} {
				set Duplex [lindex $args [expr $index + 1]]
				set Duplex [string toupper $Duplex]
			} else  {
				set LineSpeed SPEED_1G
			}		
			
			set index [lsearch $args -lineSpeed] 
			if {$index != -1} {
				set LineSpeed [lindex $args [expr $index + 1]]
				set LineSpeed [string toupper $LineSpeed]
			} else  {
				set Duplex FULL
			}
		
		}
		
		stc::config $portCopper -AutoNegotiation $AutoNegotiation -AutoMdix $AutoMdix -AutoNegotiationMasterSlave $AutoNegotiationMasterSlave  -Duplex $Duplex -LineSpeed $LineSpeed 
        stc::apply
		after 3000
	}
}

# ------------add by peng 2012/06/14--------------------#
proc ConfigPort {args} {

    set args [string tolower $args]

	set index [lsearch $args -stcport ]  
	if {$index != -1} {
        set stcPort  [lindex $args [expr $index + 1]]
    } else  {
        set stcPort 1
    }
	set hPortList [stc::get project1 -children-port]
	set m_hPort [lindex $hPortList [expr $stcPort - 1]]

    set phy [stc::get $m_hPort -SupportedPhys]
    if {$phy == "ETHERNET_COPPER|ETHERNET_FIBER"} {

        #Parse MediaType parameter
        set index [lsearch $args -mediatype ] 
        if {$index != -1} {
            set MediaType  [lindex $args [expr $index + 1]]
        } else  {
            set MediaType  COPPER
        }
        if {[string tolower $MediaType] =="fiber"} {
              set phy "ETHERNET_FIBER"
              set m_mediaType "ETHERNET_FIBER"
        } elseif {[string tolower $MediaType] =="copper"} {
	          set phy "ETHERNET_COPPER"
              set m_mediaType "ETHERNET_COPPER"
        } else {
              error "Parameter MediaType should be FIBER/COPPER, your value is $MediaType"
        }
    
    }

    #Parse LinkSpeed parameter
    set index [lsearch $args -linkspeed ] 
    if {$index != -1} {
        set LinkSpeed  [lindex $args [expr $index + 1]]
    } else  {
        set LinkSpeed   "AUTO"
    }

    if {[string tolower $LinkSpeed] == "10m"} {
        set LinkSpeed "SPEED_10M"
    } elseif {[string tolower $LinkSpeed] == "100m"} {
        set LinkSpeed "SPEED_100M"
    } elseif {[string tolower $LinkSpeed] == "1g"} {
        set LinkSpeed "SPEED_1G"
    } elseif {[string tolower $LinkSpeed] == "10g"} {
        set LinkSpeed "SPEED_10G"
    } elseif {[string tolower $LinkSpeed] == "auto"}  {
        if {$phy == "ETHERNET_10_GIG_FIBER" || $phy == "ETHERNET_10_GIG_COPPER"} {
           set LinkSpeed "SPEED_10G"
        } else {
           set LinkSpeed "SPEED_1G"
        }     
    } else {
        error "unsuppoted port speed"
    }

    #Parse DuplexMode parameter
    set index [lsearch $args -duplexmode ] 
    if {$index != -1} {
        set DuplexMode  [lindex $args [expr $index + 1]]
    } else  {
        set DuplexMode   "FULL"
    }  

    #Parse AutoNeg parameter
    set index [lsearch $args -autoneg ] 
    if {$index != -1} {
        set AutoNeg  [lindex $args [expr $index + 1]]
        if {[string tolower $AutoNeg] == "auto"} {
            set AutoNeg "TRUE"
        }
    } else  {
        set AutoNeg   "TRUE"
    }
   
    #Parse ArpEnable parameter
    set index [lsearch $args -arpenable] 
    if {$index != -1} {
        set ArpEnable [lindex $args [expr $index + 1]]
    } else  {
        set ArpEnable  "TRUE"
    }

    set index [lsearch $args -mtusize] 
    if {$index != -1} {
        set MtuSize [lindex $args [expr $index + 1]]
    } else  {
        set MtuSize  1500
    }   

    #Parse FlowControl parameter
    set index [lsearch $args -flowcontrol] 
    if {$index != -1} {
        set FlowControl [lindex $args [expr $index + 1]]
        set FlowControl [string tolower $FlowControl]
        if {$FlowControl == "off" || $FlowControl  == "false"} {
               set FlowControl "FALSE"
        } elseif {$FlowControl == "on" || $FlowControl == "true"} {
               set FlowControl "TRUE"
        } 
    } else  {
        set FlowControl  FALSE
    }   

    #Parse AutoNegotiationMasterSlave parameter
    set index [lsearch $args -autonegotiationmasterslave] 
    if {$index != -1} {
        set AutoNegotiationMasterSlave [lindex $args [expr $index + 1]]
        set m_autoNegotiationMasterSlave $AutoNegotiationMasterSlave
    } else  {
        set AutoNegotiationMasterSlave  $m_autoNegotiationMasterSlave
    }
  
    set index [lsearch $args -portmode] 
    if {$index != -1} {
        set PortMode [lindex $args [expr $index + 1]]
        set m_portMode $PortMode
    } 
	 
    #Get the handle 
    if {$phy == "ETHERNET_COPPER"} {
        if {[stc::get $m_hPort -children-EthernetCopper] ==""} {
            set hLinkConfig [stc::create EthernetCopper -under $m_hPort]
        } else {
            set hLinkConfig [stc::get $m_hPort -children-EthernetCopper]
        }
     } elseif {$phy == "ETHERNET_10_GIG_FIBER"} {
        if {[stc::get $m_hPort -children-Ethernet10GigFiber] ==""} {
            set hLinkConfig [stc::create Ethernet10GigFiber -under $m_hPort]
        } else {
            set hLinkConfig [stc::get $m_hPort -children-Ethernet10GigFiber]
        }
     } elseif {$phy == "ETHERNET_10_GIG_COPPER"} {
         if {[stc::get $m_hPort -children-Ethernet10GigCopper] ==""} {
             set hLinkConfig [stc::create Ethernet10GigCopper -under $m_hPort]
         } else {
             set hLinkConfig [stc::get $m_hPort -children-Ethernet10GigCopper]
         }
     } else {
         if {[stc::get $m_hPort -children-EthernetFiber] ==""} {
             set hLinkConfig [stc::create EthernetFiber -under $m_hPort]
         } else {
             set hLinkConfig [stc::get $m_hPort -children-EthernetFiber]
         }
     }


		#set port1 [stc::get $m_hPort -children-EthernetFiber]
		#Config port parameters
		if {$phy == "ETHERNET_FIBER"} {
			stc::config $hLinkConfig \
                   -Mtu $MtuSize -AutoNegotiationMasterSlave $AutoNegotiationMasterSlave \
                   -LineSpeed $LinkSpeed\
                   -AutoNegotiation $AutoNeg\
                   -FlowControl $FlowControl    
		} else {
			if {$LinkSpeed == "SPEED_10G"} {
				stc::config $hLinkConfig \
                        -Mtu $MtuSize -AutoNegotiationMasterSlave $AutoNegotiationMasterSlave \
                        -LineSpeed $LinkSpeed \
                        -AutoNegotiation $AutoNeg\
                        -FlowControl $FlowControl -PortMode $m_portMode
			} else {  
				stc::config $hLinkConfig \
                        -Mtu $MtuSize -AutoNegotiationMasterSlave $AutoNegotiationMasterSlave \
                        -LineSpeed $LinkSpeed\
                        -Duplex $DuplexMode\
                        -AutoNegotiation $AutoNeg\
                        -FlowControl $FlowControl    
			} 
		}
  

    stc::config $m_hPort -ActivePhy-targets $hLinkConfig
    stc::perform PortSetupSetActivePhy -ActivePhy $hLinkConfig

    set hArpConfig [stc::get project1 -children-arpndconfig]      
    stc::config $hArpConfig -Active $ArpEnable  

	stc::apply

}
proc GetPortCopperStat {port} {
	set portCopper ""
    set hPortList [stc::get project1 -children-port]
	foreach ele $port {
		set portCopper [lindex $hPortList [expr $ele - 1]]
		set portCopper [stc::get $portCopper -children-EthernetCopper]
		set DuplexStatus [stc::get $portCopper -DuplexStatus]
		set LineSpeedStatus [stc::get $portCopper -LineSpeedStatus]
		set LinkStatus [stc::get $portCopper -LinkStatus]
	}
	puts "DuplexStatus=$DuplexStatus"
	puts "LineSpeedStatus=$LineSpeedStatus "
	puts "LinkStatus=$LinkStatus "
}

proc BreakLink {port} {
	set portCopper ""
    set hPortList [stc::get project1 -children-port]
	foreach ele $port {
		set portCopper [lindex $hPortList [expr $ele - 1]]
		stc::perform L2TestBreakLink -Port $portCopper
		stc::apply
	}

}

proc RestoreLink {port} {
	set portCopper ""
    set hPortList [stc::get project1 -children-port]
	foreach ele $port {
		set portCopper [lindex $hPortList [expr $ele - 1]]
		stc::perform L2TestRestoreLink -Port $portCopper
		stc::apply
	}

}

proc RestartAutoNegotiation {port} {
	set portCopper ""
    set hPortList [stc::get project1 -children-port]
	foreach ele $port {
		set portCopper [lindex $hPortList [expr $ele - 1]]
		stc::perform PortSetupRestartAutoNegotiation -PortList $portCopper
		stc::apply
	}

}

proc ConfigMiiRegister {port args} {
	set hPortList [stc::get project1 -children-port]
	foreach ele $port {
		
		set hPort [lindex $hPortList [expr $ele - 1]]
		set portCopper [stc::get $hPort -children-EthernetCopper]
		stc::apply
		stc::config $portCopper -PortSetupMode REGISTERS_ONLY
		set hMii [stc::get $portCopper -children-Mii]
		puts [stc::get $hMii -children-MiiRegister]
		set miiRegisterList [stc::get $hMii -children-MiiRegister]
		after 7000
		set index [lsearch $args -miiRegister] 
		if {$index != -1} {
			set miiRegister [lindex $args [expr $index + 1]]
		} else  {
			puts "argument error"
		}
		puts $miiRegister
		foreach temp $miiRegister {
			puts $temp
			set hMiiRegister [lindex $miiRegisterList [lindex $temp 0]]
			puts $hMiiRegister
			stc::config $hMiiRegister -RegValue [lindex $temp 1]
			stc::apply
		}
		set miiRegister0 [lindex $miiRegisterList 0]
		stc::config $miiRegister0 -RegValue 0x1940
		stc::apply
		after 3000
		stc::config $miiRegister0 -RegValue 0x1140
		stc::apply
		after 7000
		

	}
	
}

proc ConfigIgmpClientHost {port args} {

	#default value
	set hostName host1
	set srcMac 00:00:11:00:00:10
	set ipAddress 192.168.85.10
	set gateway 192.168.85.1
	set vlanId 100
	set priority 0
	
   # puts "create host"
	set clientPort ""
	
	set index [lsearch $args -hostName] 
	if {$index != -1} {
		set hostName [lindex $args [expr $index + 1]]
	} else  {
		
	}
	
	set index [lsearch $args -srcMac] 
	if {$index != -1} {
		set srcMac [lindex $args [expr $index + 1]]
	} else  {
		
	}
	
	set index [lsearch $args -ipAddress] 
	if {$index != -1} {
		set ipAddress [lindex $args [expr $index + 1]]
	} else  {
		
	}
	
	set index [lsearch $args -gateway] 
	if {$index != -1} {
		set gateway [lindex $args [expr $index + 1]]
	} else  {
		
	}
	
	set index [lsearch $args -vlanId] 
	if {$index != -1} {
		set vlanId [lindex $args [expr $index + 1]]
	} else  {
		
	}
	
	set index [lsearch $args -priority] 
	if {$index != -1} {
		set priority [lindex $args [expr $index + 1]]
	} else  {
		
	}
	
    set hPortList [stc::get project1 -children-port]
	set clientPort [lindex $hPortList [expr $port - 1]]
    set host [stc::create Host -under project1 -DeviceCount 1 -name $hostName]
    set ethIIIf [stc::create EthIIIf -under $host -SourceMac $srcMac]
	set vlanIf [stc::create vlanIf -under $host -VlanId $vlanId -Priority $priority]
    set ipv4If [stc::create Ipv4If -under $host -Address $ipAddress -Gateway $gateway]
	
	#puts "host attach interface stack"
	stc::config $host -AffiliatedPort $clientPort
	stc::config $host -TopLevelIf $ipv4If
	stc::config $host -PrimaryIf $ipv4If
	stc::config $ipv4If -StackedOn $ethIIIf
	#stc::config $IgmpHostConfig -UsesIf $ipv4If
	stc::config $ipv4If -StackedOnEndpoint-targets $vlanIf
    stc::config $vlanIf -StackedOnEndpoint-targets $ethIIIf  
			   
	stc::apply
	puts "config igmphost completed"
}


proc ConfigIgmpGroup {port hostName args} {
    
	set igmpGroupName "group1"
	set igmpVersion "IGMP_V2"
	set startGroupIp "224.0.0.1"
	set groupIpCount 1
	set insertCheckSumErrors FALSE
	
	set hPortList [stc::get project1 -children-port]
	
	#set host [stc::get $clientPort -children-Host]
	
	set hostList  [stc::get project1 -children-host]
	foreach host $hostList {
		set hostPort [stc::get $host -AffiliatedPort]
		set clientPort [lindex $hPortList [expr $port - 1]]
		set tempHostName [stc::get $host -Name]
		puts "tempHostName:$tempHostName"
		puts "hostName:$hostName"
		if {$hostName == $tempHostName} {
			set ipv4If [stc::get $host -children-Ipv4If]
			
			set index [lsearch $args -igmpGroupName] 
			if {$index != -1} {
				set igmpGroupName [lindex $args [expr $index + 1]]
			} else  {
				
			}
			
			set index [lsearch $args -igmpVersion] 
			if {$index != -1} {
				set igmpVersion [lindex $args [expr $index + 1]]
			} else  {
				
			}
			
			set index [lsearch $args -startGroupIp] 
			if {$index != -1} {
				set startGroupIp [lindex $args [expr $index + 1]]
			} else  {
				
			}
			
			set index [lsearch $args -groupIpCount] 
			if {$index != -1} {
				set groupIpCount [lindex $args [expr $index + 1]]
			} else  {
				
			}
			
			set index [lsearch $args -insertCheckSumErrors] 
			if {$index != -1} {
				set insertCheckSumErrors [lindex $args [expr $index + 1]]
			} else  {
				
			}
			
			#puts "config igmphostconfig"
			set IgmpHostConfig \
			[stc::create "IgmpHostConfig" -Under $host \
			-name $igmpGroupName \
			-Version $igmpVersion \
			-ForceRobustJoin "FALSE" \
			-ForceLeave "FALSE" \
			-InsertLengthErrors "FALSE" \
			-InsertCheckSumErrors $insertCheckSumErrors \
			-RobustnessVariable "2" \
			-UnsolicitedReportInterval "1" \
			-UsePartialBlockState "FALSE" \
			 ]
		 
			#puts "Config IgmpGroupMembership "
			set IgmpGroupMembership [stc::create IgmpGroupMembership -under $IgmpHostConfig -name $igmpGroupName]
			set Ipv4Group [stc::create "Ipv4Group" -Under project1 -Name $igmpGroupName]
			set Ipv4NetworkBlock [stc::get $Ipv4Group -children-Ipv4NetworkBlock]
			#puts "Configuring IPv4 Network Block..."
			stc::config $Ipv4NetworkBlock -StartIpList $startGroupIp -NetworkCount $groupIpCount -AddrIncrement 1 -Name $igmpGroupName
			stc::config $IgmpGroupMembership -MulticastGroup $Ipv4Group
			
			stc::config $IgmpHostConfig -UsesIf $ipv4If 
		}
	}
	stc::apply
    puts "config igmpGroup completed"
}



     
proc CheckPhyPortStatus {stcIpAddr portList} {
	stc::perform ChassisConnect -Hostname $stcIpAddr
	set chassisHandle [stc::get system1 -children-PhysicalChassisManager]
	set physicalChassisH [stc::get $chassisHandle -children-PhysicalChassis]
	stc::config $physicalChassisH -Hostname $stcIpAddr
	for {set i 0} {$i < [llength $portList]} {incr i} {
		set portLocation [lindex $portList $i]
		set str [split $portLocation /]
		set slot [lindex $str 1]
		set port [lindex $str 2]
		set physicalTestModuleH [stc::get $physicalChassisH -children-PhysicalTestModule]
		set testModuleH [lindex $physicalTestModuleH [expr $slot - 1]]
		set physicalPortGroupH [stc::get $testModuleH -children-PhysicalPortGroup]
		set portGroupH [lindex $physicalPortGroupH [expr $port - 1]]
		set time 0
		while {1} {
			set ownerShipState [stc::get $portGroupH -OwnershipState]
			set status [stc::get $portGroupH -Status]
			#if {($status == "MODULE_STATUS_UP") && ($ownerShipState == "OWNERSHIP_STATE_AVAILABLE")} {
			#	break 
			#}
			if {($status != "MODULE_STATUS_UP")} {
				puts "port${port} : $ownerShipState"
				puts "port${port} : $status"
				
			} else {
				break
			}
			#after 10000
			#if {$time == 6} {
			#	stc::perform RebootEquipment -EquipmentList $portGroupH
			#}
			#puts "$time"
			#incr time
		}
	}
}

#Add by Huangfu chunfeng;2014-3-11
proc CreateEmulatedDevice {args} {

    set args [string tolower $args]
    puts "Enter the proc of CreateEmulatedDeviceEmulatedDevice..."
        
    #Parse Emulateddevicename parameter
    set index [lsearch $args -emulateddevicename] 
    if {$index != -1} {
        set emulatedDeviceName [lindex $args [expr $index + 1]]
    } else  {
        puts " Please specify emulatedDevicename parameter \nexit the proc of CreateEmulatedDevice..."
    }

	#Parse stc port parameter
    set index [lsearch $args -stcport] 
    if {$index != -1} {
        set stcPort [lindex $args [expr $index + 1]]
    } else  {
        set stcPort 1
    } 	
	#Parse MacAddr parameter
    set index [lsearch $args -macaddr] 
    if {$index != -1} {
        set macAddr [lindex $args [expr $index + 1]]
    } else {
        set macAddr "00:01:20:00:00:01"
    } 
    #Parse IpVersion parameter
    set index [lsearch $args -ipversion] 
    if {$index != -1} {
        set ipVersion [lindex $args [expr $index + 1]]
    } else {
        set ipVersion ipv4
    }
    set ipVersion [string tolower $ipVersion]

    #Parse EmulatedDeviceType parameter
    set index [lsearch $args -EmulatedDevicetype] 
    if {$index != -1} {
        set EmulatedDeviceType [lindex $args [expr $index + 1]]
    } else  {
        set EmulatedDeviceType "ETHERNET"
    }
    set EmulatedDeviceType [string tolower $EmulatedDeviceType]
    
    #Parse Ipv4Addr parameter
    set index [lsearch $args -ipv4addr] 
    if {$index != -1} {
        set ipv4Addr [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else  {
        set ipv4Addr "192.168.1.2"
    }
    
    #Parse Ipv4SutAddr parameter
    set index [lsearch $args -ipv4gateway] 
    if {$index != -1} {
        set ipv4AddrGateway [lindex $args [expr $index + 1]]
        if {$ipv4AddrGateway == "default"} {
			set ipv4AddrGateway [join [lreplace [split $ipv4Addr "."] 3 3 1] "."]
        }
    }
	
     #Parse RouterId parameter
    set index [lsearch $args -routerid] 
    if {$index != -1} {
        set routerId [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else  {
        set routerId $ipv4Addr
    }
	
    #Parse Ipv4Mask parameter
    set index [lsearch $args -ipv4mask] 
    if {$index != -1} {
        set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
        set ipVersion ipv4
    } else {
        set index [lsearch $args -ipv4addrprefixlen] 
        if {$index != -1} {
            set ipv4AddrPrefixLen [lindex $args [expr $index + 1]]
            set ipVersion ipv4
        } else  {
            set ipv4AddrPrefixLen 24
        }
    }
    #Parse vlanId parameter
    set index [lsearch $args -vlanid] 
    if {$index != -1} {
        set vlanId [lindex $args [expr $index + 1]]
    } else {
		set vlanId 100
	}
	
	#Parse priority of vlan parameter
	set index [lsearch $args -vlanpriority] 
    if {$index != -1} {
        set vlanPriority [lindex $args [expr $index + 1]]
    } else {
		set vlanPriority 7
	}
	
	#Parser vlan type parameter
	set index [lsearch $args -vlantype] 
    if {$index != -1} {
        set vlanType [lindex $args [expr $index + 1]]
    } else {
		set vlanType 33024
	}
	
	#Parser vlan type parameter
	set index [lsearch $args -qinqlist] 
    if {$index != -1} {
        set QinQList [lindex $args [expr $index + 1]]
    }

	#Check if there is already exist the same name device
	set hEmulatedDevice ""
	foreach emulateddevice [stc::get project1 -children-emulateddevice] {
		set emulateddevicename [stc::get $emulateddevice -name]
		if {$emulateddevicename!=$emulatedDeviceName} {
			set hEmulatedDevice $emulateddevice
			break
		} else {
			puts "The device has exists"
		}
		
	}
    #if {$hEmulatedDevice == ""} {
    #    error "emulatedDevice ($emulatedDeviceName can not be found, please correct!" 
    #}
	#---------------------------------------------------
	# Create the emulateddevice.
	#------------------------------------------
	set hEmulatedDevice [stc::create emulateddevice -under project1 \
									-DeviceCount 1 \
									-RouterId 1.1.1.1 \
									-EnablePingResponse TRUE \
									-Name $emulatedDeviceName \
									]
	puts "stc::create emulateddevcie $emulatedDeviceName completed."
    #---------------------------------------------------
	# Create or Configure the ethernet II interface for the EmulatedDevice.
	#------------------------------------------
	set hEtherIIIf [stc::create EthIIIf -under $hEmulatedDevice -Active TRUE -SourceMac $macAddr]
	puts "EmulatedDevice EthIIIf creation/configuration has completed."
	
	
	#---------------------------------------------------
	# Create or Configure the ethernet II Vlan interface for the EmulatedDevice.
	#------------------------------------------
	set hVlanIf [stc::create VlanIf -under $hEmulatedDevice \
		-Priority $vlanPriority \
		-VlanId $vlanId]
	puts "EmulatedDevice VlanIf creation/configuration has completed."
	
	
	#---------------------------------------------------
	# Creating/configuring the EmulatedDevice's IPv4 interface...
	#------------------------------------------
    if {$ipVersion == "ipv4"} {
		set hIpv4If [stc::create Ipv4If \
							-under $hEmulatedDevice \
							-Address $ipv4Addr \
							-PrefixLength $ipv4AddrPrefixLen \
							-UsePortDefaultIpv4Gateway "FALSE" \
							-Gateway $ipv4AddrGateway \
							-ResolveGatewayMac "TRUE" \
							-Name "Ipv4If 2"]
		puts "Emulateddevice IPv4 interface creation/configuration has completed."
		
	    set stcPortList [stc::get project1 -children-port]
		stc::config $hEmulatedDevice -AffiliationPort-targets [lindex $stcPortList [expr $stcPort-1]] 
		stc::config $hEmulatedDevice -TopLevelIf-targets $hIpv4If
		stc::config $hEmulatedDevice -PrimaryIf-targets $hIpv4If
		stc::config $hIpv4If -StackedOn $hEtherIIIf
		stc::config $hEtherIIIf -StackedOn $hVlanIf
		puts "Emualteddevice $emulatedDeviceName has been created..."
	}
}



#==================================================add by hanxu=========================================================================

#################################################

proc ExecQuickCall {callProc} {
    if {[catch {
        eval $callProc
    } err]} {
         return "error:$err"
    } else {
        #return "[lindex $callProc] completed!"
    }
}

proc ipnetmask { ip mask } {
    if {[string is integer $mask]} {
        set masknum [expr (0xffffffff << (32 - $mask)) & 0xffffffff]
    } else {
        set masknum [ipaddr2dec $mask]
    }
    set ipnum [ipaddr2dec $ip]
    return [dec2ipaddr [expr $ipnum & $masknum]]   
}

proc ipaddr2dec {ipaddr} { 
   set list [split $ipaddr .]
   set len [llength $list]

   set dec 0
   
   set para1 [lindex $list 0]
   set para2 [lindex $list 1]
   set para3 [lindex $list 2]
   set para4 [lindex $list 3]

   set dec [expr $para4 + $para3 * 256 + $para2 *65536 + $para1 * 65536 * 256]
   return $dec
}
proc dec2ipaddr { num } {
    set ip ""
    binary scan [binary format I $num] c4 octets
    foreach oct $octets {
        lappend ip [expr ($oct & 0xff)]
    }
    return [join $ip .]
}