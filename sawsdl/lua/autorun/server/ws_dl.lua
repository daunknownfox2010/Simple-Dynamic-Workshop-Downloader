-- Manage the server-side bit of the in-game workshop downloader

if ( game.SinglePlayer() ) then return; end

wsdl = {}
wsdl.__index = wsdl

-- Enables debug printing
local DEBUG_PRINT = false

-- Legacy tags that should not use the in-game downloader
local WORKSHOP_LEGACY_TAGS = {
	[ "gamemode" ] = true,
	[ "map" ] = true
}

-- Forbidden tags that should not be downloaded
local WORKSHOP_FORBIDDEN_TAGS = {
	[ "save" ] = true,
	[ "demo" ] = true,
	[ "dupe" ] = true
}

-- Local download list
local WORKSHOP_DOWNLOAD_LIST = {}

-- ConVar for using data files
local sawsdl_use_data_files = CreateConVar( "sawsdl_use_data_files", 0, FCVAR_ARCHIVE, "Use the addon's data files instead of the engine's current addon return. Does nothing on dedicated servers!", 0, 1 )


-- Local function to print verbosely
local function PrintVerbose( msg )

	if ( !DEBUG_PRINT || !msg ) then return; end

	if ( istable( msg ) ) then
	
		PrintTable( msg )
	
	else
	
		print( "[SAWSDL] " .. msg )
	
	end

end


-- Checks the given tags and returns something based on what it finds
-- 0: tags met no criteria
-- 1: tags met legacy criteria
-- 2: tags met forbidden criteria
local function CheckAddonTags( tags )

	if ( !tags || !istable( tags ) ) then PrintVerbose( "@CheckAddonTags() failed, probably because it was given incorrect data" ); return; end

	for k, v in ipairs( tags ) do
	
		if ( WORKSHOP_FORBIDDEN_TAGS[ string.lower( v ) ] ) then
		
			PrintVerbose( "@CheckAddonTags() found a forbidden tag: \'" .. v .. "\'" )
			return 2
		
		end
	
	end

	for k, v in ipairs( tags ) do
	
		if ( WORKSHOP_LEGACY_TAGS[ string.lower( v ) ] ) then
		
			PrintVerbose( "@CheckAddonTags() found a legacy tag: \'" .. v .. "\'" )
			return 1
		
		end
	
	end

	return 0

end


-- Sync the ID over to the clients
local function SyncWorkshopDownloadList( id, ply )

	if ( !id || ( !isnumber( id ) && !tonumber( id ) ) ) then PrintVerbose( "@SyncWorkshopDownloadList() couldn't use Workshop ID: \"" .. id .. "\"" ); return; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	local recipientFilter = RecipientFilter()
	if ( IsValid( ply ) && ply:IsPlayer() ) then
	
		PrintVerbose( "@SyncWorkshopDownloadList() syncing \"" .. id .. "\" to player: \'" .. ply:Nick() .. "\'" )
		recipientFilter:AddPlayer( ply )
	
	else
	
		PrintVerbose( "@SyncWorkshopDownloadList() syncing \"" .. id .. "\" to all players" )
		recipientFilter:AddAllPlayers()
	
	end

	umsg.Start( "SyncWorkshopDownloadList", recipientFilter )
		umsg.String( tostring( id ) )
	umsg.End()

end


-- Add to the workshop download list
function wsdl.AddWorkshopID( id, sync )

	if ( !id || ( !isnumber( id ) && !tonumber( id ) ) ) then PrintVerbose( "@wsdl.AddWorkshopID() couldn't use Workshop ID: \"" .. id .. "\"" ); return; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	if ( !table.HasValue( WORKSHOP_DOWNLOAD_LIST, id ) ) then
	
		PrintVerbose( "@wsdl.AddWorkshopID() adding Workshop ID to {WORKSHOP_DOWNLOAD_LIST}: \"" .. id .. "\"" )
		table.insert( WORKSHOP_DOWNLOAD_LIST, id )
	
		if ( sync && sync == true ) then
		
			SyncWorkshopDownloadList( id )
		
		end
	
	else
	
		PrintVerbose( "@wsdl.AddWorkshopID() tried adding a Workshop ID to {WORKSHOP_DOWNLOAD_LIST} but it's already listed: \"" .. id .. "\"" )
	
	end

	-- Sorts the download list
	table.sort( WORKSHOP_DOWNLOAD_LIST )

	-- For debug purposes
	PrintVerbose( "@wsdl.AddWorkshopID() {WORKSHOP_DOWNLOAD_LIST} listing:" )
	PrintVerbose( WORKSHOP_DOWNLOAD_LIST )

end


-- Hook into the server PlayerInitialSpawn function and send the workshop download list
local function wsPlayerInitialSpawn( ply )

	if ( !ply:IsBot() ) then
	
		PrintVerbose( "@wsPlayerInitialSpawn() ... Player \'" .. ply:Nick() .. "\' (" .. ply:SteamID() .. ") has initially spawned" )
		for k, v in ipairs( WORKSHOP_DOWNLOAD_LIST ) do
		
			SyncWorkshopDownloadList( v, ply )
		
		end
	
	end

end
hook.Add( "PlayerInitialSpawn", "wsPlayerInitialSpawn", wsPlayerInitialSpawn )


-- Hook into the server Initialize function and add workshop downloads automatically
local function wsInitialize()

	-- Initialize message
	print( "-= Simple Automatic Workshop Downloader (SAWSDL) =-\n-== SAWSDL was created by \'Jai the (Choco) Fox\' ==-" )

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
			
				PrintVerbose( "@wsInitialize() adding Workshop ID to {LEGACY}: \"" .. v .. "\"" )
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
			if ( addonMounted && addonMounted == true ) then
			
				PrintVerbose( "@wsInitialize() found \'" .. addonTitle .. "\' mounted, checking ID: \"" .. addonWSID .. "\"" )
			
				local addonTagCriteria = CheckAddonTags( addonTags )
				if ( addonModels > 0 && addonTagCriteria <= 0 ) then
				
					wsdl.AddWorkshopID( addonWSID )
				
				elseif ( addonModels <= 0 || addonTagCriteria == 1 ) then
				
					PrintVerbose( "@wsInitialize() adding Workshop ID to {LEGACY}: \"" .. addonWSID .. "\"" )
					resource.AddWorkshop( addonWSID )
				
				else
				
					PrintVerbose( "@wsInitialize() skipped: \"" .. addonWSID .. "\"" )
				
				end
			
			end
		
		end
	
	end

end
hook.Add( "Initialize", "wsInitialize", wsInitialize )
