﻿#Can be changed as needed.

Function Add-Header{
 #Creates the header script
 param( 
  [String] $ScriptName,
  $InvocationLine,
  [string] $SourceName 
)
 $Date="{0:d}" -f [DateTime]::Today 
 $Line ="#" * 80
@"
$Line 
`#
`#  Name    : $ScriptName  
`#  Version : 0.1
`#  Author  :
`#  Date    : $Date
`#
`#  Generated with PowerShell V$($PSVersionTable.PSVersion)
`#  Invocation Line   : $InvocationLine
`#  Source            : $SourceName
$Line
"@
}

