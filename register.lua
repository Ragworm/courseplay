--COURSEPLAY
--print_r(g_fruitTypeManager)
--print_r(g_vehicleTypeManager)
--DebugUtil.printTableRecursively(g_fillTypeManager, '  ', 0, 10)

g_specializationManager:addSpecialization("courseplay", "courseplay", Utils.getFilename("courseplay.lua",  g_currentModDirectory), nil)

function courseplay.registerEventListeners(vehicleType)
	--print(string.format( "courseplay:registerEventListeners(%s)",tostring(vehicleType)))
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", courseplay)
end

if courseplay.houstonWeGotAProblem then
	return;
end;

local numInstallationsVehicles = 0;
local courseplaySpecName = g_currentModName .. ".courseplay"

function courseplay:register(secondTime)
	if secondTime then
		print('## Courseplay: register later loaded mods:');
	else
		print('## Courseplay: register into vehicle types:');
	end
	for typeName,vehicleType in pairs(g_vehicleTypeManager.vehicleTypes) do
		if SpecializationUtil.hasSpecialization(AIVehicle, vehicleType.specializations) and not vehicleType.hasCourseplaySpec then
				print("  install courseplay into "..typeName)
				g_vehicleTypeManager:addSpecialization(typeName, courseplaySpecName)
				vehicleType.hasCourseplaySpec = true;
				numInstallationsVehicles = numInstallationsVehicles + 1;
		end;
	end;
end;

function courseplay:attachablePostLoad(xmlFile)
	if self.cp == nil then self.cp = {}; end;

	if self.cp.xmlFileName == nil then
		self.cp.xmlFileName = courseplay.utils:getFileNameFromPath(self.configFileName);
	end;

	--SET SPECIALIZATION VARIABLE
	courseplay:setNameVariable(self);
	courseplay:setCustomSpecVariables(self);

	if courseplay.liquidManureOverloaders == nil then
		courseplay.liquidManureOverloaders ={}
	end
	if self.cp.isLiquidManureOverloader then
		courseplay.liquidManureOverloaders[self.rootNode] = self
	end


	--SEARCH AND SET OBJECT'S self.name IF NOT EXISTING
	if self.name == nil then
		self.name = courseplay:getObjectName(self, xmlFile);
	end;
end;
Attachable.postLoad = Utils.appendedFunction(Attachable.postLoad, courseplay.attachablePostLoad);

function courseplay:attachableDelete()
	if self.cp ~= nil then
		if self.cp.isLiquidManureOverloader then
			courseplay.liquidManureOverloaders[self.rootNode] = nil
		end
	end;
end;
Attachable.delete = Utils.prependedFunction(Attachable.delete, courseplay.attachableDelete);

function courseplay.vehiclePostLoadFinished(self, superFunc, ...)
	local loadingState = superFunc(self, ...);
	if loadingState ~= BaseMission.VEHICLE_LOAD_OK then
		-- something failed. Probably handle this: do not do anything else
		-- return loadingState;
	end

	if self.cp == nil then self.cp = {}; end;

	-- XML FILE NAME VARIABLE
	if self.cp.xmlFileName == nil then
		self.cp.xmlFileName = courseplay.utils:getFileNameFromPath(self.configFileName);
	end;

	-- make sure every vehicle has the CP API functions
	self.getIsCourseplayDriving = courseplay.getIsCourseplayDriving;
	self.setIsCourseplayDriving = courseplay.setIsCourseplayDriving;
	self.setCpVar = courseplay.setCpVar;

	courseplay:setNameVariable(self);

	-- combines table
	if courseplay.combines == nil then
		courseplay.combines = {};
	end;
	if self.cp.isCombine or self.cp.isChopper or self.cp.isHarvesterSteerable or self.cp.isSugarBeetLoader or courseplay:isAttachedCombine(self) then
		courseplay.combines[self.rootNode] = self;
	end;

	return loadingState;
end;
Vehicle.loadFinished = Utils.overwrittenFunction(Vehicle.loadFinished, courseplay.vehiclePostLoadFinished);
-- NOTE: using loadFinished() instead of load() so any other mod that overwrites Vehicle.load() doesn't interfere


function courseplay:prePreDelete(self)
	if self.cp ~= nil then
		courseplay:deleteMapHotspot(self);
	end
end;
FSBaseMission.removeVehicle = Utils.prependedFunction(FSBaseMission.removeVehicle, courseplay.prePreDelete);

courseplay.initAIImplements()

function courseplay:vehicleDelete()
	if self.cp ~= nil then
		--if vehicle is a courseplayer, delete the vehicle from activeCourseplayers
		if CpManager.activeCoursePlayers[self.rootNode] then
			CpManager:removeFromActiveCoursePlayers(self);
		end

		-- Remove created nodes
		if self.cp.notesToDelete and #self.cp.notesToDelete > 0 then
			for _, nodeId in ipairs(self.cp.notesToDelete) do
				if nodeId and nodeId ~= 0 then
					delete(nodeId);
				end;
			end;
			self.cp.notesToDelete = nil;
		end;

		if courseplay.combines[self.rootNode] then
			for _, courseplayer in pairs(g_currentMission.enterables) do
				if courseplayer.cp then
					if courseplayer.cp.activeCombine and courseplayer.cp.activeCombine == self then
						courseplay:unregisterFromCombine(courseplayer, self)
					end
					if courseplayer.cp.lastActiveCombine and courseplayer.cp.lastActiveCombine == self then
						courseplayer.cp.lastActiveCombine = nil
					end
				end
			end
			courseplay.combines[self.rootNode] = nil;
		end;
	end;
end;
Vehicle.delete = Utils.prependedFunction(Vehicle.delete, courseplay.vehicleDelete);

function courseplay:foldableLoad(savegame)
	if self.cp == nil then self.cp = {}; end;

	--FOLDING PARTS STARTMOVEDIRECTION
	local startMoveDir = getXMLInt(self.xmlFile, 'vehicle.foldingParts#startMoveDirection');
	if startMoveDir == nil then
 		local singleDir;
		local i = 0;
		while true do -- go through single foldingPart entries
			local key = string.format('vehicle.foldingParts.foldingPart(%d)', i);
			if not hasXMLProperty(self.xmlFile, key) then break; end;
			local dir = getXMLInt(self.xmlFile, key .. '#startMoveDirection');
			if dir then
				if singleDir == nil then --first foldingPart -> set singleDir
					singleDir = dir;
				elseif dir ~= singleDir then -- two or more foldingParts have non-matching startMoveDirections --> not valid
					singleDir = nil;
					break;
				elseif dir == singleDir then -- --> valid
				end;
			end;
			i = i + 1;
		end;
		if singleDir then -- startMoveDirection found in single foldingPart
			startMoveDir = singleDir;
		end;
	end;

	self.cp.foldingPartsStartMoveDirection = Utils.getNoNil(startMoveDir, 0);
end;
Foldable.load = Utils.appendedFunction(Foldable.load, courseplay.foldableLoad);

courseplay.locales = courseplay.utils.table.copy(g_i18n.texts, true);

-- make l10n global so they can be used in GUI XML files directly (Thanks `Mogli!)
for n,t in pairs( g_i18n.texts ) do
	if string.sub( n, 1, 10 ) == "COURSEPLAY" then
		getfenv(0).g_i18n.texts[n] = t
	end
end

courseplay:register();
print(string.format('### Courseplay: installed into %d vehicle types', numInstallationsVehicles));

-- TODO: Remove the AIVehicleUtil.driveToPoint overwrite when the new patch goes out to fix it. (Temp fix from Giants: Emil)

-- This fixes the problems with driveInDirection motor and cruise control. There is a bug some where that is setting self.rotatedTime to 0
local originaldriveInDirection = AIVehicleUtil.driveInDirection;
AIVehicleUtil.driveInDirection = function (self, dt, steeringAngleLimit, acceleration, slowAcceleration, slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, slowDownFactor)

	local angle = 0;
    if lx ~= nil and lz ~= nil then
        local dot = lz;
		angle = math.deg(math.acos(dot));
        if angle < 0 then
            angle = angle+180;
        end
        local turnLeft = lx > 0.00001;
        if not moveForwards then
            turnLeft = not turnLeft;
        end
        local targetRotTime = 0;
        if turnLeft then
            --rotate to the left
			targetRotTime = self.maxRotTime*math.min(angle/steeringAngleLimit, 1);
        else
            --rotate to the right
			targetRotTime = self.minRotTime*math.min(angle/steeringAngleLimit, 1);
        end
		if targetRotTime > self.rotatedTime then
			self.rotatedTime = math.min(self.rotatedTime + dt*self:getAISteeringSpeed(), targetRotTime);
		else
			self.rotatedTime = math.max(self.rotatedTime - dt*self:getAISteeringSpeed(), targetRotTime);
        end
    end
    if self.firstTimeRun then
        local acc = acceleration;
        if maxSpeed ~= nil and maxSpeed ~= 0 then
            if math.abs(angle) >= slowAngleLimit then
                maxSpeed = maxSpeed * slowDownFactor;
            end
            self.spec_motorized.motor:setSpeedLimit(maxSpeed);
            if self.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
                self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);
            end
        else
            if math.abs(angle) >= slowAngleLimit then
                acc = slowAcceleration;
            end
        end
        if not allowedToDrive then
            acc = 0;
        end
        if not moveForwards then
            acc = -acc;
        end
		--FS 17 Version WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal, acc, not allowedToDrive, self.requiredDriveMode);
		WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal*self.movingDirection, acc, not allowedToDrive, true)
    end
end

