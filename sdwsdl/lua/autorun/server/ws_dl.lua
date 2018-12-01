-- Manage the server-side bit of the in-game workshop downloader

if ( game.SinglePlayer() ) then return; end

workshop_dl = {}
workshop_dl.__index = workshop_dl

-- Local download list
local WORKSHOP_DOWNLOAD_LIST = {}


-- Add to the workshop download list
function workshop_dl.AddWorkshopID( id )

	if ( !id || !tonumber( id ) ) then return; end

	id = tonumber( id )

	table.insert( WORKSHOP_DOWNLOAD_LIST, id )

end


-- Remove from the workshop download list
function workshop_dl.RemoveWorkshopID( id )

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

	local recipientFilter = RecipientFilter():AddPlayer( ply )

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
	
		-- Create the workshop data file
		if ( !file.Exists( "ws.dat", "DATA" ) ) then file.Write( "ws.dat", util.TableToJSON( { "XXXXXX", "XXXXXX" }, true ) ); end
	
		-- Load via the workshop data file
		if ( file.Exists( "ws.dat", "DATA" ) ) then
		
			local wsData = util.JSONToTable( file.Read( "ws.dat" ) )
			for k, v in ipairs( wsData ) do
			
				workshop_dl.AddWorkshopID( v )
			
			end
		
		end
	
	else
	
		-- Engine Addons
		local engineAddons = engine.GetAddons()
		for i = 1, #engineAddons do
		
			if ( engineAddons[ i ].mounted ) then
			
				workshop_dl.AddWorkshopID( engineAddons[ i ].wsid )
			
			end
		
		end
	
	end

end
hook.Add( "Initialize", "wsInitialize", wsInitialize )
