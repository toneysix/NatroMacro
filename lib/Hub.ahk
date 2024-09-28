#Requires AutoHotkey >=2.0- <2.1

#Include "%A_ScriptDir%\..\lib"
#Include JSON.ahk
#Include WebSocket.ahk

class SignalrClient
{
	wsClient:=0
	onMessage:=0

	__New(url, hubName, onMsg)
	{
		this.url := url
		this.fullUrl := "" url "/" hubName
		this.onMessage := onMsg
	}
	
	preconnect()
	{
		wr := ComObject("WinHttp.WinHttpRequest.5.1")
		wr.Open("POST", "http://" this.fullUrl "/negotiate", 1)
		wr.SetRequestHeader("accept", "application/vnd.github+json")
		wr.Send()
		wr.WaitForResponse()
	
		local response:=JSON.parse(wr.ResponseText)
		
		if !response or !response["connectionId"]
			throw ValueError("connect id cannot be obtained", -1, 0)
		
		this.fullUrl := this.fullUrl "/?id=" response["connectionId"]
		
		this.wsClient := WebSocket("ws://" this.fullUrl, {
			open: (s) => msg("opened"),
			message: (s, data) => this.processMessage(JSON.parse(StrSplit(data, chr(0x1E))[1])),
			close: (s, status, reason) => msg("closed")
		})
	}
	
	processMessage(message)
	{
		if message.Has("type") = 0
			return
		
		if message["type"] != 1
			return
			
		if message.Has("target") = 0
			return
			
		if message.Has("arguments") = 0
			return
		
		this.onMessage(message)
	}
	
	handshake()
	{
		local payLoad := Map(
			"protocol", "json",
			"version", 1,
		)
		
		this.wsClient.sendText(JSON.stringify(payLoad) chr(0x1E))
	}
	
	invoke(targetName, args*)
	{
		local payLoad := Map(
			"type", 1,
			"invocationId", "",
			"target", targetName,
			"arguments", args
		)		
		
		this.wsClient.sendText(JSON.stringify(payLoad) chr(0x1E))
	}
	
	connect()
	{
		this.preconnect()
		this.handshake()
	}
	
	disconnect()
	{
		this.wsClient.shutdown()
	}
}

class AltHubSerivce
{
	client:=0
	isAlt:=false
	onUse:=0

	__New(alt:=false, onUse:= (s, itemName, count) => 0)
	{
		this.isAlt := alt
		this.client := SignalrClient("192.168.0.194:5101", "alt", (s, message) => this.onMessage(message))
		this.onUse := onUse
	}
	
	onMessage(message)
	{
		switch message["target"], 0
		{
			case "Use":
			local itemName := message["arguments"][1]
			local count := message["arguments"].Length > 1 ? message["arguments"][2] : 1
			this.onUse(itemName, count)
		}
	}
	
	join()
	{
		this.client.connect()
		this.client.invoke("Join", this.isAlt)
	}
	
	leave()
	{
		this.client.disconnect()
	}
	
	useClouds(c:=3)
	{
		this.client.invoke("UseClouds", c)
	}
	
	useJellyBeans()
	{
		this.client.invoke("UseJellyBeans")
	}
}

