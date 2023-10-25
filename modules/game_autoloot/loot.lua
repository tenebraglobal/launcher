
GameServerOpcodes.AutoLoot = 157
maxSlot = 5 -- altere ao seu gosto podendo fazer: g_game.getLocalPlayer():isPremium() and valorX or valorY

listLoot = nil
itemSelected = nil
edtItemName = nil
lblItemList = nil
mouseGrabberWidget = nil

function init()
	connect(g_game, { onTextMessage = onTextMessage }) -- sem apcode
	-- connect(g_game, { onGameEnd = offline }) -- com apcode
	ProtocolGame.registerExtendedOpcode(GameServerOpcodes.AutoLoot, function(protocol, opcode, buffer) createListLoot(buffer) end)
	
	btnAutoLoot = modules.client_topmenu.addRightGameToggleButton('lootButton', tr('Auto-Loot'), 'loot', toggle)
	windowAutoLoot = g_ui.displayUI('loot')
	windowAutoLoot:hide()

	itemSelected = windowAutoLoot:getChildById('itemSelected')
	lblItemList = windowAutoLoot:getChildById('lblItemList')
	edtItemName = windowAutoLoot:getChildById('edtItemName')
	listLoot = windowAutoLoot:getChildById('listLoot')
	connect(listLoot, { onChildFocusChange = 
		function(self, focusedChild)
			if focusedChild == nil then return end
			local itemName = focusedChild:getChildById('rowItemName'):getText()
			if itemName ~= 'Empty Slot' then
				itemSelected:setItemId(focusedChild:getChildById('rowItem'):getItemId())
				edtItemName:setText(itemName)
			end
		end
	})
	
	mouseGrabberWidget = g_ui.createWidget('UIWidget')
	mouseGrabberWidget:setVisible(false)
	mouseGrabberWidget:setFocusable(false)
	mouseGrabberWidget.onMouseRelease = onChooseItemMouseRelease
						
	g_keyboard.bindKeyPress('Up', function() listLoot:focusPreviousChild(KeyboardFocusReason) end, windowAutoLoot)
    g_keyboard.bindKeyPress('Down', function() listLoot:focusNextChild(KeyboardFocusReason) end, windowAutoLoot)
end

function onTextMessage(mode, text)
	if not g_game.isOnline() then return end
	if mode == MessageModes.Failure then 
		if string.find(text, 'AutoLoot>') then
			createListLoot(text:explode('>')[2])
		end
	end
end

function terminate()
	disconnect(g_game, { onTextMessage = onTextMessage }) -- sem apcode
	-- disconnect(g_game, { onGameEnd = offline }) --com apcode
	disconnect(listLoot, { onChildFocusChange = 
		function(self, focusedChild)
			if focusedChild == nil then return end
			local itemName = focusedChild:getChildById('rowItemName'):getText()
			if itemName ~= 'Slot Item Name' then
				itemSelected:setItemId(focusedChild:getChildById('rowItem'):getItemId())
				edtItemName:setText(itemName)
			end
		end
	})
	ProtocolGame.unregisterExtendedOpcode(GameServerOpcodes.AutoLoot)
	windowAutoLoot:destroy()
	btnAutoLoot:destroy()
	listLoot:destroy()
	edtItemName:destroy()
	lblItemList:destroy()
	mouseGrabberWidget:destroy()
end

function offline()
	listLoot:destroyChildren()
	windowAutoLoot:hide()
	eraseLoot()
	listLoot:focusChild(nil)
end

function toggle()
	if windowAutoLoot:isVisible() then
		windowAutoLoot:hide()
	else
		onOpenAutoLoot()
	end
end

function onOpenAutoLoot()
	windowAutoLoot:show()
	windowAutoLoot:raise()
	windowAutoLoot:focus()
end

function createListLoot(buffer)
	local _listloot = {}
	for i, v in ipairs(buffer:split('@')) do
		table.insert(_listloot, {
			itemId = v:split('-')[1],
			itemName = v:split('-')[2]
		})  
	end
	for i, loot in ipairs(_listloot) do
		itemSelected:setItemId(loot.itemId)
		edtItemName:setText(loot.itemName)
		addSlotLoot()
		addLoot(false)
	end
	countLootList()
end

function addLoot(sendLoot)
	selectedSlot = listLoot:getFocusedChild()
	if selectedSlot then
		local itemId = itemSelected:getItemId() == 0 and g_things.findItemTypeByName(edtItemName:getText()):getClientId() or itemSelected:getItemId()
		if itemId == 0 then
			displayErrorBox('Item nao encontrado', 'Verifique o nome do item e digite novamente!')
			return
		end
		selectedSlot.itemId = itemId
		selectedSlot:getChildById('rowItemName'):setText(edtItemName:getText())		
		selectedSlot:getChildById('rowItem'):setItemId(itemId)
		if sendLoot then g_game.talk('!autoloot add, '..edtItemName:getText()) end
		eraseLoot()
	else
		displayErrorBox('Auto-Loot', 'Selecione um Slot para adicionar um item!')
	end
end

function addSlotLoot()
	if listLoot:getChildCount() < maxSlot then
		local rowLoot = g_ui.createWidget('RowListLoot', listLoot)
		listLoot:focusChild(rowLoot, ActiveFocusReason)
		countLootList()
	end
end

function removeListLoot()
	g_game.talk('!autoloot clear')
	eraseLoot()
	listLoot:destroyChildren()
	countLootList()
end

function removeSlot()
	selectedSlot = listLoot:getFocusedChild()
	if selectedSlot then
		g_game.talk('!autoloot remove, '..selectedSlot:getChildById('rowItemName'):getText())
		eraseLoot()	
		listLoot:focusPreviousChild(KeyboardFocusReason)
		listLoot:removeChild(selectedSlot)		
		countLootList()
	else
		displayErrorBox('Auto-Loot', 'Selecione um Slot para ser removido!')
	end
end

function eraseLoot()
    itemSelected:setItem(nil)
	edtItemName:clearText()
end

function countLootList()
	lblItemList:setText('Itens na lista: '..listLoot:getChildCount()..'/'..maxSlot)
end

function startChooseItem()
	if g_ui.isMouseGrabbed() then return end
	mouseGrabberWidget:grabMouse()
	g_mouse.pushCursor('target')
	windowAutoLoot:hide()
end

function onChooseItemMouseRelease(self, mousePosition, mouseButton)
	local item = nil
	if mouseButton == MouseLeftButton then
		local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
		if clickedWidget then
			if clickedWidget:getClassName() == 'UIMap' then
				local tile = clickedWidget:getTile(mousePosition)
				if tile then
					local thing = tile:getTopMoveThing()
					if thing and thing:isItem() then
						item = thing
					end
				end
			elseif clickedWidget:getClassName() == 'UIItem' and not clickedWidget:isVirtual() then
				item = clickedWidget:getItem()
			end
		end
	end

	if item then
		itemSelected:setItemId(item:getId())
		edtItemName:setText(item:getName())
	end

	onOpenAutoLoot()

	g_mouse.popCursor('target')
	self:ungrabMouse()
	return true
end