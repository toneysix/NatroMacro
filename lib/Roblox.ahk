#Requires AutoHotkey >=2.0- <2.1
/***********************************************************
* @description: Functions for automating the Roblox window
* @author SP
***********************************************************/

#Include "%A_InitialWorkingDir%\lib"
#Include JSON.ahk

global serverIds := []
global errorMessage := ""

; Updates global variables windowX, windowY, windowWidth, windowHeight
; Optionally takes a known window handle to skip GetRobloxHWND call
; Returns: 1 = successful; 0 = TargetError
GetRobloxClientPos(hwnd?)
{
    global windowX, windowY, windowWidth, windowHeight
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()

    try
        WinGetClientPos &windowX, &windowY, &windowWidth, &windowHeight, "ahk_id " hwnd
    catch TargetError
        return windowX := windowY := windowWidth := windowHeight := 0
    else
        return 1
}

; Returns: hWnd = successful; 0 = window not found
GetRobloxHWND()
{
	if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
		return hwnd
	else if (WinExist("Roblox ahk_exe ApplicationFrameHost.exe"))
    {
        try
            hwnd := ControlGetHwnd("ApplicationFrameInputSinkWindow1")
        catch TargetError
		    hwnd := 0
        return hwnd
    }
	else
		return 0
}

; Finds the y-offset of GUI elements in the current Roblox window
; Image is specific to BSS but can be altered for use in other games
; Optionally takes a known window handle to skip GetRobloxHWND call
; Returns: offset (integer), defaults to 0 on fail (ByRef param fail is then set to 1, else 0)
GetYOffset(hwnd?, &fail?)
{
	static hRoblox := 0, offset := 0
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()

	if (hwnd = hRoblox)
	{
		fail := 0
		return offset
	}
	else if WinExist("ahk_id " hwnd)
	{
		try WinActivate "Roblox"
		GetRobloxClientPos(hwnd)
		pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2 "|" windowY "|60|100")

		Loop 20 ; for red vignette effect
		{ 
			if ((Gdip_ImageSearch(pBMScreen, bitmaps["toppollen"], &pos, , , , , 20) = 1)
				&& (Gdip_ImageSearch(pBMScreen, bitmaps["toppollenfill"], , x := SubStr(pos, 1, (comma := InStr(pos, ",")) - 1), y := SubStr(pos, comma + 1), x + 41, y + 10, 20) = 0))
			{
				Gdip_DisposeImage(pBMScreen)
				hRoblox := hwnd, fail := 0
				return offset := y - 14
			}
			else
			{
				if (A_Index = 20)
				{
					Gdip_DisposeImage(pBMScreen), fail := 1
					return 0 ; default offset, change this if needed
				}
				else
				{
					Sleep 50
					Gdip_DisposeImage(pBMScreen)
					pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2 "|" windowY "|60|100")
				}				
			}
		}
	}
	else
		return 0
}

; Returns: 1 = successful; 0 = TargetError
ActivateRoblox()
{
	try
		WinActivate "Roblox"
	catch
		return 0
	else
		return 1
}

JoinServerById(id)
{
	try run '"roblox://placeId=1537690962&gameInstanceId=' id '"'	
}

JoinToPrivateServer(linkCode)
{
	try Run '"roblox://placeID=1537690962&linkCode=' linkCode '"'
}

Rejoin()
{
	try Run '"roblox://placeID=1537690962"'
}

JoinRandomServer() 
{
	GetServerIds()
    global serverIds

    if (serverIds.Length > 1)
	{
        global RandomServer := serverIds[Random(1, serverIds.Length)]
        JoinServerById(RandomServer)
		return
    } 

	Sleep 5000
}

GetServerIds() 
{
    try 
	{
        global serverIds := []
        cursor := ""

        loop 2
		{
            url := "https://games.roblox.com/v1/games/1537690962/servers/0?sortOrder=1&excludeFullGames=true&limit=100" (
                cursor ? "&cursor=" cursor : "")
            req := ComObject("WinHttp.WinHttpRequest.5.1")
            req.open("GET", url, true)
            req.send()
            req.WaitForResponse()

            response := JSON.parse(req.responsetext, true, false)

            cursor := response.nextPageCursor
            data := response.data
            for server in data 
                serverIds.push(server.id)
    	}
    } 
	catch Error 
	{
        ;response := JSON.parse(req.responsetext, true, false)
        ;global errorMessage := response
        return
    }
}