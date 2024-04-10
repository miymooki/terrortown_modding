--#region CVars
local cvarRadius = CreateConVar("ttt_laggrenade_radius", 400, { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED },
    "The radius of the lag grenade in units.")
local cvarDuration = CreateConVar("ttt_laggrenade_duration", 10, { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED },
    "The duration of the lag grenade in seconds.")
local cvarFPS = CreateConVar("ttt_laggrenade_fps", 5, { FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED },
    "The FPS limit of the lag grenade.")
--#endregion

if SERVER then
    AddCSLuaFile()
end

DEFINE_BASECLASS("ttt_basegrenade_proj")

ENT.Type = "anim"
ENT.Base = "ttt_basegrenade_proj"
ENT.Model = Model("models/weapons/w_eq_flashbang_thrown.mdl")

local explodeSound = Sound("npc/assassin/ball_zap1.wav")

function ENT:Initialize()
    self:SetColor(Color(255, 0, 0, 255))
    if BaseClass then
        return BaseClass.Initialize(self)
    end
end

function ENT:Explode(tr)
    if CLIENT then return end
    local pos = self:GetPos()

    self:Remove()

    net.Start("ttt_laggrenade_detonation")
    net.WriteVector(pos)
    net.Broadcast()

    -- Effects
    sound.Play(explodeSound, pos, 100, 100)
    local effectData = EffectData()
    effectData:SetStart(pos)
    effectData:SetOrigin(pos)
    util.Effect("Explosion", effectData, true, true)
    util.Effect("cball_explode", effectData, true, true)
end

if SERVER then
    util.AddNetworkString("ttt_laggrenade_detonation")
else
    ---@type {[number]: {pos: Vector, expires: number, nextparticle: number}}
    local activeGrenades = {}

    net.Receive("ttt_laggrenade_detonation", function()
        local pos = net.ReadVector()
        local expires = CurTime() + cvarDuration:GetFloat()

        table.insert(activeGrenades, { pos = pos, expires = expires, nextparticle = 0 })
    end)

    hook.Add("RenderScreenspaceEffects", "ttt_laggrenade", function()
        local pos = LocalPlayer():GetPos()
        local fps = cvarFPS:GetFloat()
        local radius = cvarRadius:GetFloat()
        local renderingLag = false

        for id, detData in pairs(activeGrenades) do
            if detData.expires < CurTime() then
                table.remove(activeGrenades, id)
            elseif not renderingLag and pos:Distance(detData.pos) < cvarRadius:GetFloat() then
                renderingLag = true
                DrawMotionBlur(1, 1, 1 / fps)

                -- Draw a "low signal" icon
                local x = ScrW() / 2 - 40
                local y = ScrH() / 2 + 100

                surface.SetDrawColor(0, 0, 0, 255)
                surface.DrawRect(x + 1, y + 61, 20, 30)
                surface.DrawOutlinedRect(x + 31, y + 31, 20, 60)
                surface.DrawOutlinedRect(x + 61, y + 1, 20, 90)
                surface.SetDrawColor(255, 0, 0, 255)
                surface.DrawRect(x, y + 60, 20, 30)
                surface.DrawOutlinedRect(x + 30, y + 30, 20, 60)
                surface.DrawOutlinedRect(x + 60, y, 20, 90)
            end
            if detData.nextparticle < CurTime() then
                detData.nextparticle = CurTime() + 0.2

                local e = EffectData()
                e:SetOrigin(detData.pos + Vector(
                    math.random(-radius, radius),
                    math.random(-radius, radius),
                    math.random(-radius, radius)
                ))
                e:SetNormal(Vector(0, 0, 1))
                e:SetMagnitude(1)
                e:SetRadius(16)
                util.Effect("Sparks", e, true, true)
            end
        end
    end)

    hook.Add("TTTEndRound", "ttt_laggrenade", function()
        activeGrenades = {}
    end)
end
