local class = require(script.Parent)

local kwMap;

local baseClass = {}
baseClass.__index = baseClass

baseClass.Name = "Bob"
baseClass["read-only Role"] = "Smith"
baseClass["static read-only Amount"] = 1
baseClass.Health = 100
baseClass._lastHealth = 100

function baseClass.new()
	return class.classInstance(setmetatable({}, baseClass))
end

function baseClass:_onModHealth(val)
	warn("Health was modified to : " .. tostring(val))
	
	self._lastHealth = self.Health
end

kwMap = class.getKeywordMap(baseClass)

local eBaseClass = class.exposeBase(baseClass)

local newBob = eBaseClass.new()

print(newBob.Name)
print(eBaseClass.Amount)
print(newBob.Amount)

baseClass[kwMap.Amount] += 1
eBaseClass.Amount += 1
newBob.Amount += 1

print(eBaseClass.Amount)
print(newBob.Amount)