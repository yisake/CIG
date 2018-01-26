package require tcom

set app ""
set workbook ""
set worksheet ""
set visiable 0

set argv "-csvFile D:/1.txt"
array set args $argv
set index [lsearch $argv "-csvFile"]

if {$index != -1} {
	set csvFile [lindex $argv [expr $index + 1]]
} else {
	puts "ERROR: could not find the csv file!"
}
puts "File is $csvFile"


proc InitXlsFile {} {
	global app
	global workbook 
	global visiable 
	global worksheet	
	set app [::tcom::ref createobject "Excel.Application"]
	set workbooks [$app Workbooks]
	set workbook [$workbooks Add]
	
	$app Visible $visiable
	set worksheets [$workbook Worksheets]
	set worksheet [$worksheets Item [expr 1]]
}


proc SetCell {row col color italic bold name size value} {
	global worksheet 	
	set aColList {A B C D E F}
	set cells [$worksheet Cells]
	$cells Item $row [lindex $aColList $col] $value
	
	set range [$worksheet Range [lindex $aColList $col]$row]
	#set interior [$range Interior]
	set font [$range Font]	
	# set font color.
	$font Color [expr $color]
	# Set bold font.
	$font Bold [expr $bold]	
	# Set italic font.
	$font Italic [expr $italic]	
	# Set font style.
	$font Name $name		
	# Set font size.
	$font Size [expr $size]	
}


proc SaveXlsFile {xlsFile} {

	global workbook
	global app
	
	if {[file exists $xlsFile]} {
		file delete $xlsFile
	}
	# Save file with Xls format.
	$workbook SaveAs $xlsFile
	$app Quit
}


# #################################
# Main
# #################################
puts "$csvFile"
set path [lindex [split $csvFile "."] 0]
puts "Path is $path\n\n"
set tmpFile ${path}.xlsx
set xlsFile [regsub -all / $tmpFile \\] 


InitXlsFile 
#打开文本文件
set csv [open $csvFile r+]
set row 1
#读取每一行的文本内容
while {[gets $csv line] >= 0} {
	puts $line
	set colList [split $line ","]
	#在一行中搜索到Fail case字符串时，则把
	if {[regexp  -all "Fail case" $line ]} {
		for {set col 0} {$col <= [llength $colList]} {incr col} {
			SetCell $row $col 0xA0522D 1 1 "Arial" 11 [lindex $colList $col]
		}
	} elseif {[regexp  -all "ITEM" $line ]} {
		for {set col 0} {$col <= [llength $colList]} {incr col} {
			SetCell $row $col 0x9400D3 0 1 "Britannic Bold" 11 [lindex $colList $col]
		}
		set caseLine $row
	} else {
		for {set col 0} {$col <= [llength $colList]} {incr col} {
			SetCell $row $col 0xFF0000 0 0 "Arial" 9 [lindex $colList $col]
		}	
	}
	incr row
}


set range [$worksheet Range A1]
$range ColumnWidth 35
SaveXlsFile $xlsFile
