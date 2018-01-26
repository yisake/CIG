#--------------------------------
#
# The script are used to remote operate iTest lic server.
# 	
# Usage: you only edit the below command 
#		set command "reboot"  -- reboot license sever
#			set command "shutdown" -- shutdown license server
#				set command "start" -- start license server
#
# 2012/8/27 Peng
#----------------------------------

set serverIp 10.3.2.121
set serverPort 5000
set localHost [info hostname]
set command "reboot"

proc Client {host port} {
   set sock [socket $host $port]
   fconfigure $sock -buffering line
   return $sock
}

set sock [Client $serverIp $serverPort]

#--------- send your command --------------
set cmd "$localHost apply for $command license server ..."
puts $cmd
puts $sock $cmd
gets $sock


