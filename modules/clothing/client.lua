if not lib then return end

local savedClothing = {}

local function playClothingAnim(dict, name, duration)
	lib.requestAnimDict(dict)
	TaskPlayAnim(cache.ped, dict, name, 8.0, 3.0, duration, 49, 0, false, false, false)
	RemoveAnimDict(dict)
	Wait(duration)
	ClearPedTasks(cache.ped)
end

local function togglePedProp(propId, typeName, animDict, animName, animDuration)
	local ped = cache.ped
	if savedClothing[typeName] then
		playClothingAnim(animDict, animName, animDuration)
		SetPedPropIndex(ped, propId, savedClothing[typeName].drawable, savedClothing[typeName].texture, true)
		savedClothing[typeName] = nil
	else
		local drawable = GetPedPropIndex(ped, propId)
		local texture = GetPedPropTextureIndex(ped, propId)
		if drawable ~= -1 then
			savedClothing[typeName] = { drawable = drawable, texture = texture }
			playClothingAnim(animDict, animName, animDuration)
			ClearPedProp(ped, propId)
		end
	end
end

local function togglePedComponent(componentId, typeName, nakedDrawable, nakedTexture, animDict, animName, animDuration)
	local ped = cache.ped
	if savedClothing[typeName] then
		playClothingAnim(animDict, animName, animDuration)
		SetPedComponentVariation(ped, componentId, savedClothing[typeName].drawable, savedClothing[typeName].texture, savedClothing[typeName].palette)
		savedClothing[typeName] = nil
	else
		local drawable = GetPedDrawableVariation(ped, componentId)
		local texture = GetPedTextureVariation(ped, componentId)
		local palette = GetPedPaletteVariation(ped, componentId)
		if drawable ~= nakedDrawable then
			savedClothing[typeName] = { drawable = drawable, texture = texture, palette = palette }
			playClothingAnim(animDict, animName, animDuration)
			SetPedComponentVariation(ped, componentId, nakedDrawable, nakedTexture, 0)
		end
	end
end

local function toggleTorso()
	local ped = cache.ped
	if savedClothing.torso then
		playClothingAnim('clothingtie', 'try_tie_neutral_a', 1200)
		SetPedComponentVariation(ped, 11, savedClothing.torso.topDrawable, savedClothing.torso.topTexture, savedClothing.torso.topPalette)
		SetPedComponentVariation(ped, 8, savedClothing.torso.underDrawable, savedClothing.torso.underTexture, savedClothing.torso.underPalette)
		SetPedComponentVariation(ped, 3, savedClothing.torso.armsDrawable, savedClothing.torso.armsTexture, savedClothing.torso.armsPalette)
		savedClothing.torso = nil
	else
		local topDrawable = GetPedDrawableVariation(ped, 11)
		local topTexture = GetPedTextureVariation(ped, 11)
		local topPalette = GetPedPaletteVariation(ped, 11)
		local underDrawable = GetPedDrawableVariation(ped, 8)
		local underTexture = GetPedTextureVariation(ped, 8)
		local underPalette = GetPedPaletteVariation(ped, 8)
		local armsDrawable = GetPedDrawableVariation(ped, 3)
		local armsTexture = GetPedTextureVariation(ped, 3)
		local armsPalette = GetPedPaletteVariation(ped, 3)
		if topDrawable ~= 15 then
			savedClothing.torso = {
				topDrawable = topDrawable, topTexture = topTexture, topPalette = topPalette,
				underDrawable = underDrawable, underTexture = underTexture, underPalette = underPalette,
				armsDrawable = armsDrawable, armsTexture = armsTexture, armsPalette = armsPalette
			}
			playClothingAnim('clothingtie', 'try_tie_neutral_a', 1200)
			SetPedComponentVariation(ped, 11, 15, 0, 0)
			SetPedComponentVariation(ped, 8, 15, 0, 0)
			SetPedComponentVariation(ped, 3, 15, 0, 0)
		end
	end
end

local function togglePedClothing(type)
	local ped = cache.ped
	local isMale = GetEntityModel(ped) == `mp_m_freemode_01`
	if type == 'hat' then
		togglePedProp(0, 'hat', 'mp_masks@on_foot', 'put_on_mask', 800)
	elseif type == 'glasses' then
		togglePedProp(1, 'glasses', 'mp_masks@on_foot', 'put_on_mask', 800)
	elseif type == 'ear' then
		togglePedProp(2, 'ear', 'mp_masks@on_foot', 'put_on_mask', 800)
	elseif type == 'watch' then
		togglePedProp(6, 'watch', 'nns_clothes@wrist', 'wrist_look', 800)
	elseif type == 'bracelets' then
		togglePedProp(7, 'bracelets', 'nns_clothes@wrist', 'wrist_look', 800)
	elseif type == 'mask' then
		togglePedComponent(1, 'mask', 0, 0, 'mp_masks@on_foot', 'put_on_mask', 800)
	elseif type == 'neck' then
		togglePedComponent(7, 'neck', 0, 0, 'clothingtie', 'try_tie_neutral_a', 1200)
	elseif type == 'vest' then
		togglePedComponent(9, 'vest', 0, 0, 'clothingtie', 'try_tie_neutral_a', 1200)
	elseif type == 'bag' then
		togglePedComponent(5, 'bag', 0, 0, 'clothingtie', 'try_tie_neutral_a', 1200)
	elseif type == 'pants' then
		local nakedPants = isMale and 21 or 15
		togglePedComponent(4, 'pants', nakedPants, 0, 'clothingtrousers', 'try_trousers_neutral_c', 1200)
	elseif type == 'shoes' then
		local nakedShoes = isMale and 34 or 35
		togglePedComponent(6, 'shoes', nakedShoes, 0, 'clothingtrousers', 'try_trousers_neutral_c', 1200)
	elseif type == 'torso' then
		toggleTorso()
	end
end

RegisterNUICallback('toggleClothing', function(data, cb)
	togglePedClothing(data.type)
	cb(1)
end)
