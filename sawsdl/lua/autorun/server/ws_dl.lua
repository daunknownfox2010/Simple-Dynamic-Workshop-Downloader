-- Manage the server-side bit of the in-game workshop downloader

if ( game.SinglePlayer() ) then return; end

wsdl = {}
wsdl.__index = wsdl

-- Local download list
local WORKSHOP_DOWNLOAD_LIST = {}


-- Sync the ID over to the clients
local function SyncWorkshopDownloadList( id, ply )

	if ( !id || !tonumber( id ) ) then print( "[SAWSDL] Couldn't use Workshop ID: "..id ) return; end
	id = tonumber( id )

	local recipientFilter = RecipientFilter()
	if ( IsValid( ply ) && ply:IsPlayer() ) then
	
		print( "[SAWSDL] Syncing "..id.." to player: "..ply:Nick() )
		recipientFilter:AddPlayer( ply )
	
	else
	
		print( "[SAWSDL] Syncing "..id.." to all players" )
		recipientFilter:AddAllPlayers()
	
	end

	umsg.Start( "SyncWorkshopDownloadList", recipientFilter )
		umsg.Long( id )
	umsg.End()

end


-- Add to the workshop download list
function wsdl.AddWorkshopID( id, sync )

	if ( !id || !tonumber( id ) ) then print( "[SAWSDL] Couldn't use Workshop ID: "..id ) return; end
	id = tonumber( id )

	if ( !table.HasValue( WORKSHOP_DOWNLOAD_LIST, id ) ) then
	
		table.insert( WORKSHOP_DOWNLOAD_LIST, id )
	
		if ( sync && ( sync == true ) ) then
		
			SyncWorkshopDownloadList( id )
		
		end
	
	end

end


-- Hook into the server PlayerInitialSpawn function and send the workshop download list
local function wsPlayerInitialSpawn( ply )

	if ( !ply:IsBot() ) then
	
		for k, v in ipairs( WORKSHOP_DOWNLOAD_LIST ) do
		
			SyncWorkshopDownloadList( v, ply )
		
		end
	
	end

end
hook.Add( "PlayerInitialSpawn", "wsPlayerInitialSpawn", wsPlayerInitialSpawn )


-- Hook into the server Initialize function and add workshop downloads automatically
local function wsInitialize()

	-- Initialize message
	print( "-= Simple Automatic Workshop Downloader (SAWSDL) =-\n-== SAWSDL was created by D4 the (Perth) Fox ==-" )

	-- Dedicated servers are different, manage the different server types
	if ( game.IsDedicated() ) then
	
		-- Create the sawsdl folder
		if ( !file.IsDir( "sawsdl", "DATA" ) ) then file.CreateDir( "sawsdl" ); end
	
		-- Create the workshop data file
		if ( !file.Exists( "sawsdl/ws.dat", "DATA" ) ) then file.Write( "sawsdl/ws.dat", util.TableToJSON( { "XXXXXX", "XXXXXX" }, true ) ); end
	
		-- Load via the workshop data file
		if ( file.Exists( "sawsdl/ws.dat", "DATA" ) ) then
		
			local wsData = util.JSONToTable( file.Read( "sawsdl/ws.dat" ) )
			for k, v in ipairs( wsData ) do
			
				print( "[SAWSDL] Adding ID: "..v )
				wsdl.AddWorkshopID( v )
			
			end
		
		end
	
		-- Use the old resource method for the resource data file
		-- This is for if you have content that needs to be mounted during load time
		if ( file.Exists( "sawsdl/rs.dat", "DATA" ) ) then
		
			local rsData = util.JSONToTable( file.Read( "sawsdl/rs.dat" ) )
			for k, v in ipairs( rsData ) do
			
				print( "[SAWSDL] Adding ID (Legacy): "..v )
				resource.AddWorkshop( tostring( v ) )
			
			end
		
		end
	
	else
	
		-- Listen server uses Engine Addons to get the download list
		for k, info in ipairs( engine.GetAddons() ) do
		
			if ( tobool( info.mounted ) ) then
			
				print( "[SAWSDL] Found \""..info.title.."\" as mounted, adding ID: "..info.wsid )
				wsdl.AddWorkshopID( info.wsid )
			
			end
		
		end
	
	end

end
hook.Add( "Initialize", "wsInitialize", wsInitialize )
