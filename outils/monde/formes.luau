-- Formes des pièces pour les contrôles de carte (verifier-bords.luau, couloirs.luau) : lecture d'une pièce et distance
-- d'un point à son volume réel (bloc orienté, boule, cylindre, coin).
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

local Formes = {}

-- Une pièce, réduite à des nombres : centre, axes, demi-dimensions, forme, boîte alignée.
function Formes.lire(d)
	local cf, s = d.CFrame, d.Size
	local forme = "Bloc"
	if d:IsA("WedgePart") then
		forme = "Coin"
	elseif d:IsA("Part") and d.Shape.Name ~= "Block" then
		forme = d.Shape.Name
	end
	local r, u, l = cf.RightVector, cf.UpVector, -cf.LookVector
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	if forme == "Ball" then
		hx = math.min(hx, hy, hz)
		hy, hz = hx, hx
	elseif forme == "Cylinder" then
		hy = math.min(hy, hz)
		hz = hy
	end
	local e = Vector3.new(
		math.abs(r.X) * hx + math.abs(u.X) * hy + math.abs(l.X) * hz,
		math.abs(r.Y) * hx + math.abs(u.Y) * hy + math.abs(l.Y) * hz,
		math.abs(r.Z) * hx + math.abs(u.Z) * hy + math.abs(l.Z) * hz
	)
	return {
		part = d,
		nom = d:GetFullName(),
		c = cf.Position,
		r = r,
		u = u,
		l = l,
		hx = hx,
		hy = hy,
		hz = hz,
		forme = forme,
		mn = cf.Position - e,
		mx = cf.Position + e,
	}
end

-- Distance d'un point (x, y, z) au volume de la pièce (0 dedans).
function Formes.distance(p, x: number, y: number, z: number): number
	local dx, dy, dz = x - p.c.X, y - p.c.Y, z - p.c.Z
	local a = dx * p.r.X + dy * p.r.Y + dz * p.r.Z
	local b = dx * p.u.X + dy * p.u.Y + dz * p.u.Z
	local c = dx * p.l.X + dy * p.l.Y + dz * p.l.Z
	if p.forme == "Ball" then
		return math.max(0, math.sqrt(a * a + b * b + c * c) - p.hx)
	elseif p.forme == "Cylinder" then
		local ex, er = math.max(0, math.abs(a) - p.hx), math.max(0, math.sqrt(b * b + c * c) - p.hy)
		return math.sqrt(ex * ex + er * er)
	end
	local ex, ey, ez = math.max(0, math.abs(a) - p.hx), math.max(0, math.abs(b) - p.hy), math.max(0, math.abs(c) - p.hz)
	local ext = math.sqrt(ex * ex + ey * ey + ez * ez)
	if p.forme == "Coin" then
		-- Coin : la pente va du bas de la face -Z au haut de la face +Z ; au-dessus du plan, on est dehors.
		local n = math.sqrt(p.hy * p.hy + p.hz * p.hz)
		ext = math.max(ext, (b * p.hz - c * p.hy) / n)
	end
	return ext
end

return Formes
