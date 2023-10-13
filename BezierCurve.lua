local class = function(nc, newf) -- I did not create this class function.
	nc = nc or {}
	nc.__index = nc
	local classDebugData
	function nc:new(o, ...)
		o = o or {}
		if type(o) == 'table' and not getmetatable(o) then -- cannot assume all classes contruct using base object
			setmetatable(o, nc)
		end
		if newf then
			o = newf(o, ...) or o
		end
		if type(o) == 'table' and not getmetatable(o) then
			setmetatable(o, nc)
		end
		return o
	end
	return nc
end

local BitBuffer = require(game:GetService("ReplicatedStorage").BitBuffer)
local BezierCurve = class({

}, function(p0, p1, p2)
	local self = {
		type = 'default',
		visualizationParts = {},
		adorneeConnections = {},
		testParts = {},
		defaultTestColor = BrickColor.White()
	}
	if (not p0 and not p1 and not p2) then 
		return false
	end
	self.p0 = p0 
	self.p1 = p1 
	self.p2 = p2 
	self.testThread = {}
	
	if typeof(p0) == 'Vector3' and typeof(p1) == 'Vector3' and typeof(p2) == 'Vector3' then 
		self.type = 'Vector3'
		self.v0 = p0 
		self.v1 = p1
		self.v2 = p2 
	elseif typeof(p0) == 'Vector2' and typeof(p1) == 'Vector2' and typeof(p1) == 'Vector2' then 
		self.type = 'Vector2'
		self.v0 = p0 
		self.v1 = p1
		self.v2 = p2 
	elseif typeof(p0) == 'CFrame' and typeof(p1) == 'CFrame' and typeof(p2) == 'CFrame' then 
		self.type = 'CFrame'
		self.cf0 = p0
		self.cf1 = p1 
		self.cf2 = p2 
	elseif typeof(p0) == 'number' and typeof(p1) == 'number' and typeof(p2) == 'number' then 
		self.type = 'default'
	else
		error('BezierCurve: Received invalid inputs')
		print(typeof(self.p0))
		print(typeof(self.p1))
		print(typeof(self.p2))
	end
	return self 
end)

local function solveBezier(p0, p1, p2, t, str)
	if not str or str == 'default' then 
		return p1 + (1 - t) ^ 2 * (p0 - p1) + t ^ 2 * (p2 - p1)
	elseif str == 'derivative' then 
		return 2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)
	elseif str == 'derivative2' then 
		return 2 * (p2 - 2 * p1 + p0)
	end
end

function BezierCurve:SolveDerivative(a)
	return self:Solve(a, function()
		return solveBezier(self.p0, self.p1, self.p2, a, 'derivative')
	end)
end

function BezierCurve:SolveSecondDerivative(a)
	return self:Solve(a, function()
		return solveBezier(self.p0, self.p1, self.p2, a, 'derivative2')
	end)
end

function BezierCurve:SolveAll(a)
	return self:Solve(a), self:SolveDerivative(a), self:SolveSecondDerivative(a)
end

function BezierCurve:SolveBoth(a)
	return self:Solve(a), self:SolveDerivative(a)
end

function BezierCurve:Solve(a, quadBezier)
	if not quadBezier then 
		quadBezier = function(p0, p1, p2, t)
			return solveBezier(p0, p1, p2, t, 'default')
		end
	end
	if self.type == 'default' then 
		return quadBezier(self.p0, self.p1, self.p2, a)
	elseif self.type == 'Vector2' then 
		local t = {
			{self.v0.x, self.v1.x, self.v2.x},
			{self.v0.y, self.v1.y, self.v2.y},
		}
		local qBzX, qBzY;
		for i = 1, 2 do 
			if i == 1 then 
				qBzX = quadBezier(t[i][i], t[i][i+1], t[i][i+2], a)
			elseif i == 2 then 
				qBzY = quadBezier(t[i][i-1], t[i][i], t[i][i+1], a)
			end
		end
		return Vector2.new(qBzX, qBzY)
	elseif self.type == 'Vector3' then 
		local t = {
			{self.v0.x, self.v1.x, self.v2.x},
			{self.v0.y, self.v1.y, self.v2.y},
			{self.v0.z, self.v1.z, self.v2.z}
		}
		local qBzX, qBzY, qBzZ;
		for i = 1, 3 do 
			if i == 1 then 
				qBzX = quadBezier(t[i][i], t[i][i+1], t[i][i+2], a)
			elseif i == 2 then 
				qBzY = quadBezier(t[i][i-1], t[i][i], t[i][i+1], a)
			elseif i == 3 then 
				qBzZ = quadBezier(t[i][i-2], t[i][i-1], t[i][i], a)
			end
		end
		return Vector3.new(qBzX, qBzY, qBzZ)
	elseif self.type == 'CFrame' then 
		local mat = {
			{self.cf0.p, self.cf0 - self.cf0.p},
			{self.cf1.p, self.cf1 - self.cf1.p},
			{self.cf2.p, self.cf2 - self.cf2.p}
		}
		local v3 = {
			{mat[1][1].x, mat[2][1].x, mat[3][1].x},
			{mat[1][1].y, mat[2][1].y, mat[3][1].y},
			{mat[1][1].z, mat[2][1].z, mat[3][1].z},
		}
		local _, _, _, m11, m12, m13, m21, m22, m23, m31, m32, m33 = self.cf0:components()
		local _, _, _, m112, m122, m132, m212, m222, m232, m312, m322, m332 = self.cf1:components()
		local _, _, _, m113, m123, m133, m213, m223, m233, m313, m323, m333 = self.cf2:components()
		local o = {
			{m11, m12, m13, m21, m22, m23, m31, m32, m33},
			{m112, m122, m132, m212, m222, m232, m312, m322, m332},
			{m113, m123, m133, m213, m223, m233, m313, m323, m333}
		}
		local qBzX, qBzY, qBzZ, qBzm11, qBzm12, qBzm13, qBzm21, qBzm22, qBzm23, qBzm31, qBzm32, qBzm33;
		for i = 1, 9 do
			if i == 1 then 
				qBzX = quadBezier(v3[i][i], v3[i][i+1], v3[i][i+2], a)
				qBzm11 = quadBezier(o[i][i], o[i+1][i], o[i+2][i], a)
			elseif i == 2 then 
				qBzY = quadBezier(v3[i][i-1], v3[i][i], v3[i][i+1], a)
				qBzm12 = quadBezier(o[i-1][i], o[i][i], o[i+1][i], a)
			elseif i == 3 then 
				qBzZ = quadBezier(v3[i][i-2], v3[i][i-1], v3[i][i], a)
				qBzm13 = quadBezier(o[i-2][i], o[i-1][i], o[i][i], a)
			elseif i == 4 then 
				qBzm21 = quadBezier(o[i-3][i], o[i-2][i], o[i-1][i], a)
			elseif i == 5 then 
				qBzm22 = quadBezier(o[i-4][i], o[i-3][i], o[i-2][i], a)
			elseif i == 6 then 
				qBzm23 = quadBezier(o[i-5][i], o[i-4][i], o[i-3][i], a)
			elseif i == 7 then 
				qBzm31 = quadBezier(o[i-6][i], o[i-5][i], o[i-4][i], a)
			elseif i == 8 then 
				qBzm32 = quadBezier(o[i-7][i], o[i-6][i], o[i-5][i], a)
			elseif i == 9 then 
				qBzm33 = quadBezier(o[i-8][i], o[i-7][i], o[i-6][i], a)
			end
		end
		return CFrame.new(qBzX, qBzY, qBzZ, qBzm11, qBzm12, qBzm13, qBzm21, qBzm22, qBzm23, qBzm31, qBzm32, qBzm33)
	end
end

function BezierCurve:UpdateCoordinates()
	if self.type == 'Vector3' or self.type == 'Vector2' then 
		self.v0 = self.p0 
		self.v1 = self.p1
		self.v2 = self.p2
		return {self.v0, self.v1, self.v2}
	elseif self.type == 'CFrame' then 
		self.cf0 = self.p0
		self.cf1 = self.p1
		self.cf2 = self.p2
		return {self.cf0, self.cf1, self.cf2}
	end
	return {self.p0, self.p1, self.p2}
end

function BezierCurve:GetElevation(elevation, max)
	local start;
	if self.type == 'Vector3' or self.type == 'Vector2' or self.type == 'CFrame' then 
		start = self.p0.y
	end
	if not elevation then 
		if self.type == 'Vector3' or self.type == 'Vector2' then 
			elevation = start + math.max((self.p2 - self.p0).magnitude, max or 5)
		elseif self.type == 'CFrame' then 
			elevation = start + math.max((self.p2.p - self.p0.p).magnitude, max or 5)
		elseif self.type == 'default' then 
			elevation = math.max((self.p2 - self.p0), max or 5)
		end 
	end
	return (start and start + elevation) or elevation
end

function BezierCurve:ResolveMiddle(elevation)
	self:UpdateCoordinates()
	if self.type == 'Vector3' then 
		local elevation = self:GetElevation(elevation)
		self.p1 = Vector3.new(self.p0.x + (self.p2.x - self.p0.x) * 0.5, elevation, self.p0.z + (self.p2.z - self.p0.z) * 0.5)
	elseif self.type == 'Vector2' then 
		local elevation = self:GetElevation(elevation)
		self.p1 = Vector2.new(self.p0.x + (self.p2.x - self.p0.x) * 0.5, self.p0.y + (self.p2.y - self.p0.y) * 0.5)
	elseif self.type == 'CFrame' then 
		local elevation = self:GetElevation(elevation)
		self.p1 = CFrame.new(self.p0.p.x + (self.p2.p.x - self.p0.p.x) * 0.5, elevation, self.p0.p.z + (self.p2.p.z - self.p0.p.z) * 0.5)
	elseif self.type == 'default' then 
		self.p1 = self.p2 - self.p0 * 0.5
	end
	self:UpdateCoordinates()
	return self.p1 
end

function BezierCurve:Is3D()
	return (self.type == 'Vector3' or self.type == 'CFrame')
end

function BezierCurve:SetAdorneeParts(...) 
	if not self:Is3D() then 
		return false 
	end
	local adorneeConnections = self.adorneeConnections
	local args = {...}
	if #adorneeConnections > 0 then 
		for i = 1, #adorneeConnections do 
			adorneeConnections[i]:disconnect()
		end
	end
	for i = 1, #args do 
		local part = args[i]
		part.Anchored = true
		if self.type == 'Vector3' then 
			self['p'..tostring(i - 1)] = part.Position
			self:UpdateCoordinates()
			if self.testThread then 
				self:Draw()
			end
		elseif self.type == 'CFrame' then 
			self['p'..tostring(i - 1)] = part.CFrame 
			self:UpdateCoordinates()
			if self.testThread then 
				self:Draw()
			end
		end
		local cn = part.Changed:connect(function(prop)
			if self.type == 'Vector3' and prop == 'Position' then 
				self['p'..tostring(i - 1)] = part.Position
				self:UpdateCoordinates()
				if self.testThread then 
					self:Draw()
				end
			elseif self.type == 'CFrame' and (prop == 'Position' or prop == 'Orientation') then 
				self['p'..tostring(i - 1)] = part.CFrame
				self:UpdateCoordinates()
				if self.testThread then 
					self:Draw()
				end
			end
		end)
		table.insert(adorneeConnections, cn)
	end
	return true 
end

function BezierCurve:SetPointContext(point, fn, looped)
	if self.type == 'default' then 
		return 
	end
	local function step()
		self['p'..tostring(point)] = fn()
		if self.testThread then 
			self:Draw()
		end
		self:UpdateCoordinates()
	end
	spawn(function()
		if looped then 
			while game:GetService('RunService').RenderStepped:Wait() do 
				step()
			end
		else
			step()
		end
	end)
end

function BezierCurve:Visualize()
	if not self:Is3D() or not self.type == 'Vector2' then 
		return false 
	end
	local visualizationParts = self.visualizationParts
	local t = {'p0', 'p1', 'p2'}
	local colors = {self.defaultTestColor, BrickColor.new('Sage green'), BrickColor.new('Bright red')}
	for i = 1, 3 do 
		local part;
		if self:Is3D() then 
			part = Utilities.Create('Part'){
				Anchored = true,
				CanCollide = false, 
				Material = Enum.Material.Neon,
				BrickColor = colors[i],
				Name = t[i],
				Size = Vector3.new(0.5, 0.5, 0.5),
				Transparency = 0,
				Parent = workspace
			}
		elseif self.type == 'Vector2' then 
			part = Utilities.Create('Frame'){
				BackgroundColor3 = self.defaultTestColor,
				Name = 'BezierTest',
				Size = UDim2.new(0, 10, 0, 10),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Parent = Utilities.gui,
			}
		end
		if self.type == 'CFrame' then 
			part.CFrame = self[t[i]]
		elseif self.type == 'Vector3' then 
			part.Position = self[t[i]]
		elseif self.type == 'Vector2' then 
			part.Position = UDim2.new(0, self[t[i]].X, 0, self[t[i]].Y)
		end
		if visualizationParts[i] then 
			pcall(function()
				visualizationParts[i]:Destroy()
			end)
		end
		visualizationParts[i] = part 
	end
end

function BezierCurve:ClearVisuals()
	if not self:Is3D() then 
		return false 
	end
	local visualizationParts = self.visualizationParts
	for i = 1, #visualizationParts do 
		if visualizationParts[i] then 
			pcall(function()
				visualizationParts[i]:Destroy()
			end)
		end
	end 
end

function BezierCurve:Draw()
	spawn(function()
		self:Test(2, 0.001)
	end)
end

function BezierCurve:Intersects(c1, c2)
	local intersects = false 
	if c1.type ~= c2.type then 
		return false 
	end
	local considerationMagnitude = 2
	local considerationMultiplier = 1
	for i = 1, 100 do 
		local a = i / 100
		local sln = c1:Solve(a)
		for j = 1, 100 do 
			local sln2 = c2:Solve(j / 100)
			local dx, dy, dz;
			if c1.type == 'CFrame' then 
				dx = math.abs(sln.p.x - sln2.p.x)
				dy = math.abs(sln.p.y - sln2.p.y)
				dz = math.abs(sln.p.z - sln2.p.z)
			elseif c1.type == 'Vector3' or c1.type == 'Vector2' then 
				dx = math.abs(sln.x - sln2.x)
				dy = math.abs(sln.y - sln2.y)
				if c1.type == 'Vector3' then 
					dz = math.abs(sln.z - sln2.z)
				end
			elseif c1.type == 'default' then 
				dx = math.abs(sln - sln2)
			end
			if (c1:Is3D() and c2:Is3D()) then 
				if (dx <= considerationMagnitude * considerationMultiplier and dy <= considerationMagnitude * considerationMultiplier and dz <= considerationMagnitude * considerationMultiplier) then 
					intersects = {a, j}
					break 
				end
			elseif (c1.type == 'Vector2') then 
				if (dx <= considerationMagnitude * considerationMultiplier and dy <= considerationMagnitude * considerationMultiplier) then 
					intersects = {a, j}
					break 
				end
			elseif (c1.type == 'default') then 
				if (dx <= considerationMagnitude) then 
					intersects = {a, j}
					break
				end
			end
			if intersects then 
				break
			end
		end
	end
	return intersects
end

function BezierCurve:Test(testNumber, d)
	local testParts = self.testParts
	local d = d or 2 
	if not testNumber or testNumber == 1 then 
		local part = Utilities.Create('Part'){
			Anchored = true,
			CanCollide = false, 
			Material = Enum.Material.Neon,
			BrickColor = self.defaultTestColor,
			Name = 'BezierTest',
			Size = Vector3.new(1, 1, 1),
			Transparency = 0,
			Parent = workspace
		}
		local thisThread = {}
		self.testThread = thisThread
		Utilities.Tween(d, 'easeOutCubic', function(a)
			if self.testThread ~= thisThread then
				return false 
			end
			part.Position = self:Solve(a) 
		end)
		part:Destroy()
	elseif testNumber == 2 then 
		if self:Is3D() then 
			local thisThread = {}
			self.testThread = thisThread
			for _, v in next, testParts do 
				pcall(function()
					v:Destroy()
				end)
			end
			if d < 0.01 then 
				local resolution = 15
				for i = 1, resolution do 
					local part = Utilities.Create('Part'){
						Anchored = true,
						CanCollide = false, 
						Material = Enum.Material.Neon,
						Color = Color3.new(i / resolution, i / resolution, i / resolution),
						Name = 'BezierTest',
						Size = Vector3.new(i / resolution, i / resolution, i / resolution),
						Transparency = 0,
						Parent = workspace
					}
					if self.type == 'Vector3' then 
						part.Position = self:Solve(i / resolution) 
					elseif self.type == 'CFrame' then 
						part.CFrame = self:Solve(i / resolution) 
					end
					testParts[#testParts + 1] = part 
				end
				game:GetService('RunService').RenderStepped:Wait()
			else
				Utilities.Tween(d, 'easeOutCubic', function(a)
					if self.testThread ~= thisThread then
						return false 
					end
					local part = Utilities.Create('Part'){
						Anchored = true,
						CanCollide = false, 
						Material = Enum.Material.Neon,
						BrickColor = BrickColor.new("Institutional white"),
						Name = 'BezierTest',
						Size = Vector3.new(1, 1, 1),
						Transparency = 0,
						Parent = workspace
					}
					if self.type == 'Vector3' then 
						part.Position = self:Solve(a) 
					elseif self.type == 'CFrame' then 
						part.CFrame = self:Solve(a) 
					end
					testParts[#testParts + 1] = part 
				end)
			end
		elseif self.type == 'Vector2' then 
			local thisThread = {}
			self.testThread = thisThread
			for _, v in next, testParts do 
				pcall(function()
					v:Destroy()
				end)
			end
			if d < 0.01 then 
				local resolution = 50
				for i = 1, resolution do 
					if self.testThread ~= thisThread then
						return false 
					end
					local soln = self:Solve(i / resolution)
					local solnNext = self:Solve((i + 1) / resolution)
					local part = Utilities.Create('Frame'){
						BackgroundColor3 = Color3.new(i / resolution, i / resolution, i / resolution),
						Name = 'BezierTest',
						Size = UDim2.new(0, resolution / 10, 0, resolution / 10),
						BackgroundTransparency = 0,
						Parent = Utilities.gui,
						BorderSizePixel = 0,
						Position = UDim2.new(0, soln.X, 0, soln.Y),
						Rotation = math.deg(math.atan2(solnNext.Y, solnNext.X))
					}
					testParts[#testParts + 1] = part 
				end
				game:GetService('RunService').RenderStepped:Wait()
			else
				local part = Utilities.Create('Frame'){
					BackgroundColor3 = self.defaultTestColor,
					Name = 'BezierTest',
					Size = UDim2.new(0, 10, 0, 10),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					Parent = Utilities.gui,
				}
				Utilities.Tween(d, 'easeOutCubic', function(a)
					if self.testThread ~= thisThread then
						return false 
					end
					local soln = self:Solve(a)
					part.Position = UDim2.new(0, soln.X, 0, soln.Y)
					testParts[#testParts + 1] = part 
				end)
			end
		end
		return testParts 
	end
	return true 
end

function BezierCurve:Serialize()
	local buffer = BitBuffer.Create()
	local version = 0
	buffer:WriteUnsigned(6, version)
	buffer:WriteString(self.type)
	if self.type == 'Vector3' then 
		buffer:WriteFloat32(self.p0.X)
		buffer:WriteFloat32(self.p0.Y)
		buffer:WriteFloat32(self.p0.Z)
		buffer:WriteFloat32(self.p1.X)
		buffer:WriteFloat32(self.p1.Y)
		buffer:WriteFloat32(self.p1.Z)
		buffer:WriteFloat32(self.p2.X)
		buffer:WriteFloat32(self.p2.Y)
		buffer:WriteFloat32(self.p2.Z)
	elseif self.type == 'Vector2' then 
		buffer:WriteFloat32(self.p0.X)
		buffer:WriteFloat32(self.p0.Y)
		buffer:WriteFloat32(self.p1.X)
		buffer:WriteFloat32(self.p1.Y)
		buffer:WriteFloat32(self.p2.X)
		buffer:WriteFloat32(self.p2.Y)
	elseif self.type == 'CFrame' then 
		buffer:WriteCFrame(self.cf0)
		buffer:WriteCFrame(self.cf1)
		buffer:WriteCFrame(self.cf2)
	elseif self.type == 'default' then 
		buffer:WriteFloat32(self.p0)
		buffer:WriteFloat32(self.p1)
		buffer:WriteFloat32(self.p2)
	end
	return buffer:ToBase64()
end

function BezierCurve:Deserialize(str)
	local buffer = BitBuffer.Create()
	buffer:FromBase64(str)
	local version = buffer:ReadUnsigned(6)
	local curveType = buffer:ReadString()
	local t = {}
	local newCurve;
	if curveType == 'Vector3' then 
		for i = 1, 3 do 
			for j = 1, 3 do 
				if not t[i] then 
					t[i] = {}
				end
				t[i][j] = buffer:ReadFloat32()
			end
		end
		newCurve = BezierCurve:new(Vector3.new(t[1][1], t[1][2], t[1][3]), Vector3.new(t[2][1], t[2][2], t[2][3]), Vector3.new(t[3][1], t[3][2], t[3][3]))
	elseif curveType == 'Vector2' then 
		for i = 1, 3 do 
			for j = 1, 2 do 
				if not t[i] then 
					t[i] = {}
				end
				t[i][j] = buffer:ReadFloat32()
			end
		end
		newCurve = BezierCurve:new(Vector2.new(t[1][1], t[1][2]), Vector2.new(t[2][1], t[2][2]), Vector2.new(t[3][1], t[3][2]))
	elseif curveType == 'CFrame' then 
		for i = 1, 3 do 
			if not t[1] then 
				t[1] = {}
			end
			t[1][i] = buffer:ReadCFrame()
		end
		newCurve = BezierCurve:new(t[1][1], t[1][2], t[1][3])
	elseif curveType == 'default' then 
		for i = 1, 3 do
			if not t[1] then 
				t[1] = {}
			end
			t[1][i] = buffer:ReadFloat32()
		end
		newCurve = BezierCurve:new(t[1][1], t[1][2], t[1][3])
	end
	if not newCurve then 
		error('BitBuffer was not able to deserialize BezierCurve.')
		return false
	end
	return newCurve
end
return BezierCurve
