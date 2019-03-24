----------------------------------------------------------------------------
-- usershop with licenses and currency with atm support
----------------------------------------------------------------------------
default.usershop_current_atm_shop_position = {}
minetest.register_node("usershop:usershop_atm", {

    description = "Usershop with atm account integrated",
		tiles = {"shop_licenses_top.png",
				"shop_licenses_top.png",
				"shop_licenses.png",
				"shop_licenses.png",
				"shop_licenses.png",
				"shop_licenses.png",},
    is_ground_content = true,
		-- light_source = 10,
    groups = {dig_immediate=2}, --TODO Breakable by pickaxe ?
    sounds = default.node_sound_stone_defaults(),
-- Registriere den Owner beim Platzieren:
    after_place_node = function(pos, placer, itemstack)
      local meta = minetest.get_meta(pos)
			meta:set_string("usershop:bs", "Buy")
			meta:set_int("usershop:price", 0)
      meta:set_string("owner", placer:get_player_name())
			meta:set_int("usershop:counter", 0)
      local inv = meta:get_inventory()
      inv:set_size("einnahme", 1*1)
      inv:set_size("ausgabe", 1*1) --TODO Brauchen wir eine Ausgabe?
      inv:set_size("main", 4*8)
    end,
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
      -- Schreibe die eigene Position des Blockes in eine öffentliche Variable mit dem Namen des Spielernamens, welcher auf den Block zugegriffen hat
      default.usershop_current_atm_shop_position[player:get_player_name()] = pos
      usershop_show_spec_atm(player)
      --end
    end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
      local meta = minetest.get_meta(pos)
      if player:get_player_name() ~= meta:get_string("owner") then return 0 end
      return stack:get_count()
    end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
      local meta = minetest.get_meta(pos)
      if player:get_player_name() ~= meta:get_string("owner") then return 0 end
      return stack:get_count()
    end,
    can_dig = function(pos, player)
      local meta = minetest.get_meta(pos)
      if player:get_player_name() == meta:get_string("owner") then
        return true
      else
        return false
    end
  end


})

usershop_show_spec_atm = function (player)
    local pos = default.usershop_current_atm_shop_position[player:get_player_name()]
    local meta = minetest.get_meta(pos)
    local listname = "nodemeta:"..pos.x..','..pos.y..','..pos.z
		if atm.balance[player:get_player_name()] == nil then
			atm.balance[player:get_player_name()] = 0
		end
    if player:get_player_name() == meta:get_string("owner") then
     minetest.show_formspec(player:get_player_name(), "usershop:usershop_atm", "size[8,10.5]"..
     "label[0,0;Welcome back, ".. meta:get_string("owner").."]" ..
		 "label[2.5,0.7;Counter: "..meta:get_int("usershop:counter").."]" ..
     "label[0.6,0.6;Item:]" ..
     "list["..listname..";einnahme;0.5,1.1;2,2;]"..
		 "field[5.4,0.8;2.7,1;price_field;Price:;"..meta:get_string("usershop:price").."]" ..
		 "button[5.1,1.3;2.7,1;set_price;Set Price]" ..
     "list["..listname..";main;0,2.5;8,4;]"..
     "list[current_player;main;0,6.8;8,4;]" ..
     "button[2.2,1.1;2,1;set_buy_sell;"..meta:get_string("usershop:bs").."]"
   )
    else
      minetest.show_formspec(player:get_player_name(), "usershop:usershop_atm", "size[8,7.5]"..
      "label[0,0;Welcome, "..player:get_player_name().."]" ..
      "label[0,0.5;Items:]" ..
      "list["..listname..";einnahme;0,1;2,2;]"..
		  "label[5.7,1.45;Price: "..meta:get_string("usershop:price").."]" ..
			"label[5.7,1.8;Your Balance: "..atm.balance[player:get_player_name()].."]" ..
      "list[current_player;main;0,3.5;8,4;]" ..
      "button[3,1.5;2,1;buy_sell;"..meta:get_string("usershop:bs").."]"
    )
  end
end

-- Wenn der Spieler auf Exchange gedrückt hat:
minetest.register_on_player_receive_fields(function(customer, formname, fields)
	if formname == "usershop:usershop_atm" and fields.buy_sell ~= nil and fields.buy_sell ~= "" then
    local pos = default.usershop_current_atm_shop_position[customer:get_player_name()]
    local meta = minetest.get_meta(pos)
    local minv = meta:get_inventory()
    local pinv = customer:get_inventory()
    local items = minv:get_list("einnahme")
    local owner = meta:get_string("owner")
    if items == nil then return end -- do not crash the server

	-- Check if We Can Exchange:
	local enough_space = true
	local enough_items = true
		-- BUY:
		if meta:get_string("usershop:bs") == "Buy" then
  		if not pinv:room_for_item("main", items)  then
  		enough_space = false
  		end



		-- SELL:
		else
		  if not pinv:contains_item("main",items) then
				enough_items = false
			end
		end

  -- Customer: Enough Items?
  if not pinv:contains_item("main", items)  then
    minetest.chat_send_player(customer:get_player_name(),"You dont have enough money on your account!" )
    
  end


	-- Customer: Enough Money???
		if meta:get_string("usershop:bs") == "Buy" and atm.balance[customer:get_player_name()] < meta:get_int("usershop:price") then
			minetest.chat_send_player(customer:get_player_name(),"You dont have enough money on your account!" )
			return
		end

  -- Owner: Enough Money???
    if meta:get_string("usershop:bs") == "Sell" and atm.balance[meta:get_string("owner")] < meta:get_int("usershop:price") then
      minetest.chat_send_player(customer:get_player_name(),"The Owner hansn't enough money to pay you out! Contact the owner for that." )
      return
    end

  -- Does the Shop has enough space?
    if meta:get_string("usershop:bs") == "Sell" and not minv:room_for_item("main", items)  then
      minetest.chat_send_player(customer:get_player_name(),"The shop is full! Contact the owner for that." )
      return
    end

  -- Does the Shop has the required Item?
    if  meta:get_string("usershop:bs") == "Buy" and not minv:contains_item("main", items)  then
      minetest.chat_send_player(customer:get_player_name(),"The shop is full! Contact the owner for that." )
      return
    end



	-- Do the thing:
		-- BUY:
		if meta:get_string("usershop:bs") == "Buy" then
			if enough_space then
				pinv:add_item("main",items)
        minv:remove_item("main", items)
				atm.balance[customer:get_player_name()] = atm.balance[customer:get_player_name()] - meta:get_int("usershop:price")
        atm.balance[owner] = atm.balance[owner] + meta:get_int("usershop:price")
				usershop_show_spec_atm(customer)
				meta:set_int("usershop:counter", meta:get_int("usershop:counter") + 1)
			elseif not enough_space then
				minetest.chat_send_player(customer:get_player_name(),"You don't have enough space in your inventory!")
			end
		-- SELL:
		else
			if enough_items then
        minv:add_item("main",items)
        pinv:remove_item("main", items)
				atm.balance[customer:get_player_name()] = atm.balance[customer:get_player_name()] + meta:get_int("usershop:price")
        atm.balance[owner] = atm.balance[owner] - meta:get_int("usershop:price")
				usershop_show_spec_atm(customer)
				meta:set_int("usershop:counter", meta:get_int("usershop:counter") + 1)
			elseif not allowed then
				minetest.chat_send_player(customer:get_player_name(),"You are not allowed to buy this!" )
			else
				minetest.chat_send_player(customer:get_player_name(),"You don't have the required items in your inventory!" )
			end

		end
		atm.saveaccounts()
		-- --
    -- if enough_space and allowed then
    --   for i, item in pairs(items) do
    --     pinv:remove_item("main",item)
    --   end
    --   for i, item in pairs(gives) do
    --     pinv:add_item("main",item)
    --   end
    --   -- minetest.chat_send_player(customer:get_player_name(),"Exchanged!")
		-- elseif not allowed then
		-- 	minetest.chat_send_player(customer:get_player_name(),"You are not allowd to buy this!" )
		-- elseif enough_space then
    --   minetest.chat_send_player(customer:get_player_name(),"You don't have the required items in your inventory!")
    -- else
    --   minetest.chat_send_player(customer:get_player_name(),"You don't have enough space in your inventory!")
    -- end
  end
end)




-- Set Buy / Sell
minetest.register_on_player_receive_fields(function(customer, formname, fields)
	if formname == "usershop:usershop_atm" and fields.set_buy_sell ~= nil and fields.set_buy_sell ~= "" then
		local pos = default.usershop_current_atm_shop_position[customer:get_player_name()]
		local meta = minetest.get_meta(pos)
		if meta:get_string("usershop:bs") == "Buy" then
			meta:set_string("usershop:bs", "Sell")
		else
			meta:set_string("usershop:bs", "Buy")
		end

		usershop_show_spec_atm(customer)
	end
end)

-- Set Price
minetest.register_on_player_receive_fields(function(customer, formname, fields)
	if formname == "usershop:usershop_atm" and fields.set_price ~= nil and fields.set_price ~= "" then
		local pos = default.usershop_current_atm_shop_position[customer:get_player_name()]
		local meta = minetest.get_meta(pos)
		if tonumber(fields.price_field) ~= nil then
			meta:set_int("usershop:price", fields.price_field)
		end;
		usershop_show_spec_atm(customer)
	end
end)
