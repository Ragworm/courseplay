--[[
@name:    inputCourseNameDialogue
@desc:    Dialogue settings for the Courseplay course saving form
@author:  Jakob Tischler
@version: 1.4
@date:    30 Sep 2013
--]]

local modDir = g_currentModDirectory;

inputCourseNameDialogue = {}
local inputCourseNameDialogue_mt = Class(inputCourseNameDialogue)
inputCourseNameDialogue.stateData = {
	normal =   { stateNum = 1, fileNameVar = "imageFilename" };
	pressed =  { stateNum = 2, fileNameVar = "imagePressedFilename" };
	focused =  { stateNum = 3, fileNameVar = "imageFocusedFilename" };
	disabled = { stateNum = 4, fileNameVar = "imageDisabledFilename" };
};
inputCourseNameDialogue.types = { "course", "folder", "filter", "node" };

function inputCourseNameDialogue:new()
	local instance = {};
	instance = setmetatable(instance, inputCourseNameDialogue_mt);
	return instance;
end; --END new()

function inputCourseNameDialogue:setImageOverlay(element, state, filePath, type)
	local stateLower = state:lower();
	local stateNum = inputCourseNameDialogue.stateData[stateLower].stateNum;
	local fileNameVar = inputCourseNameDialogue.stateData[stateLower].fileNameVar;

	if element.overlays == nil and state == "normal" then --one overlay, state "normal"
		if element.overlay ~= nil then
			delete(element.overlay);
		end;
		element[fileNameVar] = filePath;
		if element[fileNameVar] ~= nil then
			element.overlay = createImageOverlay(element[fileNameVar]);
		end;
	elseif type == nil then
		if element.overlays[stateNum] ~= nil then
			delete(element.overlays[stateNum]);
		end;
		element[fileNameVar] = filePath;
		if element[fileNameVar] ~= nil then
			element.overlays[stateNum] = createImageOverlay(element[fileNameVar]);
		end;
	else
		type = type:sub(2);
		if element[type] == nil then
			element[type] = {
				overlays = {};
			};
		end;

		if Utils.startsWith(filePath, "$") then
			local copyFromType = filePath:sub(2);
			if element[copyFromType].overlays[stateNum] ~= nil then
				element[type].overlays[stateNum] = element[copyFromType].overlays[stateNum];
			end;
		else
			if element[type].overlays[stateNum] ~= nil then
				delete(element[type].overlays[stateNum]);
			end;
			element[type][fileNameVar] = filePath;
			if element[type][fileNameVar] ~= nil then
				element[type].overlays[stateNum] = createImageOverlay(element[type][fileNameVar]);
			end;

			--set "normal" overlay
			if stateLower == "normal" and element.normal ~= nil and element.normal.overlays[stateNum] ~= nil then
				element.overlays[stateNum] = element.normal.overlays[stateNum];
			end;
		end;
	end;
end;
function inputCourseNameDialogue.setModImages(element, xmlFile, key)
	element.modImgDir = modDir .. (getXMLString(xmlFile, key .. "#MOD_imageDir") or "");

	for state,data in pairs(inputCourseNameDialogue.stateData) do
		local filePaths = getXMLString(xmlFile, key .. "#MOD_" .. data.fileNameVar);
		if filePaths ~= nil then
			local split = Utils.splitString(",", filePaths);
			if #split == 1 then
				inputCourseNameDialogue:setImageOverlay(element, state, element.modImgDir .. filePaths);
			elseif #split == #inputCourseNameDialogue.types then
				for _,data in pairs(split) do
					local kv = Utils.splitString(":", data);
					local type, filePath = unpack(kv);
					local realFilePath = filePath;
					if not Utils.startsWith(filePath, "$") then
						realFilePath = element.modImgDir .. filePath;
					end;

					inputCourseNameDialogue:setImageOverlay(element, state, realFilePath, type);
				end;
			else
				--ERROR
			end;
		end;
	end;
end; --END setModImages()
BitmapElement.loadFromXML =    Utils.appendedFunction(BitmapElement.loadFromXML,    inputCourseNameDialogue.setModImages);
TextInputElement.loadFromXML = Utils.appendedFunction(TextInputElement.loadFromXML, inputCourseNameDialogue.setModImages);
ButtonElement.loadFromXML =    Utils.appendedFunction(ButtonElement.loadFromXML,    inputCourseNameDialogue.setModImages);

function inputCourseNameDialogue:onCreateTitleText(element)
	self.titleTextElement = element;
end; --END onCreateTitleText()

function inputCourseNameDialogue:onCreateSaveButton(element)
	self.saveButtonElement = element;
end; --END onCreateSaveButton()

function inputCourseNameDialogue:onCreateCancelButton(element)
	self.cancelButtonElement = element;
end; --END onCreateCancelButton()

function inputCourseNameDialogue:onCreateTextInput(element)
	self.textInputElement = element;

	--src: ASCII Table - Decimal (Base 10) Values @ http://www.parse-o-matic.com/parse/pskb/ASCII-Chart.htm
	local allowedCharacterSpans = {
		{ 32,  32 },
		{ 40,  41 },
		{ 43,  43 },
		{ 45,  57 },
		{ 65,  90 },
		{ 97, 122 }
	};
	self.textInputElement.allowedCharacters = {};

	for _,span in pairs(allowedCharacterSpans) do
		for i=span[1],span[2] do
			self.textInputElement.allowedCharacters[i] = true;
		end;
	end;
end; --END onCreateTextInput()

function inputCourseNameDialogue:onOpen(element)
	g_currentMission.isPlayerFrozen = true;
	InputBinding.setShowMouseCursor(true);

	local saveWhat = courseplay.vehicleToSaveCourseIn.cp.saveWhat;

	--SET SAVE BUTTON IMAGE
	self.saveButtonElement.overlays = self.saveButtonElement[saveWhat].overlays;

	--SET TITLE TEXT
	if self.titleTextElement.courseText == nil or self.titleTextElement.folderText == nil or self.titleTextElement.filterText == nil then
		local cpTitleParts = Utils.splitString(",", self.titleTextElement.text);
		local courseTitle = string.sub(cpTitleParts[1], 5);
		local folderTitle = string.sub(cpTitleParts[2], 5);
		local filterTitle = string.sub(cpTitleParts[3], 5);
		local nodeTitle   = string.sub(cpTitleParts[4], 5);
		self.titleTextElement.courseText =  courseplay.locales[courseTitle] or "Course name:";
		self.titleTextElement.folderText =  courseplay.locales[folderTitle] or "Folder name:";
		self.titleTextElement.filterText =  courseplay.locales[filterTitle] or "Filter courses:";
		self.titleTextElement.nodeText   =  courseplay.locales[nodeTitle]   or "Node name:";
	end;
	self.titleTextElement.text = self.titleTextElement[saveWhat .. "Text"];

	self:validateCourseName();

	--SET FOCUS
	FocusManager:setFocus(self.textInputElement);
	self.textInputElement.mouseDown = false;
	self.textInputElement.state = TextInputElement.STATE_PRESSED;
	self.textInputElement:setForcePressed(true);
end; --END onOpen()

function inputCourseNameDialogue:onClose(element)
	InputBinding.setShowMouseCursor(false);
	g_currentMission.isPlayerFrozen = false;
end; --END onClose()

function inputCourseNameDialogue:onIsUnicodeAllowed(unicode)
	return self.textInputElement.allowedCharacters[unicode] == true;
end; --END onIsUnicodeAllowed()

function inputCourseNameDialogue:onSaveClick()
	--print("inputCourseNameDialogue:onSaveClick()");
	local vehicle = courseplay.vehicleToSaveCourseIn

	if vehicle.cp.saveWhat == 'course' then
		if self.textInputElement ~= nil then
			--print("self.textInputElement.text= "..tostring(self.textInputElement.text).."  courseplay.vehicleToSaveCourseIn.current_course_name= "..tostring(courseplay.vehicleToSaveCourseIn.current_course_name));
			vehicle.current_course_name = self.textInputElement.text;
			CourseplayEvent.sendEvent(vehicle, "self.current_course_name", self.textInputElement.text)
			vehicle.cp.doNotOnSaveClick = true
		else
			--print("self.textInputElement.text= "..tostring(self.textInputElement).."  courseplay.vehicleToSaveCourseIn.current_course_name= "..tostring(courseplay.vehicleToSaveCourseIn.current_course_name));
		end

		local maxID = courseplay.courses.getMaxCourseID()
		if maxID == nil then
			g_currentMission.cp_courses = {};
			maxID = 0
		end

		vehicle.courseID = maxID + 1;
		vehicle.numCourses = 1;

		local course = { id = vehicle.courseID, uid = 'c'..vehicle.courseID, type = 'course', name = vehicle.current_course_name,  waypoints = vehicle.Waypoints, parent = 0}
		g_currentMission.cp_courses[vehicle.courseID] = course
		g_currentMission.cp_sorted = courseplay.courses.sort()

		courseplay.courses.save_course(vehicle.courseID, nil, true)
		courseplay.settings.setReloadCourseItems()
		courseplay:updateWaypointSigns(vehicle);
		
	elseif vehicle.cp.saveWhat == 'folder' then
		local maxID = courseplay.courses.getMaxFolderID()
		if maxID == nil then
			g_currentMission.cp_folders = {}
			maxID = 0
		end
		local folderID = maxID+1
		local folder = { id = folderID, uid = 'f'..folderID, type = 'folder', name = self.textInputElement.text, parent = 0 }

		g_currentMission.cp_folders[folderID] = folder
		g_currentMission.cp_sorted = courseplay.courses.sort(g_currentMission.cp_courses, g_currentMission.cp_folders, 0, 0)

		courseplay.courses.save_folder(folderID, nil, true)
		courseplay.settings.add_folder(folderID)
		courseplay.settings.setReloadCourseItems()
		courseplay:updateWaypointSigns(vehicle);
		
	elseif vehicle.cp.saveWhat == 'filter' then
		vehicle.cp.hud.filter = self.textInputElement.text;
		local button;
		if vehicle.cp.hud.currentPage == 2 then
			button = vehicle.cp.buttons["2"][vehicle.cp.hud.filterButtonIndex];
		else
			button = vehicle.cp.buttons["10"][vehicle.cp.hud.filterButtonIndex10];
		end
		courseplay.button.setOverlay(button, 2);
		courseplay.settings.setReloadCourseItems(vehicle);
		
	elseif vehicle.cp.saveWhat == 'node' then
		local maxID = courseplay.courses.getMaxNodeID();
		if maxID == nil then
			g_currentMission.cp_nodes = {conn={}};
			maxID = 0;
		end
		local node = courseplay.courses.NodeClass:new(maxID+1, self.textInputElement.text, vehicle.Waypoints[1].cx, vehicle.Waypoints[1].cz)
		g_currentMission.cp_nodes[node.id] = node;
		g_currentMission.cp_sortedNodes = courseplay.courses.sortNodes(g_currentMission.cp_nodes);
		node:save(nil, true);
		courseplay.reset_course(nil,vehicle);
		
	end

	if self.textInputElement ~= nil then
		CourseplayEvent.sendEvent(courseplay.vehicleToSaveCourseIn, "self.cp.onSaveClick",true)
		self:onCancelClick();
	end
end; --END onSaveClick()

function inputCourseNameDialogue:onCancelClick()
	self.textInputElement.text = "";
	self.textInputElement.visibleTextPart1 = "";
	self.textInputElement.cursorPosition = 1;
	self.textInputElement.cursorBlinkTime = 0;

	g_gui:showGui("");
	courseplay.vehicleToSaveCourseIn = nil;
	self:onClose();
end; --END onCancelClick()

function inputCourseNameDialogue:onTextChanged()
	self:validateCourseName();
end; --END onTextChanged()

function inputCourseNameDialogue:onEnterPressed()
	if self:validateCourseName() then
		self:onSaveClick();
	end;
end; --END onEnterPressed()

function inputCourseNameDialogue:validateCourseName()
	self.saveButtonElement.disabled = self.textInputElement.text == nil or self.textInputElement.text:len() < 1;
	--print("self.saveButtonElement.disabled="..tostring(self.saveButtonElement.disabled));
	return not self.saveButtonElement.disabled;
end; --END validateCourseName()

function inputCourseNameDialogue:setTextInputFocus(element)
end;

function inputCourseNameDialogue:setCallbacks(onCourseNameEntered, target)
	self.target = target;
end; --END setCallbacks()

function inputCourseNameDialogue:update(dt)
	if InputBinding.hasEvent(InputBinding.MENU_ACCEPT, true) then
		InputBinding.hasEvent(InputBinding.MENU_ACCEPT, true);
		self:onEnterPressed();
	elseif InputBinding.hasEvent(InputBinding.MENU, true) or InputBinding.hasEvent(InputBinding.MENU_CANCEL, true) then
		InputBinding.hasEvent(InputBinding.MENU_CANCEL, true);
		InputBinding.hasEvent(InputBinding.MENU, true);
		self:onCancelClick();
	end;
end; --END update()
