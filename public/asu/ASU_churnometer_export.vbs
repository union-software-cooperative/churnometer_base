'******************************************************************************
'* Authors: lrohde 20-09-2012
'* Name: ASU_churnometer_export.vbs
'* Purpose:  
'*   Extract and post data to churnometer web server
'* Description:  
'*   This script was designed to extract data from an MSAccess 
'*   database into tab-delimited form using either standard windows
'*   libraries or utilities that do not require installation.
'*   We are targetting a server deployment without MSAccess installed.
'*   It finds files ending in .SQL, runs adodb compatible SQL inside 
'*   those files, exports the data to a file of the same name but ending
'*   in .txt then uploads that file to a churnometer server using curl.
'* Usage:
'*  create a directory for this script 
'*  save this file and SQL files you'd like to run in that directory
'*  Set data_path in configuration section (to this directory)
'*  Set dbfile to the path of your ms access membership database
'*  Set the url of your churnometer upload path
'*  Configure silent to true or false.  If silent = true no messages will shown
'*  Execute the script by double clicking from windows explorer
'*  or schedule a task to run it.  
'*  if silent, check the output of the log file (see configuration section)
'* Known Dependancies:
'*   MDAC 2.8 or lower for jet provider http://www.microsoft.com/en-us/download/details.aspx?id=5793
'*   Curl for posting to webserver - http://curl.haxx.se/dlwiz/?type=bin
'*   Tested on Windows XP, Windows 7, Server 2003
'******************************************************************************

'******************************************************************************
'* SECTION: Configuration
'******************************************************************************
silent = false ' if silent = true then don't pop up messages
dbfile = "\\nuwvic112\workarea\asu\asu.mdb" ' This is where your MSAccess database lives
data_path = "\\nuwvic112\workarea\asu" ' This is where you put this script and SQL files
url = "https://churnometer_staging/upload" ' This is where you want the data uploaded
mailserver = "mail.nuw.org.au"
logfilename = data_path & "\" & "churn_export.log" ' This is where you want the log file to save
curl_path = data_path ' This is where curl.exe is




'******************************************************************************
'* SECTION: Helper functions
'******************************************************************************

'******************************************************************************
'* FUNCTION: error_handler
'* Authors:  lrohde 20-09-2012
'* Purpose:  common functionality for detecting errors, writing to the log file
'* Inputs: 
'*  msg: human readable explanation to use if there was an error
'* Returns: 
'*  true if there as an error
'******************************************************************************
private function error_handler(msg)
	errno = err.number
	errmsg = err.description
	if errno <> 0 then 
		msg = msg & vbcrlf & "  Error: " & errmsg & vbcrlf & "  Error No: " & errno
		if not silent then msgbox msg
		logfile.writeline msg
		error_handler = true
	else 
		error_handler = false
	end if
end function

'******************************************************************************
'* FUNCTION: read_file
'* Authors:  lrohde 20-09-2012
'* Purpose:  read text from SQL files
'* Inputs: 
'*  file: vb file object
'* Returns: 
'*  Success: text inside the file
'*  Failure: ""
'******************************************************************************
private function read_file(file)
	on error resume next
	read_file = ""

	set fs = file.OpenAsTextStream(1, false)
	if error_handler("failed to open " & file.name) then exit function  
	
	while not fs.AtEndOfStream 
		read_file = read_file + fs.ReadLine + vbcrlf
		if error_handler("failed to read " & file.name) then read_file = "": exit function  
	wend
	
	fs.close
	set fs = nothing
end function

'******************************************************************************
'* FUNCTION: get_recordset
'* Authors:  lrohde 20-09-2012
'* Purpose:  Execute SQL and return ADODB recordset of data
'* Inputs: 
'*  cnn: ADODB connection object
'*  SQL: SQL text to be executed
'* Returns: 
'*  Success: ADODB recordset
'*  Failure: nothing
'******************************************************************************
private function get_recordset(cnn, SQL)
	On error resume next
	set get_recordset = nothing ' so an error can be detected upon return
	
	set rs = CreateObject("ADODB.recordset")
	rs.CursorType = adOpenDynamic
	rs.open SQL, cnn
	if error_handler("-- failed to execute query " & vbcrlf & SQL) then exit function  
	set get_recordset = rs
end function

'******************************************************************************
'* FUNCTION: write_data
'* Authors:  lrohde 20-09-2012
'* Purpose:  writes recordset to tab delimeted text file
'* Inputs: 
'*  rs: ADODB recordset
'*  filename: The name of the file to be written/over-written
'* Returns: 
'*  Success:  true
'*  Failure:  false
'******************************************************************************
private function write_data(rs, filename)
	on error resume next
	
	write_data = false

	' open file to write to
	set f = fso.createtextfile(filename, true)
	if error_handler("-- failed to write data to " & filename) then exit function  
	
	' output header to file
	header = ""
	for i = 0 to rs.fields.count-1
		if i <> 0 then header = header & chr(9)
		header = header & rs.fields(i).name
	next
	f.writeline header
	if error_handler("-- failed to write data to " & filename) then exit function  
	
	' output each row to file
	dim row
	while not rs.EOF
		row = ""
		' build text row from fields
		for i = 0 to rs.fields.count-1
			if i <> 0 then row = row & chr(9)
			row = row & rs.fields(i) 
		next
		' output row to file
		f.writeline row
		if error_handler("-- failed to write data to " & filename) then exit function  
	
		rs.movenext
	wend
	
	f.close
	write_data = true
end function

'******************************************************************************
'* FUNCTION: upload
'* Authors:  lrohde 20-09-2012
'* Purpose:  uploads data to web server
'* Inputs: 
'*  url:  full upload path 
'*  path:  path to data file (also used for curl's log)
'*  filename:  name of file to uploaded
'* Returns: 
'*  Success: true
'*  Failure: false, output from curl's log will be in main log file
'******************************************************************************
private function upload(url, path, filename) ' if it fails, returns path to log file, if it succeeds returns ""
	on error resume next
	upload = false
	
	curl_log = path & "\curl.log"
	
	' Call CURL from the command line
	' NB --insecure allows for the certificate to be self signed with an odd name
	' But data will still be encrypted
	Set WshShell = WScript.CreateObject("WScript.Shell")
	WshShell.Run "cmd /c " & curl_path & "\curl.exe --insecure -X POST --form myfile=@""" & path & "\" & filename & """ " & url & " > " & curl_log & " 2>&1", 0, true
	if error_handler("-- failed to execute curl to upload " & filename) then exit function  
		
	' Open curl's log file
	text = ""
	on error resume next
	Set file = fso.OpenTextFile(curl_log, 1)
	if error_handler("-- could not open curl's log " & curl_log) then exit function  
	text = file.ReadAll
	if error_handler("-- could not read curl's log " & curl_log) then exit function  
	file.Close
	on error goto 0
	
	' Check the log for success/failure
	if instr(text, "was successfully uploaded") > 0 then 
		if not silent then msgbox filename & " was successfully uploaded"
		logfile.writeline "-- Successfully uploaded " & data_filename
		upload = true
	else
		if not silent then msgbox filename & " failed to upload" 
		
		logfile.writeline "-- Failed to upload " & data_filename
		logfile.write text ' write curl's log to main log file
	end if
end function
	
'******************************************************************************
'* FUNCTION: wrap_up
'* Authors:  lrohde 20-09-2012
'* Purpose:  close objects and email log file
'* Inputs: None
'* Returns: None
'******************************************************************************
private sub wrap_up
	logfile.close
	 
	' Read log from file
	Set logfile = fso.OpenTextFile(logfilename, 1)
	logtext = logfile.ReadAll
	logfile.Close
	
	' Send email with log as message body
	Set objMessage = CreateObject("CDO.Message")
	
	'objMessage.From = "churnometer@theservicesunion.com.au"
	'objMessage.To = "Cary.Pollock@theservicesunion.com.au"
	'objMessage.CC = "lukerohde@gmail.com"
	objMessage.Subject = "Churnometer Export"
	objMessage.From = "churnometer@nuw.org.au"
	objMessage.To = "lrohde@nuw.org.au"
	objMessage.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendusing")=2
	objMessage.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserver")=mailserver
	objMessage.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserverport")=25 
	objMessage.Configuration.Fields.Update
	objMessage.TextBody = logtext
	objMessage.Send
	
	cnn.close
	set cnn = nothing
	set fso = nothing
	set folder = nothing
	set files = nothing	
end sub

'******************************************************************************
'* SECTION: Program Main
'******************************************************************************

' Create log file
set fso = CreateObject("Scripting.FileSystemObject")
set logfile = fso.createtextfile(logfilename, true)

' Suppress errors so they can be handled and logged
on error resume next

' Connect to database
set cnn = CreateObject("ADODB.connection")
cnn.Provider = "Microsoft.Jet.OLEDB.4.0"
cnn.open dbfile
if error_handler("failed to connect to the database " & dbfile) then call wrap_up: Wscript.Quit

' Find files to enumerate (looking for files with .sql extensions)
set folder = fso.GetFolder(data_path)
set files = folder.files
if error_handler("Invalid data path: " & data_path) then call wrap_up: Wscript.Quit

' Set up regular expression for matching file names that have .sql extentions
set r = new regexp
r.Pattern = ".+\.sql$" ' matches anything ending in .sql
r.IgnoreCase = true

' Iterate through each file
for each file in files
	if r.test(file.name) then 	
		logfile.writeline "- Processing " & file.name
		' Read SQL from file
		SQL = read_file(file)
		if SQL <> "" then 
			' Execute SQL against database
			set rs = get_recordset(cnn, SQL)
			if not rs is nothing then 
				logfile.writeline "-- Executed query in " & file.name
				data_filename = replace(file.name, ".sql", ".txt")
			
				' Write SQL result to text file
				write_result = write_data (rs, data_path & "\" & data_filename)
				if write_result then 
					logfile.writeline "-- Wrote data to " & data_filename
					
					' upload text file to website
					upload_result = upload(url, data_path,  data_filename)
				end if ' successful data write
				
				rs.close
				set rs = nothing
			end if ' successful data load
		end if ' successful SQL file read
	else
		logfile.writeline "- Skipping " & file.name
	end if
next


On Error Goto 0 ' raise errors normally now because logging won't work during wrap-up
call wrap_up
if not silent then msgbox("Done")
