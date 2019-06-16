-- Manage the client-side bit of the in-game workshop downloader

if ( game.SinglePlayer() ) then return; end

-- Local download list
local WORKSHOP_DOWNLOAD_LIST = {}

-- Installed IDs
local WORKSHOP_INSTALLED_LIST = {}

-- Lets us know we are still downloading something
local WORKSHOP_IS_DOWNLOADING = false


-- This function helps figure out if we already have an addon installed but not mounted
-- We also return true or false here
local function IsAddonInstalled( id )

	if ( !id || !tonumber( id ) ) then print( "[SAWSDL] Couldn't use Workshop ID: "..id ) return; end
	id = tonumber( id )

	-- Use the given table to figure things out
	if ( table.HasValue( WORKSHOP_INSTALLED_LIST, id ) ) then
	
		return true
	
	end

	-- Use Engine Addons to figure things out and mount if necessary
	for k, info in ipairs( engine.GetAddons() ) do
	
		if ( id == tonumber( info.wsid ) ) then
		
			if ( tobool( info.downloaded ) ) then
			
				if ( !tobool( info.mounted ) ) then
				
					local mounted = game.MountGMA( info.file )
					if ( mounted ) then
					
						table.insert( WORKSHOP_INSTALLED_LIST, id )
					
						print( "[SAWSDL] Mounted: "..info.file )
						return true
					
					else
					
						print( "[SAWSDL] Mount Failed: "..info.file )
					
					end
				
				else
				
					table.insert( WORKSHOP_INSTALLED_LIST, id )
					return true
				
				end
			
			end
		
		end
	
	end

	return false

end


-- Process the queue and stuff
local function ProcessNextQueuedWorkshopID()

	-- Double check and make sure the table has stuff in it
	if ( WORKSHOP_DOWNLOAD_LIST && ( #WORKSHOP_DOWNLOAD_LIST == 0 ) ) then print( "[SAWSDL] ProcessNextQueuedWorkshopID tried to process the queue but we have nothing left" ) return; end

	-- We are downloading now
	WORKSHOP_IS_DOWNLOADING = true

	-- The queued ID
	local queuedWorkshopID = WORKSHOP_DOWNLOAD_LIST[ 1 ]

	-- Check if the addon is installed already
	if ( IsAddonInstalled( queuedWorkshopID ) ) then
	
		print( "[SAWSDL] ProcessNextQueuedWorkshopID found an already installed addon, skipping" )
	
		-- Remove ID from the queue and begin the next download if we can
		table.remove( WORKSHOP_DOWNLOAD_LIST, 1 )
		if ( WORKSHOP_DOWNLOAD_LIST && ( #WORKSHOP_DOWNLOAD_LIST > 0 ) ) then
		
			ProcessNextQueuedWorkshopID()
		
		else
		
			WORKSHOP_IS_DOWNLOADING = false
			WORKSHOP_DOWNLOAD_LIST = {}
		
		end
	
		return;
	
	end

	-- Grab the file data
	steamworks.FileInfo( queuedWorkshopID, function( data )
	
		-- Creates a progress notification
		notification.AddProgress( "SAWSDL", "Downloading \""..data.title.."\"" )
	
		-- Begin downloading the content
		steamworks.Download( data.fileid, true, function( file )
		
			-- Kills the progress notification
			notification.Kill( "SAWSDL" )
		
			-- Mount the GMA
			local mounted = game.MountGMA( file )
			if ( mounted ) then
			
				table.insert( WORKSHOP_INSTALLED_LIST, queuedWorkshopID )
			
				print( "[SAWSDL] Mounted: "..file )
			
			else
			
				print( "[SAWSDL] Mount Failed: "..file )
			
			end
		
			-- Remove ID from the queue and begin the next download if we can
			table.remove( WORKSHOP_DOWNLOAD_LIST, 1 )
			if ( WORKSHOP_DOWNLOAD_LIST && ( #WORKSHOP_DOWNLOAD_LIST > 0 ) ) then
			
				ProcessNextQueuedWorkshopID()
			
			else
			
				WORKSHOP_IS_DOWNLOADING = false
				WORKSHOP_DOWNLOAD_LIST = {}
			
			end
		
		end )
	
	end )

end


-- Add to the workshop download list
local function DownloadWorkshopID( id )

	if ( !id || !tonumber( id ) ) then print( "[SAWSDL] Couldn't use Workshop ID: "..id ) return; end
	id = tonumber( id )

	if ( !table.HasValue( WORKSHOP_DOWNLOAD_LIST, id ) ) then
	
		table.insert( WORKSHOP_DOWNLOAD_LIST, id )
	
		if ( !WORKSHOP_IS_DOWNLOADING ) then
		
			ProcessNextQueuedWorkshopID()
		
		end
	
	end

end


-- UserMessage to sync the download list with the server
local function SyncWorkshopDownloadList( umsg )

	DownloadWorkshopID( umsg:ReadLong() )

end
usermessage.Hook( "SyncWorkshopDownloadList", SyncWorkshopDownloadList )
