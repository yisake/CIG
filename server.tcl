#!/bin/sh
##***********************************************
##
## FILE NAME: 		server_daemon.tcl
## FUNTION:			The script is daemon for reboot iTest license server;
##						if this daemon receive the command 'reboot' or 'shutdown' of remote client 
##						 the daemon will excute these operation.
##
## AUTHOR:			Peng
## CREATION DATE:	8/25/2012
## COPYRIGHT:		CIG
##
##***********************************************

proc Server {port} {
	global echo
	set echo(main) [socket -server EchoAccept $port]
	if {[info exists $echo(main)]} {
		puts "Daemon is fail!"
	} else {
		puts "Daemon is okay!"
	}
}
proc EchoAccept {sock addr port} {
	global echo
	set currentTime [clock format [clock seconds]]
	puts "Accept $sock from $addr port $port at : $currentTime"
	set echo(addr,$sock) [list $addr $port]
	fconfigure $sock -buffering line
	fileevent $sock readable [list Excute $sock]
}
proc Excute {sock} {
	global echo
	#global licDir
	if {[eof $sock] || [catch {gets $sock line}]} {
		# end of file or abnormal connection drop
		close $sock
		puts "Close $echo(addr,$sock)"
		unset echo(addr,$sock)
	} else {
		puts "#-----------------------"
		puts "Recieve command: $line"
		puts "#-----------------------"
		if {[regexp -nocase "reboot" $line ]} {
			# Do reboot.
			set flag [Reboot]
			if {$flag == 2} {
				puts "Success to reboot."	
			} else {
				puts "Fail to reboot."
			}
		}
		if {[regexp -nocase "shutdown" $line ]} {
			# Do reboot.
			set flag [Shutdown]
			if {$flag == 1} {
				puts "Success to shutdown."	
			} else {
				puts "Fail to shutdown."
			}
		}
		if {[regexp -nocase "start" $line ]} {
			# Do reboot.
			set flag [Start]
			if {$flag == 1} {
				puts "Success to start."	
			} else {
				puts "Fail to start."
			}
		}
		if {[string compare $line "quit"] == 0} {
			# Prevent new connections.
			# Existing connections stay open.
			close $echo(main)
		}
		puts $sock $line
   }
}
proc Reboot {} {
	# Reboot iTest license server.
	set flag 0
	catch {[exec lmutil.exe lmdown -q -force]} result
	if {[string first "1 FLEXnet License Server shut down" $result] != -1 } {
		puts "It's successful to shutdown license server."
		incr flag
	} else {
		puts "It's fail to shutdown license server."
	}
	after 1000
	catch {[exec lmgrd.exe -c BC305BE2778E.lic -l logFile.log]} result
	if {[string first "invalid command name \"\"" $result] != -1} {
		puts "It's successful to start license server."
		incr flag
	} else {
		puts "It's fail to start license server."
	}
	after 1000
	return $flag
}
proc Shutdown {} {
	# Shutdown iTest license server.
	set flag 0
	catch {[exec lmutil.exe lmdown -q -force]} result
	if {[string first "1 FLEXnet License Server shut down" $result] != -1 } {
		puts "It's successful to shutdown license server."
		incr flag
	} else {
		puts "It's fail to shutdown license server."
	}
	after 1000
	return $flag
}
proc Start {} {
	# Start iTest license server.
	set flag 0
	catch {[exec lmgrd.exe -c BC305BE2778E.lic -l logFile.log]} result
	if {[string first "invalid command name \"\"" $result] != -1} {
		puts "It's successful to start license server."
		incr flag
	} else {
		puts "It's fail to start license server."
	}
	after 1000
	return $flag
}

#---------------------------------------------
# Main
#---------------------------------------------
set licDir "C:/Users/peng/Desktop/103532988.spirent-vendor-daemon_v4.2-win32/spirent-vendor-daemon_v4.2-win32"

cd $licDir
puts [pwd]
Server 5000
vwait forever
