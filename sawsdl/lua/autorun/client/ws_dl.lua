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
local function MountGMAFile( filePath, id )

	if ( !filePath || !id || !isstring( filePath ) || ( !isnumber( id ) && !tonumber( id ) ) ) then return false, nil; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	-- Perform the GMA mounting!
	local gmaMounted, gmaFiles = game.MountGMA( filePath )
	if ( gmaMounted && gmaMounted == true ) then
	
		PrintVerbose( "@MountGMAFile() mounted \"" .. id .. "\": \'" .. filePath .. "\'" )
		WORKSHOP_INSTALLED_LIST[ id ] = true
	
	else
	
		PrintVerbose( "@MountGMAFile() failed to mount \"" .. id .. "\": \'" .. filePath .. "\'" )
	
	end

	-- Maintain game.MountGMA returns
	return gmaMounted, gmaFiles

end


-- This function helps figure out if we already have an addon installed but not mounted
-- We also return true or false here
local function IsAddonInstalled( id )

	if ( !id || ( !isnumber( id ) && !tonumber( id ) ) ) then PrintVerbose( "@IsAddonInstalled() couldn't use Workshop ID: \"" .. id .. "\"" ); return false; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	-- Use the installed table as a quick shortcut to see what is already installed in the current session
	if ( WORKSHOP_INSTALLED_LIST[ id ] ) then
	
		PrintVerbose( "@IsAddonInstalled() found Workshop ID \"" .. id .. "\" is already installed" )
		return true
	
	end

	-- Use Engine Addons to figure things out and mount if necessary
	for k, info in ipairs( engine.GetAddons() ) do
	
		local addonWSID = tonumber( info.wsid )
		local addonFile = info.file
		local addonDownloaded = tobool( info.downloaded )
		local addonMounted = tobool( info.mounted )
		if ( id == addonWSID ) then
		
			if ( addonDownloaded && addonDownloaded == true ) then
			
				if ( addonMounted && addonMounted == true ) then
				
					PrintVerbose( "@IsAddonInstalled() found Workshop ID \"" .. addonWSID .. "\" is already downloaded & mounted" )
					WORKSHOP_INSTALLED_LIST[ id ] = true
					return true
				
				else
				
					local gmaMounted = MountGMAFile( addonFile, addonWSID )
					if ( gmaMounted && gmaMounted == true ) then
					
						PrintVerbose( "@IsAddonInstalled() found Workshop ID \"" .. addonWSID .. "\" is already downloaded & now mounted" )
					
					else
					
						PrintVerbose( "@IsAddonInstalled() found Workshop ID \"" .. addonWSID .. "\" is already downloaded, but failed to mount" )
					
					end
					return gmaMounted
				
				end
			
			end
		
		end
	
	end

	-- We return false for all else
	PrintVerbose( "@IsAddonInstalled() found Workshop ID \"" .. id .. "\" is not installed" )
	return false

end


-- Process the queue and stuff
local function ProcessWorkshopDownloadQueue()

	-- Double check and make sure the table has stuff in it
	if ( WORKSHOP_DOWNLOAD_LIST && #WORKSHOP_DOWNLOAD_LIST == 0 ) then PrintVerbose( "@ProcessWorkshopDownloadQueue() tried to process the queue but we have nothing left, aborting" ); return; end

	-- We shouldn't be processing the queue multiple times, ensure it never happens
	if ( WORKSHOP_IS_DOWNLOADING && WORKSHOP_IS_DOWNLOADING == true ) then PrintVerbose( "@ProcessWorkshopDownloadQueue() was called but the download queue is already being processed, aborting" ); return; end

	-- We are downloading now, do not let anything interrupt us and prevent future calls to this function from continuing
	PrintVerbose( "@ProcessWorkshopDownloadQueue() %WORKSHOP_IS_DOWNLOADING% = TRUE" )
	WORKSHOP_IS_DOWNLOADING = true

	-- Special function which loops insanely, but it works so who cares
	local function LoopWorkshopDownloadQueue()
	
		-- This statement checks to see if we have anything left in the download queue
		if ( WORKSHOP_DOWNLOAD_LIST && #WORKSHOP_DOWNLOAD_LIST > 0 ) then
		
			-- Store the queued workshop ID
			local queuedWSID = WORKSHOP_DOWNLOAD_LIST[ 1 ]
		
			-- Prints workshop ID being worked on
			PrintVerbose( "@LoopWorkshopDownloadQueue() processing: \"" .. queuedWSID .. "\"" )
		
			-- Get the file information via Steamworks and begin downloading
			local function SteamworksFileInfo( data )
			
				-- Create a progress notification
				notification.AddProgress( "SAWSDL_" .. data.id, Format( "Downloading '%s' ...", data.title ) )
			
				-- If the file ID is 0, we assume UGC
				if ( tonumber( data.fileid ) > 0 ) then
				
					-- Prints workshop ID being downloaded
					PrintVerbose( "@LoopWorkshopDownloadQueue() legacy downloading: \"" .. data.id .. "\"" )
				
					-- Legacy Steamworks
					local function SteamworksDownloadLegacy( name )
					
						-- Remove the first entry from the download queue
						table.remove( WORKSHOP_DOWNLOAD_LIST, 1 )
					
						-- Mount the GMA file
						local gmaMounted = MountGMAFile( name, data.id )
						if ( gmaMounted && gmaMounted == true ) then
						
							notification.AddLegacy( Format( "\'%s\' installed!", data.title ), NOTIFY_GENERIC, 5 )
							surface.PlaySound( "garrysmod/content_downloaded.wav" )
						
						else
						
							notification.AddLegacy( Format( "\'%s\' failed to install!", data.title ), NOTIFY_ERROR, 5 )
							surface.PlaySound( "buttons/button11.wav" )
						
						end
					
						-- Kill the progress notification
						notification.Kill( "SAWSDL_" .. data.id )
					
						-- Prints workshop ID download has finished
						PrintVerbose( "@LoopWorkshopDownloadQueue() finished legacy download: \"" .. data.id .. "\"" )
					
						-- Call the loop function to continue the cycle
						LoopWorkshopDownloadQueue()
					
					end
					steamworks.Download( data.fileid, true, SteamworksDownloadLegacy )
				
				else
				
					-- Prints workshop ID being downloaded
					PrintVerbose( "@LoopWorkshopDownloadQueue() UGC downloading: \"" .. data.id .. "\"" )
				
					-- UGC Steamworks
					local function SteamworksDownloadUGC( name, file )
					
						-- Remove the first entry from the download queue
						table.remove( WORKSHOP_DOWNLOAD_LIST, 1 )
					
						-- Mount the GMA file
						local gmaMounted = MountGMAFile( name, data.id )
						if ( gmaMounted && gmaMounted == true ) then
						
							notification.AddLegacy( Format( "\'%s\' installed!", data.title ), NOTIFY_GENERIC, 5 )
							surface.PlaySound( "garrysmod/content_downloaded.wav" )
						
						else
						
							notification.AddLegacy( Format( "\'%s\' failed to install!", data.title ), NOTIFY_ERROR, 5 )
							surface.PlaySound( "buttons/button11.wav" )
						
						end
					
						-- Kill the progress notification
						notification.Kill( "SAWSDL_" .. data.id )
					
						-- Prints workshop ID download has finished
						PrintVerbose( "@LoopWorkshopDownloadQueue() finished UGC download: \"" .. data.id .. "\"" )
					
						-- Call the loop function to continue the cycle
						LoopWorkshopDownloadQueue()
					
					end
					steamworks.DownloadUGC( data.id, SteamworksDownloadUGC )
				
				end
			
			end
			steamworks.FileInfo( queuedWSID, SteamworksFileInfo )
		
		else
		
			-- Cleans out the download queue by resetting it completely
			PrintVerbose( "@LoopWorkshopDownloadQueue() reset {WORKSHOP_DOWNLOAD_LIST}" )
			WORKSHOP_DOWNLOAD_LIST = {}
		
			-- Set the downloading variable to false so the ProcessWorkshopDownloadQueue() function can be reused later
			PrintVerbose( "@LoopWorkshopDownloadQueue() %WORKSHOP_IS_DOWNLOADING% = FALSE" )
			WORKSHOP_IS_DOWNLOADING = false
		
			PrintVerbose( "@LoopWorkshopDownloadQueue() is finished, SAWSDL is now idle" )
		
		end
	
	end
	LoopWorkshopDownloadQueue()

end


-- Add to the workshop download list
local function DownloadWorkshopID( id )

	if ( !id || ( !isnumber( id ) && !tonumber( id ) ) ) then PrintVerbose( "@DownloadWorkshopID() couldn't use Workshop ID: \"" .. id .. "\"" ); return; end
	if ( !isnumber( id ) ) then id = tonumber( id ); end

	-- Making sure the ID doesn't already exist in the download queue and doesn't correspond with an installed addon, add it to the download list
	if ( !table.HasValue( WORKSHOP_DOWNLOAD_LIST, id ) && !IsAddonInstalled( id ) ) then
	
		PrintVerbose( "@DownloadWorkshopID() adding Workshop ID to {WORKSHOP_DOWNLOAD_LIST}: \"" .. id .. "\"" )
		table.insert( WORKSHOP_DOWNLOAD_LIST, id )
	
		PrintVerbose( "@DownloadWorkshopID() {WORKSHOP_DOWNLOAD_LIST} listing:" )
		PrintVerbose( WORKSHOP_DOWNLOAD_LIST )
	
		-- If we aren't already downloading something, begin processing the queue
		if ( !WORKSHOP_IS_DOWNLOADING ) then
		
			PrintVerbose( "@DownloadWorkshopID() is calling @ProcessWorkshopDownloadQueue()" )
			ProcessWorkshopDownloadQueue()
		
		end
	
	end

end


-- UserMessage to sync the download list with the server
local function SyncWorkshopDownloadList( umsg )

	DownloadWorkshopID( tonumber( umsg:ReadString() ) )

end
usermessage.Hook( "SyncWorkshopDownloadList", SyncWorkshopDownloadList )
