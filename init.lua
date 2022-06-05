local READ_ONLY = "read%-only"
local STATIC  = "static"
local PRIVATE_FIGURE = "%_"
local MODIFICATION_IDENTIFIER = "_onMod"

local keywords = {
	READ_ONLY,
	STATIC
}

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			-- To prevent infinite loop on metatables...
			if orig_value == orig then continue end
			if orig_key == orig then continue end
			
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	
	return copy
end

local function removeKeywords(k)
	local str = k
	
	for _, keyW in ipairs(keywords) do
		str = str:gsub(keyW .. " ", "")
	end
	
	return str
end

local t = {}

function t.exposeBase(baseClass)
	local p = newproxy(true)
	local m = getmetatable(p)

	local readOnlyKeys = {}
	local staticKeys = {}
	
	-- constructor method is assumed to be static
	staticKeys.new = "new"
	
	-- It's important that baseClasses' keys are not overridden because they are used again in classInstance
	for k : string, v in pairs(baseClass) do
		local rawKey = removeKeywords(k)
		
		if k:find(READ_ONLY) then
			readOnlyKeys[rawKey] = k
		end

		if k:find(STATIC) then
			staticKeys[rawKey] = k
		end
	end
	
	function m:__index(k : string)
		assert(type(k) == "string", "Attempt to index class with non-string key")
		assert(staticKeys[k], "Attempt to access non-static field")

		return baseClass[staticKeys[k]]
	end

	function m:__newindex(k : string, v : any)
		assert(type(k) == "string", "Attempt to index class with non-string key")
		assert(staticKeys[k], "Attempt to access non-static field")
		assert(not readOnlyKeys[k], "Attempt to write to read-only field")

		baseClass[staticKeys[k]] = v
	end	
	
	return p
end

function t.classInstance(class)
	local p = newproxy(true)
	local m = getmetatable(p)
	
	local readOnlyKeys = {}
	local staticKeys = {}

	for k : string, v in pairs(class) do
		if k:find(READ_ONLY) then
			local rawKey = removeKeywords(k)
			
			class[rawKey] = class[k]
			
			class[k] = nil
			
			readOnlyKeys[rawKey] = true
		end
	end
	
	local classMeta = getmetatable(class)
	
	if classMeta then
		for k, v in pairs(classMeta) do
			local isStatic = false

			v = type(v) == "table" and deepcopy(v) or v

			if k:find(STATIC) then
				staticKeys[removeKeywords(k)] = k
			end

			if k:find(READ_ONLY) then
				local rawKey = removeKeywords(k)

				readOnlyKeys[rawKey] = true

				if staticKeys[rawKey] then continue end

				class[rawKey] = classMeta[k]
			end
		end
	end
	
	function m:__index(k : string)
		assert(type(k) == "string", "Attempt to index class with non-string key")
				
		if (k:find(PRIVATE_FIGURE) == 1) then
			return error("Attempt to index private field")
		end
		
		if k == "RawSet" then
			return function(self, k, v)
				class[k] = v
				
				print(k, "was raw set to", class[k])
			end
		end
		
		local statKey = staticKeys[k]
		
		assert((class[k] ~= nil) or (statKey ~= nil), k .. " is not a valid property")
		
		if statKey then
			return class[statKey]
		else
			return class[k]
		end
	end
	
	function m:__newindex(k : string, v : any)
		assert(type(k) == "string", "Attempt to index class with non-string key")

		if (k:find(PRIVATE_FIGURE) == 1) then
			return error("Attempt to index private field")
		end
		
		if readOnlyKeys[k] then
			return error("Attempt to write to read-only field")
		end
		
		local statKey = staticKeys[k]
		
		assert((class[k] ~= nil) or (statKey ~= nil), k .. " is not a valid property")
		
		local modFCallback = class[MODIFICATION_IDENTIFIER .. k]
		
		if modFCallback then
			modFCallback(class, v)
		end
		
		if statKey then
			if not classMeta then class[k] = v end
			
			classMeta[statKey] = v
		else
			class[k] = v
		end
	end
	
	return p
end

function t.getKeywordMap(baseClass)
	local map = {}
	
	for k : string, v in pairs(baseClass) do
		local rawKey = removeKeywords(k)

		map[rawKey] = k
	end
	
	return map
end

return t