--- Single entry point. ox_lib's require (set up by @ox_lib/init.lua) pulls in
--- the rest of the modules on demand.
if not lib then
    return print('^1[lk_inv] ox_lib is required but not started^0')
end

if IsDuplicityVersion() then
    require 'server.main'
else
    require 'client.main'
    require 'client.nui'
    require 'client.sync'
    require 'client.drops'
    require 'client.stashes'
    require 'client.shops'
    require 'client.vehicles'
    require 'client.crafting'
end
