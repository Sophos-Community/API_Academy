# Send Email using Gmail and app password
# Please note that you have to prepare your Gmail account accordingly. 
# To be able to sent emails you namely have to activate MFA within your Gmail account and 
# once this has been done create an application password, for more details see: 
# https://support.google.com/accounts/answer/185833?hl=en.  

$SmtpSrvr = "smtp.gmail.com"
$SmtpPort = 587
$SmtpUser = "your@gmail.com"
$SmtpRcpt = "recipient@company.com"
$SmtpPass = "apppassword"

# Create MailMessage because it allows HTML content
$Message = New-Object System.Net.Mail.MailMessage
$Message.From = $SmtpUser
$Message.To.Add($SmtpRcpt)
$Message.Subject = "Automated Email"
$Message.IsBodyHtml = $false # set to true if you want to send an HTML based email
$Message.Body = "This is your content"

# Create the SmtpClient object and send the Email
$Smtp = New-Object Net.Mail.SmtpClient($SmtpSrvr, $SmtpPort)
$Smtp.EnableSsl = $true
if ($SmtpPass -ne "") {
    $Smtp.Credentials = New-Object System.Net.NetworkCredential( $SmtpUser, $SmtpPass );
}
$Smtp.Send($Message)
