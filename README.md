# Simple Dynamic Workshop Downloader
"Simple Dynamic Workshop Downloader" is a Garry's Mod add-on that allows server hosters to automatically make players download the necessary workshop content.
Instead of relying on `resource.AddWorkshop`, the add-on uses the `steamworks` functions to download Workshop content on-the-fly.
This allows players to play the game while waiting for the content to finish downloading.
<br/><br/>
The add-on is also able to mount GMAs already installed via `engine.GetAddons`, saving time from having to re-download the GMA in cache.
The add-on works differently between listen and dedicated servers as well.
Listen servers will automatically make other players download Workshop addons the server host has mounted,
and Dedicated servers use a "ws.dat" file inside the "data" folder which is formatted in JSON.
## Installation
* Download via `git` or the ZIP.
* Place the "sdwsdl" folder inside "garrysmod/addons".
## Using "ws.dat"
Using "ws.dat" is very simple. It's formatted in the JSON format, you'll need a plain text editor to edit it.<br/>
* Launch the game and start a map to generate an example "ws.dat" file.
* Navigate to your Garry's Mod data folder and open the "ws.dat" file.
* Adjust the JSON layout to cater for the amount of Workshop contents you want to make players download (commas are important, and you don't need to include a comma for the final entry).
* Replace the **X**'s with the Workshop IDs (the IDs you use are what you use for `resource.AddWorkshop`).
