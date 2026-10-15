AIWorkerRefillSplit = {
    MOD_NAME = g_currentModName,
    SETTINGS_FILE = getUserProfileAppPath() .. "modSettings/FS25_AIWorkerRefillSplit.xml",
    buySolidFertilizer = true,
    buyLiquidFertilizer = true,
    buyLime = true,
    buyHerbicide = true,
    isUiInitialized = false,
    controls = {}
}

local SETTING_DEFINITIONS = {
    { property = "buySolidFertilizer", id = "awrs_solidFertilizer" },
    { property = "buyLiquidFertilizer", id = "awrs_liquidFertilizer" },
    { property = "buyLime", id = "awrs_lime" },
    { property = "buyHerbicide", id = "awrs_herbicide" }
}

local function updateFocusIds(element)
    if element == nil then return end
    element.focusId = FocusManager:serveAutoFocusId()
    for _, child in pairs(element.elements or {}) do
        updateFocusIds(child)
    end
end

local function containsIdentifier(element, identifier)
    if element == nil then return false end
    local id = string.lower(tostring(element.id or ""))
    local name = string.lower(tostring(element.name or ""))
    if string.find(id, identifier, 1, true) or string.find(name, identifier, 1, true) then
        return true
    end
    for _, child in pairs(element.elements or {}) do
        if containsIdentifier(child, identifier) then return true end
    end
    return false
end

local function containsElement(element, target)
    if element == nil then return false end
    if element == target then return true end
    for _, child in pairs(element.elements or {}) do
        if containsElement(child, target) then return true end
    end
    return false
end

local function containsFertilizerLabel(element)
    if element == nil then return false end

    local text = element.text
    if element.getText ~= nil then
        local succeeded, value = pcall(element.getText, element)
        if succeeded and value ~= nil then text = value end
    end

    text = string.lower(tostring(text or ""))
    local labels = {"fertilizer", "dünger", "duenger", "meststof", "engrais", "fertilizante", "fertilizzante", "nawóz"}
    for _, label in ipairs(labels) do
        if string.find(text, label, 1, true) ~= nil then return true end
    end

    for _, child in pairs(element.elements or {}) do
        if containsFertilizerLabel(child) then return true end
    end
    return false
end

local function findFertilizerOptionBox(settingsPage)
    local layoutElements = settingsPage.gameSettingsLayout.elements

    -- First use the GUI controller's named bindings. The exact key has varied
    -- between game versions, but it consistently contains "fertilizer".
    for key, value in pairs(settingsPage) do
        if type(key) == "string"
            and string.find(string.lower(key), "fertilizer", 1, true) ~= nil
            and type(value) == "table" then
            for _, topLevelElement in ipairs(layoutElements) do
                if containsElement(topLevelElement, value) then
                    return topLevelElement, "controller binding '" .. key .. "'"
                end
            end
        end
    end

    -- Fall back to element IDs/names, then to the localized visible label.
    for _, element in ipairs(layoutElements) do
        if containsIdentifier(element, "helperbuyfertilizer")
            or containsIdentifier(element, "buyfertilizer") then
            return element, "element identifier"
        end
    end
    for _, element in ipairs(layoutElements) do
        if containsFertilizerLabel(element) then
            return element, "localized label"
        end
    end

    return nil, nil
end

local function findIndex(elements, target)
    for index, element in ipairs(elements) do
        if element == target then return index end
    end
    return nil
end

local function removeElement(elements, target)
    local index = findIndex(elements, target)
    if index ~= nil then table.remove(elements, index) end
    return index
end

local function insertAt(elements, target, index)
    removeElement(elements, target)
    table.insert(elements, math.min(index, #elements + 1), target)
end

function AIWorkerRefillSplit:updateVanillaAggregateSetting()
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        -- Some base-game specializations still use this aggregate flag before
        -- Sprayer asks for the actual fill type.
        g_currentMission.missionInfo.helperBuyFertilizer =
            self.buySolidFertilizer or self.buyLiquidFertilizer or self.buyHerbicide
    end
end

function AIWorkerRefillSplit:loadSettings()
    local vanillaValue = true
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        vanillaValue = g_currentMission.missionInfo.helperBuyFertilizer
    end

    self.buySolidFertilizer = vanillaValue
    self.buyLiquidFertilizer = vanillaValue
    self.buyLime = vanillaValue
    self.buyHerbicide = vanillaValue

    local xmlFile = loadXMLFile("aiWorkerRefillSplit", self.SETTINGS_FILE)
    if xmlFile ~= 0 then
        for _, definition in ipairs(SETTING_DEFINITIONS) do
            local key = "aiWorkerRefillSplit#" .. definition.property
            if hasXMLProperty(xmlFile, key) then
                self[definition.property] = getXMLBool(xmlFile, key)
            end
        end

        -- Migrate the lime-only setting written by versions 1.0.0.0/1.0.0.1.
        if hasXMLProperty(xmlFile, "aiWorkerRefillSplit#buyLime") then
            self.buyLime = getXMLBool(xmlFile, "aiWorkerRefillSplit#buyLime")
        end
        delete(xmlFile)
    end

    self:updateVanillaAggregateSetting()
end

function AIWorkerRefillSplit:saveSettings()
    createFolder(getUserProfileAppPath() .. "modSettings")
    local xmlFile = createXMLFile("aiWorkerRefillSplit", self.SETTINGS_FILE, "aiWorkerRefillSplit")
    if xmlFile == 0 then
        Logging.error("[%s] Could not save settings to '%s'", self.MOD_NAME, self.SETTINGS_FILE)
        return
    end

    for _, definition in ipairs(SETTING_DEFINITIONS) do
        setXMLBool(xmlFile, "aiWorkerRefillSplit#" .. definition.property, self[definition.property])
    end
    saveXMLFile(xmlFile)
    delete(xmlFile)
end

function AIWorkerRefillSplit:onSettingChanged(property, state)
    self[property] = state == BinaryOptionElement.STATE_RIGHT
    self:updateVanillaAggregateSetting()
    self:saveSettings()
end

function AIWorkerRefillSplit:onSolidFertilizerChanged(state)
    self:onSettingChanged("buySolidFertilizer", state)
end

function AIWorkerRefillSplit:onLiquidFertilizerChanged(state)
    self:onSettingChanged("buyLiquidFertilizer", state)
end

function AIWorkerRefillSplit:onLimeChanged(state)
    self:onSettingChanged("buyLime", state)
end

function AIWorkerRefillSplit:onHerbicideChanged(state)
    self:onSettingChanged("buyHerbicide", state)
end

function AIWorkerRefillSplit:updateUi()
    local canChange = g_currentMission == nil
        or g_currentMission:getIsServer()
        or g_currentMission.isMasterUser

    for _, definition in ipairs(SETTING_DEFINITIONS) do
        local option = self[definition.property .. "Option"]
        if option ~= nil then
            option:setState(self[definition.property]
                and BinaryOptionElement.STATE_RIGHT
                or BinaryOptionElement.STATE_LEFT)
            option:setDisabled(not canChange)
        end
    end
end

function AIWorkerRefillSplit:createOption(settingsPage, definition, callback)
    local optionBox = settingsPage.checkWoodHarvesterAutoCutBox:clone(settingsPage.gameSettingsLayout)
    updateFocusIds(optionBox)
    optionBox.id = definition.id .. "Box"

    local option = optionBox.elements[1]
    option.id = definition.id
    option.target = self
    option:setCallback("onClickCallback", callback)
    option:setDisabled(false)
    optionBox.elements[2]:setText(g_i18n:getText(definition.id .. "_short"))
    option.elements[1]:setText(g_i18n:getText(definition.id .. "_long"))

    self[definition.property .. "Option"] = option
    table.insert(self.controls, optionBox)
    return optionBox
end

function AIWorkerRefillSplit:injectUi()
    if g_dedicatedServer or self.isUiInitialized then return end

    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local settingsPage = inGameMenu ~= nil and inGameMenu.pageSettings or nil
    if settingsPage == nil or settingsPage.gameSettingsLayout == nil then
        Logging.warning("[%s] Could not find the Game Settings page", self.MOD_NAME)
        return
    end

    local fertilizerOptionBox, matchMethod = findFertilizerOptionBox(settingsPage)

    if fertilizerOptionBox == nil then
        Logging.error("[%s] Could not find the vanilla fertilizer option; refill controls were not injected", self.MOD_NAME)
        return
    end

    Logging.info("[%s] Found vanilla fertilizer option via %s", self.MOD_NAME, matchMethod)

    local layoutIndex = findIndex(settingsPage.gameSettingsLayout.elements, fertilizerOptionBox)
    local controlsIndex = findIndex(settingsPage.controlsList, fertilizerOptionBox) or (#settingsPage.controlsList + 1)
    removeElement(settingsPage.gameSettingsLayout.elements, fertilizerOptionBox)
    removeElement(settingsPage.controlsList, fertilizerOptionBox)
    fertilizerOptionBox:setVisible(false)

    self.name = settingsPage.name
    local callbacks = {
        "onSolidFertilizerChanged",
        "onLiquidFertilizerChanged",
        "onLimeChanged",
        "onHerbicideChanged"
    }

    for index, definition in ipairs(SETTING_DEFINITIONS) do
        local optionBox = self:createOption(settingsPage, definition, callbacks[index])
        insertAt(settingsPage.gameSettingsLayout.elements, optionBox, layoutIndex + index - 1)
        table.insert(settingsPage.controlsList, controlsIndex + index - 1, optionBox)
    end

    FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
        if gui == nil then return end
        for _, control in ipairs(self.controls) do
            if control.focusId == nil
                or FocusManager.currentFocusData.idToElementMapping[control.focusId] == nil then
                FocusManager:loadElementFromCustomValues(control, nil, nil, false, false)
            end
        end
    end)

    settingsPage.gameSettingsLayout:invalidateLayout()
    self.isUiInitialized = true
    self:updateUi()
end

function AIWorkerRefillSplit:isBuyEnabled(fillType)
    if fillType == FillType.FERTILIZER then return self.buySolidFertilizer end
    if fillType == FillType.LIQUIDFERTILIZER then return self.buyLiquidFertilizer end
    if fillType == FillType.LIME then return self.buyLime end
    if fillType == FillType.HERBICIDE then return self.buyHerbicide end
    return nil
end

function AIWorkerRefillSplit:getSelectedFillType(vehicle, fillType)
    if fillType ~= FillType.UNKNOWN then return fillType end

    local fillUnitIndex = vehicle:getSprayerFillUnitIndex()
    if self.buyLiquidFertilizer and vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.LIQUIDFERTILIZER) then
        return FillType.LIQUIDFERTILIZER
    end
    if self.buySolidFertilizer and vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.FERTILIZER) then
        return FillType.FERTILIZER
    end
    if self.buyHerbicide and vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.HERBICIDE) then
        return FillType.HERBICIDE
    end
    if self.buyLime and vehicle:getFillUnitAllowsFillType(fillUnitIndex, FillType.LIME) then
        return FillType.LIME
    end
    return FillType.UNKNOWN
end

function AIWorkerRefillSplit:getCurrentFillType(vehicle)
    local fillUnitIndex = vehicle:getSprayerFillUnitIndex()
    local fillType = vehicle:getFillUnitFillType(fillUnitIndex)
    if fillType == FillType.UNKNOWN then
        fillType = vehicle:getFillUnitLastValidFillType(fillUnitIndex)
    end
    return self:getSelectedFillType(vehicle, fillType)
end

function AIWorkerRefillSplit:callWithVanillaBuyEnabled(superFunc, vehicle, ...)
    local missionInfo = g_currentMission.missionInfo
    local previousValue = missionInfo.helperBuyFertilizer
    missionInfo.helperBuyFertilizer = true
    local result1, result2 = superFunc(vehicle, ...)
    missionInfo.helperBuyFertilizer = previousValue
    return result1, result2
end

function AIWorkerRefillSplit.getIsSprayerExternallyFilled(vehicle, superFunc)
    local fillType = AIWorkerRefillSplit:getCurrentFillType(vehicle)
    local enabled = AIWorkerRefillSplit:isBuyEnabled(fillType)
    if enabled == false or fillType == FillType.UNKNOWN then return false end
    if enabled == true then
        return AIWorkerRefillSplit:callWithVanillaBuyEnabled(superFunc, vehicle)
    end
    return superFunc(vehicle)
end

function AIWorkerRefillSplit.getExternalFill(vehicle, superFunc, fillType, dt)
    fillType = AIWorkerRefillSplit:getSelectedFillType(vehicle, fillType)
    local enabled = AIWorkerRefillSplit:isBuyEnabled(fillType)
    if enabled == false or fillType == FillType.UNKNOWN then
        return FillType.UNKNOWN, 0
    end
    if enabled == true then
        return AIWorkerRefillSplit:callWithVanillaBuyEnabled(superFunc, vehicle, fillType, dt)
    end
    return superFunc(vehicle, fillType, dt)
end

Sprayer.getIsSprayerExternallyFilled = Utils.overwrittenFunction(
    Sprayer.getIsSprayerExternallyFilled,
    AIWorkerRefillSplit.getIsSprayerExternallyFilled)
Sprayer.getExternalFill = Utils.overwrittenFunction(
    Sprayer.getExternalFill,
    AIWorkerRefillSplit.getExternalFill)

BaseMission.loadMapFinished = Utils.appendedFunction(BaseMission.loadMapFinished, function()
    AIWorkerRefillSplit:loadSettings()
    AIWorkerRefillSplit:injectUi()
end)

InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
    AIWorkerRefillSplit:updateUi()
end)

Logging.info("[%s] Loaded", AIWorkerRefillSplit.MOD_NAME)
