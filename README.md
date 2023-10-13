# BezierCurve
I wrote this module in 2020 to make BezierCurves more fluid for my Roblox games. I was very passionate about calculus in 2020 (when I was in 10th grade), so I implemented some derivative functions from wikipedia as well. This is a really simple class, really. Here's how it works:

```lua
local bz = BezierCurve:new(p0, p1, p2) -- Initialize a new BezierCurve object with coordinates p0, p1, and p2. They can be vectors, cframes, etc. 
bz:ResolveMiddle() --[[  This is a function that will automatically set the elevation of the curve (p1),
                         based off the distance from p0 to p2. If you want the curve's
                         elevation to be automatically calculated, use
                         this method. ]]
bz:Solve(0) -- This will return the 1st position in the curve.
bz:Solve(1) -- This will return the last position in the curve.
bz:Solve(0.5) -- This will return the midpoint of the curve.
```

You can use this module with a for loop to create easy curves. 
Here's an example, that makes a part go in a curve.:

```lua
local bz = BezierCurve:new(part1.Position, Vector3.new(0, 0, 0), part2.Position)
-- NOTE that we can set "p1" to the zero vector, because it will be overridden in the next line.
bz:ResolveMiddle()
for i = 1, 100 do 
  local alpha = i / 100
  part1.Position = bz:Solve(alpha)
  game:GetService("RunService").RenderStepped:Wait()
end 
```
