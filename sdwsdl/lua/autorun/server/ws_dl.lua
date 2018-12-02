-- Manage the server-side bit of the in-game workshop downloader

if ( game.SinglePlayer() ) then return; end

wsdl = {}
wsdl.__index = wsdl

-- Local download list
local WORKSHOP_DOWNLOAD_LIST = {}


-- Add to the workshop download list
function wsdl.AddWorkshopID( id )

	if ( !id || !tonumber( id ) ) then return; end

	id = tonumber( id )

	table.insert( WORKSHOP_DOWNLOAD_LIST, id )

end


-- Remove from the workshop download list
function wsdl.RemoveWorkshopID( id )

	if ( !id || !tonumber( id ) ) then return; end

	id = tonumber( id )

	for k, v in ipairs( WORKSHOP_DOWNLOAD_LIST ) do
	
		if ( v == id ) then
		
			table.remove( WORKSHOP_DOWNLOAD_LIST, k )
		
		end
	
	end

end


-- Hook into the server PlayerInitialSpawn function and send the workshop download list
local function wsPlayerInitialSpawn( ply )

	local recipientFilter = RecipientFilter()
	recipientFilter:AddPlayer( ply )

	for k, v in ipairs( WORKSHOP_DOWNLOAD_LIST ) do
	
		umsg.Start( "AddWorkshopDownloadList", recipientFilter )
			umsg.Long( v )
		umsg.End()
	
	end

	umsg.Start( "BeginWorkshopDownloadProcess", recipientFilter )
	umsg.End()

end
hook.Add( "PlayerInitialSpawn", "wsPlayerInitialSpawn", wsPlayerInitialSpawn )


-- Hook into the server Initialize function and add workshop downloads automatically
local function wsInitialize()

	-- Dedicated servers are different, manage the different server types
	if ( game.IsDedicated() ) then
	
		-- Create the sdwsdl folder
		if ( !file.IsDir( "sdwsdl", "DATA" ) ) then file.CreateDir( "sdwsdl" ); end
	
		-- Create the workshop data file
		if ( !file.Exists( "sdwsdl/ws.dat", "DATA" ) ) then file.Write( "sdwsdl/ws.dat", util.TableToJSON( { "XXXXXX", "XXXXXX" }, true ) ); end
	
		-- Load via the workshop data file
		if ( file.Exists( "sdwsdl/ws.dat", "DATA" ) ) then
		
			local wsData = util.JSONToTable( file.Read( "sdwsdl/ws.dat" ) )
			for k, v in ipairs( wsData ) do
			
				wsdl.AddWorkshopID( v )
			
			end
		
		end
	
		-- Use the old resource method for the resource data file
		-- This is for if you have content that needs to be mounted during load time
		if ( file.Exists( "sdwsdl/rs.dat", "DATA" ) ) then
		
			local rsData = util.JSONToTable( file.Read( "sdwsdl/rs.dat" ) )
			for k, v in ipairs( rsData ) do
			
				resource.AddWorkshop( tostring( v ) )
			
			end
		
		end
	
	else
	
		-- Engine Addons
		local engineAddons = engine.GetAddons()
		for i = 1, #engineAddons do
		
			if ( tobool( engineAddons[ i ].mounted ) ) then
			
				wsdl.AddWorkshopID( engineAddons[ i ].wsid )
			
			end
		
		end
	
	end

end
hook.Add( "Initialize", "wsInitialize", wsInitialize )
