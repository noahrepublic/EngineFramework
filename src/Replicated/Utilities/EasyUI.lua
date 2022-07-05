-- @noahrepublic
-- @version 1.0
-- @date 07/02/22

--  Variables --

-- Public:

local EasyUI = {}
EasyUI.__index = EasyUI

local Components = {}
Components.__index = Components

-- Private:

local KnownProperties = {
   Size = true,
   Position = true,
   AnchorPosition = true,
   Visible = true,
    
}

-- Functions --
-- Private:

local function BuildComponent(component_type, name)
   local build = Instance.new(component_type)
   if not build then
      return nil
   end
   build.Name = name
   
end
-- Public:

function EasyUI.new(name) -- Called for new GUI component
   return setmetatable({
      _Children = {}, -- [component] = {components}
      _Build = nil,
      _Name = name
   },Components[name])
end

function Components:CreateComponent(component_type, name) -- i would add type checking however i am on mobile so it fills my screen and looks ugly, just like this comment
   local component = setmetatable({
      _Children = {},
      _Build = component_type
      _Name = name,
      _Parent = self
   }, Components[self._Children][name])
   self._Children[name] = component
   return component
end

function Components:Build()
   if type(self._Build) == "string" and type(self._Parent._Build) ~= "string" then
      -- build
      
      local err, success, build = pcall(Instance.new, self._Build)
      print(build)
      if not success then
         error("EasyUI | "..err)
      end
   elseif type(self._Parent._Build) == "string" then
      error("EasyUI | You need to build the parent object first!)
   else
      warn("EasyUI | This object is already built! Maybe you mean Rebuild?")
   end
end

return EasyUI