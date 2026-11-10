return function()
    require("@src/features/buttons/generic_teleport").new(CFrame.new(-20000, 19713.9609, -20000), function()
        local vh = workspace:FindFirstChild("Voidheart");
        if not vh then return end
        return vh:FindFirstChild("VoidheartVoidWarp")
    end, function()
        local root = local_player and local_player.root_part
        if not root then return false end
        return root.CFrame.Y > 19990
    end):run();
end
