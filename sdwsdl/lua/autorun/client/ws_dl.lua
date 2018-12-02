-- Manage the client-side bit of the in-game workshop downloader

if ( game.SinglePlayer() ) then return; end

wsdl = {}
wsdl.__index = wsdl

-- Local variable to control whether downloading is forced or not
local FORCE_WORKSHOP_DOWNLOADS = false

-- Local download list
local WORKSHOP_DOWNLOAD_LIST = {}


-- Add to the workshop download list
function wsdl.Download( wsid, lindex )

	-- Variable to be used by FileInfo
	local selectedID = 0

	-- Determine what to use
	if ( wsid && tonumber( wsid ) ) then
	
		selectedID = tonumber( wsid )
	
	elseif ( lindex && isnumber( lindex ) ) then
	
		selectedID = WORKSHOP_DOWNLOAD_LIST[ lindex ]
	
	else
	
		print( "Invalid download arguments!" )
	
	end

	-- Grab the file data
	steamworks.FileInfo( selectedID, function( data )
	
		-- Creates a progress notification
		notification.AddProgress( "WSDownload_"..selectedID, "Downloading \""..data.title.."\"" )
	
		-- Begin downloading the content
		steamworks.Download( data.fileid, true, function( file )
		
			-- Kills the progress notification
			notification.Kill( "WSDownload_"..selectedID )
		
			-- Mount the GMA
			local mounted = game.MountGMA( file )
			if ( mounted ) then
			
				print( "[SDWSDL] Mounted: "..file )
			
			end
		
			-- Loop until the end of the download list
			if ( lindex && isnumber( lindex ) && ( lindex < #WORKSHOP_DOWNLOAD_LIST ) ) then
			
				wsdl.Download( nil, lindex + 1 )
			
			end
		
		end )
	
	end )

end


-- UserMessage to add to the download list
local function AddWorkshopDownloadList( umsg )

	table.insert( WORKSHOP_DOWNLOAD_LIST, umsg:ReadLong() )

end
usermessage.Hook( "AddWorkshopDownloadList", AddWorkshopDownloadList )


-- UserMessage to begin the workshop download process
local function BeginWorkshopDownloadProcess( umsg )

	-- Use Engine Addons to filter out workshop downloads we don't need to do
	local engineAddons = engine.GetAddons()
	for i = 1, #engineAddons do
	
		if ( table.HasValue( WORKSHOP_DOWNLOAD_LIST, tonumber( engineAddons[ i ].wsid ) ) ) then
		
			if ( tobool( engineAddons[ i ].downloaded ) ) then
			
				if ( !tobool( engineAddons[ i ].mounted ) ) then
				
					local mounted = game.MountGMA( engineAddons[ i ].file )
					if ( mounted ) then
					
						print( "[SDWSDL] Mounted: "..engineAddons[ i ].file )
					
					end
				
				end
			
				table.RemoveByValue( WORKSHOP_DOWNLOAD_LIST, tonumber( engineAddons[ i ].wsid ) )
			
			end
		
		end
	
	end

	-- Need to do the cool stuff if this is non-zero
	if ( #WORKSHOP_DOWNLOAD_LIST > 0 ) then
	
		if ( !FORCE_WORKSHOP_DOWNLOADS ) then
		
			-- Build the message
			local message = "This server uses Workshop content to complete your gaming experience.\nWe've detected that your client doesn't have all the necessary Workshop addons for this server."
			message = message.."\n\nPress \"OK\" to begin downloading the Workshop content!\nYou may also continue without downloading anything by pressing \"Cancel\"."
		
			-- Creates a Derma Query
			Derma_Query( message, "Workshop", "OK", function() wsdl.Download( nil, 1 ) end, "Cancel" )
		
		else
		
			wsdl.Download( nil, 1 )
		
		end
	
	end

end
usermessage.Hook( "BeginWorkshopDownloadProcess", BeginWorkshopDownloadProcess )
