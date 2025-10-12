local BaseLayoutCalculator = require('vgit.ui.calculators.BaseLayoutCalculator')
local FlexLayoutCalculator = require('vgit.ui.calculators.FlexLayoutCalculator')
local AbsoluteLayoutCalculator = require('vgit.ui.calculators.AbsoluteLayoutCalculator')

local RootLayoutCalculator = BaseLayoutCalculator:extend()

function RootLayoutCalculator:constructor()
  return {
    flex_calculator = FlexLayoutCalculator(),
    absolute_calculator = AbsoluteLayoutCalculator(),
  }
end

function RootLayoutCalculator:calculate_flex(spec, parent_bounds)
  return self.flex_calculator:calculate_flex(spec, parent_bounds)
end

function RootLayoutCalculator:calculate_absolute(spec, parent_bounds)
  return self.absolute_calculator:calculate_absolute(spec, parent_bounds)
end

return RootLayoutCalculator
