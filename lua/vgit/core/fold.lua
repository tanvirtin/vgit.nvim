local fold = {}

function fold.create(top, bot)
  return vim.cmd(string.format('%s,%sfo', top, bot))
end

function fold.delete_all(top, bot)
  return vim.cmd('norm! zE')
end

return fold
