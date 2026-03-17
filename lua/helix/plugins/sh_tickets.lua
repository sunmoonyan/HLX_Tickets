local PLUGIN = PLUGIN

PLUGIN.name = "Tickets"
PLUGIN.author = "Summe & Sunshi"
PLUGIN.description = "Summe TicketSystem port for helix."


ix.command.Add("Ticket", {
    description = "Send a ticket to currently connected admins.",
    privilege = "TicketSystem.CanCreateTicket",
    arguments = {
    },
    OnRun = function(self,client)
        client:ConCommand("TicketSystemCreate")
    end
})

ix.command.Add("Tickets", {
    description = "View all the tickets.",
    privilege = "TicketSystem.CanOpenAdminMenu",
    arguments = {
    },
    OnRun = function(self,client)
        client:ConCommand("TicketSystemAdmin")
    end
})


function TicketSystem:PlayerHasPermission(ply, permission, preventMessage)

    if CAMI.PlayerHasAccess(ply, permission) then
        return true 
    else
        if preventMessage then return false end

        if SERVER then
            ply:TicketMessage(Color(255,0,0), TicketSystem:GetText("MSG_NOPERMS", permission))
        else
            chat.AddText(Color(255,77,77), "[Ticket] ", Color(90,90,90), Color(255,0,0), TicketSystem:GetText("MSG_NOPERMS", permission))
        end
        return false
    end
end

if SERVER then

    TicketSystem.Config.Commands = {
        Creation = {"!ticket"},
        Admin = {"!tickets"},
    }

else

net.Receive("TicketSystem.ChatMessage", function(len)
    chat.AddText(Color(255,77,77), "[Ticket] ", Color(90,90,90), unpack(net.ReadTable()))
end)

local theme = TicketSystem.Config.Theme

TicketSystem.SelectMenu = {}
TicketSystem.CreateMenu = {}

-- These are the options that are called when you right-click on a ticket
local dropdownOptions = {
    {
        shouldShow = function(ticket)
            return not TicketSystem:IsClaimed(ticket)
        end,
        name = TicketSystem:GetText("OPTIONS_CLAIM"),
        icon = "icon16/accept.png",
        func = function(ticketKey)
            net.Start("TicketSystem.ClaimTicket")
            net.WriteInt(ticketKey, 32)
            net.SendToServer()
            TicketSystem.SelectMenu:RefreshOverview()
        end
    },
    {
        shouldShow = function(ticket)
            return TicketSystem:ClaimedBy(LocalPlayer(), ticket)
        end,
        name = TicketSystem:GetText("OPTIONS_CLOSE"),
        icon = "icon16/cross.png",
        func = function(ticketKey)
            net.Start("TicketSystem.CloseTicket")
            net.WriteInt(ticketKey, 32)
            net.SendToServer()
            TicketSystem.SelectMenu:RefreshOverview()
        end
    },
    {
        shouldShow = function(ticket)
            return TicketSystem:ClaimedBy(LocalPlayer(), ticket)
        end,
        name = TicketSystem:GetText("OPTIONS_REOPEN"),
        icon = "icon16/arrow_refresh.png",
        func = function(ticketKey)
            net.Start("TicketSystem.ReopenTicket")
            net.WriteInt(ticketKey, 32)
            net.SendToServer()
            TicketSystem.SelectMenu:RefreshOverview()
        end
    },
    {
        shouldShow = function(ticket)
            return TicketSystem:IsClaimed(ticket)
        end,
        name = TicketSystem:GetText("OPTIONS_GOTO"),
        icon = "icon16/zoom_in.png",
        func = function(ticketKey, ply)
            if ULib then
                RunConsoleCommand("ulx", "goto", ply:Name())
            elseif serverguard then
                serverguard.command.Run("goto", "false", ply:Name())
            elseif sam then
                RunConsoleCommand("sam", "goto", ply:SteamID64())
            end
        end
    },
    {
        shouldShow = function(ticket)
            return TicketSystem:IsClaimed(ticket)
        end,
        name = TicketSystem:GetText("OPTIONS_BRING"),
        icon = "icon16/zoom_out.png",
        func = function(ticketKey, ply)
            if ULib then
                RunConsoleCommand("ulx", "bring", ply:Name())
            elseif serverguard then
                serverguard.command.Run("bring", "false", ply:Name())
            elseif sam then
                RunConsoleCommand("sam", "bring", ply:SteamID64())
            end
        end
    },
    {
        shouldShow = function(ticket)
            return TicketSystem:IsClaimed(ticket)
        end,
        name = TicketSystem:GetText("OPTIONS_RETURN"),
        icon = "icon16/user_go.png",
        func = function(ticketKey, ply)
            if ULib then
                RunConsoleCommand("ulx", "return", ply:Name())
            elseif serverguard then
                serverguard.command.Run("return", "false", ply:Name())
            elseif sam then
                RunConsoleCommand("sam", "return", ply:SteamID64())
            end
        end
    },
}

-- Opens the main ticket overview for staff members
--
function TicketSystem.SelectMenu:OpenMenu()

    if not TicketSystem:PlayerHasPermission(LocalPlayer(), "TicketSystem.CanOpenAdminMenu") then return end

    if self.MainFrame then self.MainFrame:Remove() end

    local width = ScrW() * .6
    local height = ScrH() * .6
    local windowTitle = "Tickets"

    local activeButton

    self.MainFrame = vgui.Create("DFrame")
    self.MainFrame:SetTitle(windowTitle)
    self.MainFrame:SetSize(width, height)
    self.MainFrame:MakePopup()
    self.MainFrame:Center()
    self.MainFrame:SetDraggable(false)

    self.NavBar = vgui.Create("DScrollPanel", self.MainFrame)
    self.NavBar:SetPos(0, height * 0.08)
    self.NavBar:SetSize(width * 0.2, height * 0.9)
    self.NavBar.Paint = function(me,w,h)
        surface.SetDrawColor(Color(theme.bg.r + 8, theme.bg.g + 8, theme.bg.b + 8, 50))
        surface.DrawRect(0, 0, w, h)
    end

    self.MasterPanel = vgui.Create("DPanel", self.MainFrame)
    self.MasterPanel:SetPos(width * 0.22, height * 0.1)
    self.MasterPanel:SetSize(width * 0.78, height * 0.9)
    self.MasterPanel.Paint = function(me,w,h)
    end

    local navButtons = {}
    navButtons[1] = {
        name = TicketSystem:GetText("FRAME_OVERVIEW"),
        color = Color(242,44,3),
        func = function(master)
            self.bgPanel = vgui.Create("DScrollPanel", master)
            self.bgPanel:SetSize(width * .76, height * .86)
            self.bgPanel:SetPos(width * .001, height * .01)
            function self.bgPanel:Paint(w, h) end

            local sbar = self.bgPanel:GetVBar()

            sbar.LerpTarget = 0

            function sbar:AddScroll(dlta)
                local OldScroll = self.LerpTarget or self:GetScroll()
                dlta = dlta * 75
                self.LerpTarget = math.Clamp(self.LerpTarget + dlta, -self.btnGrip:GetTall(), self.CanvasSize + self.btnGrip:GetTall())

                return OldScroll ~= self:GetScroll()
            end

            sbar.Think = function(s)
                local frac = FrameTime() * 5
                if (math.abs(s.LerpTarget - s:GetScroll()) <= (s.CanvasSize / 10)) then
                    frac = FrameTime() * 2
                end
                local newpos = Lerp(frac, s:GetScroll(), s.LerpTarget)
                s:SetScroll(math.Clamp(newpos, 0, s.CanvasSize))
                if (s.LerpTarget < 0 and s:GetScroll() <= 0) then
                    s.LerpTarget = 0
                elseif (s.LerpTarget > s.CanvasSize and s:GetScroll() >= s.CanvasSize) then
                    s.LerpTarget = s.CanvasSize
                end
            end


            function TicketSystem.SelectMenu:RefreshOverview()
                if IsValid(self.bgPanel) then self.bgPanel:Clear() end

                net.Start("TicketSystem.RequestTickets")
                net.SendToServer()

                net.Receive("TicketSystem.TicketsSent", function()

                    local ticketList = net.ReadTable()

                    if #ticketList == 0 then
                        local DLabel = vgui.Create("DLabel", self.bgPanel)
                        DLabel:SetPos(ScrW() * .12, ScrH() * .18)
                        DLabel:SetSize(ScrW() * .2, ScrH() * .1)
                        DLabel:SetFont("TicketSystem.NoTicketsInfo")
                        DLabel:SetText(TicketSystem:GetText("OVERVIEW_NOTICKETS"))
                        DLabel:SetColor(color_white)
                        DLabel:SetContentAlignment(5)
                    end

                    local transistionTime = 0

                    for key, ticket in SortedPairsByMemberValue(ticketList, "status") do

                        local sender = player.GetBySteamID64(ticket.sender_id)
                        local admin
    
                        if not IsValid(sender) then continue end
                        if not sender:IsPlayer() then continue end
    
                        if ticket.status == 2 then
                            admin = player.GetBySteamID64(ticket.admin_id)
                            if not IsValid(admin) then continue end
                            if not admin:IsPlayer() then continue end
                        end
    
                        local statusName, statusColor = TicketSystem:GetTicketStatus(ticket.status)
    
                        local senderNick = sender:GetName()
                        local adminNick
                        if ticket.status == 2 then
                            adminNick = admin:GetName()
                        end
    
                        
                        local ticketPanel = vgui.Create("DButton", self.bgPanel)
                        ticketPanel:Dock(TOP)
                        ticketPanel:SetText("")
                        ticketPanel:DockMargin(0, 0, 0, ScrH() * .01)
                        ticketPanel:SetSize(ScrW() * .3, ScrH() * .07)
                        ticketPanel:SetAlpha(0)
                        ticketPanel.state = "collapsed"

                        ticketPanel.OldPaint = ticketPanel.Paint
                        local wStatic = width * .76
                        local hStatic = ScrH() * .07

                        function ticketPanel:Paint(w, h)
                            if self.OldPaint then
                                self:OldPaint(w, h)
                            end
                            

                            local titleWidth = draw.SimpleText(ticket.title, "TicketSystem.TicketTitle", w * .01, hStatic * .06, Color(255,255,255), TEXT_ALIGN_LEFT)
                            draw.DrawText(senderNick, "TicketSystem.TicketText1", w * .05, hStatic * .55, Color(146,146,146), TEXT_ALIGN_LEFT)
    
                            local time = (ticket.time - CurTime()) / 60
    
                            draw.DrawText(TicketSystem:GetText("OVERVIEW_TICKET_TIMESTAMP", math.Round(-time, 0)), "TicketSystem.TicketText1", w * .97, hStatic * .55, Color(146,146,146), TEXT_ALIGN_RIGHT)
    
                            draw.RoundedBox(0, w * .02 + titleWidth, hStatic * .08, w * .1, hStatic * .3, statusColor)
                            draw.DrawText(statusName, "TicketSystem.LabelText", w * .069 + titleWidth, hStatic * .096, Color(255,255,255), TEXT_ALIGN_CENTER)
    
                            if ticket.status == 2 then
                                draw.DrawText(adminNick, "TicketSystem.TicketText1", w * .483, hStatic * .55, Color(146,146,146), TEXT_ALIGN_LEFT)
                            end

                            draw.RoundedBox(5, 0, hStatic * 1.01, w, hStatic * .03, Color(104,104,104, 10))
                        end

                        ticketPanel:AlphaTo(255, 0.2 + transistionTime)
                        transistionTime = transistionTime + 0.3

                        self.Text = vgui.Create("DLabel", ticketPanel)
                        self.Text:SetPos( ScrW() * .005, ScrH() * .08 )
                        self.Text:SetText(ticket.text)
                        self.Text:SetSize(ScrW() * .4, 40)
                        self.Text:SetFont("TicketSystem.TextEntry")
                        self.Text:SetWrap(true)
                        self.Text:SetAutoStretchVertical( true )
                        
                        local senderAvatar = vgui.Create("TicketSystem.Avatar", ticketPanel)
                        senderAvatar:SetPlayer(sender, 64)
                        senderAvatar:SetPos(ScrW() * .003, ScrH() * .035)
                        senderAvatar:SetSize(ScrH() * .03, ScrH() * .03)
    
                        if ticket.status == 2 then
                            local adminAvatar = vgui.Create("TicketSystem.Avatar", ticketPanel)
                            adminAvatar:SetPlayer(sender, 64)
                            adminAvatar:SetPos(ScrW() * .2, ScrH() * .035)
                            adminAvatar:SetSize(ScrH() * .03, ScrH() * .03)
                        end

                        function ticketPanel:DoClick()
                            if self.state == "collapsed" then
                                self:SizeTo(width * .76, ScrH() * .3, 0.7)
                                self.state = "extended"
                            else
                                self:SizeTo(width * .76, ScrH() * .07, 0.7)
                                self.state = "collapsed"
                            end
                        end

                        function ticketPanel:DoRightClick()
                            local contextMenu = DermaMenu(line)
                            function contextMenu:Paint(width, height) end
        
                            for k, option in pairs(dropdownOptions) do
                                if option.shouldShow(ticket) then
                                    local optionPanel = contextMenu:AddOption(option.name, function()
                                        option.func(key, sender)
                                    end)
        
                                    optionPanel:SetColor(color_white)
                                    optionPanel:SetFont("TicketSystem.Button")
        
              
        
                                    local icon = vgui.Create("DImage", optionPanel)
                                    icon:SetPos(optionPanel:GetWide() * 0.075, optionPanel:GetTall() * 0.15)
                                    icon:SetSize(ScrH() / 67.5, ScrH() / 67.5)
                                    icon:SetImage(option.icon)
                                end
                            end
        
                            contextMenu:Open()
                        end
                    end
                end)

            end
            TicketSystem.SelectMenu:RefreshOverview()
        end,
    }
    navButtons[2] = {
        name = TicketSystem:GetText("FRAME_STAFF"),
        color = Color(126,39,22),
        func = function(master)

            self.bgPanel = vgui.Create("DScrollPanel", master)
            self.bgPanel:SetSize(width * .76, height * .86)
            self.bgPanel:SetPos(width * .001, height * .01)
            function self.bgPanel:Paint(w, h) end
            local sbar = self.bgPanel:GetVBar()


            sbar.LerpTarget = 0

            function sbar:AddScroll(dlta)
                local OldScroll = self.LerpTarget or self:GetScroll()
                dlta = dlta * 75
                self.LerpTarget = math.Clamp(self.LerpTarget + dlta, -self.btnGrip:GetTall(), self.CanvasSize + self.btnGrip:GetTall())

                return OldScroll ~= self:GetScroll()
            end

            sbar.Think = function(s)
                local frac = FrameTime() * 5
                if (math.abs(s.LerpTarget - s:GetScroll()) <= (s.CanvasSize / 10)) then
                    frac = FrameTime() * 2
                end
                local newpos = Lerp(frac, s:GetScroll(), s.LerpTarget)
                s:SetScroll(math.Clamp(newpos, 0, s.CanvasSize))
                if (s.LerpTarget < 0 and s:GetScroll() <= 0) then
                    s.LerpTarget = 0
                elseif (s.LerpTarget > s.CanvasSize and s:GetScroll() >= s.CanvasSize) then
                    s.LerpTarget = s.CanvasSize
                end
            end

            for k, v in SortedPairs(TicketSystem.Config.Usergroups, true) do
                for _, ply in pairs(player.GetAll()) do

                    if k == ply:GetUserGroup() then

                        local usrGrpName, usrGrpColor = TicketSystem:GetUsergroupInfo(ply)
                        local plyNick = ply:GetName()

                        local plyPanel = vgui.Create("DButton", self.bgPanel)
                        plyPanel:Dock(TOP)
                        plyPanel:SetText("")
                        plyPanel:DockMargin(0, 0, 0, ScrH() * .01)
                        plyPanel:SetSize(ScrW() * .3, ScrH() * .05)

                        plyPanel.OldPaint = plyPanel.Paint

                        function plyPanel:Paint(w, h)
                            if self.OldPaint then
                                self:OldPaint(w, h)
                            end
                            local titleWidth = draw.SimpleText(plyNick, "TicketSystem.TicketText1", w * .07, h * .28, Color(114,114,114), TEXT_ALIGN_LEFT)

                            draw.RoundedBox(0, w * .09 + titleWidth, h * .3, w * .15, h * .35, usrGrpColor)
                            draw.DrawText(usrGrpName, "TicketSystem.LabelText", w * .165 + titleWidth, h * .3, Color(255,255,255), TEXT_ALIGN_CENTER)
                        end

                        local senderAvatar = vgui.Create("TicketSystem.Avatar", plyPanel)
                        senderAvatar:SetPlayer(ply, 64)
                        senderAvatar:SetPos(ScrW() * .003, ScrH() * .006)
                        senderAvatar:SetSize(ScrH() * .04, ScrH() * .04)
                    end
                end
            end

            

        end,
    }

    for k, v in pairs(navButtons) do
        local navButton = vgui.Create("TicketSystem.NavButton", self.NavBar)
        navButton:Dock(TOP)
        navButton:DockMargin(10, 0, 10, ScrH() * .005)
        navButton:SetText(v.name)
        navButton:SetTall(height * .05)
        navButton:SetRound(10)
        navButton.DoClick = function()
            windowTitle = "Ticket".." - ".. v.name
            self.MasterPanel:Clear()
            self.MasterPanel.Paint = function() end
            v.func(self.MasterPanel)
            activeButton = navButton
        end
    end


    navButtons[1].func(self.MasterPanel)
end


function TicketSystem.CreateMenu:OpenMenu()

    if not TicketSystem:PlayerHasPermission(LocalPlayer(), "TicketSystem.CanCreateTicket") then return end

    if self.MainFrame then self.MainFrame:Remove() end

    local width = ScrW() * .2
    local height = ScrH() * .3
    local windowTitle = "Ticket"

    self.MainFrame = vgui.Create("DFrame")
    self.MainFrame:SetTitle("")
    self.MainFrame:SetSize(width, height)
    self.MainFrame:MakePopup()
    self.MainFrame:Center()
    self.MainFrame:SetTitle(windowTitle.. " - ".. TicketSystem:GetText("CREATE_FRAMETITLE"))
    self.MainFrame:SetDraggable(false)

    self.TitleEntry = vgui.Create("DTextEntry", self.MainFrame)
    self.TitleEntry:SetSize(width * .8, height * .08)
    self.TitleEntry:SetPos(width * .1, height * .25)
    self.TitleEntry:SetEnterAllowed(false)
    self.TitleEntry:SetMultiline(false)
    self.TitleEntry:SetPlaceholderText(TicketSystem:GetText("CREATE_TITLEPLACEHOLDER"))

    self.TextEntry = vgui.Create("DTextEntry", self.MainFrame)
    self.TextEntry:SetSize(width * .8, height * .3)
    self.TextEntry:SetPos(width * .1, height * .35)
    self.TextEntry:SetEnterAllowed(false)
    self.TextEntry:SetMultiline(true)
    self.TextEntry:SetPlaceholderText(TicketSystem:GetText("CREATE_TEXTPLACEHOLDER"))
    
    self.Submit = vgui.Create("DButton", self.MainFrame)
    self.Submit:SetSize( width * .6, height * .08 )
    self.Submit:SetPos( width * .2, height * .7 )
    self.Submit:SetText(TicketSystem:GetText("CREATE_SUBMIT"))
    self.Submit.DoClick = function()

        if self.TitleEntry:GetText() == "" then return end
        if self.TextEntry:GetText() == "" then return end

        net.Start("TicketSystem.AddTicket")
        net.WriteString(self.TitleEntry:GetText())
        net.WriteString(self.TextEntry:GetText())
        net.SendToServer()

        self.MainFrame:Remove()
    end

end

--Concommands

concommand.Add("TicketSystemAdmin", function()
    TicketSystem.SelectMenu:OpenMenu()
end)

concommand.Add("TicketSystemCreate", function()
    TicketSystem.CreateMenu:OpenMenu()
end)

--Networking Commands

net.Receive("TicketSystem.OpenTicketCreation", function()
    TicketSystem.CreateMenu:OpenMenu()
end)

net.Receive("TicketSystem.OpenTicketAdmin", function()
    TicketSystem.SelectMenu:OpenMenu()
end)

local NavButton = {}

function NavButton:Init()
    self.Color = TicketSystem.Config.Theme.navButton
    self.HoverColor = Color(self.Color.r + 16, self.Color.g + 16, self.Color.b + 16, 255)
    self.DisabledColor = Color(180, 180, 180)

    self.RoundRadius = 0
    self.round1 = false
    self.round2 = false
    self.round3 = false
    self.round4 = false

    self:SetFont("TicketSystem.Button")
end

function NavButton:DoClickInternal()
    surface.PlaySound("UI/buttonclick.wav")
end

function NavButton:SetDisabledButton(color)
    self.DisabledColor = color
end

function NavButton:SetRound(radius)
    self.RoundRadius = radius

    if self.RoundRadius > 0 then
        self:SetRoundCorners(true, true, true, true)
    else
        self:SetRoundCorners(false, false, false, false)
    end
end

function NavButton:SetRoundCorners(round1, round2, round3, round4)
    self.round1 = round1
    self.round2 = round2
    self.round3 = round3
    self.round4 = round4
end

vgui.Register("TicketSystem.NavButton", NavButton, "DButton")

end