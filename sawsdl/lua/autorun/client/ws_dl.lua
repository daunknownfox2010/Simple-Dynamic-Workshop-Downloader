-- Manage the client-side bit of the in-game workshop downloader

if ( game.SinglePlayer() ) then return; end

-- Enables debug printing
local DEBUG_PRINT = false

-- Local download list
local WORKSHOP_DOWNLOAD_LIST = {}

-- Installed IDs
local WORKSHOP_INSTALLED_LIST = {}

-- Lets us know we are still downloading something
local WORKSHOP_IS_DOWNLOADING = false


-- Local function to print verbosely
local function PrintVerbose( msg )

	if ( !DEBUG_PRINT || !msg ) then return; end

	if ( istable( msg ) ) then
	
		PrintTable( msg )
	
	else
	
		print( "[SAWSDL] " .. msg )
	
	end

end


-- Local function to do the GMA mounting, cause we may as well save a few lines
-- The Workshop ID is enforced cause we need the ID for WORKSHOP_INSTALLED_LIST
local function MountGMAFile( filep, id )

	if ( !filep || !id || !isstring( filep ) || ( !isnumber( id ) && !tonumber( id ) ) || !file.Exists( filep, "GAME" ) ) then return false, nil; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	-- Perform the GMA mounting!
	local gmaMounted, gmaFiles = game.MountGMA( filep )
	if ( gmaMounted && ( gmaMounted == true ) ) then
	
		PrintVerbose( "Mounted (\"" .. id .. "\"): '" .. filep .. "'" )
		WORKSHOP_INSTALLED_LIST[ id ] = true
	
	else
	
		PrintVerbose( "Mount Failed (\"" .. id .. "\"): '" .. filep .. "'" )
	
	end

	-- Maintain game.MountGMA returns
	return gmaMounted, gmaFiles

end


-- This function helps figure out if we already have an addon installed but not mounted
-- We also return true or false here
local function IsAddonInstalled( id )

	if ( !id || ( !isnumber( id ) && !tonumber( id ) ) ) then PrintVerbose( "Couldn't use Workshop ID: \"" .. id .. "\"" ); return; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	-- Use the given table to figure things out
	if ( table.HasValue( WORKSHOP_INSTALLED_LIST, id ) ) then
	
		PrintVerbose( "Workshop ID \"" .. id .. "\" is already installed" )
		return true
	
	end

	-- Use Engine Addons to figure things out and mount if necessary
	for k, info in ipairs( engine.GetAddons() ) do
	
		local addonWSID = tonumber( info.wsid )
		local addonFile = info.file
		local addonDownloaded = tobool( info.downloaded )
		local addonMounted = tobool( info.mounted )
		if ( id == addonWSID ) then
		
			if ( addonDownloaded && ( addonDownloaded == true ) ) then
			
				if ( addonMounted && ( addonMounted == true ) ) then
				
					PrintVerbose( "Workshop ID \"" .. id .. "\" is already installed" )
					WORKSHOP_INSTALLED_LIST[ id ] = true
					return true
				
				else
				
					local gmaMounted = MountGMAFile( addonFile, addonWSID )
					if ( gmaMounted && ( gmaMounted == true ) ) then
					
						PrintVerbose( "Workshop ID \"" .. addonWSID .. "\" is already installed" )
					
					else
					
						PrintVerbose( "Workshop ID \"" .. addonWSID .. "\" is not installed" )
					
					end
					return gmaMounted
				
				end
			
			end
		
		end
	
	end

	-- We return false for all else
	PrintVerbose( "Workshop ID \"" .. id .. "\" is not installed" )
	return false

end


-- Process the queue and stuff
local function ProcessWorkshopDownloadQueue( id, ignoreDownloadingCheck )

	-- We can optionally include a Workshop ID with this function which will add the ID to the queue
	if ( id && ( isnumber( id ) || ( !isnumber( id ) && tonumber( id ) ) ) ) then
	
		if ( !isnumber( id ) ) then id = tonumber( id ); end
	
		if ( !table.HasValue( WORKSHOP_DOWNLOAD_LIST, id ) && !WORKSHOP_INSTALLED_LIST[ id ] ) then
		
			PrintVerbose( "Adding Workshop ID to {WORKSHOP_DOWNLOAD_LIST}: \"" .. id .. "\"" )
			table.insert( WORKSHOP_DOWNLOAD_LIST, id )
		
			PrintVerbose( "{WORKSHOP_DOWNLOAD_LIST} listing:" )
			PrintVerbose( WORKSHOP_DOWNLOAD_LIST )
		
		end
	
	end

	-- Double check and make sure the table has stuff in it
	if ( WORKSHOP_DOWNLOAD_LIST && ( #WORKSHOP_DOWNLOAD_LIST == 0 ) ) then PrintVerbose( "@ProcessWorkshopDownloadQueue() tried to process the queue but we have nothing left, aborting" ); return; end

	-- We shouldn't be processing the queue multiple times, ensure it never happens
	if ( WORKSHOP_IS_DOWNLOADING && ( WORKSHOP_IS_DOWNLOADING == true ) ) then PrintVerbose( "@ProcessWorkshopDownloadQueue() is already processing the queue, aborting" ); return; end

	-- We are downloading now, do not let anything interrupt us and prevent future calls to this function from continuing
	PrintVerbose( "%WORKSHOP_IS_DOWNLOADING% set: TRUE" )
	WORKSHOP_IS_DOWNLOADING = true

	-- Get the Workshop ID that is first in the queue
	local queuedWSID = WORKSHOP_DOWNLOAD_LIST[ 1 ]

	-- Create progress notification
	notification.AddProgress( "SAWSDL", "#GameUI_VerifyingAndDownloading" )

	-- This function handles the moving to the next entry in the queue
	local function MoveToNextInQueue()
	
		table.remove( WORKSHOP_DOWNLOAD_LIST, 1 )
	
		-- We are no longer downloading anything
		PrintVerbose( "%WORKSHOP_IS_DOWNLOADING% set: FALSE" )
		WORKSHOP_IS_DOWNLOADING = false
	
		if ( WORKSHOP_DOWNLOAD_LIST && ( #WORKSHOP_DOWNLOAD_LIST > 0 ) ) then
		
			ProcessWorkshopDownloadQueue()
		
		else
		
			-- Kill progress notification
			notification.Kill( "SAWSDL" )
		
			-- Clean up the download list table
			PrintVerbose( "Cleaning up {WORKSHOP_DOWNLOAD_LIST}" )
			WORKSHOP_DOWNLOAD_LIST = {}
		
		end
	
	end

	-- Handle the workshop downloads
	if ( IsAddonInstalled( queuedWSID ) ) then
	
		MoveToNextInQueue()
	
	else
	
		PrintVerbose( "Downloading Workshop ID: \"" .. queuedWSID .. "\"" )
		steamworks.DownloadUGC( queuedWSID, function( file ) MountGMAFile( file, queuedWSID ); PrintVerbose( "Finished Workshop ID: \"" .. queuedWSID .. "\"" ); MoveToNextInQueue(); end )
	
	end

end


-- Add to the workshop download list
local function DownloadWorkshopID( id )

	if ( !id || ( !isnumber( id ) && !tonumber( id ) ) ) then PrintVerbose( "Couldn't use Workshop ID: \"" .. id .. "\"" ); return; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	ProcessWorkshopDownloadQueue( id )

end


-- UserMessage to sync the download list with the server
local function SyncWorkshopDownloadList( umsg )

	DownloadWorkshopID( umsg:ReadLong() )

end
usermessage.Hook( "SyncWorkshopDownloadList", SyncWorkshopDownloadList )
