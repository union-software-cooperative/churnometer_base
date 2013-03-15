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
'* SECTION: Diagnostics
'******************************************************************************
debugging = false 'throw pop-up error messages instead of catching and logging
silent = true ' suppress pop-up progress mesages
clientsend = true ' send email notification to end-users
just_backup = false ' only does the backup

'******************************************************************************
'* SECTION: Configuration
'******************************************************************************
' Churnometer
data_path = "C:\Users\lucas.rohde\Desktop\churn_export"    ' This is where you put this script and SQL files
url = "http://churnometer:asualwaysfresh@churnometer:3000/import"    ' This is where you want the data uploaded
logfilename = data_path & "\"    & "churn_export.log"    ' This is where you want the log file to save
curl_path = data_path ' This is where curl.exe is
' Database
dbusername = "myreadonlyuser"
dbpassword = "mypassword"
' MS Access specific
dbfile = ""    ' "M:\membership.mdb"' This is where your MSAccess database lives (leave blank for MSSQL)
dbprovider = "Microsoft.ACE.OLEDB.12.0"    '"Microsoft.Jet.OLEDB.4.0"
' MS SQL specific
dbserver = "TSUSQL2008"
dbname = "membership"
dbconnectionstring = "DRIVER=SQL Server;SERVER="    & dbserver & ";DATABASE="    & dbname & ";UID=sa;PWD="    & dbpassword & ";APP=churnometer_export;"
expected_backup_size = (5 * 1024 * 1024)

' freechange mail
fcmailserver = "mail.nuw.org.au"
fcmailto = "lrohde@nuw.org.au"
fcmailcc = ""
fcmailfrom = "churnometer@theservicesunion.com.au"

' client mail
clientmailserver = "mail.theservicesunion.com.au"
clientmailto = "Cary.Pollock@theservicesunion.com.au"
clientmailcc = ""
clientmailfrom = "churnometer@freechange.com.au"
	

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
		msg = msg & vbcrlf & "     Error: "    & errmsg & vbcrlf & "     Error No: "    & errno
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
	if not debugging then on error resume next
	read_file = ""

	set fs = file.OpenAsTextStream(1, false)
	if error_handler("           failed to open "    & file.name) then exit function  
	
	while not fs.AtEndOfStream 
		read_file = read_file + fs.ReadLine + vbcrlf
		if error_handler("           failed to read "    & file.name) then read_file = "": exit function  
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
	if not debugging then on error resume next
	set get_recordset = nothing ' so an error can be detected upon return
	
	set rs = CreateObject("ADODB.recordset")
	rs.CursorType = adOpenDynamic
	rs.open SQL, cnn
	if error_handler("           failed to execute query "    & vbcrlf & SQL) then exit function  
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
	if not debugging then on error resume next
	
	write_data = false

	' open file to write to
	set f = fso.createtextfile(filename, true)
	if error_handler("           failed to write data to "    & filename) then exit function  
	
	' output header to file
	header = ""
	for i = 0 to rs.fields.count-1
		if i <> 0 then header = header & chr(9)
		header = header & rs.fields(i).name
	next
	f.writeline header
	if error_handler("           failed to write data to "    & filename) then exit function  
	
	' output each row to file
	dim row
	while not rs.EOF
		row = ""
		' build text row from fields
		for i = 0 to rs.fields.count-1
			if i <> 0 then row = row & chr(9)
			'row = row & rs.fields(i).name & ":"
			On error resume next
			row = row & rs.fields(i).value
			if err.number <> 0 then 
				row = row & rs.fields(i).name & "#error"
			end if
			On error goto 0
		next
		' output row to file
		f.writeline row
		if error_handler("           failed to write data to "    & filename) then exit function  
	
		rs.movenext
	wend
	
	f.close
	write_data = true
end function


'******************************************************************************
'* FUNCTION: read_curl_log
'* Authors:  lrohde 22-10-2012
'* Purpose:  Reads curl log file
'* Inputs: 
'*  curl_log: path to curl's log files
'* Returns: 
'*  Success: text of file
'*  Failure: ""
'******************************************************************************
private function read_curl_log(curl_log)
	' Open curl's log file
	read_curl_log = ""
	if not debugging then on error resume next
	Set file = fso.OpenTextFile(curl_log, 1)
	if error_handler("           could not open curl's log "    & curl_log) then exit function  
	read_curl_log = file.ReadAll
	if error_handler("           could not read curl's log "    & curl_log) then exit function  
	file.Close
	on error goto 0
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
	if not debugging then on error resume next
	upload = false
	
	curl_log = path & "\curl.log"
	
	' Call CURL from the command line
	' NB --insecure allows for the certificate to be self signed with an odd name
	' But data will still be encrypted
	Set WshShell = WScript.CreateObject("WScript.Shell")
	WshShell.Run "cmd /c "    & curl_path & "\curl.exe --insecure -X POST --form myfile=@"""    & path & "\"    & filename & """    --form scripted=true "    & url & "    > "    & curl_log & "    2>&1", 0, true
	if error_handler("           failed to execute curl to upload "    & filename) then exit function  
		
	' Open curl's log file
	text = read_curl_log(curl_log)
	
	' Check the log for success/failure
	if instr(text, "was successfully uploaded") > 0 then 
		if not silent then msgbox filename & "    was successfully uploaded"
		logfile.writeline "           Successfully uploaded "    & data_filename
		upload = true
	else
		if not silent then msgbox filename & "    failed to upload"    
		
		logfile.writeline "           Failed to upload "    & data_filename
		logfile.write text ' write curl's log to main log file
	end if
end function

'******************************************************************************
'* FUNCTION: backup
'* Authors:  lrohde 2-112012
'* backup of the software and database
'* Inputs: 
'*  url:  backup
'* Returns: 
'*  Success: true
'*  Failure: false, output from curl's log will be in main log file
'******************************************************************************
private function backup(url, path) ' if it fails, returns path to log file, if it succeeds returns ""
	if not debugging then on error resume next
	backup = false

	If fso.FileExists(path & "\backup_prev.zip") Then fso.DeleteFile path & "\backup_prev.zip"
	If fso.FileExists(path & "\backup.zip") Then fso.MoveFile path & "\backup.zip", path & "\backup_prev.zip"
	
	curl_log = path & "\curl.log"
	
	' Call CURL from the command line
	' NB --insecure allows for the certificate to be self signed with an odd name
	' But data will still be encrypted
	Set WshShell = WScript.CreateObject("WScript.Shell")
	cmd = "cmd /c "    & curl_path & "\curl.exe -o backup.zip --insecure -X GET --form scripted=true "    & replace(url, "import", "backup_download") & "    > "    & curl_log & "    2>&1"
	
	if just_backup then logfile.writeline cmd
		
	WshShell.Run cmd, 0, true
	if error_handler("           failed to execute curl to download backup ") then exit function  
		
	' Open curl's log file
	text = read_curl_log(curl_log)
	
	' Check the backup file
	if fso.FileExists(path & "\backup.zip") then 
		set f = fso.getfile(path & "\backup.zip")
		if f.size > expected_backup_size then 
			backup = true
		else
			logfile.writeline "           backup file smaller than expected: " & (f.size \ 1024) & "kb"
		end if
	end if

	if backup = true then 
		if not silent then msgbox "successfully downloaded backup"
		logfile.writeline "           Successfully downloaded backup"

		If fso.FileExists(path & "\backup_prev.zip") Then fso.DeleteFile path & "\backup_prev.zip"
	else
		If fso.FileExists(path & "\backup_prev.zip") Then fso.MoveFile path & "\backup_prev.zip", path & "\backup.zip"
		if not silent then msgbox "failed to download backup"   
		
		logfile.writeline "           Failed to download backup"
		logfile.write text ' write curl's log to main log file
	end if
end function


'******************************************************************************
'* FUNCTION: import
'* Authors:  lrohde 20-09-2012
'* Purpose:  checks if churnometer is ready to import and if so, starts import
'* Inputs: 
'*  url:  full upload path 
'*  path: data directory containing curl's log
'* Returns: 
'*  Success: true
'*  Failure: false, output from curl's log will be in main log file
'******************************************************************************
private function import(url, path) ' if it fails, returns path to log file, if it succeeds returns ""
	if not debugging then on error resume next
	import = false
	
	curl_log = path & "\curl.log"
	
	' Call CURL from the command line
	' NB --insecure allows for the certificate to be self signed with an odd name
	' But data will still be encrypted
	Set WshShell = WScript.CreateObject("WScript.Shell")
	WshShell.Run "cmd /c "    & curl_path & "\curl.exe --insecure -X GET --form scripted=true "    & url & "    > "    & curl_log & "    2>&1", 0, true
	if error_handler("           failed to execute curl to upload "    & filename) then exit function  
		
	' Open curl's log file
	text = read_curl_log(curl_log)
	
	' Check the log for successful prior uploads
	if instr(text, "ready to import") > 0 then 
		if not silent then msgbox filename & "    data is staged and ready for import"
		logfile.writeline "    Data is staged and ready for import"
			
		WshShell.Run "cmd /c "    & curl_path & "\curl.exe --insecure -X POST --form action=import --form scripted=true --form import_date="""    & now() & """    "    & url & "    > "    & curl_log & "    2>&1", 0, true
		if error_handler("           failed to execute curl to start import") then exit function  
		
		text = read_curl_log(curl_log)
	
		if instr(text, "Successfully commenced import of staged data") > 0 then 
			logfile.writeline "           Successfully commenced import of staged data"			
				do
				logfile.writeline "           Importing..."
				Wscript.sleep 5000
 
				WshShell.Run "cmd /c "    & curl_path & "\curl.exe --insecure -X GET --form scripted=true "    & url & "    > "    & curl_log & "    2>&1", 0, true
				if error_handler("           failed to execute curl to check import status") then exit function  
				text = read_curl_log(curl_log)
				
			loop until instr(text, "Importing...") = 0 
			
			if instr(text, "Importer Progress: Import successfully finished") > 0 then 
				logfile.writeline "           Import Succeeded"
				Import = true
			end if
		end if
	end if
	
	if import = false then 
		if not silent then msgbox "Import failed" & text
		logfile.writeline "           Import failed "
		logfile.write text ' write curl's log to main log file
	end if	
end function
	
'******************************************************************************

'******************************************************************************
'* FUNCTION: empty_cache
'* Authors:  lrohde 20-09-2012
'* Purpose:  empties cached data because it'll be different after import
'* Inputs: 
'*  url:  full upload path 
'*  path: data directory containing curl's log
'* Returns: 
'*  Success: true
'*  Failure: false, output from curl's log will be in main log file
'******************************************************************************
private function empty_cache(url, path) ' if it fails, returns path to log file, if it succeeds returns ""
	if not debugging then on error resume next
	empty_cache = false
	
	curl_log = path & "\curl.log"
	
	Set WshShell = WScript.CreateObject("WScript.Shell")
	WshShell.Run "cmd /c "    & curl_path & "\curl.exe --insecure -X POST --form action=empty_cache --form scripted=true "    & url & "    > "    & curl_log & "    2>&1", 0, true
	if error_handler("           failed to execute curl to empty cache") then exit function  
		
	text = read_curl_log(curl_log)
	
	if instr(text, "Successfully emptied cache") > 0 then 
		logfile.writeline "           Successfully emptied cache"
		empty_cache = true
	end if

	if empty_cache = false then 
		if not silent then msgbox "Failed to empty cache " & text
		logfile.writeline "           Failed to empty cache"
		logfile.write text ' write curl's log to main log file
	end if	
end function
	
'******************************************************************************

	
'******************************************************************************
'* FUNCTION: wrap_up
'* Authors:  lrohde 20-09-2012
'* Purpose:  close objects and email log file
'* Inputs: None
'*  Result: True/False indicating import success or failure
'* Returns: None
'******************************************************************************
private sub wrap_up(result)
	logfile.close
	
	subject = "Churnometer Import Success"
	if result = false then subject = "CHURNOMETER IMPORT FAILURE!"
	
 
	' Read log from file
	Set logfile = fso.OpenTextFile(logfilename, 1)
	logtext = logfile.ReadAll
	logfile.Close
	
	' Send email with log as message body
	sendmail fcmailserver, fcmailfrom, fcmailto, fcmailcc, subject, logtext
	if clientsend then sendmail clientmailserver, clientmailfrom, clientmailto, clientmailcc, subject, logtext
	
	cnn.close
	set cnn = nothing
	set fso = nothing
	set folder = nothing
	set files = nothing	
end sub

'******************************************************************************
'* FUNCTION: sendmail
'* Authors:  lrohde 5-11-2012
'* Purpose:  send email, can't relay to different domains so refactored so we can send two emails (client and fc)
'* Inputs: None
'*  mailserver
'*  mailfrom
'*  mailto
'*  mailcc
'*  mailsubject
'*  mailbody
'* Returns: None
'******************************************************************************
private sub sendmail(mailserver, mailfrom, mailto, mailcc, mailsubject, mailbody)
	Set objMessage = CreateObject("CDO.Message")
	
	objMessage.Subject = mailsubject
	objMessage.From = mailfrom
	objMessage.To = mailto
	objMessage.CC = mailcc
	objMessage.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendusing")=2
	objMessage.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserver")=mailserver
	objMessage.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserverport")=25 
	objMessage.Configuration.Fields.Update
	objMessage.TextBody = mailbody
	objMessage.Send

	set objMessage = nothing
end sub

'******************************************************************************
'* SECTION: Program Main
'******************************************************************************

' Create log file
set fso = CreateObject("Scripting.FileSystemObject")
set logfile = fso.createtextfile(logfilename, true)
logfile.writeline "Starting Import "    & Now()

' Suppress errors so they can be handled and logged
if not debugging then on error resume next

' Connect to database
set cnn = CreateObject("ADODB.connection")

if dbfile & ""    = ""    then 
	' Connect to MSSQL
	cnn.open dbconnectionstring
else
	cnn.Provider = dbprovider
	'cnn.Properties("Jet OLEDB:Database Password") = dbpassword
	cnn.open dbfile, dbusername, dbpassword
end if	
if error_handler("failed to connect to the database "    & dbfile) then call wrap_up: Wscript.Quit

' Find files to enumerate (looking for files with .sql extensions)
set folder = fso.GetFolder(data_path)
set files = folder.files
if error_handler("Invalid data path: "    & data_path) then call wrap_up: Wscript.Quit


' Set up regular expression for matching file names that have .sql extentions
set r = new regexp
r.Pattern = ".+\.sql$"    ' matches anything ending in .sql
r.IgnoreCase = true

if not just_backup then 
	' Iterate through each file
	for each file in files
		if r.test(file.name) then 	
			logfile.writeline "    Processing "    & file.name
			' Read SQL from file
			SQL = read_file(file)
			if SQL <> ""    then 
				' Execute SQL against database
				set rs = get_recordset(cnn, SQL)
				if not rs is nothing then 
					logfile.writeline "           Executed query in "    & file.name
					data_filename = replace(file.name, ".sql", ".txt")
				
					' Write SQL result to text file
					write_result = write_data (rs, data_path & "\"    & data_filename)
					if write_result then 
						logfile.writeline "           Wrote data to "    & data_filename
						
						' upload text file to website
						upload_result = upload(url, data_path,  data_filename)
					end if ' successful data write
					
					rs.close
					set rs = nothing
				end if ' successful data load
			end if ' successful SQL file read
		else
			if debugging then logfile.writeline "    Skipping "    & file.name
		end if
	next

	' Check if server is ready for import, and if it is, start import
	result = import(url, data_path)
	if result then 
		result = empty_cache(url, data_path)
		if result then
			result=backup(url, data_path)
		end if 
	end if
else 
	result=backup(url, data_path)
end if


logfile.writeline "Import Finished "    & Now()

On Error Goto 0 ' raise errors normally now because logging won't work during wrap-up
call wrap_up(result)
if not silent then msgbox("Done")
