local lazy = require('vgit.core.lazy')

local BaseLayoutCalculator = lazy('vgit.ui.calculators.BaseLayoutCalculator')
local FlexLayoutCalculator = lazy('vgit.ui.calculators.FlexLayoutCalculator')
local AbsoluteLayoutCalculator = lazy('vgit.ui.calculators.AbsoluteLayoutCalculator')

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
