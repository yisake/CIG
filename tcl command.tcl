1.��ȡ�����в���
#��C����һ����Tcl��������Ĭ�ϱ�����$argc �洢�����в����ĸ�����list $argv�а����˲�����Ϣ��
tclsh 1.tcl 11 22 33 44
puts $argc
puts $argv
argc������Ŀ
argv0�ű�����
argv�����б�

ȫ�ֱ���
auto_path
errorCode
tcl_library
tcl_versions

ȫ������
auto_execs---���洢��auto_mkIndex�Ϳ��ַ�{}
auto_index
tcl_platform
env������ȫ�ֻ������� tcl_library��ȫ�ֿ�Ŀ¼

2.��cmd����д��bat�ļ���Ȼ����execִ��
proc cmd {cmd} {
     set a [open D:/tmp.txt]
     puts $a "$cmd\n"
     close $a
     set b [exec D:/tmp.txt]
     puts $b
}

#�﷨֪ʶ�ܽ�
array exists arrayName��mode����pattern�����Է�������Ԫ�أ�ָ��mode������string equal�ϸ�ƥ�䣬string matchͨ���ģʽĬ��,string regexp�����������pattern���򷵻�pattern����Ԫ�����֣��������
array gets  xx ����Ԫ������
array get env Path;#�����ض�����Ԫ�غ�ֵ���б�
array set hf {
	name huangfu
	height 168
	weight 64
	age 24
}#��������,�����޸��޸������е�Ԫ��
array size;#��������Ԫ�صĸ���



#��string��ָ����encodingת��ΪUTF-8 Unicode,�����ָ����Ĭ��Ϊϵͳ����
encoding convertfrom ?encoding?string?
#��string��UTF-8 Unicodeת��Ϊencoding�������ָ��encoding��Ĭ��Ϊϵͳ����
encoding convertto ?encoding?string?
#����ʶ�𵽵ı�������
encoding names
#��ϵͳ����ָ��Ϊencoding�������ָ��encoding������ϵͳ��ǰ���롣
encoding system��encoding��

#ɾ��name����ļ�������Ŀ¼��
file delete ?-force ?name?
#�Ƿ����name���ļ�������Ŀ¼��
file exists name?
#����Ŀ¼name
file mkdir name?
file copy�ݹ鿽���ļ�,Ŀ¼,-forceǿ�Ƹ���
file deleteɾ���ļ�������Ŀ¼
file exists�Ƿ�����ļ�������Ŀ¼
file executable�Ƿ��ִ��
file extension�����ļ����.֮�������ַ�
file channels��������ͨ��������  
file rename������
file rootname���ز�����չ�����ļ���
file size�����ļ���С���ֽ�
flush;#��ͨ��������������������ļ������豸
fileevent;#�¼��������

gets fileId varName#��ȡfileId��һ�У����Ի��з��������varName�򸳸����������ظ����ַ������ļ�β����-1

glob glob�����linuxϵͳ��ls�������ƣ������ļ���ƥ������������һ����ģʽƥ����ļ����б�-directory��ָ��Ŀ¼�в��ң�-path��ָ��·�������ܺ�-directoryһ��ʹ��

info script;#����ִ�еĽű�����

puts -nonewline fileId string ���û��nonewlineѡ���ӻ��з�fileIdĬ����stdout������������

string equal ?-nocase??-length num?string1 string2?#���string1��string2��ͬ�����أ����򷵻�0,-nocase���Դ�Сд��-length��ͷ��ʼ�ڼ����ַ����бȽ�
string first string1 string2 ?startIndex?#����string1��string2�е�һ��ƥ����ַ����������������ƥ�䣬����-1,���ָ����startIndex���������ΪstartIndex���ַ���ʼƥ��
string length#�����ַ�������
string match ?-nocase?pattern string#�ַ���ƥ��,Ĭ��ͨ���
string match a* abbb
string map {abc 1 ab 2 a 3 1 0} 1abcaababcabababc;#����01321221���ݴ�����mapper�����滻�ַ���
string tolower first? last?
string totitle
string toupper


regexp -indices "ontSessionTcpPort: " $b a;#����������ʽ����ƥ�䣬regexp -start -all -nocase -indices -inline�����Ҵ浽ָ���ı�����
#����������ʽ�滻�ַ���
regsub -all there "They live there lives " their 
regsub -all / $a \\;#�÷�б��ȡ��ת��
set a {C:\Program Files\NetIQ\IxChariot\TCL}
regsub -all {\\} $a /



lset�����б���ĳ��Ԫ�ص�ֵ
#6.6�����б�:lsearch
#��־:-exact�ϸ�ƥ�䣬-globͨ�����-regexp������ʽ,-all��������ƥ���-inline����ƥ���Ԫ�أ���ƥ�䷵��-1
set x {John Anne Mary Jim}
lsearch $x Mary
lsearch $x Phil

set states {California Hawaii Iowa Maine Vermont}
lsearch -all $states *a*
lsearch -all -inline $states *a*




#��8�� ���̿���
source
#8.1 eval����
set reset {
	set a 0
	set b 0
	set c 0
}
eval $reset



#��10�� �����ռ�
#��һ��namespaceִ�����::huangfu::���� ����
namespace children ?namespace? ?pattern?
#����ָ�������ռ������������ռ���б����û��namespace�����򷵻ص�ǰ�����ռ�
namespace current
#���ص�ǰ�����ռ���ȫ�޶�����

namespace origin command?
#����commnad����ȫ�޶�����

namespace parrent namespace?
#����namespace�ĸ������ռ䣬


namespace eval  alu {
	proc ConfigVlan {} {
		puts "config alu vlan"
	}
	namespace export ConfigVlan
}

namespace eval adtran {
	 namespace import ::alu::ConfigVlan
}




#10.5��������ռ�
namespace children 
#��������ռ�����������info command ::ISAM::OLTCommand::*



#��11�� �����ļ�
open name? access?
#��accessģʽ���ļ�name��access������r,r+,w,w+,a��a+,Ĭ��ֵΪr�����ص��ļ�������������������
#�����gets��close�����name��ͷ�ַ���|������򿪵Ĳ����ļ����ǹܵ���

#11.5��������ϵ��ļ�
#11.5.1����Ŀ¼
file mkdir foo
#11.5.2ɾ���ļ�
file delete a.txt

#11.6��д�ļ�
#11.6.1�����ļ�I/O
open a.txt
close a.txt
#���ص�ǰ���е�ͨ��������sock����
file channels

set a [open D:/1.txt r+]
while {![eof $a]} {
        puts "[get $a]"
}

#11.6.4�����ַ����뼯
chan configure channelID? optionName? ?value??optionName value...?
fconfigure channelID? optionName? ?value??optionName value...?
#�鿴�����趨channelIDͨ�������á����û��optionName��value����������һ���ֵ䣬������
#���е�����ѡ������ǵ�ֵ������ṩoptionName�����ṩvalue���򷵻�ָ��ѡ���ֵ��
#��Tcl8.5��ʼ������ʹ��chan configure���
set a [socket 10.7.20.12 23]
chan configure $a -blocking 0 -buffering none
puts $a "cig\r"
puts $a "sy\r"
puts $a "display mac-address\r"

#11.6.5����������ļ�


#12.4����������������

#12.9TCP/IPͨ��
#�����ͻ�socket
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


	
#��14�� ������ʹ��Tcl�ű���
auto_mkindex dir? pattern...?
info library
info loaded ?interp?���ص�ǰ���������صİ�
info sharedlibextension���ظ�ƽ̨Ϊ�����ʹ�õ��ļ���չ��(��window�з���.dll��׺��
package ifneeded package version script��pkgIndex.tcl�ļ���ʹ�ã�script�Զ�����
package names���ؽ����������еİ�

package require package?requirement?(-exact package requirement)
package vcompare version1 version2���version1��version2�£�����1,���ڷ���0���Ϸ���-1
pkg_mkIndex ?options?dir?pattern...?��������Tcl���Ļ���ʹ�õ�pkgIndex.tcl����������������dir��������pattern����
#ƥ����ļ�����glob����ƥ�䣩�����û�и���pattern��Ĭ��ģʽΪ*.tcl��*.[info sharedlibxtension]
#::tcl::tm::path list����һ���б�������Ϊ����ע���Tclģ���·��
#load��Ԥ����Ŀ���ص�Tcl�������У���Щ��ͨ����C����C++��д��


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

#��15�� Tcl�ڲ�����
% clock format [clock seconds] -format "%Z %A %a %B %b %w %Y %y %m %d %H %I %p %M %S %j %u"
�й���׼ʱ�� Monday Mon July Jul 1 2014 14 07 28 22 10 PM 24 36 209 1


��cmd����д��bat�ļ���Ȼ����execִ��

proc cmd {cmd} {

     set a [open D:/tmp.txt]

     puts $a "$cmd\n"

     close $a

     set b [exec D:/tmp.txt]

     puts $b

}


�򿪴�������

open com1��xѡ��Ϊ

-mode

baud������

parity��żУ�鷽ʽΪ���µ�һ��n o e m s

data����λ���ȣ�һ����5��8

stopֹͣλ���ȣ�1��2


�ļ�ʱ����

-pollinterval

ֻ����windows�����������������趨fileevent���ʱ����

-lasterror
ֻ����windows������������ͨѶ��������ʱ��read��puts��������һ��IO����



�����Ƽ�ͨ������
fconfigure $com -blocking 0 -buffering none -translation binary #�������ó�binaryģʽ�����򲻻����κ��¼���������


proc Com_Init{com {baud 9600}} {
        set comId [open $com r+]#�Զ�д��ʽ�򿪴���
        puts $comId
        fconfigure $comId -mode $baud,n,8,1
        #���ô���ģʽ����
        fconfigure $comId -blocking 0 -buffering none -translation binary
         #���÷�����ģʽ
         fileevent $comId readable [list Com_gets $comId]       
}

proc Com_gets {comId} {
         puts [gets $comId]
}


file copy�ݹ鿽���ļ�,Ŀ¼,-forceǿ�Ƹ���

file deleteɾ���ļ�������Ŀ¼

file exists�Ƿ�����ļ�������Ŀ¼

file executable�Ƿ��ִ��

file extension�����ļ����.֮�������ַ�

file channels��������ͨ��������  
file rename������
filerootname���ز�����չ�����ļ���
file size�����ļ���С���ֽ�

flush��ͨ��������������������ļ������豸
fileevent�¼��������

gets fileId varName#��ȡfileId��һ�У����Ի��з��������varName�򸳸����������ظ����ַ������ļ�β����-1
glob glob�����linuxϵͳ��ls�������ƣ������ļ���ƥ������������һ����ģʽƥ����ļ����б�-directory��ָ��Ŀ¼�в��ң�-path��ָ��·�������ܺ�-directoryһ��ʹ��

puts -nonewline fileId string ���û�� 
-nonewlineѡ���ӻ��з�fileIdĬ����stdout������������
read -nonewline fileId