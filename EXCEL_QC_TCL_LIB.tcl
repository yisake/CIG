package require tcom

set workbook ""
set app ""
set worksheet ""
set visiable 0


proc OpenXlsFile {args} {
	global workbook 
	global app
	global visiable 
	#搜索函数中是否有-filename参数，并按照索引+1方式，取得Excel文件名
	set index [lsearch $args "-fileName"]
	if {$index != -1} {
		set fileName  [lindex $args [expr $index + 1]]
	}
	#如果存在同名文件名，则删除
	if {[file exists $fileName] == 1 } {
		puts "file delete!!"
		file delete -force $fileName
	}
	
	set app [::tcom::ref createobject "Excel.Application"]
	set workbooks [$app Workbooks]
	set workbook [$workbooks Add]
	
	# 显示Excel
	$app Visible $visiable
}

proc SetWorksheet {args} {
	global workbook
	global worksheet  
	set index [lsearch $args "-worksheet"]
	if {$index != -1} {
		set worksheet [lindex $args [expr $index + 1]]
	}
	set worksheets [$workbook Worksheets]
	set worksheet [$worksheets Item $worksheet]
}

proc SetCell {args} {
	global worksheet 
	
	# 获取A1单元的范围对象
	
	
	set index [lsearch $args "-cell"]
	if {$index != -1} {
		set cell [lindex $args [expr $index + 1]]
		set range [$worksheet Range $cell]
		set interior [$range Interior]
	}
	
	set index [lsearch $args "-string"]
	if {$index != -1} {
		set string [lindex $args [expr $index + 1]]
		# 给A1单元赋值
		$range Value2 "$string"
	}
	set index [lsearch $args "-bgColor"]
	if {$index != -1} {
		# 设置单元的背景色
		set bgColor [lindex $args [expr $index + 1]]
		$interior Color [expr $bgColor]
	}	
}

proc SaveXlsFile {args} {
	puts "$args"
	global workbook
	global app
	
	set index [lsearch $args "-fileName"]
	if {$index != -1} {
		set fileName [lindex $args [expr $index + 1]]
		set fileName [regsub -all / $fileName \\] 
		
	}
	
	# 保存文档
	$workbook SaveAs $fileName
	$app Quit
	
}