-- Manage the server-side bit of the in-game workshop downloader

if ( game.SinglePlayer() ) then return; end

wsdl = {}
wsdl.__index = wsdl

-- Enables debug printing
local DEBUG_PRINT = false

-- Forbidden tags that should not use the in-game downloader
local WORKSHOP_FORBIDDEN_TAGS = {
	[ "gamemode" ] = true,
	[ "map" ] = true,
	[ "save" ] = true,
	[ "demo" ] = true,
	[ "dupe" ] = true
}

-- Local download list
local WORKSHOP_DOWNLOAD_LIST = {}

-- ConVar for using data files
local sawsdl_use_data_files = CreateConVar( "sawsdl_use_data_files", 0, FCVAR_ARCHIVE, "Use the addon's data files instead of the engine's current addon return. Does not work on dedicated servers!", 0, 1 )


-- Local function to print verbosely
local function PrintVerbose( msg )

	if ( !DEBUG_PRINT || !msg ) then return; end

	if ( istable( msg ) ) then
	
		PrintTable( msg )
	
	else
	
		print( "[SAWSDL] " .. msg )
	
	end

end


-- Determines if an addon has a forbidden tag, which forces the addon to be installed over legacy resource.AddWorkshop
-- This is only ever used in listen servers, do not worry about this function on dedicated servers
local function CheckForForbiddenTags( tags )

	if ( !tags || !istable( tags ) ) then PrintVerbose( "@CheckForForbiddenTags() received an argument that wasn't a table" ); return; end

	for k, v in ipairs( tags ) do
	
		if ( WORKSHOP_FORBIDDEN_TAGS[ string.lower( v ) ] ) then
		
			PrintVerbose( "@CheckForForbiddenTags() found a forbidden tag: '" .. v .. "'" )
			return true
		
		end
	
	end

	return false

end


-- Sync the ID over to the clients
local function SyncWorkshopDownloadList( id, ply )

	if ( !id || ( !isnumber( id ) && !tonumber( id ) ) ) then PrintVerbose( "Couldn't use Workshop ID: \"" .. id .. "\"" ); return; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	local recipientFilter = RecipientFilter()
	if ( IsValid( ply ) && ply:IsPlayer() ) then
	
		PrintVerbose( "Syncing \"" .. id .. "\" to player: '" .. ply:Nick() .. "'" )
		recipientFilter:AddPlayer( ply )
	
	else
	
		PrintVerbose( "Syncing \"" .. id .. "\" to all players" )
		recipientFilter:AddAllPlayers()
	
	end

	umsg.Start( "SyncWorkshopDownloadList", recipientFilter )
		umsg.Long( id )
	umsg.End()

end


-- Add to the workshop download list
function wsdl.AddWorkshopID( id, sync )

	if ( !id || ( !isnumber( id ) && !tonumber( id ) ) ) then PrintVerbose( "Couldn't use Workshop ID: \"" .. id .. "\"" ); return; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	if ( !table.HasValue( WORKSHOP_DOWNLOAD_LIST, id ) ) then
	
		PrintVerbose( "Adding Workshop ID to {WORKSHOP_DOWNLOAD_LIST}: \"" .. id .. "\"" )
		table.insert( WORKSHOP_DOWNLOAD_LIST, id )
	
		if ( sync && ( sync == true ) ) then
		
			SyncWorkshopDownloadList( id )
		
		end
	
	else
	
		PrintVerbose( "Tried adding Workshop ID to {WORKSHOP_DOWNLOAD_LIST} but it's already listed: \"" .. id .. "\"" )
	
	end

	-- For debug purposes
	PrintVerbose( "{WORKSHOP_DOWNLOAD_LIST} listing:" )
	PrintVerbose( WORKSHOP_DOWNLOAD_LIST )

end


-- Hook into the server PlayerInitialSpawn function and send the workshop download list
local function wsPlayerInitialSpawn( ply )

	if ( !ply:IsBot() ) then
	
		PrintVerbose( "Player '" .. ply:Nick() .. "' (" .. ply:SteamID() .. ") has initially spawned" )
		for k, v in ipairs( WORKSHOP_DOWNLOAD_LIST ) do
		
			SyncWorkshopDownloadList( v, ply )
		
		end
	
	end

end
hook.Add( "PlayerInitialSpawn", "wsPlayerInitialSpawn", wsPlayerInitialSpawn )


-- Hook into the server Initialize function and add workshop downloads automatically
local function wsInitialize()

	-- Initialize message
	print( "-= Simple Automatic Workshop Downloader (SAWSDL) =-\n-== SAWSDL was created by D4 the (Choco) Fox ==-" )

	-- Dedicated servers are different, manage the different server types
	if ( game.IsDedicated() || sawsdl_use_data_files:GetBool() ) then
	
		-- Create the sawsdl folder
		if ( !file.IsDir( "sawsdl", "DATA" ) ) then file.CreateDir( "sawsdl" ); end
	
		-- Load via the workshop data file
		if ( file.Exists( "sawsdl/ws.dat", "DATA" ) ) then
		
			local wsData = util.JSONToTable( file.Read( "sawsdl/ws.dat" ) )
			for k, v in ipairs( wsData ) do
			
				wsdl.AddWorkshopID( v )
			
			end
		
		end
	
		-- Use the old resource method for the resource data file
		-- This is for if you have content that needs to be mounted during load time
		if ( file.Exists( "sawsdl/rs.dat", "DATA" ) ) then
		
			local rsData = util.JSONToTable( file.Read( "sawsdl/rs.dat" ) )
			for k, v in ipairs( rsData ) do
			
				PrintVerbose( "Adding Workshop ID to {LEGACY}: \"" .. v .. "\"" )
				resource.AddWorkshop( tostring( v ) )
			
			end
		
		end
	
	else
	
		-- Listen server uses Engine Addons to get the download list
		for k, info in ipairs( engine.GetAddons() ) do
		
			local addonTitle = info.title
			local addonWSID = tonumber( info.wsid )
			local addonTags = string.Explode( ",", info.tags )
			local addonModels = tonumber( info.models )
			local addonMounted = tobool( info.mounted )
			if ( addonMounted && ( addonMounted == true ) ) then
			
				PrintVerbose( "Found '" .. addonTitle .. "' as mounted: \"" .. addonWSID .. "\"" )
				if ( ( addonModels > 0 ) && !CheckForForbiddenTags( addonTags ) ) then
				
					wsdl.AddWorkshopID( addonWSID )
				
				else
				
					PrintVerbose( "Adding Workshop ID to {LEGACY}: \"" .. addonWSID .. "\"" )
					resource.AddWorkshop( addonWSID )
				
				end
			
			end
		
		end
	
	end

end
hook.Add( "Initialize", "wsInitialize", wsInitialize )
