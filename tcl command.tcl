1.获取命令行参数
#和C语言一样，Tcl中有两个默认变量，$argc 存储命令行参数的个数。list $argv中包含了参数信息。
tclsh 1.tcl 11 22 33 44
puts $argc
puts $argv
argc参数数目
argv0脚本名字
argv参数列表

全局变量
auto_path
errorCode
tcl_library
tcl_versions

全局数组
auto_execs---》存储了auto_mkIndex和空字符{}
auto_index
tcl_platform
env数组是全局环境变量 tcl_library是全局库目录

2.将cmd命令写成bat文件，然后用exec执行
proc cmd {cmd} {
     set a [open D:/tmp.txt]
     puts $a "$cmd\n"
     close $a
     set b [exec D:/tmp.txt]
     puts $b
}

#语法知识总结
array exists arrayName？mode？？pattern？可以返回数组元素，指定mode可以是string equal严格匹配，string match通配符模式默认,string regexp正则，如果带上pattern，则返回pattern数组元素名字，如果存在
array gets  xx 数组元素名，
array get env Path;#返回特定数组元素和值的列表
array set hf {
	name huangfu
	height 168
	weight 64
	age 24
}#创建数组,或者修改修改数组中的元素
array size;#返回数组元素的个数



#将string从指定的encoding转化为UTF-8 Unicode,如果不指定，默认为系统编码
encoding convertfrom ?encoding?string?
#将string从UTF-8 Unicode转化为encoding。如果不指定encoding，默认为系统编码
encoding convertto ?encoding?string?
#返回识别到的编码名称
encoding names
#将系统编码指定为encoding。如果不指定encoding，返回系统当前编码。
encoding system？encoding？

#删除name这个文件（或者目录）
file delete ?-force ?name?
#是否存在name的文件（或者目录）
file exists name?
#创建目录name
file mkdir name?
file copy递归拷贝文件,目录,-force强制覆盖
file delete删除文件，包涵目录
file exists是否存在文件，包括目录
file executable是否可执行
file extension返回文件最后.之后所有字符
file channels返回所有通道描述符  
file rename重命名
file rootname返回不带扩展名的文件名
file size返回文件大小，字节
flush;#将通道缓冲区的内容输出到文件或者设备
fileevent;#事件驱动编程

gets fileId varName#读取fileId下一行，忽略换行符，如果有varName则赋给他，并返回该行字符数，文件尾返回-1

glob glob命令和linux系统的ls命令相似，用于文件的匹配搜索并返回一个与模式匹配的文件名列表。-directory在指定目录中查找，-path在指定路径，不能和-directory一起使用

info script;#返回执行的脚本名字

puts -nonewline fileId string 如果没有nonewline选项，添加换行符fileId默认是stdout，缓冲区机制

string equal ?-nocase??-length num?string1 string2?#如果string1和string2相同，返回，否则返回0,-nocase忽略大小写，-length从头开始第几个字符进行比较
string first string1 string2 ?startIndex?#返回string1在string2中第一次匹配的字符串的索引，如果不匹配，返回-1,如果指定了startIndex，则从索引为startIndex的字符开始匹配
string length#返回字符串长度
string match ?-nocase?pattern string#字符串匹配,默认通配符
string match a* abbb
string map {abc 1 ab 2 a 3 1 0} 1abcaababcabababc;#返回01321221根据创建的mapper规则，替换字符串
string tolower first? last?
string totitle
string toupper


regexp -indices "ontSessionTcpPort: " $b a;#根据正则表达式进行匹配，regexp -start -all -nocase -indices -inline，并且存到指定的变量中
#根据正则表达式替换字符串
regsub -all there "They live there lives " their 
regsub -all / $a \\;#用反斜杠取消转义
set a {C:\Program Files\NetIQ\IxChariot\TCL}
regsub -all {\\} $a /



lset设置列表中某个元素的值
#6.6搜索列表:lsearch
#标志:-exact严格匹配，-glob通配符，-regexp正则表达式,-all返回所有匹配项，-inline返回匹配的元素，无匹配返回-1
set x {John Anne Mary Jim}
lsearch $x Mary
lsearch $x Phil

set states {California Hawaii Iowa Maine Vermont}
lsearch -all $states *a*
lsearch -all -inline $states *a*




#第8章 流程控制
source
#8.1 eval命令
set reset {
	set a 0
	set b 0
	set c 0
}
eval $reset



#第10章 命名空间
#在一个namespace执行命令，::huangfu::命令 参数
namespace children ?namespace? ?pattern?
#返回指定命名空间所有子命名空间的列表，如果没有namespace参数则返回当前命名空间
namespace current
#返回当前命名空间完全限定名称

namespace origin command?
#返回commnad的完全限定名称

namespace parrent namespace?
#返回namespace的父命名空间，


namespace eval  alu {
	proc ConfigVlan {} {
		puts "config alu vlan"
	}
	namespace export ConfigVlan
}

namespace eval adtran {
	 namespace import ::alu::ConfigVlan
}




#10.5检查命名空间
namespace children 
#检查命名空间下所有命令info command ::ISAM::OLTCommand::*



#第11章 访问文件
open name? access?
#以access模式打开文件name，access可以是r,r+,w,w+,a或a+,默认值为r。返回的文件描述符可以用于其他
#命令，如gets和close。如果name开头字符是|，命令打开的不是文件而是管道。

#11.5处理磁盘上的文件
#11.5.1创建目录
file mkdir foo
#11.5.2删除文件
file delete a.txt

#11.6读写文件
#11.6.1基本文件I/O
open a.txt
close a.txt
#返回当前所有的通道，包括sock连接
file channels

set a [open D:/1.txt r+]
while {![eof $a]} {
        puts "[get $a]"
}

#11.6.4管理字符编码集
chan configure channelID? optionName? ?value??optionName value...?
fconfigure channelID? optionName? ?value??optionName value...?
#查看或者设定channelID通道的配置。如果没有optionName和value参数，返回一个字典，内容是
#所有的设置选项和它们的值。如果提供optionName而不提供value，则返回指定选项的值。
#从Tcl8.5开始，建议使用chan configure命令。
set a [socket 10.7.20.12 23]
chan configure $a -blocking 0 -buffering none
puts $a "cig\r"
puts $a "sy\r"
puts $a "display mac-address\r"

#11.6.5处理二进制文件


#12.4管线命令的输入输出

#12.9TCP/IP通信
#创建客户socket
set socketid [socked localhost 22]
set socketid [socket -myaddr 192.168.1.101 -myport 1234 192.168.1.101 22]

proc connected {fid} {
	#Remove the writable event handler to prevent it
	#from being invoked again
	chan event $fid writable {}
	#Test for the existence of -peername in the channel
	#Configuration to see if the connection was successful.
	if {[dict exists [chan configure $fid] -peername]} {
	} else {
	}
}


	
#第14章 创建与使用Tcl脚本库
auto_mkindex dir? pattern...?
info library
info loaded ?interp?返回当前解释器加载的包
info sharedlibextension返回该平台为共享库使用的文件扩展名(在window中返回.dll后缀）
package ifneeded package version script在pkgIndex.tcl文件中使用，script自动运行
package names返回解释其中所有的包

package require package?requirement?(-exact package requirement)
package vcompare version1 version2如果version1比version2新，返回1,等于返回0，老返回-1
pkg_mkIndex ?options?dir?pattern...?生成适于Tcl包的机制使用的pkgIndex.tcl索引。该命令搜索dir中所有与pattern参数
#匹配的文件（由glob命令匹配），如果没有给定pattern，默认模式为*.tcl和*.[info sharedlibxtension]
#::tcl::tm::path list返回一个列表，其内容为所有注册的Tcl模块的路径
#load将预编译的库加载到Tcl解释器中，这些库通常由C或者C++编写。


namespace eval src {
        set d 1234
        proc a {} {return "alpha"}
        proc b {} {return "beta"}
        proc c {} {return "..."}
        namespace export a b d
}
namespace eval dst {
        namespace import ::src::*
        proc c {} {return "charlie"}
        expr {"[a][b][c]"}
}
%alphabetacharlie

namespace eval dst {
        namespace import ::src::*
        proc c {} {return "charlie"}
        expr {"[a] [b] [c]"}
}
%alpha beta charlie



#Practical Programming in Tcl and Tk,Fourth Edition
#Chapter 9 Working with Files and Programs
#Input/Output Command Summary
#Queries end-of-file status
eof channel
#Writes buffers of a channel
flush channel

#第15章 Tcl内部管理
% clock format [clock seconds] -format "%Z %A %a %B %b %w %Y %y %m %d %H %I %p %M %S %j %u"
中国标准时间 Monday Mon July Jul 1 2014 14 07 28 22 10 PM 24 36 209 1


将cmd命令写成bat文件，然后用exec执行

proc cmd {cmd} {

     set a [open D:/tmp.txt]

     puts $a "$cmd\n"

     close $a

     set b [exec D:/tmp.txt]

     puts $b

}


打开串口命令

open com1～x选项为

-mode

baud波特率

parity奇偶校验方式为以下的一种n o e m s

data数据位长度，一般是5～8

stop停止位长度，1或2


文件时间间隔

-pollinterval

只用于windows环境，用来检测或者设定fileevent最大时间间隔

-lasterror
只用于windows环境，当串口通讯出现问题时，read或puts都将返回一个IO错误，



串口推荐通道配置
fconfigure $com -blocking 0 -buffering none -translation binary #必须设置成binary模式，否则不会有任何事件触发发生


proc Com_Init{com {baud 9600}} {
        set comId [open $com r+]#以读写方式打开串口
        puts $comId
        fconfigure $comId -mode $baud,n,8,1
        #设置串口模式参数
        fconfigure $comId -blocking 0 -buffering none -translation binary
         #设置非阻塞模式
         fileevent $comId readable [list Com_gets $comId]       
}

proc Com_gets {comId} {
         puts [gets $comId]
}


file copy递归拷贝文件,目录,-force强制覆盖

file delete删除文件，包涵目录

file exists是否存在文件，包括目录

file executable是否可执行

file extension返回文件最后.之后所有字符

file channels返回所有通道描述符  
file rename重命名
filerootname返回不带扩展名的文件名
file size返回文件大小，字节

flush将通道缓冲区的内容输出到文件或者设备
fileevent事件驱动编程

gets fileId varName#读取fileId下一行，忽略换行符，如果有varName则赋给他，并返回该行字符数，文件尾返回-1
glob glob命令和linux系统的ls命令相似，用于文件的匹配搜索并返回一个与模式匹配的文件名列表。-directory在指定目录中查找，-path在指定路径，不能和-directory一起使用

puts -nonewline fileId string 如果没有 
-nonewline选项，添加换行符fileId默认是stdout，缓冲区机制
read -nonewline fileId